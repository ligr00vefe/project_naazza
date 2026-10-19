// Official contract: https://www.data.go.kr/data/15100064/standard.do
// Never turn a name search result into an automatically accepted product.
export type PublicRow = Record<string, unknown>
export type LookupStatus = 'candidates' | 'not_found' | 'not_configured' | 'timeout' | 'quota_exceeded' | 'authentication_failed' | 'unavailable' | 'invalid_response'
const endpoint = 'https://api.data.go.kr/openapi/tn_pubr_public_nutri_info_api'
function text(v: unknown): string { return typeof v === 'string' ? v.trim().slice(0, 300) : '' }
function number(v: unknown): number | null {
  if (typeof v !== 'number' && typeof v !== 'string') return null
  if (typeof v === 'string' && !/^\d+(?:\.\d+)?$/.test(v.trim())) return null
  const n = Number(v)
  return Number.isFinite(n) && n >= 0 ? n : null
}
export function amount(v: unknown) {
  const m = /^(\d+(?:\.\d+)?)\s*(kg|g|ml|l)$/i.exec(text(v))
  if (!m || Number(m[1]) <= 0) return null
  const unit = m[2].toLowerCase()
  return { value: Number(m[1]) * (['kg', 'l'].includes(unit) ? 1000 : 1), unit: ['ml', 'l'].includes(unit) ? 'ml' : 'g' }
}
export function normalizePublicRow(row: PublicRow, retrievedAt: string) {
  const id = text(row.foodCd), name = text(row.foodNm)
  if (!id || !name) return null
  const basis = amount(row.nutConSrtrQua), size = amount(row.foodSize)
  const nutrition = {
    energyKcal: number(row.enerc), carbohydrateG: number(row.chocdf),
    proteinG: number(row.prot), fatG: number(row.fatce), sodiumMg: number(row.nat),
    sugarG: number(row.sugar), fiberG: number(row.fibtg), saturatedFatG: number(row.fasat),
    transFatG: number(row.fatrn), cholesterolMg: number(row.chole),
    calciumMg: number(row.ca), ironMg: number(row.fe), potassiumMg: number(row.k),
    vitaminA: number(row.vitaRae), vitaminC: number(row.vitc), vitaminD: number(row.vitd),
  }
  return {
    id, name, dataType: text(row.typeNm), dataCode: text(row.dataCd),
    manufacturer: text(row.mkrNm), company: text(row.companyNm),
    importer: text(row.imptrNm), distributor: text(row.rtlBzentyNm),
    reportNumber: text(row.itemMnftrRptNo), imported: text(row.imptYn), origin: text(row.cooNm),
    basis, basisText: text(row.nutConSrtrQua), packageSize: size, packageSizeText: text(row.foodSize),
    nutrition,
    packageEnergyKcal: basis && size && basis.unit === size.unit && nutrition.energyKcal !== null
      ? nutrition.energyKcal * size.value / basis.value : null,
    requiresConfirmation: true,
    source: { provider: 'data.go.kr', recordId: id, sourceName: text(row.srcNm),
      createdAt: text(row.crtYmd), referenceDate: text(row.crtrYmd), retrievedAt },
  }
}
export async function lookupPublicNutrition(query: string, apiKey: string | undefined,
  options: { fetcher?: typeof fetch; timeoutMs?: number; page?: number } = {}) {
  if (!query.trim() || query.length > 80) throw new Error('invalid_query')
  if (!apiKey?.trim()) return { status: 'not_configured' as LookupStatus, candidates: [], totalCount: 0, hasMore: false }
  const url = new URL(endpoint)
  // Accept a decoded key only; URLSearchParams performs encoding exactly once.
  url.searchParams.set('serviceKey', apiKey.trim())
  url.searchParams.set('type', 'json')
  url.searchParams.set('foodNm', query.trim())
  url.searchParams.set('pageNo', String(options.page ?? 1))
  url.searchParams.set('numOfRows', '20')
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), options.timeoutMs ?? 6000)
  const empty = (status: LookupStatus) => ({ status, candidates: [], totalCount: 0, hasMore: false })
  try {
    const response = await (options.fetcher ?? fetch)(url, { signal: controller.signal })
    if (!response.ok) {
      let gateway: PublicRow = {}
      try { gateway = await response.json() as PublicRow } catch {}
      const header = (gateway.OpenAPI_ServiceResponse as PublicRow | undefined)?.cmmMsgHeader as PublicRow | undefined
      const code = String(header?.returnReasonCode ?? '')
      if (['20','21','30','31','32','33'].includes(code)) return empty('authentication_failed')
      return empty(response.status === 429 || code === '22' ? 'quota_exceeded' : 'unavailable')
    }
    let raw: PublicRow
    try { raw = await response.json() as PublicRow } catch { return empty(controller.signal.aborted ? 'timeout' : 'invalid_response') }
    if (!raw || typeof raw !== 'object') return empty('invalid_response')
    const envelope = (raw.response ?? raw) as PublicRow | undefined
    const header = envelope?.header as PublicRow | undefined
    const code = text(header?.resultCode)
    if (!header || !code) return empty('invalid_response')
    if (code === '03') return empty('not_found')
    if (code === '22') return empty('quota_exceeded')
    if (['20','21','30','31','32','33'].includes(code)) return empty('authentication_failed')
    if (code !== '00') return empty('unavailable')
    const body = envelope?.body as PublicRow | undefined
    if (!body) return empty('invalid_response')
    const totalCount = number(body.totalCount)
    if (totalCount === null) return empty('invalid_response')
    const items = body.items
    // Standard APIs return an array; tolerate the documented XML-style item wrapper.
    const wrapped = items && typeof items === 'object' && !Array.isArray(items) ? (items as PublicRow).item : items
    const rows = Array.isArray(wrapped) ? wrapped : wrapped && typeof wrapped === 'object' ? [wrapped] : []
    if (totalCount > 0 && rows.length === 0) return empty('invalid_response')
    const now = new Date().toISOString()
    const candidates = rows.slice(0, 20).filter((r): r is PublicRow => !!r && typeof r === 'object')
      .map(r => normalizePublicRow(r, now)).filter(r => r !== null)
    if (rows.length > 0 && candidates.length === 0) return empty('invalid_response')
    return { status: candidates.length ? 'candidates' as LookupStatus : 'not_found' as LookupStatus,
      candidates, totalCount, hasMore: totalCount > (options.page ?? 1) * 20 }
  } catch {
    // Do not log request URLs: the public API key is a URL parameter.
    return empty(controller.signal.aborted ? 'timeout' : 'unavailable')
  } finally { clearTimeout(timer) }
}

// These are lookup variants, never evidence that two products are identical.
export function productSearchQueries(input: string): string[] {
  const q = input.normalize('NFKC').replace(/[®™]/g, '').replace(/\s+/g, ' ').trim()
  const parts = q.split(' ')
  const brand = /^(크라운|해태|오리온|롯데|농심|삼양|오뚜기|대상|빙그레|매일|남양|동원|풀무원|CJ)(?:제과|식품)?\s*/
  const withoutBrand = q.replace(brand, '').trim()
  return [...new Set([
    input.trim(), q,
    ...(parts.length >= 3 ? [parts[0] + parts[1] + ' ' + parts.slice(2).join(' ')] : []),
    q.replace(/\s/g, '').replace(/(.{2,}?)(밤티라미수|티라미수|딸기|초코|바닐라|호두맛|오리지널)$/, '$1 $2'),
    q.replace(/\s/g, ''),
    ...(withoutBrand && withoutBrand !== q ? [withoutBrand, withoutBrand.replace(/\s/g, '')] : []),
  ])].filter(v => v.length >= 2 && v.length <= 80).slice(0, 7)
}
export async function searchPublicNutrition(query: string, apiKey: string | undefined,
  options: { fetcher?: typeof fetch; timeoutMs?: number; page?: number } = {}) {
  if ((options.page ?? 1) > 1) {
    return { ...await lookupPublicNutrition(query, apiKey, options), searchedQuery: query, originalQuery: query }
  }
  const started = performance.now()
  const attempts: string[] = []
  for (const variant of productSearchQueries(query)) {
    const remaining = (options.timeoutMs ?? 5500) - (performance.now() - started)
    if (remaining <= 0) return { status: 'timeout' as LookupStatus, candidates: [], totalCount: 0, hasMore: false, attempts, originalQuery: query }
    attempts.push(variant)
    const result = await lookupPublicNutrition(variant, apiKey, { ...options, timeoutMs: remaining })
    if (result.status !== 'not_found') {
      return { ...result, searchedQuery: variant, originalQuery: query, attempts, searchAdjusted: variant !== query }
    }
  }
  return { status: 'not_found' as LookupStatus, candidates: [], totalCount: 0, hasMore: false, attempts, originalQuery: query }
}
