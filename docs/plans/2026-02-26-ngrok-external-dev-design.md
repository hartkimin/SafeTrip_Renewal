# WSL2 + ngrok 외부 공유 개발 환경 설계

**날짜:** 2026-02-26
**목적:** 물리 기기에서 Firebase Auth Emulator + 로컬 백엔드를 외부 네트워크로 접근 가능하게 구성

---

## 1. 배경 및 문제

- Firebase Auth Emulator가 `--import` 없이 시작되어 테스트 유저 0명
- 물리 기기(외부 네트워크)에서 로컬 서비스 접근 불가
- 하드코딩된 IP(`192.168.219.115`)는 같은 WiFi에서만 동작
- 테스트 유저가 아닌 실제 여행 생성/참여 플로우 검증 필요

---

## 2. 아키텍처

```
Flutter 앱 (물리 기기, 외부 네트워크)
    ↓ HTTPS
ngrok Cloud
    ↓ HTTP 터널
WSL2 localhost
├── Backend API          :3001  (Node.js npm run dev)
├── Firebase Auth EMU    :9099
├── Firebase RTDB EMU    :9000
└── Firebase Storage EMU :9199
```

ngrok이 WSL2 내부에서 `localhost`로 직접 연결하므로 Windows `netsh portproxy` 불필요.

---

## 3. 변경 파일 목록

### 새 파일
| 경로 | 역할 |
|------|------|
| `scripts/ngrok.yml` | ngrok 4개 터널 설정 |
| `scripts/start-dev-ngrok.sh` | 에뮬레이터 + ngrok 시작, `.env` 자동 업데이트 |

### 수정 파일
| 경로 | 변경 내용 |
|------|----------|
| `safetrip-mobile/lib/config/firebase_emulator_config.dart` | 서비스별 개별 URL + HTTPS(포트 443) 지원 |
| `safetrip-mobile/.env.local` | 새 환경변수 구조로 업데이트 |

---

## 4. 환경변수 구조

### 기존 (로컬 WiFi 전용)
```env
USE_FIREBASE_EMULATOR=true
FIREBASE_EMULATOR_HOST=192.168.219.115
API_SERVER_URL=http://192.168.219.115:3001
```

### 신규 (ngrok 지원, start-dev-ngrok.sh가 자동 업데이트)
```env
USE_FIREBASE_EMULATOR=true

# ngrok이 자동으로 채워주는 값들
API_SERVER_URL=https://xxx.ngrok-free.app
FIREBASE_AUTH_EMULATOR_URL=https://yyy.ngrok-free.app
FIREBASE_RTDB_EMULATOR_URL=https://zzz.ngrok-free.app
FIREBASE_STORAGE_EMULATOR_URL=https://www.ngrok-free.app
```

### `.env.local` (초기값 / 로컬 WiFi 폴백)
```env
USE_FIREBASE_EMULATOR=true
FIREBASE_EMULATOR_HOST=10.0.2.2        # Android 에뮬레이터용
API_SERVER_URL=http://10.0.2.2:3001
```

---

## 5. firebase_emulator_config.dart 로직

```
connectIfNeeded():
  if USE_FIREBASE_EMULATOR != 'true' → return

  # 개별 URL이 있으면 ngrok 모드 (HTTPS, port 443)
  if FIREBASE_AUTH_EMULATOR_URL 설정됨:
    host = URL에서 호스트만 추출 (https:// 제거)
    useAuthEmulator(host, 443, isEmulatorSecure: true)
  else:
    host = FIREBASE_EMULATOR_HOST (폴백)
    useAuthEmulator(host, 9099)

  # RTDB, Storage도 동일 패턴
```

---

## 6. start-dev-ngrok.sh 동작 순서

```
1. ngrok 설치 확인
2. NGROK_AUTHTOKEN 환경변수 확인
3. Firebase Emulator 시작
   - firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
4. ngrok start --all --config scripts/ngrok.yml (백그라운드)
5. ngrok API(localhost:4040) 응답 대기 (최대 15초)
6. 터널 URL 4개 파싱
7. safetrip-mobile/.env 업데이트 (4개 URL 교체)
8. 터미널 출력:
   - 각 서비스 URL
   - "flutter run 또는 앱 재시작 후 테스트 가능" 안내
   - Firebase Auth 인증 코드 확인 방법 안내 (localhost:4000)
```

---

## 7. 물리 기기 테스트 플로우

```
① PC: sh scripts/start-dev-ngrok.sh 실행
② 물리 기기: flutter run 또는 설치된 앱 재실행
③ 앱: 전화번호 입력 → Auth Emulator로 전송
④ PC: localhost:4000/auth 에서 SMS 코드 확인
⑤ 앱: 코드 입력 → 로그인 성공
⑥ 앱: 여행 생성 → 실제 UUID group_id 발급
⑦ 앱: 초대 코드 공유 → 다른 기기 참여 가능
```

---

## 8. ngrok 사전 요구사항

- [ngrok.com](https://ngrok.com) 무료 계정 가입
- authtoken 발급: Dashboard → Your Authtoken
- WSL2 설치: `curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt update && sudo apt install ngrok`
- `export NGROK_AUTHTOKEN=your_token` (또는 `~/.bashrc`에 추가)
