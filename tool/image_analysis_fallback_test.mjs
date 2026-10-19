import { imageGenerationConfig } from '../supabase/functions/analyze-meal-image/generation_config.ts';
import assert from 'node:assert/strict';
import { readImageAnalysis, ImageAnalysisTimeout } from '../supabase/functions/analyze-meal-image/gemini_request.ts';
import { analysisPrompt } from '../supabase/functions/analyze-meal-image/analysis_prompt.ts';
let calls = 0;
const normal = await readImageAnalysis('gemini-3.5-flash-lite', async (model, signal) => {
  calls++; assert.equal(model, 'gemini-3.5-flash-lite'); assert.equal(signal.aborted, false);
  return new Response('{"foods":[]}');
});
assert.equal(calls, 1); assert.deepEqual(normal.payload, {foods: []});
let aborted = false;
await assert.rejects(() => readImageAnalysis('gemini-3.5-flash-lite', async (_, signal) => {
  signal.addEventListener('abort', () => aborted = true);
  return new Response(new ReadableStream({start() { /* Headers arrive, body never completes. */ }}));
}, 15), error => error instanceof ImageAnalysisTimeout && error.stage === 'gemini_body' && error.headersMs !== null);
assert.equal(aborted, true);
await assert.rejects(() => readImageAnalysis('gemini-3.5-flash-lite', async () => new Promise(() => {}), 15), error => error instanceof ImageAnalysisTimeout && error.stage === 'gemini_waiting' && error.headersMs === null);
const missing = await readImageAnalysis('gemini-3.5-flash-lite', async () => new Response('{}', {status: 404}));
assert.equal(missing.status, 404); assert.equal(missing.ok, false);
const invalid = await readImageAnalysis('gemini-3.5-flash-lite', async () => new Response('invalid'));
assert.deepEqual(invalid.payload, {});
for (const body of ['null', '[]', 'true']) {
  const malformed = await readImageAnalysis('gemini-3.5-flash-lite', async () => new Response(body));
  assert.deepEqual(malformed.payload, {});
}
assert.match(analysisPrompt('ko-KR'), /한글 제품명을 영어로 번역/);
assert.match(analysisPrompt('ko-KR'), /영양값을 추정하거나 다른 상품으로 보충하지 않는다/);
assert.match(analysisPrompt('ko-KR'), /일반 요리/);
assert.match(analysisPrompt('en-US'), /preserving Korean text/);
console.log('Selected model, body-inclusive deadline, stalled headers/body, invalid JSON and product prompt checks passed');

const config = imageGenerationConfig('gemini-3.5-flash-lite', {});
assert.equal('temperature' in config, false);
assert.equal(config.thinkingConfig.thinkingLevel, 'minimal');
assert.equal(config.maxOutputTokens, 2048);
assert.equal('thinkingConfig' in imageGenerationConfig('gemini-2.5-flash', {}), false);
