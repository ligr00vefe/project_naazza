# NAAZZA

질환별 식사·증상·배변·내원 기록을 시간축으로 연결하는 Flutter 앱입니다.

## 실행

실제 앱은 Supabase 설정이 없으면 시작하지 않습니다. 먼저 루트 `.env`에서
공개 설정 파일을 생성한 뒤 실행합니다.

```powershell
.\tool\naazza_env.ps1 prepare
.\tool\naazza_env.ps1 run
```

실제 Supabase 프로젝트를 연결할 때는 루트 `.env`를 단일 설정 원본으로
사용합니다. `.env.example`을 `.env`로 복사해 값을 입력합니다. 실행 스크립트는
클라이언트에 공개 가능한 URL과 publishable key만 Flutter에 전달하며,
`GEMINI_API_KEY` 같은 서버 비밀값은 앱에 포함하지 않습니다.

```powershell
Copy-Item .env.example .env
.\tool\naazza_env.ps1 run
```

폰에 직접 설치할 디버그 APK는 다음 명령으로 만듭니다.

```powershell
.\tool\naazza_env.ps1 build-apk
```

Gemini 키를 변경한 뒤 Supabase Edge Function 실행 환경에 반영합니다.

```powershell
.\tool\naazza_env.ps1 sync-secrets
```

## 구조

- `lib/app`: 부트스트랩, 라우팅, 테마
- `lib/core`: 환경 설정과 공통 기반
- `lib/features`: 기능 단위 UI·도메인·데이터 접근
- 화면에서는 Supabase SDK를 직접 호출하지 않고 Repository를 통합니다.

## 구현 단계

- P0: 앱 기반, 인증, 라우팅, 테마
- P1: 복수 관리 목표, 추천 추적 항목 합집합, Quick Log 설정, 알림 설정
- P2: 식사 직접 입력, 컨디션 상태 구분, 배변 기록, 타임라인, 캘린더, 수정·삭제
- P3: 카메라·앨범, 음식 후보 분석, 신뢰도 확인, 영양 계산, 직접 검색 fallback
- P4: 7·30·90일 기록 집계, 활동 차트, 증상·식사·배변 요약, 관찰 메시지
- P5: 내원 이벤트, 검사·상담·처방 변경 메모, 다음 진료 D-day, 1회 알림 규칙, 진료 준비 요약
- P6: 나짜 캐릭터·감소 모션, CSV 내보내기, 접근성·빈 상태 UX
- P7: EAN/UPC 바코드 스캔, 제품 영양 조회, 섭취량 보정, 식사 저장, 직접 입력 fallback

P1의 실제 Supabase 저장은 다음 테이블을 전제로 합니다.

- `user_conditions`: `user_id`, `condition_key`
- `user_tracking_metrics`: `user_id`, `metric_key`, `enabled`, `quick_log_order`
- `user_preferences`: `user_id`, `reminders_enabled`, `onboarding_completed`

클라이언트 접근을 허용하기 전에 각 테이블에 RLS와 사용자 소유권 정책을
적용하고, 그 다음 `authenticated` 역할에 필요한 Data API 권한만 부여해야
합니다. 현재 서버는 연결되어 있으며 스키마 변경은 `supabase/migrations`에
보관합니다.

P2 기록 Repository는 `meals`, `condition_logs`, `bowel_logs`를 사용자 ID와
기록 시각 기준으로 조회해 공통 타임라인 모델로 병합합니다. 실제 스키마를
적용할 때 모든 테이블의 `SELECT/UPDATE/DELETE` 정책은
`(select auth.uid()) = user_id` 소유권 조건을 사용해야 하며, UPDATE에는
동일한 `WITH CHECK` 조건도 필요합니다.

P3 실제 연동에는 다음 Supabase 리소스가 필요합니다.

- Private Storage bucket `meals`
- 인증 필수 Edge Function `analyze-meal-image`
- 인증 필수 Edge Function `nutrition-search`
- Storage 경로는 반드시 `{auth.uid()}/...` 형식으로 제한
- Gemini 및 영양 API 키는 Edge Function secret에만 저장

AI 요청에는 음식 이미지와 locale만 전달하며 질환, 증상, 배변, 사용자 메모는
전송하지 않습니다. AI 후보는 사용자가 삭제·추가하고 섭취량을 확정한 뒤에만
식사 기록으로 저장됩니다.

P4 인사이트는 현재 로그인 사용자의 기록을 앱 내부에서 기간별로 집계합니다.
표시 내용은 기록에서 관찰된 빈도와 경향이며 의학적 진단 또는 인과관계가
아닙니다. 같은 항목이 3회 미만이면 패턴을 단정하지 않고 추가 기록을 안내합니다.

P5 실제 Supabase 저장은 `visit_events` 테이블의 `user_id`, `visit_at`,
`visit_type`, `facility_label`, `next_visit_at`, `memo`, `details jsonb`를
사용합니다. 새 테이블은 Data API에 명시적으로 노출하고 RLS를 활성화한 뒤,
SELECT/INSERT/UPDATE/DELETE 모두 `(select auth.uid()) = user_id` 소유권 조건을
적용해야 합니다. UPDATE 정책에는 동일한 `WITH CHECK` 조건도 필요합니다.

현재 앱은 진료 준비 알림의 활성 여부와 1~7일 전 규칙을 Visit Event에
저장합니다. 실제 OS Push 예약과 권한 요청은 Supabase 프로젝트 및 모바일
알림 공급자 설정 후 연결해야 합니다.

P7 실제 제품 조회에는 인증 필수 Supabase Edge Function `product-barcode`가
필요합니다. 함수는 클라이언트의 사용자 JWT를 검증한 뒤 Open Food Facts 또는
국내 제품 DB를 서버에서 조회하고, `FoodCandidate` 형식의 `product`를 반환해야
합니다. 외부 API Key가 필요한 경우 앱이 아니라 Function secret에만 저장합니다.

## 제품 사진 및 바코드 조회

음식 사진 기록 화면에서 식품 포장 사진도 AI 분석할 수 있습니다. 제품명과
사진에 표시된 용량·열량은 판독할 수 있으나, 국내 공공데이터를 통해 제품 영양 후보를 조회하고 사용자 확인 후 적용합니다. 같은 이름의 이전 기록에서 영양정보를 가져오지 않습니다. 사진에 없는 제품 영양정보는 공공데이터 후보 확인으로 보완하며, 조회되지 않은 값은 미확인으로 유지합니다. 바코드 화면에서도 사진 분석으로
이동할 수 있습니다.

`product-barcode`는 사용자 JWT를 함수 내부에서 검증하고 Open Food Facts에서
EAN/UPC 제품을 조회합니다. 등록되지 않은 제품은 `product: null`을 반환하며,
영양 필수값이 누락된 제품은 사진 분석 또는 직접 입력을 안내합니다.
나트륨은 g에서 mg으로 변환하고, kJ 열량은 kcal로 변환합니다.

서버 함수는 코드 추가와 별도로 배포해야 합니다.

```powershell
npx --yes supabase@2.81.3 functions deploy product-barcode --use-api
npx --yes supabase@2.81.3 functions deploy analyze-meal-image --use-api
npx --yes supabase@2.81.3 functions deploy nutrition-search --use-api
```

바코드 검증 및 영양값 변환 테스트(Node.js 22.6 이상):

```powershell
node --experimental-strip-types tool/product_barcode_test.mjs
```
AI 응답 스키마는 간단한 필드와 타입만 요청합니다. 범위와 배열 크기를 포함한 복잡한 스키마가 Gemini에서 400 INVALID_ARGUMENT을 반환하여, 결과의 숫자 범위 및 배열 크기는 서버 sanitizer에서 제한합니다.

## 앱 아이콘과 배변 형태 안내

앱 아이콘은 `assets/branding/naazza-icon-sprout-note.png`의 새싹 노트입니다.
`tool/generate_launcher_icons.py`로 Android(기존 PNG 및 적응형), iOS, macOS,
Windows, 웹 리소스를 다시 생성할 수 있습니다. Python과 Pillow가 필요합니다.

배변 형태는 브리스톨 1~7 데이터 값을 유지하면서 번호·한국어
이름·짧은 설명으로 선택합니다. 저장한 기록과 이전 기록의 타임라인 요약에도
이름을 표시합니다. 형태 안내는 진단이나 점수 판정 대신 관찰한 모습을 고르게
하며, 숫자가 클수록 묽은 편임을 설명합니다.

형태 정의 참고: [University Hospitals Plymouth NHS Trust — Bristol Stool Chart](https://www.plymouthhospitals.nhs.uk/display-pil/pil-loss-of-bowel-motions-in-adults-4092/).

`test/bowel_record_page_test.dart`는 선택·저장, 기존 기록 수정, 큰 글씨·좁은 화면,
선택 상태의 접근성을 검증합니다. `NAAZZA_WRITE_PREVIEW`를 출력 PNG 경로로 설정하면
Flutter 형태 안내를 렌더링합니다. 로컬 미리보기에서는 선택적으로
`NAAZZA_PREVIEW_FONT`와 `NAAZZA_PREVIEW_MATERIAL_FONT`에 폰트 파일 경로를 지정할 수
있습니다.
배변 선택 화면에는 형태 그림이나 연상 도형을 표시하지 않습니다. 숫자와 상태 설명만으로 선택합니다.

매일 선택하는 화면은 번호와 짧은 한 줄 이름만 표시합니다. 긴 정의와 척도 안내는 `설명 보기`에서 필요할 때 열며, 안내를 열거나 닫아도 선택값은 바뀌지 않습니다.

## 최근 기록 입력 개선

- 캘린더: 식사 카테고리별 묶음·필터와 배변·검진·음주 목록, 날짜별 아이콘, 상세 조회 및 수정
- 식사: 사진·제품 바코드·영양 검색, 이름만 기록, 전체 용량 대비 소분 비율 및 열량 계산
- 음주: 주종과 잔/병 선택, 병·캔·페트 용량, 여러 주종 저장 및 상세 수정
- 진료: 세션에서 최근 병원/기관 3개와 진료과 5개를 최신순으로 제안. ×는 제안만 삭제하며 실제 기록에는 영향을 주지 않는다.
- 입력: 선택 문구 제거, 다음 진료일과 알림의 여백, 키보드 위 저장 버튼 및 드래그 시 키보드 닫기
- 홈: 내 음식 메뉴와 페이지 제거
- 앱 아이콘: 사용자가 선택한 새싹 노트·샐러드 이미지 적용

음주 기록의 서버 확장은 `20261010222553_alcohol_logs.sql`,
`20261010224829_alcohol_items.sql` 마이그레이션에 포함되어 있다.


## 공공데이터 영양·원재료 조회

제품 사진에서 단일 상품을 식별하면 공공데이터 후보 확인으로 연결하며, 음식 검색도 공공데이터를 사용한다. 제품명·규격·제조사를 사용자가 확인한 뒤 적용한다. 미수록 상품은 사진을 첨부해 직접 입력할 수 있다. 영양정보는 product-nutrition/nutrition-search, 품목제조번호 기반 원재료는 product-ingredients 함수가 제공한다. 서버 전용 DATA_GO_KR_API_KEY(15100064 승인 Decoding 키), FOODSAFETY_API_KEY(C002 승인 키)가 필요하다. 최신 구현 및 실검증 범위는 docs/public-product-nutrition-plan.md를 참고한다. 이름만 같은 이전 기록은 사용하지 않는다.


원재료는 식사 상세의 원재료 정보 보기 버튼에서 조회한다. 새 기록에는 원재료 본문을 저장하지 않고 휴대폰 로컬 캐시에 당일 결과를 보관한다(7일 만료, 100건/2MiB 상한). 업체명 표기 차이는 안내하고 품목번호로 조회된 원문을 표시한다. 자세한 정책과 실제 사진 용량은 docs/ingredient-on-demand-cache.md를 참고한다.
