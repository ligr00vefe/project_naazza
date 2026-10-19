import { identifiedProducts } from './identified_products.ts'
import { analysisDiagnosis, inspectImage } from './analysis_diagnosis.ts'
import { foodIdentity } from './food_identity.ts'
import { readImageAnalysis, ImageAnalysisTimeout } from './gemini_request.ts'
import { imageGenerationConfig } from './generation_config.ts'
import { analysisPrompt } from './analysis_prompt.ts'
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
    "imageQuality": {
      "type": "string",
      "enum": [
        "clear",
        "blurry",
        "too_dark",
        "glare",
        "low_resolution",
        "unknown"
      ]
    },
    "failureReason": {
      "type": "string",
      "enum": [
        "none",
        "no_food",
        "product_unidentified",
        "product_name_unreadable",
        "nutrition_unreadable",
        "low_confidence",
        "unknown"
      ]
    },
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
          "isProduct": {
            "type": "boolean"
          },
          "visibleProductName": {
            "type": "string"
          },
          "nutritionLabelReadable": {
            "type": "boolean"
          },
          "amountG": {
            "type": [
              "number",
              "null"
            ]
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
                "type": [
                  "number",
                  "null"
                ]
              },
              "energyKcal": {
                "type": [
                  "number",
                  "null"
                ]
              },
              "carbohydrateG": {
                "type": [
                  "number",
                  "null"
                ]
              },
              "proteinG": {
                "type": [
                  "number",
                  "null"
                ]
              },
              "fatG": {
                "type": [
                  "number",
                  "null"
                ]
              },
              "sodiumMg": {
                "type": [
                  "number",
                  "null"
                ]
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
          "isProduct",
          "visibleProductName",
          "nutritionLabelReadable",
          "displayName",
          "normalizedName",
          "confidence",
          "amountG",
          "tags",
          "nutrition"
        ]
      }
    },
    "identifiedProducts": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "confidence": {
            "type": "number"
          },
          "amountText": {
            "type": "string"
          },
          "energyKcal": {
            "type": [
              "number",
              "null"
            ]
          },
          "wholePackageEnergy": {
            "type": "boolean"
          }
        },
        "required": [
          "name",
          "confidence",
          "amountText",
          "energyKcal",
          "wholePackageEnergy"
        ]
      }
    }
  },
  "required": [
    "imageQuality",
    "failureReason",
    "foods",
    "identifiedProducts"
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
    const identity = foodIdentity(food)
    if (!identity) return []
    const { displayName, isProduct } = identity
    const normalizedName = typeof food.normalizedName === 'string'
      ? food.normalizedName.trim().slice(0, 80)
      : displayName
    const sourceNutrition = food.nutrition && typeof food.nutrition === 'object'
      ? food.nutrition as UnknownRecord
      : {}

    return [{
      displayName,
      normalizedName: isProduct ? displayName : normalizedName || displayName,
      isProduct,
      confidence: clamp(finiteNumber(food.confidence), 0, 1),
      amountG: isProduct ? finiteNumber(food.amountG) : clamp(finiteNumber(food.amountG, 100), 1, 3000),
      tags: Array.isArray(food.tags)
        ? food.tags
          .filter((tag): tag is string => typeof tag === 'string')
          .map((tag) => tag.trim().slice(0, 30))
          .filter(Boolean)
          .slice(0, 6)
        : [],
      nutrition: {
        baseAmountG: isProduct ? finiteNumber(sourceNutrition.baseAmountG) : clamp(finiteNumber(sourceNutrition.baseAmountG, 100), 1, 1000),
        energyKcal: isProduct ? finiteNumber(sourceNutrition.energyKcal) : clamp(finiteNumber(sourceNutrition.energyKcal), 0, 1000),
        carbohydrateG: isProduct ? finiteNumber(sourceNutrition.carbohydrateG) : clamp(finiteNumber(sourceNutrition.carbohydrateG), 0, 100),
        proteinG: isProduct ? finiteNumber(sourceNutrition.proteinG) : clamp(finiteNumber(sourceNutrition.proteinG), 0, 100),
        fatG: isProduct ? finiteNumber(sourceNutrition.fatG) : clamp(finiteNumber(sourceNutrition.fatG), 0, 100),
        sodiumMg: isProduct ? finiteNumber(sourceNutrition.sodiumMg) : clamp(finiteNumber(sourceNutrition.sodiumMg), 0, 10000),
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

  const imageDownloadStarted = performance.now()
  const { data: image, error: downloadError } = await client.storage
    .from('meals')
    .download(storagePath)
  if (downloadError || !image) {
    console.error('analyze-meal-image: image download failed', downloadError?.message)
    return json(404, { error: 'image_not_found' })
  }
  if (image.size === 0) return json(422, {error:'invalid_image'})
  if (image.size > 10 * 1024 * 1024) {
    return json(413, { error: 'unsupported_image_size' })
  }

  const imageBytes = new Uint8Array(await image.arrayBuffer())
  const imageInfo = inspectImage(imageBytes)
  if (imageInfo.code) return json(422, {error:imageInfo.code})
  const storageMs = Math.round(performance.now() - imageDownloadStarted)
  const geminiStarted = performance.now()
  const requestGemini = async (requestModel: string, signal: AbortSignal): Promise<Response> => {
    return await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(requestModel)}:generateContent`, {
      method: 'POST',
      signal,
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
                mimeType: imageInfo.mime || mimeTypeFor(storagePath, image.type),
                data: toBase64(imageBytes.buffer),
              },
            },
            {
              text: analysisPrompt(locale),
            },
          ],
        }],
        generationConfig: imageGenerationConfig(requestModel, foodSchema),
      }),
    })
  }
  let geminiResponse: Awaited<ReturnType<typeof readImageAnalysis>>
  const usedModel = model
  try {
    geminiResponse = await readImageAnalysis(model, requestGemini)
  } catch (error) {
    const timedOut = error instanceof Error && (error.name === 'TimeoutError' || error.name === 'AbortError')
    const stage = error instanceof ImageAnalysisTimeout ? error.stage : 'gemini_response'
    console.error('analyze-meal-image: Gemini response failed', {
      model, storageMs, geminiMs: Math.round(performance.now()-geminiStarted),
      stage, headersMs: error instanceof ImageAnalysisTimeout ? error.headersMs : null, reason: timedOut ? 'ai_timeout' : 'ai_unavailable',
    })
    return json(timedOut ? 504 : 502, { error: timedOut ? 'ai_timeout' : 'ai_unavailable', stage })
  }

  const geminiPayload = geminiResponse.payload
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
  if (!parsed || typeof parsed !== 'object' || !Array.isArray((parsed as UnknownRecord).foods)) return json(502, {error:'ai_invalid_result'})
  const validatedFoods = sanitizeFoods(parsed)
  const baseDiagnosis = analysisDiagnosis(parsed as UnknownRecord, validatedFoods.length)
  const products = identifiedProducts((parsed as UnknownRecord).identifiedProducts)
  const diagnosis = validatedFoods.length === 0 && products.length > 0
    ? {code: 'product_identified_nutrition_pending', source: 'validated_product_names'}
    : baseDiagnosis
  const foods = diagnosis.code === 'recognized' ? validatedFoods : []
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
    : usedModel

  console.info('analyze-meal-image: completed', {
    storageMs, geminiMs: geminiResponse.totalMs, headersMs: geminiResponse.headersMs,
    model: modelVersion,
    ...usageSummary,
    foodCount: foods.length, identifiedProductCount: products.length,
    diagnosis: diagnosis.code, diagnosisSource: diagnosis.source,
  })
  return json(200, {
    foods,
    identifiedProducts: products,
    diagnosis,
    analysis: {
      model: modelVersion,
      usage: usageSummary,
      tier: 'verify_in_ai_studio',
      timings: { storageMs, headersMs: geminiResponse.headersMs, geminiMs: geminiResponse.totalMs },
    },
  })
})
