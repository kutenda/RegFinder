// RegFinder supplier-search Edge Function
// Connects the storefront to an AUTHORISED registration inventory API/feed.
// Do not point this at websites that prohibit automated extraction.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type SupplierResult = {
  registration: string
  source_price: number
  style?: string
  vehicle_age_note?: string
  source_reference?: string
}

function fee(price: number) {
  if (price <= 299) return 29
  if (price <= 499) return 39
  if (price <= 749) return 49
  if (price <= 999) return 59
  if (price <= 1499) return 69
  if (price <= 1999) return 89
  if (price <= 2999) return 119
  if (price <= 4999) return 149
  if (price <= 9999) return 179
  return 249
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { query } = await req.json()
    const q = String(query || '').trim().toUpperCase()
    if (!q || q.length > 20) throw new Error('Enter a valid registration search')

    // Configure these as Supabase Edge Function secrets when an authorised
    // supplier/feed is obtained. Never place supplier credentials in GitHub
    // or browser JavaScript.
    const endpoint = Deno.env.get('REGFINDER_SUPPLIER_SEARCH_URL')
    const apiKey = Deno.env.get('REGFINDER_SUPPLIER_API_KEY')
    if (!endpoint) {
      return Response.json({ configured: false, results: [] }, { headers: cors })
    }

    const url = new URL(endpoint)
    url.searchParams.set('q', q)
    const headers: Record<string,string> = { 'Accept': 'application/json' }
    if (apiKey) headers['Authorization'] = `Bearer ${apiKey}`

    const upstream = await fetch(url, { headers })
    if (!upstream.ok) throw new Error(`Supplier returned ${upstream.status}`)
    const raw = await upstream.json()

    // Expected generic format: either an array or {results:[...]}. The adapter
    // can be changed here when the chosen supplier gives us its exact schema.
    const rows: SupplierResult[] = Array.isArray(raw) ? raw : (raw.results || [])
    const results = rows.slice(0, 100).map((r) => {
      const source = Number(r.source_price)
      const service = fee(source)
      return {
        registration: String(r.registration || '').toUpperCase(),
        source_price: source,
        service_fee: service,
        customer_price: source + service,
        style: r.style || 'Current',
        vehicle_age_note: r.vehicle_age_note || 'Age rules apply',
        source_reference: r.source_reference || null,
      }
    }).filter(r => r.registration && Number.isFinite(r.source_price))

    return Response.json({ configured: true, results }, { headers: { ...cors, 'Cache-Control': 'no-store' } })
  } catch (error) {
    return Response.json({ error: error.message || 'Search failed', results: [] }, { status: 400, headers: cors })
  }
})
