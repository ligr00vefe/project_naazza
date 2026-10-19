// C002 official contract: https://www.foodsafetykorea.go.kr/api/openApiInfo.do?svc_no=C002
export type IngredientRow = Record<string, unknown>
const clean = (value: unknown) => typeof value === 'string' ? value.trim() : ''
const companyKey = (value: string) => value.replace(/\s/g, '')
export function ingredientRows(rows: unknown[], reportNumber: string, company: string) {
  return rows.filter((raw): raw is IngredientRow => !!raw && typeof raw === 'object').flatMap(row => {
    if (clean(row.PRDLST_REPORT_NO) !== reportNumber) return []
    const manufacturer = clean(row.BSSH_NM)
    const rawText = clean(row.RAWMTRL_NM)
    if (!rawText) return []
    return [{ reportNumber, name: clean(row.PRDLST_NM), company: manufacturer,
      ingredientText: rawText, displayOrder: /^\d+$/.test(clean(row.RAWMTRL_ORDNO)) ? Number(row.RAWMTRL_ORDNO) : null,
      changedAt: clean(row.CHNG_DT), licenseNumber: clean(row.LCNS_NO),
      companyMatches: !!company && !!manufacturer && companyKey(company) === companyKey(manufacturer),
    }]
  })
}
export async function lookupIngredients(reportNumber: string, company: string, key: string | undefined,
  options: { fetcher?: typeof fetch; timeoutMs?: number; page?: number } = {}) {
  if (!/^\d{5,30}$/.test(reportNumber)) throw new Error('invalid_report_number')
  const empty = (status: string) => ({ status, rows: [], totalCount: 0, hasMore: false,
    allergyStatus: 'unknown', source: { provider: 'foodsafetykorea', service: 'C002', reportNumber } })
  if (!key?.trim()) return empty('not_configured')
  const page = options.page ?? 1
  const start = (page - 1) * 100 + 1
  // HTTPS only. Never downgrade transport if TLS is unavailable.
  const url = `https://openapi.foodsafetykorea.go.kr/api/${encodeURIComponent(key.trim())}/C002/json/${start}/${start + 99}/PRDLST_REPORT_NO=${encodeURIComponent(reportNumber)}`
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), options.timeoutMs ?? 6000)
  try {
    const response = await (options.fetcher ?? fetch)(url, { signal: controller.signal })
    if (!response.ok) return empty(response.status === 429 ? 'quota_exceeded' : 'unavailable')
    let payload: IngredientRow
    try { payload = await response.json() } catch { return empty(controller.signal.aborted ? 'timeout' : 'invalid_response') }
    if (!payload || typeof payload !== 'object') return empty('invalid_response')
    const data = (payload.C002 ?? payload) as IngredientRow
    const result = data.RESULT as IngredientRow | undefined
    const code = clean(result?.CODE)
    if (code === 'INFO-200') return empty('not_found')
    if (['INFO-100','INFO-110','INFO-120','INFO-400','INFO-600'].includes(code)) return empty('authentication_failed')
    if (['INFO-300','INFO-310','INFO-320','ERROR-503'].includes(code)) return empty('quota_exceeded')
    if (code !== 'INFO-000') return empty(code ? 'unavailable' : 'invalid_response')
    const rawRows = data.row
    const countText = String(data.total_count ?? '')
    if (!/^\d+$/.test(countText)) return empty('invalid_response')
    const totalCount = Number(countText)
    if (!Array.isArray(rawRows)) return empty(totalCount === 0 ? 'not_found' : 'invalid_response')
    const rows = ingredientRows(rawRows, reportNumber, company)
    if (rawRows.length && !rows.length) return empty('identity_mismatch')
    const hasMore = totalCount > start + 99
    return { ...empty(rows.length ? 'ingredients' : 'not_found'), rows, totalCount, hasMore,
      requiresConfirmation: true,
      companyVerified: rows.length > 0 && rows.every(row => row.companyMatches),
      source: { provider: 'foodsafetykorea', service: 'C002', reportNumber, retrievedAt: new Date().toISOString() } }
  } catch { return empty(controller.signal.aborted ? 'timeout' : 'unavailable') }
  finally { clearTimeout(timer) }
}
