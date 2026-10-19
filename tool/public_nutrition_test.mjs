import assert from 'node:assert/strict'
import { test } from 'node:test'
import { normalizePublicRow, lookupPublicNutrition, amount } from '../supabase/functions/_shared/public_nutrition.ts'
// Synthetic fixture; not the real nutrition of any commercial product.
const row = { foodCd: 'fixture-1', foodNm: '테스트 제품', nutConSrtrQua: '100g', foodSize: '250g', enerc: '200', nat: '', prot: '0', mkrNm: '테스트 제조사', crtrYmd: '2026-10-01' }
const ok = (items = [row], totalCount = items.length) => new Response(JSON.stringify({ response: { header: { resultCode: '00' }, body: { items, totalCount } } }))
test('source and missing/zero nutrients remain distinct; same-unit package math', () => {
 const item = normalizePublicRow(row, 'today')
 assert.equal(item.packageEnergyKcal, 500)
 assert.equal(item.nutrition.sodiumMg, null)
 assert.equal(item.nutrition.proteinG, 0)
 assert.equal(item.requiresConfirmation, true)
 assert.equal(item.source.recordId, 'fixture-1')
 assert.equal(item.source.referenceDate, '2026-10-01')
})
test('ml and grams cannot be converted without density; unparseable size stays unknown', () => {
 assert.equal(normalizePublicRow({ ...row, foodSize: '200ml' }, 'today').packageEnergyKcal, null)
 assert.equal(normalizePublicRow({ ...row, foodSize: '1병' }, 'today').packageSize, null)
 assert.deepEqual(amount('1L'), {value:1000, unit:'ml'})
 assert.equal(amount('0g'), null)
 assert.equal(normalizePublicRow({...row, enerc:'N/A'},'today').nutrition.energyKcal,null)
})
test('missing key does not invoke provider', async () => {
 let calls=0
 assert.equal((await lookupPublicNutrition('제품',undefined,{fetcher:async()=>{calls++;return ok()}})).status,'not_configured')
 assert.equal(calls,0)
})
test('query is encoded once, paginated and never automatically accepted', async () => {
 const result=await lookupPublicNutrition('테스트 제품','abc+/=', {page:2, fetcher:async url=>{
  assert.equal(url.searchParams.get('serviceKey'),'abc+/=')
  assert.equal(url.searchParams.get('foodNm'),'테스트 제품')
  assert.equal(url.searchParams.get('pageNo'),'2')
  return ok([row,{...row,foodCd:'fixture-2',foodSize:'500g'}],100)
 }})
 assert.equal(result.candidates.length,2)
 assert.equal(result.hasMore,true)
 assert.ok(result.candidates.every(item=>item.requiresConfirmation))
})
test('empty result differs from provider error', async () => {
 assert.equal((await lookupPublicNutrition('제품','key',{fetcher:async()=>ok([])})).status,'not_found')
 assert.equal((await lookupPublicNutrition('제품','key',{fetcher:async()=>{throw new Error('network')}})).status,'unavailable')
 assert.equal((await lookupPublicNutrition('제품','key',{fetcher:async()=>new Response('invalid')})).status,'invalid_response')
})
test('quota/auth/provider errors are distinguished', async () => {
 for(const [code,status] of [['22','quota_exceeded'],['30','authentication_failed'],['02','unavailable'],['03','not_found']]) {
  const result=await lookupPublicNutrition('제품','key',{fetcher:async()=>new Response(JSON.stringify({response:{header:{resultCode:code}}}))})
  assert.equal(result.status,status)
 }
})
test('timeout covers the body as well as headers; no automatic retry', async () => {
 let calls=0
 const result=await lookupPublicNutrition('제품','key',{timeoutMs:10,fetcher:async(url,{signal})=>{
  calls++
  return {ok:true,json:()=>new Promise((resolve,reject)=>signal.addEventListener('abort',()=>reject(new Error('aborted')),{once:true}))}
 }})
 assert.equal(result.status,'timeout')
 assert.equal(calls,1)
})
test('malformed envelope and inconsistent empty rows are invalid', async () => {
 for(const payload of ['null','{}',JSON.stringify({response:{header:{resultCode:'00'},body:{items:[],totalCount:2}}})])
  assert.equal((await lookupPublicNutrition('제품','key',{fetcher:async()=>new Response(payload)})).status,'invalid_response')
})

test('gateway HTTP403 key error is authentication failure, not missing product', async()=>{
 const result=await lookupPublicNutrition('제품','key',{fetcher:async()=>new Response(JSON.stringify({OpenAPI_ServiceResponse:{cmmMsgHeader:{returnReasonCode:'30'}}}),{status:403})})
 assert.equal(result.status,'authentication_failed')
})

test('real standard API root header/body and wrapped items are accepted',async()=>{
 const result=await lookupPublicNutrition('제품','key',{fetcher:async()=>new Response(JSON.stringify({header:{resultCode:'00'},body:{items:{item:[row]},totalCount:1}}))})
 assert.equal(result.status,'candidates');assert.equal(result.candidates.length,1)
})

import { legacyNutritionCandidates } from '../supabase/functions/_shared/nutrition_candidates.ts'
test('legacy food search uses catalog values and rejects unknown/contradictory units',()=>{
 const complete={...row,prot:'5',fatce:'2',chocdf:'10',nat:'30',dataCd:'P'}
 const product=normalizePublicRow(complete,'today')
 const food=legacyNutritionCandidates([product]).single ?? legacyNutritionCandidates([product])[0]
 assert.equal(food.nutrition.energyKcal,200);assert.equal(food.nutritionSource.id,'fixture-1')
 assert.equal(legacyNutritionCandidates([normalizePublicRow(row,'today')]).length,0)
 assert.equal(legacyNutritionCandidates([normalizePublicRow({...complete,foodSize:'200ml'},'today')]).length,0)
})

import { productSearchQueries, searchPublicNutrition } from '../supabase/functions/_shared/public_nutrition.ts'
test('brand/spacing variants recover catalog names without accepting product identity', async () => {
 for (const [input, target] of [['크라운 산도 밤티라미수','크라운산도 밤티라미수'],['크라운산도밤티라미수','크라운산도 밤티라미수'],['해태 사브레','사브레']]) {
  const calls=[]
  const result=await searchPublicNutrition(input,'key',{fetcher:async u=>{
   const q=u.searchParams.get('foodNm');calls.push(q)
   return ok(q===target?[{...row,foodNm:target}]:[])
  }})
  assert.equal(result.status,'candidates');assert.equal(result.searchedQuery,target)
  assert.equal(result.searchAdjusted,true);assert.equal(result.candidates[0].requiresConfirmation,true)
  assert.ok(calls.length<=7)
 }
 assert.ok(productSearchQueries('  해태  사브레  ').includes('사브레'))
})
test('provider errors stop variant search; pagination does not switch product query', async()=>{
 let calls=0
 const fetcher=async()=>{calls++;return new Response('{}',{status:429})}
 assert.equal((await searchPublicNutrition('해태 사브레','key',{fetcher})).status,'quota_exceeded')
 assert.equal(calls,1)
 calls=0
 await searchPublicNutrition('해태 사브레','key',{page:2,fetcher:async()=>{calls++;return ok([])}})
 assert.equal(calls,1)
})
