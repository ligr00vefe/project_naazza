// Gemini 3 recommends default sampling. Do not force low temperature.
export function imageGenerationConfig(model: string, schema: unknown) {
  return {
    ...(/^gemini-3[.].*flash/.test(model) ? { thinkingConfig: { thinkingLevel: 'minimal' } } : {}),
    responseMimeType: 'application/json',
    responseJsonSchema: schema,
    maxOutputTokens: 2048,
  }
}
