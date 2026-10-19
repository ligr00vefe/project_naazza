import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { searchPublicNutrition } from '../_shared/public_nutrition.ts'
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' })
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json(401, { error: 'authentication_required' })
  const url = Deno.env.get('SUPABASE_URL'), key = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !key) return json(503, { error: 'server_not_configured' })
  const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await client.auth.getUser(authorization.slice(7))
  if (error || !data.user) return json(401, { error: 'invalid_session' })
  let body: Record<string, unknown>
  try { body = await request.json() } catch { return json(400, { error: 'invalid_json' }) }
  if (!body || typeof body !== 'object') return json(400, { error: 'invalid_json' })
  const query = typeof body.query === 'string' ? body.query.trim() : ''
  if (!query || query.length > 80) return json(400, { error: 'invalid_query' })
  const page = body.page === undefined ? 1 : body.page
  if (typeof page !== 'number' || !Number.isInteger(page) || page < 1 || page > 100) return json(400, { error: 'invalid_page' })
  const result = await searchPublicNutrition(query, Deno.env.get('DATA_GO_KR_API_KEY'), { page })
  return json(200, result)
})
