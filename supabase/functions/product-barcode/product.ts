type Product = Record<string, unknown>
function number(value: unknown): number | null {
  if (typeof value !== 'number' && typeof value !== 'string') return null
  if (typeof value === 'string' && !value.trim()) return null
  const result = Number(value)
  return Number.isFinite(result) && result >= 0 ? result : null
}
export function normalizeBarcode(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const code = value.trim()
  if (!/^(\d{8}|\d{12}|\d{13}|\d{14})$/.test(code)) return null
  // UPC-E is an eight digit compressed UPC-A, not an EAN-8.
  let full = code
  if (code.length === 8 && /^[01]/.test(code)) {
    const [system, a, b, c, d, e, last, check] = code
    if ('012'.includes(last)) full = `${system}${a}${b}${last}0000${c}${d}${e}${check}`
    else if (last === '3') full = `${system}${a}${b}${c}00000${d}${e}${check}`
    else if (last === '4') full = `${system}${a}${b}${c}${d}00000${e}${check}`
    else full = `${system}${a}${b}${c}${d}${e}0000${last}${check}`
  }
  let sum = 0
  for (let i = full.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += Number(full[i]) * weight
  }
  if ((10 - sum % 10) % 10 !== Number(full.at(-1))) {
    // An EAN-8 beginning with 0/1 may also be valid without UPC-E expansion.
    if (full !== code) {
      sum = 0
      for (let i = code.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) sum += Number(code[i]) * weight
      if ((10 - sum % 10) % 10 === Number(code.at(-1))) return code
    }
    return null
  }
  return full
}
export function productCandidate(product: Product) {
  const name = [product.product_name_ko, product.product_name].find(
    (value): value is string => typeof value === 'string' && !!value.trim(),
  )?.trim().slice(0, 80)
  if (!name) return null
  const nutrition = product.nutriments as Product | undefined
  if (!nutrition) return null
  const energy = number(nutrition['energy-kcal_100g']) ??
    (number(nutrition.energy_100g) === null ? null : number(nutrition.energy_100g)! / 4.184)
  const carbohydrate = number(nutrition.carbohydrates_100g)
  const protein = number(nutrition.proteins_100g)
  const fat = number(nutrition.fat_100g)
  const sodium = number(nutrition.sodium_100g) ??
    (number(nutrition.salt_100g) === null ? null : number(nutrition.salt_100g)! / 2.5)
  // Missing fields must not silently become zero nutrition in saved meals.
  if ([energy, carbohydrate, protein, fat, sodium].some(value => value === null)) return null
  const serving = number(product.serving_quantity)
  const whole = number(product.product_quantity)
  const amountG = product.product_quantity_unit === 'g' && whole && whole <= 3000 ? whole : product.serving_quantity_unit === 'g' && serving && serving <= 3000 ? serving : 100
  const brand = typeof product.brands === 'string' ? product.brands.trim().slice(0, 30) : ''
  return {
    displayName: name, normalizedName: name, confidence: 1, amountG, isProduct: true,
    tags: ['제품 영양표', ...(brand ? [brand] : [])],
    nutrition: {
      baseAmountG: 100, energyKcal: energy, carbohydrateG: carbohydrate,
      proteinG: protein, fatG: fat, sodiumMg: sodium! * 1000,
    },
  }
}