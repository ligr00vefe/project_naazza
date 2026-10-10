import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { normalizeBarcode, productCandidate } from './product.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' })
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json(401, { error: 'authentication_required' })
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !key) return json(503, { error: 'server_configuration_error' })
  const client = createClient(url, key, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await client.auth.getUser(authorization.slice(7))
  if (error || !data.user) return json(401, { error: 'invalid_session' })
  let body: Record<string, unknown>
  try { body = await request.json() } catch { return json(400, { error: 'invalid_json' }) }
  const barcode = normalizeBarcode(body?.barcode)
  if (!barcode) return json(400, { error: 'invalid_barcode' })
  try {
    const fields = 'product_name_ko,product_name,brands,nutriments,serving_quantity,serving_quantity_unit'
    const result = await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=${fields}`, {
      headers: { 'User-Agent': 'NAAZZA/1.0 (food diary; barcode lookup)' },
      signal: AbortSignal.timeout(10000),
    })
    if (result.status === 404) return json(200, { product: null })
    if (!result.ok) return json(502, { error: 'product_lookup_unavailable' })
    const payload = await result.json()
    if (payload.status === 0 || !payload.product) return json(200, { product: null })
    const product = productCandidate(payload.product)
    if (!product) return json(422, { error: 'product_nutrition_missing' })
    return json(200, { product, source: 'open_food_facts' })
  } catch {
    return json(502, { error: 'product_lookup_unavailable' })
  }
})