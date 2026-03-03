# SafeTrip Firebase + AWS RDS 아키텍처

## 📋 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [서비스 분리 전략](#서비스-분리-전략)
3. [데이터 동기화 패턴](#데이터-동기화-패턴)
4. [PostgreSQL만 사용 시 문제점](#postgresql만-사용-시-문제점)
5. [Firebase Realtime DB 사용 이유](#firebase-realtime-db-사용-이유)

---

## 아키텍처 개요

### 기술 스택

```
┌─────────────────────────────────────────────────────────┐
│                    모바일 앱 (Flutter/iOS/Android)        │
└─────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌─────────────┐
    │Firebase │    │AWS RDS   │    │Firebase    │
    │Realtime │    │PostgreSQL│    │Functions   │
    │Database │    │(PostGIS)  │    │            │
    └─────────┘    └──────────┘    └─────────────┘
         │               │              │
         │               │              │
         └───────────────┼──────────────┘
                         │
                   동기화 & 비즈니스 로직
```

### 서비스 역할

| 서비스 | 역할 | 데이터 타입 |
|--------|------|------------|
| **Firebase Realtime Database** | 실시간 데이터 스트림 | 위치, 지오펜스, 메시지, 토큰 |
| **AWS RDS PostgreSQL** | 관계형 + 공간 데이터 | 사용자, 여행, 그룹, 위치 이력, PostGIS 쿼리 |
| **Firebase Functions** | 동기화 및 비즈니스 로직 | RTDB ↔ PostgreSQL |

---

## 서비스 분리 전략

### 📍 Firebase Realtime Database (실시간 데이터)

| 데이터 | 경로 | 용도 | TTL |
|--------|------|------|-----|
| **위치 스트림** | `/realtime_locations/{user_id}` | 최신 위치만 (보호자/그룹 실시간 조회) | 24시간 |
| **지오펜스** | `/realtime_geofences/{group_id}/{geofence_id}` | 활성 지오펜스 정보 | 없음 |
| **그룹 메시지** | `/realtime_messages/{group_id}/{message_id}` | 실시간 채팅 | 없음 |
| **메시지 읽음 상태** | `/realtime_message_reads/{group_id}/{message_id}/{user_id}` | 읽음 상태 | 없음 |
| **FCM 토큰** | `/realtime_tokens/{user_id}/{token_id}` | 디바이스 토큰 관리 | 없음 |

**자세한 내용**: [Firebase Realtime Database](../04-firebase/firebase-rtdb.md)

### 🗄️ AWS RDS PostgreSQL (영구 저장 + 공간 계산)

#### 1. 관계형 데이터 (PostGIS 불필요)
- `TB_USER` - 사용자 계정 및 프로필
- `TB_TRIP` - 여행 정보
- `TB_GROUP` - 그룹 정보
- `TB_GROUP_MEMBER` - 그룹 멤버십
- `TB_GUARDIAN` - 보호자 관계
- `TB_TRAVEL_SCHEDULE` - 여행 일정
- `TB_DEVICE_TOKEN` - 디바이스 토큰
- `TB_EVENT_LOG` - 통합 이벤트 로그

#### 2. PostGIS 필수 데이터 (공간 계산 필요)
- `TB_LOCATION` - 위치 이력 전체 (분석/통계용)
- `TB_MOVEMENT_SESSION` - 이동 세션 (시작/종료 위치, 거리 계산)
- `TB_GEOFENCE` - 지오펜스 정의 (PostgreSQL에 저장, Firebase Realtime Database와 동기화)
- `TB_GEOFENCE_EVENT` - 지오펜스 이벤트 이력
- `TB_PLANNED_ROUTE` - 계획 경로 (LineString - 경로 이탈 감지)
- `TB_ROUTE_DEVIATION` - 경로 이탈 이력

#### 3. 마스터 데이터 (PostGIS 불필요)
- `TB_COUNTRY` - 국가 정보
- `TB_GUIDE` - 국가별 여행 가이드

### ⚡ PostGIS가 꼭 필요한 이유

| 기능 | PostGIS 없이 | PostGIS 사용 |
|------|------------|------------|
| **지오펜스 체크** | ❌ 불가능 (다각형 내부 판단) | ✅ `ST_Contains()` |
| **원형 반경 체크** | ❌ 느림 (거리 계산 복잡) | ✅ `ST_DWithin()` |
| **경로 이탈 감지** | ❌ 불가능 (LineString 거리) | ✅ `ST_Distance()` |
| **공간 인덱스** | ❌ 없음 | ✅ GIST 인덱스 (100배 빠름) |

**결론: PostGIS 없이는 지오펜스와 경로 이탈 감지 기능을 구현할 수 없습니다.**

### 📊 데이터 흐름

```
모바일 앱 → Firebase Realtime Database (최신 위치)
                ↓
        Firebase Functions (선택적)
                ↓
    AWS RDS PostgreSQL (전체 이력 저장)
                ↓
    PostGIS (지오펜스/경로 이탈 계산)
                ↓
        Firebase Realtime Database (알림 이벤트)
```

---

## 데이터 동기화 패턴

### 패턴 1: Firebase Realtime Database → PostgreSQL (실시간 → 영구 저장)

**위치 데이터 흐름:**
1. 모바일 앱이 Firebase Realtime Database에 최신 위치 저장 (`/realtime_locations/{user_id}`)
2. 백엔드 API가 주기적으로 PostgreSQL에 전체 위치 이력 저장
3. PostGIS로 지오펜스 체크 및 경로 이탈 감지
4. 이벤트 발생 시 Firebase Realtime Database에 알림 저장

**지오펜스 이벤트 흐름:**
1. 모바일 앱 (flutter_background_geolocation)이 지오펜스 진입/이탈 감지
2. 백엔드 API에 이벤트 전송 (`POST /api/v1/geofences/events`)
3. PostgreSQL에 지오펜스 이벤트 이력 저장
4. Firebase Realtime Database에 실시간 업데이트

**이동 세션 관리:**
1. 모바일 앱이 이동 시작/종료 감지
2. 백엔드 API에 위치 업로드 (`POST /api/v1/locations`)
3. PostgreSQL에 이동 세션 생성/업데이트
4. 세션 완료 시 지도 이미지 생성 (Google Maps Static API)
5. Firebase Storage에 이미지 저장

### 패턴 2: PostgreSQL → Firebase Realtime Database (캐시 업데이트)

**지오펜스 동기화:**
- PostgreSQL에 지오펜스 생성/수정/삭제 시
- Firebase Realtime Database에 동기화 (`/realtime_geofences/{group_id}/{geofence_id}`)
- 모바일 앱에서 실시간으로 지오펜스 정보 수신

---

## PostgreSQL만 사용 시 문제점

### ❌ 실시간성 문제
- 레이턴시: 200-500ms (네트워크 + DB 쿼리)
- 위치 업데이트마다 네트워크 왕복 필요
- 보호자가 위치 조회 시 매번 PostgreSQL 쿼리

### ❌ 확장성 문제
- 보호자가 위치 조회 시: 매번 PostgreSQL 쿼리
- 사용자 1,000명 × 보호자 3명 = 초당 수천 건 쿼리
- 동시 접속 증가 시 DB 부하 급증

### ❌ 오프라인 지원 한계
- Firebase Realtime Database는 자동 동기화 지원
- PostgreSQL만 사용 시 앱에서 직접 처리 필요 (복잡도 증가)

### ❌ 실시간 업데이트 부족
- 보호자가 위치 조회 시 폴링 필요
- Firebase Realtime Database는 리스너로 실시간 업데이트 가능

### 결론
PostgreSQL만 사용하면 실시간성이 크게 떨어지고, 대규모 그룹에서 동시 위치 조회 시 성능 문제가 발생합니다.

---

## Firebase Realtime DB 사용 이유

### Firebase Realtime Database vs Firestore 비교

| 항목 | Realtime Database | Firestore | 현재 사용 |
|------|-------------------|-----------|----------|
| **레이턴시** | 50-100ms | 100-200ms | ✅ Realtime DB |
| **데이터 구조** | JSON 트리 | 문서/컬렉션 | ✅ Realtime DB |
| **쿼리 기능** | ❌ 제한적 | ✅ 강력 | Realtime DB (단순 구조) |
| **오프라인 지원** | ✅ 우수 | ✅ 우수 | 동일 |
| **비용 (읽기)** | $0.01/100K | $0.06/100K | ✅ Realtime DB 저렴 |
| **비용 (쓰기)** | $0.05/100K | $0.18/100K | ✅ Realtime DB 저렴 |
| **스케일링** | ✅ 자동 | ✅ 자동 | 동일 |
| **복잡도** | 낮음 | 중간 | ✅ Realtime DB 단순 |

### ✅ Firebase Realtime Database 사용 이유

**1. 실시간 위치 공유**
- 그룹 멤버들의 최신 위치를 실시간으로 동기화
- 리스너로 자동 업데이트 (폴링 불필요)
- 오프라인 자동 동기화

**2. 지오펜스 실시간 동기화**
- PostgreSQL에 저장된 지오펜스를 RTDB로 동기화
- 모바일 앱에서 실시간으로 지오펜스 정보 수신
- flutter_background_geolocation에서 직접 사용

**3. 그룹 채팅**
- 실시간 메시지 전송 및 읽음 상태 동기화
- 오프라인 메시지 자동 동기화

**4. 비용 효율성**
- 위치 업데이트가 빈번한 경우 Firestore보다 저렴
- 읽기/쓰기 비용이 낮음

### 데이터 분리 전략

**Firebase Realtime Database:**
- 실시간 위치 스트림 (`/realtime_locations`)
- 활성 지오펜스 정보 (`/realtime_geofences`)
- 그룹 메시지 (`/realtime_messages`)
- 메시지 읽음 상태 (`/realtime_message_reads`)
- FCM 토큰 (`/realtime_tokens`)

**AWS RDS PostgreSQL:**
- 모든 영구 데이터
- 관계형 데이터, PostGIS 쿼리
- 위치 이력 전체
- 이동 세션 및 이벤트 로그

### 성능 비교

**Firebase Realtime Database 사용:**
- 위치 업데이트: RTDB 저장 (~50ms) → 백엔드 동기화 → PostgreSQL 저장
- 실시간 조회: RTDB 리스너로 즉시 업데이트 (~50ms)
- 총 소요: ~50-100ms ✅

**PostgreSQL만 사용:**
- 위치 업데이트: API 호출 → PostgreSQL 저장 (~200ms)
- 실시간 조회: 폴링 또는 WebSocket 필요 (~200-500ms)
- 총 소요: ~200-500ms ❌

---

## 결론

### 현재 아키텍처: Firebase Realtime Database + AWS RDS PostgreSQL

**Firebase Realtime Database:**
- 실시간 데이터 (위치, 지오펜스, 메시지)
- 빠른 읽기/쓰기 (50-100ms)
- 자동 오프라인 동기화
- 비용 효율적

**AWS RDS PostgreSQL (PostGIS 포함):**
- 영구 저장 (위치 이력, 사용자, 여행, 그룹)
- 공간 계산 (지오펜스, 경로 이탈)
- 복잡한 관계형 쿼리
- 데이터 분석 및 통계

**이 하이브리드 아키텍처는 실시간성과 영구 저장, 공간 계산을 모두 만족합니다.**

---

**작성일**: 2025-01-15  
**버전**: 2.0 (AWS RDS + Firebase Realtime Database 기준)
