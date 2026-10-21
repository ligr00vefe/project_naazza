export function parseProfileSex(value: unknown): 'male' | 'female' | null {
  return value === 'male' || value === 'female' ? value : null
}
