import type { normalizePublicRow } from './public_nutrition.ts'
type Product = NonNullable<ReturnType<typeof normalizePublicRow>>
// Legacy endpoint returns only complete, dimensionally compatible records.
export function legacyNutritionCandidates(products: Product[]) {
 return products.flatMap(product => {
  const basis=product.basis, size=product.packageSize, n=product.nutrition
  if (!basis || !size || basis.unit !== size.unit ||
    [n.energyKcal,n.carbohydrateG,n.proteinG,n.fatG,n.sodiumMg].some(value=>value===null)) return []
  return [{ displayName:product.name,normalizedName:product.name,confidence:1,
    isProduct:product.dataCode==='P',amountG:size.value,amountUnit:size.unit,
    hasCompleteNutrition:true,tags:['공공데이터 · 정보 확인'],nutritionSource:product,
    nutrition:{baseAmountG:basis.value,energyKcal:n.energyKcal,carbohydrateG:n.carbohydrateG,
      proteinG:n.proteinG,fatG:n.fatG,sodiumMg:n.sodiumMg} }]
 })
}
