# MK POSHAK HOUSE — Supabase + Vercel edition

This package is prepared source code, not an already deployed site. It contains the existing inventory, sales/profit dashboard, Excel export, photo PDF printing, and JSON backup/restore, with Supabase persistence.

## Connection check

The supplied project URL and anon key successfully reached the Auth settings endpoint (HTTP 200). Email login is enabled and public signup is currently enabled. The inventory endpoint returned PGRST205 (table not found in schema cache), so run the SQL setup before signing in to the app. Database writes, photo upload, and Vercel deployment are not yet verified.

## 1. Preserve existing data first
Open your OLD local HTML tool in the same browser where stock was entered. Download its full JSON backup before clearing browser site data. The cloud site cannot read another file/address's localStorage. Records already erased without a backup cannot be recovered by this upgrade.

## 2. Supabase setup
1. Create or select your Supabase project at https://supabase.com/dashboard.
2. In SQL Editor, paste and run `supabase-setup.sql`.
3. In Authentication → Users, create your owner user with an email and password (confirm the user). Disable new user signups in Auth settings for a private owner-only tool. There is no public signup button in this app.
4. Get your Project URL and publishable key from the project Connect/API settings. A legacy anon key also works.
5. `public/config.js` is already configured for project `hwmwvfnbuheymefedbzo` using the anon key you supplied. NEVER put a secret key, service_role key, database password, or account password in this file.
6. Each login account owns its own inventory. Use the same owner login on your devices to see the same stock. A separate email account will have separate stock.

## 3. GitHub → Vercel (ready to import)
1. Extract this ZIP. Do not upload the ZIP file itself.
2. Create a private GitHub repository, for example `mk-poshak-inventory`.
3. Upload ALL extracted files and folders into the repository root and commit. The root must show `package.json`, `vercel.json`, `scripts`, `public`, `supabase-setup.sql`, and `README.md`. Do not place them inside an extra project folder.
4. In Vercel choose Add New → Project → Import Git Repository, connect GitHub, and select this repository.
5. Keep Root Directory at the repository root. Click Deploy. `vercel.json` provides the framework, build command, and output folder automatically. No environment variables or paid dependencies are needed for this configured project.
6. Open the deployed HTTPS address and sign in with your Supabase user. The database SQL and owner user must be set up first (sections above).
7. Future commits to the connected production branch trigger new Vercel deployments. Your inventory stays in Supabase across frontend deployments.

Build settings for troubleshooting only: Framework = Other; Build Command = `npm run build`; Output Directory = `dist`; no Install Command. The build uses only built-in Node modules, copies public files into dist, and validates the public configuration and application syntax. There is no Vite dependency.

Local build check: run `npm run build` in the extracted project. Only `dist` is published; the SQL and setup documentation are excluded from the website.

The Vercel URL serves the login page publicly; inventory and photos require your Supabase login and are protected by database/storage policies. This is application authentication, not Vercel's team-only deployment protection.

## 4. Move existing stock
Sign in → Backup, restore & instructions → Restore backup → select the old tool's JSON backup. Review the replacement confirmation. Photos are compressed and uploaded before the inventory transaction. Wait for “Saved to Supabase”. Then log out and back in to confirm your records. Only after this should you clear old browser data.

## Behaviour
- Only successful cloud writes are shown as saved. Internet is required.
- Browser clearing does not delete Supabase records or stored images. You must sign in again.
- Tokens are held in memory, not saved in localStorage. Refresh requires login; expired sessions require signing in again. Unsaved form changes are not persistent.
- JPEG thumbnails are at most **5,000 bytes each** (strict decimal 5 KB). Compression reduces both dimensions and quality; complex photos may become very small. The storage bucket independently enforces 5,000 bytes. The original full-resolution image is not stored.
- A save writes stock and sales together. Revision checks reject stale writes from another phone/tab, reload current stock and ask you to retry. Data refreshes on sign-in, successful writes and conflicts; there is no live push subscription.
- Photo filenames use a SHA-256 digest to deduplicate identical compressed photos per account. Historical photos are immutable. A failed save may leave an unused private photo; it does not change stock.
- Money is kept in paise. Total purchase cost is available stock cost plus recorded sold cost, not a separate supplier purchase ledger. Stock edits are corrections/replenishment at the same unit cost; create another batch for a changed purchase price.
- The database stores one versioned inventory document per owner. This is a small-shop design; it loads the complete history and photos into memory. Consider normalized tables/pagination for very large catalogs.
- Excel includes details, not embedded photos; PDF includes photos via the browser's Print → Save as PDF.

## Validation and launch checks
JavaScript syntax, inherited money calculations, real XLSX generation, configuration and implementation checks were run locally. The Supabase SQL and cloud network flow have not been executed against your account. No live URL has been created yet.

Before real entries, create a test product (5 pieces at ₹250), sell 2 at ₹350, and confirm stock 3 and profit ₹200. Log out and log in after clearing browser site data; verify records and photo return. Verify another account cannot read this account's stock/photos. Test two open devices: the stale save must be rejected. Export Excel/PDF and void the test sale to restore quantity. Use an old JSON backup on an empty test account to verify migration.

Official references:
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/auth-signinwithpassword
- https://vercel.com/docs/deployments
