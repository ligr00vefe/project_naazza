import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ message: '지원하지 않는 요청이야.' }, 405)

  let body: { username?: unknown; pin?: unknown }
  try { body = await request.json() } catch { return json({ message: '요청 형식이 올바르지 않아.' }, 400) }
  const username = String(body.username ?? '').trim().toLowerCase()
  const pin = String(body.pin ?? '')
  if (!/^[a-z0-9_]{3,20}$/.test(username) || !/^\d{4}$/.test(pin)) {
    return json({ message: '아이디 또는 비밀번호가 맞지 않아.' }, 401)
  }

  const url = Deno.env.get('SUPABASE_URL')!
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const admin = createClient(url, serviceRole, { auth: { autoRefreshToken: false, persistSession: false } })
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    request.headers.get('cf-connecting-ip') ?? 'unknown'
  const { data: allowed, error: rateError } = await admin.rpc(
    'consume_signup_attempt',
    { p_client_key: `login:${username}:${ip}` },
  )
  if (rateError || allowed !== true) {
    return json({ message: '로그인 시도가 너무 많아. 한 시간 뒤 다시 시도해 줘.' }, 429)
  }

  const password = await internalPassword(serviceRole, username, pin)
  const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  let result = await auth.auth.signInWithPassword({
    email: `${username}@accounts.naazza.invalid`,
    password,
  })

  if (result.error && username === 'admin') {
    const legacy = await auth.auth.signInWithPassword({
      email: 'admin@accounts.naazza.invalid',
      password: `Naazza#${pin}#v1`,
    })
    if (!legacy.error && legacy.data.user) {
      await admin.auth.admin.updateUserById(legacy.data.user.id, { password })
      result = legacy
    }
  }

  if (result.error || !result.data.session) {
    return json({ message: '아이디 또는 비밀번호가 맞지 않아.' }, 401)
  }
  return json({
    access_token: result.data.session.access_token,
    refresh_token: result.data.session.refresh_token,
  }, 200)
})

async function internalPassword(secret: string, username: string, pin: string) {
  const bytes = new TextEncoder().encode(`${secret}:${username}:${pin}`)
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
