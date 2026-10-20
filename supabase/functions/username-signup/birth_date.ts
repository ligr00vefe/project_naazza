// null: omitted, undefined: invalid. Calendar dates follow the app's Korean day.
export function parseOptionalBirthDate(value: unknown, now = new Date()): string | null | undefined {
  if (value === null || value === undefined) return null
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || value < '1900-01-01') return undefined
  const date = new Date(`${value}T00:00:00Z`)
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) return undefined
  const today = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now)
  return value > today ? undefined : value
}
