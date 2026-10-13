import assert from 'node:assert/strict';
import { foodIdentity } from '../supabase/functions/analyze-meal-image/food_identity.ts';
const input={displayName:'English substitute',visibleProductName:'뉴케어 당플랜 호두맛',confidence:0.99,isProduct:true,nutritionLabelReadable:true,amountG:200,nutrition:{baseAmountG:100,energyKcal:400,carbohydrateG:60,proteinG:10,fatG:12,sodiumMg:300}};
assert.equal(foodIdentity(input).displayName,'뉴케어 당플랜 호두맛');
for(const invalid of [{...input,visibleProductName:''},{...input,confidence:0.5},{...input,nutritionLabelReadable:false}])assert.equal(foodIdentity(invalid),null);
assert.equal(foodIdentity({displayName:'라면',confidence:0.95,isProduct:false}).displayName,'라면');
console.log('Korean product labels and uncertain-result rejection checks passed');

assert.equal(foodIdentity({...input,amountG:0}),null);
assert.equal(foodIdentity({...input,nutrition:{}}),null);
