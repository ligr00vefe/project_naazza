import assert from 'node:assert/strict';
import { requestImageAnalysis } from '../supabase/functions/analyze-meal-image/gemini_request.ts';
let calls=0;
await assert.rejects(()=>requestImageAnalysis('gemini-3.5-flash-lite',async(model,timeout)=>{calls++;assert.equal(model,'gemini-3.5-flash-lite');assert.equal(timeout,25000);throw new DOMException('timeout','TimeoutError');}));
assert.equal(calls,1);
const missing=await requestImageAnalysis('gemini-3.5-flash-lite',async()=>new Response('{}',{status:404}));assert.equal(missing.model,'gemini-3.5-flash-lite');assert.equal(missing.response.status,404);
console.log('Image analysis stays on the selected model with one bounded request');
