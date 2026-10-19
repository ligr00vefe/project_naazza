import { readFile } from 'node:fs/promises'
import { lookupPublicNutrition } from '../supabase/functions/_shared/public_nutrition.ts'
import { lookupIngredients } from '../supabase/functions/_shared/product_ingredients.ts'
const content = await readFile(new URL('../.env', import.meta.url), 'utf8')
const env = Object.fromEntries(content.split(/\r?\n/).filter(l=>l.trim()&&!l.trim().startsWith('#')&&l.includes('=')).map(l=>{
 const i=l.indexOf('=');let v=l.slice(i+1).trim();if((v.startsWith('"')&&v.endsWith('"'))||(v.startsWith("'")&&v.endsWith("'")))v=v.slice(1,-1);return [l.slice(0,i).trim(),v]
}))
let nutritionKey=env.DATA_GO_KR_API_KEY || env.DATA_GO_KR_SERVICE_KEY
if(nutritionKey?.includes('%')) { try { nutritionKey=decodeURIComponent(nutritionKey) } catch {} }
const instrument = async (url,options) => {
 const r=await fetch(url,options)
 try { const p=await r.clone().json();console.log(JSON.stringify({providerHttp:r.status,resultCode:p.response?.header?.resultCode ?? p.RESULT?.CODE ?? p.C002?.RESULT?.CODE,rootFields:Object.keys(p)})) } catch {console.log(JSON.stringify({providerHttp:r.status,format:'not_json'}))}
 return r
}
for(const query of ['뉴케어 당플랜 호두맛','퀴노아 크래커']) {
 const started=performance.now();const result=await lookupPublicNutrition(query,nutritionKey,{fetcher:instrument})
 console.log(JSON.stringify({query,status:result.status,totalCount:result.totalCount,hasMore:result.hasMore,elapsedMs:Math.round(performance.now()-started),candidates:result.candidates.slice(0,5).map(p=>({name:p.name,id:p.id,manufacturer:p.manufacturer,reportNumber:p.reportNumber,basis:p.basisText,size:p.packageSizeText,energy:p.nutrition.energyKcal}))}))
}
if(env.FOODSAFETY_API_KEY) {
 const url=`https://openapi.foodsafetykorea.go.kr/api/${encodeURIComponent(env.FOODSAFETY_API_KEY)}/C002/json/1/20/PRDLST_NM=${encodeURIComponent('뉴케어')}`
 try {
  const r=await fetch(url,{signal:AbortSignal.timeout(6000)});const p=await r.json();const d=p.C002??p;
  const rows=Array.isArray(d.row)?d.row:[]
  console.log(JSON.stringify({provider:'C002',http:r.status,code:d.RESULT?.CODE,totalCount:d.total_count,candidates:rows.slice(0,5).map(row=>({name:row.PRDLST_NM,company:row.BSSH_NM,report:row.PRDLST_REPORT_NO}))}))
  if(rows[0]) { const item=rows[0];const result=await lookupIngredients(item.PRDLST_REPORT_NO,item.BSSH_NM,env.FOODSAFETY_API_KEY);
   console.log(JSON.stringify({exactIngredientLookup:result.status,rowCount:result.rows.length,totalCount:result.totalCount,hasMore:result.hasMore,companyVerified:result.companyVerified})) }
 } catch(e) {console.log(JSON.stringify({provider:'C002',status:'unavailable',errorType:e.name}))}
}
