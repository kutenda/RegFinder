# RegFinder V4 — production setup

The customer-facing product is complete as a polished static prototype. Four external connections are deliberately left credential-driven because they require accounts/keys or an authorised commercial data arrangement.

## 1. Database + admin authentication
Use the included `database-schema.sql` with a hosted Postgres/Supabase-style backend.
Protect all admin writes. Do not expose a service-role key in `index.html`.

## 2. Payments
Create payment sessions server-side only **after** a registration has been re-verified.
Recommended state flow:

`enquiry -> awaiting_verification -> verified -> awaiting_payment -> paid -> fulfilment -> complete`

Never take payment for a plate merely because an old cached result says it is available.

## 3. Transactional email
Send:
- enquiry received
- registration verified / final price
- payment receipt
- fulfilment/assignment instructions
- finder-result alert

## 4. Registration inventory
Do not scrape or republish DVLA's website without permission.
Plug an authorised dealer/feed/source into the inventory adapter and save:
`source_name`, `source_reference`, `source_checked_at`, and `status`.

## 5. Legal launch checklist
Before accepting live UK consumers, replace the included draft Terms/Privacy/Cancellation text with wording matching:
- your legal trading identity/address/contact details
- exact sourcing/agency role
- when the service begins
- cancellation/refund rights
- payment/fulfilment process
- privacy retention/processors/cookies
- VAT position where applicable

## 6. GitHub Pages
`index.html`, `manifest.webmanifest`, and `sw.js` can be hosted on Pages for the storefront.
Server-side verification, secrets, payment webhooks and privileged database writes must run on a backend/serverless service, not public GitHub Pages.

## What is already working
Search, filters, favourites, basket, fee tiers, finder requests, order enquiries, order references, admin inventory, admin fee editor, CSV exports, JSON backup/restore, draft legal/help pages, mobile layout and PWA manifest.
