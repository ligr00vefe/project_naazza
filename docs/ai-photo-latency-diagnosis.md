# 사진 분석 지연 진단 (2026-10-14)

개인 사진은 외부 진단에 사용하지 않았다. 개인정보 없는 가상 라벨(640×640, 테스트 오트밀·100g·380kcal)을 생성해 같은 모델 gemini-3.5-flash-lite로 검증했다. 실측은 한 번씩의 표본이므로 일반적인 지연 분포나 특정 사용자 사진의 원인으로 단정할 수 없다.

| 요청 | 결과 |
|---|---|
| 짧은 텍스트, minimal | HTTP 200, 16.848초 |
| 단순 사진 판독, minimal | 25초 시간 초과 |
| 기존 사진·스키마 분석, minimal | 25초 시간 초과 |
| 조건 충돌 정리 후 배포 함수 호출 | 업로드 HTTP 200, 분석 HTTP 504 ai_timeout, 약 28초, stage=gemini_response |

텍스트만 보내도 지연되었고 단순 사진 판독도 시간 초과되어, 긴 프롬프트만을 원인으로 볼 수 없다. Gemini 응답 대기 구간에서 실패를 확인했으나 Google 내부 큐·추론·네트워크 중 어느 부분인지 증명할 수 없다. 정상 인식 성공이나 지연 해결을 주장하지 않는다. 동일 방식의 반복 테스트는 중단했다.

## 반영한 수정
- 상품 영양표 판독 필수와 미판독 영양 추정을 동시에 지시하던 충돌 제거. 상품은 판독한 값만 사용하며 일반 요리 추정은 별도로 명시.
- 모델 3.5, minimal 및 한국어 제품명·확신도·영양 검증 유지. 모델 자동 전환 없음.
- 요청·헤더·본문 파싱을 하나의 25초 기한으로 묶음. 헤더 후 본문 전송이 멈추어도 ai_timeout 처리.
- headersMs(응답 헤더 수신 시간), totalMs, storageMs, 실패 stage 기록. 키·이미지·제품명 로그 제외.
- 헤더 전 무응답, 본문 중 무응답, AbortSignal 취소, HTTP 오류, 잘못된 JSON·null 응답 테스트.
- 임시 테스트 계정 로그아웃 후 삭제, 사진 제거 확인 완료.

참고: [Google thinking](https://ai.google.dev/gemini-api/docs/generate-content/thinking), [image understanding](https://ai.google.dev/gemini-api/docs/generate-content/image-understanding). minimal은 지원되지만 완전한 thinking off를 보장하지 않는다. maxOutputTokens 축소나 모델 하향으로 실패를 숨기지 않았다.

## 후속 검증: 정상 응답 복구 확인

후속 비교에서는 같은 가상 라벨과 모델로 기존 temperature=0.2 요청도 2.571초에 성공했다. 기본 temperature 요청은 2.534초, 기본 설정 스트리밍은 최초 응답 1.334초·완료 2.524초였다. 낮은 temperature만의 원인으로 단정할 수 없으며 스트리밍이 전체 시간을 줄였다고 주장하지 않는다. 응답 시간 개선은 변경 전 대조군에서도 관측되었으므로 코드 수정의 인과적 효과로 단정하지 않는다.

Google의 Gemini 3 권고에 따라 temperature 강제값을 제거했다. 동일 모델·minimal·영양 검증·25초 기한은 유지한다. 시간 초과는 Gemini 응답 헤더 전 대기(gemini_waiting)와 본문 수신(gemini_body)으로 나눠 남긴다. 정상 응답에는 단계별 소요 시간(storageMs/headersMs/geminiMs)을 포함한다.

배포된 앱 서버 경로에서 연속 두 번 정상 인식했다.

| 요청 | 전체 경과 | 사진 다운로드 | Gemini 응답 | 결과 |
|---|---|---|---|---|
| 1 | 4.253초 | 458ms | 1560ms | HTTP200, recognized, 상품1개 |
| 2 | 1.521초 | 18ms | 1416ms | HTTP200, recognized, 상품1개 |

두 결과 모두 한국어 오트밀 제품명, 한 개 100g, 기준량 100g, 380kcal 검증을 통과했다. 사용자의 실제 실패 사진은 사용하지 않았으므로 해당 사진의 인식 성공을 보장하지 않는다. 현재 서버 경로 정상 작동은 확인했지만 Google 내부 큐/모델/네트워크의 이전 지연 원인을 확정하지는 못했다. 테스트 사진 제거와 로그아웃을 확인 후 QA 계정 한 개를 삭제했다.

[공식 Gemini 3 생성 설정 권고](https://ai.google.dev/gemini-api/docs/generate-content/gemini-3): 기본 sampling 설정을 권장하며 낮은 temperature가 일부 작업에서 looping이나 성능 저하를 일으킬 수 있다고 안내한다.
