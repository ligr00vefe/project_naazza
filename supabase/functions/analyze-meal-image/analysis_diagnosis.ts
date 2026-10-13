export function analysisDiagnosis(raw: Record<string,unknown>, validCount: number): {code:string;source:string} {
  const quality = raw.imageQuality
  if (['blurry','too_dark','glare','low_resolution'].includes(String(quality))) return {code:String(quality),source:'model_assessment'}
  if (validCount > 0) return {code:'recognized',source:'validated_candidates'}
  const candidates = Array.isArray(raw.foods) ? raw.foods.filter((f):f is Record<string,unknown>=>!!f&&typeof f==='object') : []
  for (const food of candidates) {
    if (typeof food.confidence !== 'number' || food.confidence < 0.85) return {code:'low_confidence',source:'validation'}
    if (food.isProduct === true) {
      if(typeof food.visibleProductName!=='string'||!food.visibleProductName.trim())return {code:'product_name_unreadable',source:'validation'}
      if(food.nutritionLabelReadable!==true)return {code:'nutrition_unreadable',source:'validation'}
      return {code:'invalid_nutrition',source:'validation'}
    }
  }
  const allowed=['no_food','product_unidentified','product_name_unreadable','nutrition_unreadable','low_confidence']
  return allowed.includes(String(raw.failureReason)) ? {code:String(raw.failureReason),source:'model_assessment'} : {code:'unconfirmed',source:'unknown'}
}
export function inspectImage(bytes: Uint8Array): {code?:string;mime?:string} {
  if(bytes.length<12)return {code:'invalid_image'}
  const png=[137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v)
  if(png){
    if(bytes.length<24)return {code:'invalid_image'}
    const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength)
    const width=view.getUint32(16),height=view.getUint32(20)
    if(!width||!height)return {code:'invalid_image'}
    if(Math.min(width,height)<160&&Math.max(width,height)<320)return {code:'low_resolution'}
    return {mime:'image/png'}
  }
  if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255){
    let offset=2
    while(offset+4<bytes.length){
      if(bytes[offset]!==255){offset++;continue}
      const marker=bytes[offset+1];offset+=2
      if(marker===218||marker===217)break
      if(marker===255||marker===216||(marker>=208&&marker<=215))continue
      const length=(bytes[offset]<<8)|bytes[offset+1]
      if(length<2||offset+length>bytes.length)return {code:'invalid_image'}
      if([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)&&length>=7){
        const height=(bytes[offset+3]<<8)|bytes[offset+4],width=(bytes[offset+5]<<8)|bytes[offset+6]
        if(!width||!height)return {code:'invalid_image'}
        if(Math.min(width,height)<160&&Math.max(width,height)<320)return {code:'low_resolution'}
        break
      }
      offset+=length
    }
    return {mime:'image/jpeg'}
  }
  const text=new TextDecoder('ascii').decode(bytes.subarray(0,32))
  if(text.startsWith('RIFF')&&text.slice(8,12)==='WEBP')return {mime:'image/webp'}
  if(text.slice(4,8)==='ftyp'&&/hei[cf]|mif1/.test(text.slice(8)))return {mime:'image/heic'}
  return {code:'unsupported_image_type'}
}
