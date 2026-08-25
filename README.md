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

P1의 실제 Supabase 저장은 다음 테이블을 전제로 합니다.

- `user_conditions`: `user_id`, `condition_key`
- `user_tracking_metrics`: `user_id`, `metric_key`, `enabled`, `quick_log_order`
- `user_preferences`: `user_id`, `reminders_enabled`, `onboarding_completed`

클라이언트 접근을 허용하기 전에 각 테이블에 RLS와 사용자 소유권 정책을
적용하고, 그 다음 `authenticated` 역할에 필요한 Data API 권한만 부여해야
합니다. 아직 Supabase 프로젝트가 연결되지 않아 마이그레이션은 생성하지
않았습니다.
