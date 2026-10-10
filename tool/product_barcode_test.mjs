import assert from 'node:assert/strict'
import { normalizeBarcode, productCandidate } from '../supabase/functions/product-barcode/product.ts'
assert.equal(normalizeBarcode(' 3017620422003 '), '3017620422003')
assert.equal(normalizeBarcode('036000291452'), '036000291452')
assert.equal(normalizeBarcode('04252614'), '042100005264')
for (const value of ['3017620422004', '', 'abc', '123', null, 3017620422003]) assert.equal(normalizeBarcode(value), null)
const base = {
  product_name_ko: '테스트 제품', brands: '브랜드', serving_quantity: 30, serving_quantity_unit: 'g',
  nutriments: { 'energy-kcal_100g': 250, carbohydrates_100g: 20, proteins_100g: 5, fat_100g: 10, sodium_100g: 0.4 },
}
const candidate = productCandidate(base)
assert.equal(candidate.displayName, '테스트 제품')
assert.equal(candidate.amountG, 30)
assert.equal(candidate.nutrition.sodiumMg, 400)
const converted = productCandidate({ ...base, nutriments: { ...base.nutriments, 'energy-kcal_100g': undefined, energy_100g: 1046, sodium_100g: undefined, salt_100g: 1 } })
assert.equal(converted.nutrition.energyKcal, 250)
assert.equal(converted.nutrition.sodiumMg, 400)
assert.equal(productCandidate({ product_name: '영양표 없음' }), null)
assert.equal(productCandidate({ ...base, nutriments: { 'energy-kcal_100g': 10 } }), null)
assert.equal(productCandidate({ ...base, serving_quantity_unit: 'ml' }).amountG, 100)
assert.equal(productCandidate({ ...base, nutriments: Object.fromEntries(Object.keys(base.nutriments).map(key => [key, 0])) }).nutrition.energyKcal, 0)
console.log('Barcode validation and nutrition conversion checks passed')