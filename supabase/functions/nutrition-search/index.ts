import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Keep the generation schema compact; sanitize numeric bounds and list sizes below.
const responseSchema = {
  "type": "object",
  "properties": {
    "candidates": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "displayName": {
            "type": "string"
          },
          "normalizedName": {
            "type": "string"
          },
          "confidence": {
            "type": "number"
          },
          "amountG": {
            "type": "number"
          },
          "tags": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "nutrition": {
            "type": "object",
            "properties": {
              "baseAmountG": {
                "type": "number"
              },
              "energyKcal": {
                "type": "number"
              },
              "carbohydrateG": {
                "type": "number"
              },
              "proteinG": {
                "type": "number"
              },
              "fatG": {
                "type": "number"
              },
              "sodiumMg": {
                "type": "number"
              }
            },
            "required": [
              "baseAmountG",
              "energyKcal",
              "carbohydrateG",
              "proteinG",
              "fatG",
              "sodiumMg"
            ]
          }
        },
        "required": [
          "displayName",
          "normalizedName",
          "confidence",
          "amountG",
          "tags",
          "nutrition"
        ]
      }
    }
  },
  "required": [
    "candidates"
  ]
} as const

type UnknownRecord = Record<string, unknown>

function json(status: number, body: UnknownRecord) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function finiteNumber(value: unknown, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(Math.max(value, minimum), maximum)
}

function sanitizeCandidates(value: unknown) {
  if (!value || typeof value !== 'object') return []
  const candidates = (value as UnknownRecord).candidates
  if (!Array.isArray(candidates)) return []
  return candidates.slice(0, 5).flatMap((item) => {
    if (!item || typeof item !== 'object') return []
    const candidate = item as UnknownRecord
    const displayName = typeof candidate.displayName === 'string'
      ? candidate.displayName.trim().slice(0, 80)
      : ''
    if (!displayName) return []
    const normalizedName = typeof candidate.normalizedName === 'string'
      ? candidate.normalizedName.trim().slice(0, 80)
      : displayName
    const sourceNutrition = candidate.nutrition && typeof candidate.nutrition === 'object'
      ? candidate.nutrition as UnknownRecord
      : {}
    return [{
      displayName,
      normalizedName: normalizedName || displayName,
      confidence: clamp(finiteNumber(candidate.confidence), 0, 1),
      amountG: clamp(finiteNumber(candidate.amountG, 100), 1, 3000),
      tags: Array.isArray(candidate.tags)
        ? candidate.tags
          .filter((tag): tag is string => typeof tag === 'string')
          .map((tag) => tag.trim().slice(0, 30))
          .filter(Boolean)
          .slice(0, 6)
        : [],
      nutrition: {
        baseAmountG: clamp(finiteNumber(sourceNutrition.baseAmountG, 100), 1, 1000),
        energyKcal: clamp(finiteNumber(sourceNutrition.energyKcal), 0, 1000),
        carbohydrateG: clamp(finiteNumber(sourceNutrition.carbohydrateG), 0, 100),
        proteinG: clamp(finiteNumber(sourceNutrition.proteinG), 0, 100),
        fatG: clamp(finiteNumber(sourceNutrition.fatG), 0, 100),
        sodiumMg: clamp(finiteNumber(sourceNutrition.sodiumMg), 0, 10000),
      },
    }]
  })
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    return json(401, { error: 'authentication_required' })
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
  const model = Deno.env.get('GEMINI_MODEL') || 'gemini-3.5-flash-lite'
  if (!supabaseUrl || !publishableKey || !geminiApiKey) {
    console.error('nutrition-search: server environment is missing')
    return json(503, { error: 'ai_not_configured' })
  }

  const client = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: userData, error: userError } = await client.auth.getUser(
    authorization.slice('Bearer '.length),
  )
  if (userError || !userData.user) return json(401, { error: 'invalid_session' })

  let body: UnknownRecord
  try {
    body = await request.json() as UnknownRecord
  } catch {
    return json(400, { error: 'invalid_json' })
  }
  const query = typeof body.query === 'string' ? body.query.trim() : ''
  const locale = body.locale === 'en-US' ? 'en-US' : 'ko-KR'
  if (!query || query.length > 80) return json(400, { error: 'invalid_query' })

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`
  let response: Response
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiApiKey },
      body: JSON.stringify({
        contents: [{
          role: 'user',
          parts: [{
            text: locale === 'ko-KR'
              ? `음식 검색어 "${query}"와 가장 가까운 일반적인 음식 후보를 최대 5개 반환하세요. 영양정보는 100g 기준의 보수적인 추정값이고 amountG는 일반적인 1회 섭취량입니다. 질병이나 건강 상태를 추론하지 마세요.`
              : `Return up to 5 common foods matching "${query}". Nutrition is a conservative estimate per 100g and amountG is a typical serving. Do not infer health conditions.`,
          }],
        }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseJsonSchema: responseSchema,
          temperature: 0.2,
          maxOutputTokens: 2048,
        },
      }),
    })
  } catch (error) {
    console.error('nutrition-search: Gemini network error', error)
    return json(502, { error: 'ai_unavailable' })
  }

  const payload = await response.json().catch(() => ({})) as UnknownRecord
  if (!response.ok) {
    const reason = response.status === 429 ? 'ai_free_quota_exhausted' : 'ai_request_failed'
    console.error('nutrition-search: Gemini request failed', { status: response.status, model })
    return json(response.status === 429 ? 429 : 502, { error: reason })
  }
  const candidates = Array.isArray(payload.candidates) ? payload.candidates : []
  const first = candidates[0] as UnknownRecord | undefined
  const content = first?.content as UnknownRecord | undefined
  const parts = Array.isArray(content?.parts) ? content.parts : []
  const text = parts
    .map((part) => part && typeof part === 'object' ? (part as UnknownRecord).text : null)
    .find((part): part is string => typeof part === 'string')
  if (!text) return json(502, { error: 'ai_empty_result' })

  let parsed: unknown
  try {
    parsed = JSON.parse(text)
  } catch {
    return json(502, { error: 'ai_invalid_result' })
  }
  const usage = payload.usageMetadata && typeof payload.usageMetadata === 'object'
    ? payload.usageMetadata as UnknownRecord
    : {}
  const usageSummary = {
    promptTokens: finiteNumber(usage.promptTokenCount),
    outputTokens: finiteNumber(usage.candidatesTokenCount),
    totalTokens: finiteNumber(usage.totalTokenCount),
  }
  const modelVersion = typeof payload.modelVersion === 'string' ? payload.modelVersion : model
  const sanitized = sanitizeCandidates(parsed)
  console.info('nutrition-search: completed', {
    model: modelVersion,
    ...usageSummary,
    candidateCount: sanitized.length,
  })
  return json(200, {
    candidates: sanitized,
    analysis: { model: modelVersion, usage: usageSummary, tier: 'verify_in_ai_studio' },
  })
})
