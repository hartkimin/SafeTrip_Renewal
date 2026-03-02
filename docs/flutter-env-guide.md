# Flutter 환경 설정 가이드

## 환경별 .env 파일 전환

SafeTrip Flutter는 `flutter_dotenv`로 런타임에 `.env` 파일을 로드한다.
환경을 바꾸려면 `.env` 파일을 교체하면 된다.

| 환경 | 방법 |
|------|------|
| 로컬 (Android 에뮬레이터) | `cp .env.example .env` → `10.0.2.2`를 실제 PC IP로 변경 |
| 로컬 (ngrok) | `bash ../scripts/start-dev-ngrok.sh` (자동 설정) |
| Staging | `cp .env.staging .env` |
| Production | `cp .env.production .env` |

## 빌드 명령어

```bash
# 개발 (에뮬레이터)
cd safetrip-mobile
flutter run

# Staging APK 빌드
cp .env.staging .env && flutter build apk --release

# Production APK 빌드
cp .env.production .env && flutter build apk --release
```

## 환경 변수 목록

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `API_SERVER_URL` | 백엔드 API 기본 URL | `http://10.0.2.2:3001` |
| `USE_FIREBASE_EMULATOR` | Firebase 에뮬레이터 사용 여부 | `true` / `false` |
| `FIREBASE_EMULATOR_HOST` | 에뮬레이터 호스트 IP | `10.0.2.2` |
| `FIREBASE_AUTH_EMULATOR_URL` | Auth 에뮬레이터 URL | `http://10.0.2.2:9099` |
| `FIREBASE_RTDB_EMULATOR_URL` | RTDB 에뮬레이터 URL | `http://10.0.2.2:9000` |
| `FIREBASE_STORAGE_EMULATOR_URL` | Storage 에뮬레이터 URL | `http://10.0.2.2:9199` |

## .gitignore 정책

```
.env              # 로컬 환경 (git 제외)
.env.local        # 개인 로컬 설정 (git 제외)
.env.staging      # Staging 서버 URL (git 제외)
.env.production   # Production 서버 URL (git 제외)
.env.example      # 템플릿 (git 포함)
```

## 주의사항

- `.env` 파일을 git에 커밋하지 않는다
- `API_SERVER_URL`에 실제 프로덕션 도메인 결정 후 `.env.production` 업데이트 필요
- Android 에뮬레이터에서 `localhost`는 에뮬레이터 자신을 가리키므로 `10.0.2.2` 사용
