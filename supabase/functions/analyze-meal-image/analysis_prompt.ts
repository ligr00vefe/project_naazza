export function analysisPrompt(locale: string): string {
  const language = locale === 'ko-KR'
    ? '이름과 태그는 한국어로 작성하되 포장에 보이는 제품명은 원문 그대로 복사한다. 한글 제품명을 영어로 번역하거나 다른 상품으로 대체하지 않는다.'
    : 'Use English for dish names and tags; copy product names exactly as printed, preserving Korean text.'
  return `${language}
사진에 보이는 음식/포장만 식별하고 질병을 추론하지 않는다. confidence 0.85 미만인 후보는 제외한다.
포장 상품: isProduct=true. visibleProductName은 보이는 제품명/브랜드 원문이다. foods에 완전한 영양정보를 넣는 것은 제품명, 한 개 전체 용량(amountG), 영양표가 모두 읽힐 때만 허용한다. 영양성분표 전체가 없는 포장 앞면 사진은 foods=[]로 두고 identifiedProducts만 반환한다. 제품명 식별 결과를 버리지 않는다. 읽지 못한 영양값은 null이며, 0이나 기억하는 값으로 채우지 않는다. 전체 영양성분표의 탄수화물·단백질·지방·나트륨 수치가 실제로 보이는 경우에만 nutritionLabelReadable=true이다. ml만 표시되어 있으면 밀도를 모르므로 g으로 임의 변환하지 않는다. 제품명과 맛/종류를 확실히 읽으면 identifiedProducts에 원문 제품명(name), 식별 confidence, 보이는 용량(amountText)을 별도로 남긴다. 용량이 안 보이면 빈 문자열이다. 앞면에 한 개 전체 열량이 명확히 표시되면 energyKcal와 wholePackageEnergy=true로 남긴다. 열량이 안 보이거나 기준이 불명확하면 energyKcal=null, wholePackageEnergy=false로 남긴다. 알려진 제품이라도 기억이나 유사 상품의 용량/열량을 가져오지 않는다. identifiedProducts에는 제품명만 확인되어도 반환하며, 완전한 foods가 가능한 경우에도 제품 식별 정보를 남긴다. nutritionLabelReadable=true는 실제 판독했을 때만 사용한다. 영양값을 추정하거나 다른 상품으로 보충하지 않는다. nutrition은 영양표의 기준량(baseAmountG) 기준이며 나트륨은 mg이다. 기준량과 전체 용량을 혼동하지 않는다.
일반 요리: isProduct=false. 보이는 음식만 한국어로 명명하고 양과 영양은 보수적으로 추정한다. 추정한 경우 tags에 영양 추정을 넣는다.
imageQuality는 clear/blurry/too_dark/glare/low_resolution/unknown 중 근거가 있는 값이다. 실패 시 foods=[]로 반환하고 failureReason을 no_food/product_unidentified/product_name_unreadable/nutrition_unreadable/low_confidence/unknown 중 실제 이유로 표시한다. 성공 시 failureReason=none이다. 실패 원인을 지어내지 않는다. 상품 DB를 조회하지 않았으므로 일치 상품 없음이라고 단정하지 않는다. JSON 외 설명은 쓰지 않는다.`
}
