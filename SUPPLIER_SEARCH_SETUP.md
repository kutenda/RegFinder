# RegFinder live supplier search

RegFinder now has a server-side supplier-search adapter at `supabase/functions/search-registrations/index.ts`.

## Intended flow

Customer search -> Supabase Edge Function -> authorised supplier API/feed -> plate + source price -> RegFinder fee -> customer price.

The supplier credential stays server-side. It must never be put in `index.html`, GitHub Pages, or other browser code.

## Environment variables

Set these as Supabase Edge Function secrets after obtaining an authorised feed:

- `REGFINDER_SUPPLIER_SEARCH_URL` - supplier's documented search endpoint.
- `REGFINDER_SUPPLIER_API_KEY` - supplier API credential, if required.

The connector sends the customer's search as the `q` query-string parameter and accepts either a JSON array or `{ "results": [...] }`.

Each result should map to:

```json
{
  "registration": "KU73 NDA",
  "source_price": 399,
  "style": "Current",
  "vehicle_age_note": "Age rules apply",
  "source_reference": "supplier-id"
}
```

The Edge Function calculates the RegFinder service fee server-side and returns `source_price`, `service_fee`, and `customer_price`.

## Current limitation

No authorised live supplier endpoint is configured yet. Until one is supplied, the public site continues searching verified Supabase inventory and Admin can bulk-import plate/price lists. Do not configure this function against a website whose terms prohibit automated extraction.

## When a supplier is chosen

1. Adjust the adapter to the supplier's exact documented response format.
2. Add its endpoint and credential as Supabase secrets.
3. Deploy `search-registrations`.
4. Call the Edge Function from the storefront after/alongside the local inventory search.
5. Re-verify availability before accepting payment.
