import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ message: '지원하지 않는 요청이야.' }, 405)

  const parsed = await parseCredentials(request)
  if ('error' in parsed) return json({ message: parsed.error }, 400)

  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, serviceRole, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  if (!await consumeAttempt(admin, request, `signup:${parsed.username}`)) {
    return json({ message: '회원가입 요청이 너무 많아. 한 시간 뒤 다시 시도해 줘.' }, 429)
  }

  const password = await internalPassword(serviceRole, parsed.username, parsed.pin)
  const { error } = await admin.auth.admin.createUser({
    email: `${parsed.username}@accounts.naazza.invalid`,
    password,
    email_confirm: true,
    user_metadata: { username: parsed.username },
    app_metadata: { role: 'member' },
  })
  if (error) {
    const duplicate = error.code === 'email_exists' ||
      error.code === 'user_already_exists' ||
      error.message.toLowerCase().includes('already')
    return json(
      { message: duplicate ? '이미 사용 중인 아이디야.' : '회원가입을 처리하지 못했어.' },
      duplicate ? 409 : 400,
    )
  }
  return json({ username: parsed.username }, 201)
})

async function parseCredentials(request: Request) {
  let body: { username?: unknown; pin?: unknown }
  try { body = await request.json() } catch { return { error: '요청 형식이 올바르지 않아.' } }
  const username = String(body.username ?? '').trim().toLowerCase()
  const pin = String(body.pin ?? '')
  if (!/^[a-z0-9_]{3,20}$/.test(username)) return { error: '아이디는 영문 소문자, 숫자, 밑줄로 3~20자 입력해 줘.' }
  if (!/^\d{4}$/.test(pin)) return { error: '비밀번호를 확인해 줘.' }
  return { username, pin }
}

async function consumeAttempt(admin: ReturnType<typeof createClient>, request: Request, scope: string) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    request.headers.get('cf-connecting-ip') ?? 'unknown'
  const { data, error } = await admin.rpc('consume_signup_attempt', { p_client_key: `${scope}:${ip}` })
  return !error && data === true
}

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
