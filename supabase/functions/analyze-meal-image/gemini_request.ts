export async function requestImageAnalysis(
  model: string,
  request: (model: string, timeoutMs: number) => Promise<Response>,
): Promise<{ response: Response; model: string }> {
  return { response: await request(model, 25000), model }
}
