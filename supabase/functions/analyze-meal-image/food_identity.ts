export function foodIdentity(food: Record<string, unknown>): { displayName: string; isProduct: boolean } | null {
  if (typeof food.confidence !== 'number' || !Number.isFinite(food.confidence) || food.confidence < 0.85) return null
  const isProduct = food.isProduct === true
  const name = isProduct ? food.visibleProductName : food.displayName
  if (typeof name !== 'string' || !name.trim() || (isProduct && food.nutritionLabelReadable !== true)) return null
  if (isProduct) {
    const nutrition = food.nutrition as Record<string,unknown> | undefined
    if (typeof food.amountG !== 'number' || !Number.isFinite(food.amountG) || food.amountG <= 0 || !nutrition) return null
    for (const key of ['baseAmountG','energyKcal','carbohydrateG','proteinG','fatG','sodiumMg']) {
      const value = nutrition[key]
      if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || (key === 'baseAmountG' && value === 0)) return null
    }
  }
  return { displayName: name.trim().slice(0,80), isProduct }
}
