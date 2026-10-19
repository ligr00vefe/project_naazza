import assert from 'node:assert/strict'
import { test } from 'node:test'
import { ingredientRows, lookupIngredients } from '../supabase/functions/_shared/product_ingredients.ts'
const id='123456789'
const row={PRDLST_REPORT_NO:id,PRDLST_NM:'가상제품',BSSH_NM:'가상 업체',RAWMTRL_NM:'복합원료(대두,밀),설탕',RAWMTRL_ORDNO:'2',CHNG_DT:'20261014'}
const ok=(rows=[row], count=rows.length)=>new Response(JSON.stringify({C002:{RESULT:{CODE:'INFO-000'},row:rows,total_count:String(count)}}))
test('exact product code only; raw ingredient wording and order preserved; company separately verified',()=>{
 assert.deepEqual(ingredientRows([{...row,PRDLST_REPORT_NO:'99999'}],id,'가상 업체'),[])
 const rows=ingredientRows([row],id,'가상업체')
 assert.equal(rows[0].ingredientText,row.RAWMTRL_NM)
 assert.equal(rows[0].companyMatches,true)
 assert.equal(rows[0].displayOrder,2)
 assert.equal(ingredientRows([row],id,'다른 업체')[0].companyMatches,false)
})
test('key missing causes zero external requests',async()=>{
 let calls=0;const result=await lookupIngredients(id,'가상 업체',undefined,{fetcher:async()=>{calls++;return ok()}})
 assert.equal(result.status,'not_configured');assert.equal(calls,0)
})
test('query filters report number, partial page stays partial; allergy unknown even with ingredients',async()=>{
 const result=await lookupIngredients(id,'가상 업체','test-key',{fetcher:async url=>{
  assert.ok(url.startsWith('https://'));assert.ok(url.endsWith('PRDLST_REPORT_NO='+id));return ok([row],101)
 }})
 assert.equal(result.status,'ingredients');assert.equal(result.hasMore,true)
 assert.equal(result.allergyStatus,'unknown');assert.equal(result.requiresConfirmation,true)
})
test('same name with a different report number cannot be joined',async()=>{
 const result=await lookupIngredients(id,'가상 업체','key',{fetcher:async()=>ok([{...row,PRDLST_REPORT_NO:'55555'}])})
 assert.equal(result.status,'identity_mismatch')
})
test('no data, no service approval and quota are distinct',async()=>{
 for(const [code,status] of [['INFO-200','not_found'],['INFO-110','authentication_failed'],['INFO-320','quota_exceeded']]){
  const result=await lookupIngredients(id,'가상 업체','key',{fetcher:async()=>new Response(JSON.stringify({C002:{RESULT:{CODE:code}}}))})
  assert.equal(result.status,status);assert.equal(result.allergyStatus,'unknown')
 }
})
test('body timeout produces one failed request without retry',async()=>{
 let calls=0;const result=await lookupIngredients(id,'가상 업체','key',{timeoutMs:5,fetcher:async(url,{signal})=>{
 calls++;return {ok:true,json:()=>new Promise((resolve,reject)=>signal.addEventListener('abort',()=>reject(Error('aborted'))))}
 }})
 assert.equal(result.status,'timeout');assert.equal(calls,1)
})
test('malformed reply and network are distinct; invalid report rejected before fetch',async()=>{
 assert.equal((await lookupIngredients(id,'','key',{fetcher:async()=>new Response('null')})).status,'invalid_response')
 assert.equal((await lookupIngredients(id,'','key',{fetcher:async()=>{throw Error('network')}})).status,'unavailable')
 await assert.rejects(()=>lookupIngredients('name-only','','key'),/invalid_report_number/)
})
