import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Keep the generation schema compact; sanitize numeric bounds and list sizes below.
const foodSchema = {
  "type": "object",
  "properties": {
    "foods": {
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
    "foods"
  ]
} as const

type UnknownRecord = Record<string, unknown>

function json(status: number, body: UnknownRecord) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function mimeTypeFor(path: string, blobType: string) {
  if (blobType.startsWith('image/')) return blobType
  const extension = path.split('.').pop()?.toLowerCase()
  if (extension === 'png') return 'image/png'
  if (extension === 'webp') return 'image/webp'
  if (extension === 'heic' || extension === 'heif') return 'image/heic'
  return 'image/jpeg'
}

function toBase64(buffer: ArrayBuffer) {
  const bytes = new Uint8Array(buffer)
  const chunkSize = 0x8000
  let binary = ''
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize))
  }
  return btoa(binary)
}

function finiteNumber(value: unknown, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(Math.max(value, minimum), maximum)
}

function sanitizeFoods(value: unknown) {
  if (!value || typeof value !== 'object') return []
  const foods = (value as UnknownRecord).foods
  if (!Array.isArray(foods)) return []

  return foods.slice(0, 12).flatMap((item) => {
    if (!item || typeof item !== 'object') return []
    const food = item as UnknownRecord
    const displayName = typeof food.displayName === 'string'
      ? food.displayName.trim().slice(0, 80)
      : ''
    if (!displayName) return []
    const normalizedName = typeof food.normalizedName === 'string'
      ? food.normalizedName.trim().slice(0, 80)
      : displayName
    const sourceNutrition = food.nutrition && typeof food.nutrition === 'object'
      ? food.nutrition as UnknownRecord
      : {}

    return [{
      displayName,
      normalizedName: normalizedName || displayName,
      confidence: clamp(finiteNumber(food.confidence), 0, 1),
      amountG: clamp(finiteNumber(food.amountG, 100), 1, 3000),
      tags: Array.isArray(food.tags)
        ? food.tags
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
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') {
    return json(405, { error: 'method_not_allowed' })
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    return json(401, { error: 'authentication_required' })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
  const model = Deno.env.get('GEMINI_MODEL') || 'gemini-3.5-flash-lite'
  if (!supabaseUrl || !publishableKey) {
    console.error('analyze-meal-image: Supabase environment is missing')
    return json(500, { error: 'server_configuration_error' })
  }
  if (!geminiApiKey) {
    console.error('analyze-meal-image: GEMINI_API_KEY is missing')
    return json(503, { error: 'ai_not_configured' })
  }

  let body: UnknownRecord
  try {
    body = await request.json() as UnknownRecord
  } catch {
    return json(400, { error: 'invalid_json' })
  }
  const storagePath = typeof body.storagePath === 'string'
    ? body.storagePath.trim()
    : ''
  const locale = body.locale === 'en-US' ? 'en-US' : 'ko-KR'
  if (!storagePath || storagePath.length > 300 || storagePath.includes('..')) {
    return json(400, { error: 'invalid_storage_path' })
  }

  const client = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const token = authorization.slice('Bearer '.length)
  const { data: userData, error: userError } = await client.auth.getUser(token)
  if (userError || !userData.user) {
    return json(401, { error: 'invalid_session' })
  }
  if (!storagePath.startsWith(`${userData.user.id}/`)) {
    return json(403, { error: 'storage_path_forbidden' })
  }

  const { data: image, error: downloadError } = await client.storage
    .from('meals')
    .download(storagePath)
  if (downloadError || !image) {
    console.error('analyze-meal-image: image download failed', downloadError?.message)
    return json(404, { error: 'image_not_found' })
  }
  if (image.size === 0 || image.size > 10 * 1024 * 1024) {
    return json(413, { error: 'unsupported_image_size' })
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`
  let geminiResponse: Response
  try {
    geminiResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiApiKey,
      },
      body: JSON.stringify({
        contents: [{
          role: 'user',
          parts: [
            {
              inlineData: {
                mimeType: mimeTypeFor(storagePath, image.type),
                data: toBase64(await image.arrayBuffer()),
              },
            },
            {
              text: locale === 'ko-KR'
                ? '사진에 보이는 음식 또는 식품 포장 제품을 식별하세요. 포장 제품은 읽을 수 있는 제품명과 브랜드를 사용하고, 보이지 않는 이름은 지어내지 마세요. 영양표가 읽히면 표시된 기준량을 baseAmountG로 변환하고 그 기준의 영양값을 사용하세요. 나트륨은 mg입니다. 일반 음식이나 영양표가 안 보이는 제품의 영양값은 보수적으로 추정하고 tags에 영양 추정을 넣으세요. 제품은 표시된 1회 섭취량을 amountG로 사용하고 불명확하면 100g을 사용하세요. 음식이나 식품 포장이 없으면 foods를 비우세요. 확실하지 않은 식별은 confidence를 낮추세요. 건강 상태나 질병을 추론하지 마세요.'
                : 'Identify visible foods or packaged food products. Read visible product names and brands without inventing names. When a nutrition label is legible, convert its reference quantity to baseAmountG in grams and return nutrition for that quantity, with sodium in mg. Otherwise conservatively estimate nutrition and add an estimated nutrition tag. Use the labeled serving weight for amountG or 100g when unknown. Return empty foods if no food or food packaging is visible. Lower confidence when uncertain. Do not infer health conditions.',
            },
          ],
        }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseJsonSchema: foodSchema,
          temperature: 0.2,
          maxOutputTokens: 2048,
        },
      }),
    })
  } catch (error) {
    console.error('analyze-meal-image: Gemini network error', error)
    return json(502, { error: 'ai_unavailable' })
  }

  const geminiPayload = await geminiResponse.json().catch(() => ({})) as UnknownRecord
  if (!geminiResponse.ok) {
    const reason = geminiResponse.status === 429 ? 'ai_free_quota_exhausted' : 'ai_request_failed'
    console.error('analyze-meal-image: Gemini request failed', {
      status: geminiResponse.status,
      model,
      reason,
    })
    return json(geminiResponse.status === 429 ? 429 : 502, { error: reason })
  }

  const candidates = Array.isArray(geminiPayload.candidates)
    ? geminiPayload.candidates
    : []
  const firstCandidate = candidates[0] as UnknownRecord | undefined
  const content = firstCandidate?.content as UnknownRecord | undefined
  const parts = Array.isArray(content?.parts) ? content.parts : []
  const text = parts
    .map((part) => part && typeof part === 'object' ? (part as UnknownRecord).text : null)
    .find((part): part is string => typeof part === 'string')
  if (!text) {
    console.error('analyze-meal-image: Gemini returned no structured content', { model })
    return json(502, { error: 'ai_empty_result' })
  }

  let parsed: unknown
  try {
    parsed = JSON.parse(text)
  } catch {
    console.error('analyze-meal-image: Gemini returned invalid JSON', { model })
    return json(502, { error: 'ai_invalid_result' })
  }
  const foods = sanitizeFoods(parsed)
  const usage = geminiPayload.usageMetadata && typeof geminiPayload.usageMetadata === 'object'
    ? geminiPayload.usageMetadata as UnknownRecord
    : {}
  const usageSummary = {
    promptTokens: finiteNumber(usage.promptTokenCount),
    outputTokens: finiteNumber(usage.candidatesTokenCount),
    totalTokens: finiteNumber(usage.totalTokenCount),
  }
  const modelVersion = typeof geminiPayload.modelVersion === 'string'
    ? geminiPayload.modelVersion
    : model

  console.info('analyze-meal-image: completed', {
    model: modelVersion,
    ...usageSummary,
    foodCount: foods.length,
  })
  return json(200, {
    foods,
    analysis: {
      model: modelVersion,
      usage: usageSummary,
      tier: 'verify_in_ai_studio',
    },
  })
})
