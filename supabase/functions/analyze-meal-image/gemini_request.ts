export class ImageAnalysisTimeout extends DOMException {
  readonly stage: 'gemini_waiting' | 'gemini_body'
  readonly headersMs: number | null
  constructor(stage: 'gemini_waiting' | 'gemini_body', headersMs: number | null) {
    super('AI response deadline exceeded', 'TimeoutError')
    this.stage = stage
    this.headersMs = headersMs
  }
}

// The deadline includes response-body transfer, not just receiving headers.
export async function readImageAnalysis(
  model: string,
  request: (model: string, signal: AbortSignal) => Promise<Response>,
  timeoutMs = 25000,
): Promise<{ payload: Record<string, unknown>; status: number; ok: boolean; headersMs: number; totalMs: number }> {
  const started = performance.now()
  const controller = new AbortController()
  let receivedHeadersMs: number | null = null
  let timer: ReturnType<typeof setTimeout> | undefined
  const deadline = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new ImageAnalysisTimeout(receivedHeadersMs === null ? 'gemini_waiting' : 'gemini_body', receivedHeadersMs))
      controller.abort()
    }, timeoutMs)
  })
  try {
    return await Promise.race([
      (async () => {
        const response = await request(model, controller.signal)
        const headersMs = Math.round(performance.now() - started)
        receivedHeadersMs = headersMs
        const decoded = await response.json().catch((error) => {
          if (controller.signal.aborted) throw error
          return {}
        })
        const payload = decoded && typeof decoded === 'object' && !Array.isArray(decoded) ? decoded as Record<string, unknown> : {}
        return { payload, status: response.status, ok: response.ok, headersMs, totalMs: Math.round(performance.now() - started) }
      })(),
      deadline,
    ])
  } finally {
    clearTimeout(timer)
  }
}
