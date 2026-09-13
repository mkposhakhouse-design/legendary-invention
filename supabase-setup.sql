-- Run once in your Supabase project's SQL Editor.
begin;
create table if not exists public.mk_inventory (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 1,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.mk_inventory enable row level security;
revoke all on public.mk_inventory from anon, authenticated;
grant select on public.mk_inventory to authenticated;
drop policy if exists mk_inventory_read on public.mk_inventory;
create policy mk_inventory_read on public.mk_inventory for select to authenticated using (owner_id = (select auth.uid()));

-- Serialize the complete stock-and-sales update in one transaction.
-- A stale phone/tab cannot silently overwrite a newer stock balance.
create or replace function public.mk_save_inventory(expected_revision bigint, next_data jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  account uuid := auth.uid();
  actual bigint;
  p jsonb;
  s jsonb;
  k text;
  ids text[] := array[]::text[];
  sale_ids text[] := array[]::text[];
begin
  if account is null then raise exception 'Login required'; end if;
  if expected_revision is null or expected_revision < 0 then raise exception 'Invalid revision'; end if;
  if next_data->>'version' is distinct from '1'
    or jsonb_typeof(next_data->'products') is distinct from 'array'
    or jsonb_typeof(next_data->'sales') is distinct from 'array'
    or octet_length(next_data::text) > 20000000 then
    raise exception 'Invalid inventory backup';
  end if;
  for p in select value from jsonb_array_elements(next_data->'products')
    union all select value->'product' from jsonb_array_elements(next_data->'sales') loop
    foreach k in array array['id','name','type','size','color','vendor','imagePath'] loop
      if jsonb_typeof(p->k) is distinct from 'string' then raise exception 'Invalid product field: %', k; end if;
    end loop;
    foreach k in array array['cost','qty','low'] loop
      if jsonb_typeof(p->k) is distinct from 'number' or (p->>k)::numeric < 0
        or (p->>k)::numeric > 1000000000 or trunc((p->>k)::numeric) <> (p->>k)::numeric then
        raise exception 'Invalid product amount: %',k;
      end if;
    end loop;
    if p->>'imagePath' <> '' and p->>'imagePath' !~ ('^' || account::text || '/[a-f0-9]{64}\.jpg$') then
      raise exception 'Invalid photo owner or path';
    end if;
  end loop;
  for p in select value from jsonb_array_elements(next_data->'products') loop
    if p->>'id' = any(ids) then raise exception 'Duplicate product'; end if;
    ids := array_append(ids,p->>'id');
  end loop;
  for s in select value from jsonb_array_elements(next_data->'sales') loop
    if jsonb_typeof(s->'id') is distinct from 'string' or s->>'id' = any(sale_ids)
      or jsonb_typeof(s->'productId') is distinct from 'string' or not (s->>'productId' = any(ids))
      or jsonb_typeof(s->'date') is distinct from 'string' or s->>'date' !~ '^\d{4}-\d{2}-\d{2}$' then
      raise exception 'Invalid sale reference or date';
    end if;
    perform (s->>'date')::date;
    foreach k in array array['qty','price'] loop
      if jsonb_typeof(s->k) is distinct from 'number' or (s->>k)::numeric < 0
        or (s->>k)::numeric > 1000000000 or trunc((s->>k)::numeric) <> (s->>k)::numeric then
        raise exception 'Invalid sale amount';
      end if;
    end loop;
    if (s->>'qty')::numeric < 1 then raise exception 'Sale quantity must be positive'; end if;
    sale_ids := array_append(sale_ids,s->>'id');
  end loop;
  -- The advisory lock also handles two concurrent first writes.
  perform pg_advisory_xact_lock(hashtextextended(account::text,0));
  select revision into actual from public.mk_inventory where owner_id=account for update;
  if not found then
    if expected_revision <> 0 then raise exception 'Stock changed. Reload and retry.'; end if;
    insert into public.mk_inventory(owner_id,revision,data) values(account,1,next_data);
    return 1;
  end if;
  if actual <> expected_revision then raise exception 'Stock changed on another device. Latest data reloaded; review and retry.'; end if;
  update public.mk_inventory set data=next_data,revision=actual+1,updated_at=now() where owner_id=account;
  return actual+1;
end;
$$;
revoke all on function public.mk_save_inventory(bigint,jsonb) from public,anon;
grant execute on function public.mk_save_inventory(bigint,jsonb) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mk-product-photos','mk-product-photos',false,5000,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=5000,allowed_mime_types=array['image/jpeg'];
drop policy if exists mk_photo_read on storage.objects;
create policy mk_photo_read on storage.objects for select to authenticated
using(bucket_id='mk-product-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists mk_photo_upload on storage.objects;
create policy mk_photo_upload on storage.objects for insert to authenticated
with check(bucket_id='mk-product-photos' and (storage.foldername(name))[1]=(select auth.uid())::text
and name ~ ('^' || (select auth.uid())::text || '/[a-f0-9]{64}\.jpg$'));
-- Images are immutable: no update or delete permission in the app.
-- Historical sale photos stay intact after product edits.
commit;
