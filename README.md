# NAAZZA

질환별 식사·증상·배변·내원 기록을 시간축으로 연결하는 Flutter 앱입니다.

## 실행

Supabase 설정 없이 실행하면 로컬 데모 인증을 사용합니다.

```powershell
flutter run
```

실제 Supabase 프로젝트를 연결할 때는 클라이언트에 공개 가능한 URL과
publishable key만 `dart-define`으로 전달합니다. `service_role` 또는 secret
key는 앱에 포함하지 않습니다.

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
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
- P6: 나짜 캐릭터·감소 모션, 내 음식 빠른 재기록, CSV 내보내기, 접근성·빈 상태 UX
- P7: EAN/UPC 바코드 스캔, 제품 영양 조회, 섭취량 보정, 식사 저장, 직접 입력 fallback

P1의 실제 Supabase 저장은 다음 테이블을 전제로 합니다.

- `user_conditions`: `user_id`, `condition_key`
- `user_tracking_metrics`: `user_id`, `metric_key`, `enabled`, `quick_log_order`
- `user_preferences`: `user_id`, `reminders_enabled`, `onboarding_completed`

클라이언트 접근을 허용하기 전에 각 테이블에 RLS와 사용자 소유권 정책을
적용하고, 그 다음 `authenticated` 역할에 필요한 Data API 권한만 부여해야
합니다. 아직 Supabase 프로젝트가 연결되지 않아 마이그레이션은 생성하지
않았습니다.

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
