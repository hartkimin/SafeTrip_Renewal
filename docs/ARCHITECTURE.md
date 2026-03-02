# SafeTrip Flutter Architecture Decisions

> 마지막 업데이트: 2026-03-02
>
> 이 문서는 프로덕션 Flutter 개발의 기술적 의사결정을 기록한다.

---

## 1. 상태 관리: Riverpod

**결정:** `flutter_riverpod` v2.x

**이유:**
- SafeTrip은 역할(캡틴/크루장/크루/가디언) + 프라이버시 등급(3종)에 따라
  동일 화면에서 UI 분기가 많음 → Provider 트리 세밀 관리 필요
- Riverpod의 `family`/`autoDispose` modifier로 여행별 상태 격리 가능
- 테스트 시 `ProviderContainer`로 mock injection 용이
- PoC 코드에서 `setState` + 직접 서비스 호출 패턴 → 교체

**마이그레이션 전략:**
- Phase 1: 신규 화면은 Riverpod 사용
- Phase 2: 기존 PoC 화면을 순차적으로 Riverpod으로 전환

---

## 2. 폴더 구조: Feature-Based

```
safetrip-mobile/lib/
├── core/
│   ├── constants/          (기존 constants/ 이동)
│   ├── theme/              (DESIGN.md 기반 토큰: colors, typography, spacing)
│   ├── network/            (Dio 클라이언트 설정, 인터셉터)
│   ├── error/              (공통 에러 처리, AppException 클래스)
│   └── utils/              (기존 utils/ 이동)
│
├── features/
│   ├── auth/               (로그인, 프로필 설정, 약관 동의)
│   │   ├── data/           (repository, API 호출)
│   │   ├── domain/         (use case, entity)
│   │   └── presentation/   (screens, widgets, providers)
│   ├── trip/               (여행 CRUD, 멤버 관리, 여행 선택)
│   ├── guardian/           (가디언 관리, 메시지, 대시보드)
│   ├── location/           (지도, 실시간 위치, 지오펜스)
│   ├── chat/               (채팅탭, 메시지 목록)
│   ├── guide/              (안전가이드, MOFA 탭)
│   ├── settings/           (설정 메뉴, 프로필 화면)
│   └── onboarding/         (스플래시, 웰컴, 역할 선택, 초대코드)
│
├── shared/
│   ├── widgets/            (기존 widgets/ — AppButton, AppCard 등 공통 컴포넌트)
│   ├── models/             (기존 models/ — User, Schedule, Guardian 등)
│   └── services/           (기존 services/ 중 공통: FCM, API base, etc.)
│
├── router/                 (기존 GoRouter 설정 유지)
└── main.dart
```

**마이그레이션 전략:**
- 기존 `lib/` 구조는 건드리지 않고 병행 운영
- 신규 화면은 `features/` 하위에 작성
- 기존 화면은 Sprint별로 순차 이동

---

## 3. 네트워크 레이어: Dio

**결정:** `dio` v5.x + 커스텀 인터셉터

**인터셉터 구성:**

```dart
// core/network/api_client.dart
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_SERVER_URL'] ?? 'http://10.0.2.2:3001',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(AuthInterceptor());  // Firebase ID Token 자동 주입
    _dio.interceptors.add(LogInterceptor());   // 개발 환경 로깅
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

---

## 4. 코드 품질 기준

**Linter:** `flutter_lints` + 추가 규칙 (`analysis_options.yaml`)
**포맷터:** `dart format` (line length 100)
**CI:** GitHub Actions (`flutter-analyze.yml`) — PR 시 자동 실행

**추가 규칙 (analysis_options.yaml에 추가 예정):**
- `prefer_const_constructors: true`
- `prefer_final_fields: true`
- `avoid_print: true` (debugPrint 사용)

---

## 5. 의존성 주입

Riverpod의 `Provider`/`StateNotifierProvider`/`FutureProvider`를 활용.
별도 DI 프레임워크 사용 안 함 (YAGNI).

---

## 참조

- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 화면구성원칙: `Master_docs/10_T2_화면구성원칙.md`
- API 명세서: `Master_docs/35~38_T2_API_명세서_*.md`
