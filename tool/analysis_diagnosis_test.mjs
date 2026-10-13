import assert from 'node:assert/strict';
import { analysisDiagnosis,inspectImage } from '../supabase/functions/analyze-meal-image/analysis_diagnosis.ts';
assert.equal(analysisDiagnosis({imageQuality:'blurry',foods:[]},0).code,'blurry');
assert.equal(analysisDiagnosis({imageQuality:'too_dark',foods:[]},0).source,'model_assessment');
assert.equal(analysisDiagnosis({imageQuality:'clear',failureReason:'no_food',foods:[]},0).code,'no_food');
assert.equal(analysisDiagnosis({imageQuality:'clear',failureReason:'no_matching_product',foods:[]},0).code,'unconfirmed');
assert.equal(analysisDiagnosis({foods:[{confidence:0.5}]},0).code,'low_confidence');
assert.equal(analysisDiagnosis({foods:[{confidence:0.95,isProduct:true,visibleProductName:'',nutritionLabelReadable:true}]},0).code,'product_name_unreadable');
assert.equal(analysisDiagnosis({foods:[{confidence:0.95,isProduct:true,visibleProductName:'제품',nutritionLabelReadable:false}]},0).code,'nutrition_unreadable');
assert.equal(analysisDiagnosis({foods:[]},1).code,'recognized');
assert.equal(inspectImage(new Uint8Array([1,2,3])).code,'invalid_image');
function png(w,h){const bytes=new Uint8Array(24);bytes.set([137,80,78,71,13,10,26,10]);const v=new DataView(bytes.buffer);v.setUint32(16,w);v.setUint32(20,h);return bytes;}
assert.equal(inspectImage(png(80,80)).code,'low_resolution');assert.equal(inspectImage(png(640,480)).mime,'image/png');
const jpeg=new Uint8Array([255,216,255,192,0,8,8,0,80,0,80,1,255,217]);assert.equal(inspectImage(jpeg).code,'low_resolution');
console.log('Cause classification and PNG/JPEG file validation checks passed');
