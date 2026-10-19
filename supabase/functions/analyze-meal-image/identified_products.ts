export function identifiedProducts(value: unknown) {
  if (!Array.isArray(value)) return []
  return value.slice(0, 12).flatMap((raw) => {
    if (!raw || typeof raw !== 'object') return []
    const product = raw as Record<string, unknown>
    if (typeof product.name !== 'string' || !product.name.trim() ||
        typeof product.confidence !== 'number' || !Number.isFinite(product.confidence) || product.confidence < 0.85) return []
    const energy = product.energyKcal
    return [{
      name: product.name.trim().slice(0, 80),
      confidence: Math.min(product.confidence, 1),
      amountText: typeof product.amountText === 'string' ? product.amountText.trim().slice(0, 40) : '',
      energyKcal: product.wholePackageEnergy === true && typeof energy === 'number' && Number.isFinite(energy) && energy >= 0 && energy <= 100000 ? energy : null,
    }]
  })
}
