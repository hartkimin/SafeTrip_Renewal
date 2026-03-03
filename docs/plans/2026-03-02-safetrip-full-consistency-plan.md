# SafeTrip 전체 문서 일관성 점검 및 수정 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Master + #02~#34 (34개 문서)를 비즈니스 원칙 v5.1 기준으로 점검하고 불일치 부분만 수정한다.

**Architecture:** 2-Phase 처리 — Phase 1에서 6개 그룹을 병렬 Explore하여 마스터 불일치 목록을 생성하고, Phase 2에서 불일치가 있는 문서만 타겟 Fix한다. Edit 도구만 사용하며 전체 재작성은 금지한다.

**Tech Stack:** Explore 에이전트 (Grep + Read), Edit 도구, Master_docs 경로: `/mnt/d/Project/15_SafeTrip_New/Master_docs/`

---

## 핵심 체크 항목 (모든 Explore 에이전트 공통)

다음 항목을 각 문서에서 확인한다:

| # | 체크 항목 | 기준값 (v5.1) |
|:-:|-----------|-------------|
| 1 | 버전 참조 | `v5.1` (v5.0 → 오류) |
| 2 | DB 버전 참조 | `v3.4` (v3.3 → 오류) |
| 3 | 역할명 | 캡틴/크루장/크루/가디언 |
| 4 | 계정 삭제 유예기간 | `7일` (§14.4) — 30일은 오류 |
| 5 | 채팅 메시지 보존 | `여행 종료 후 90일` (§13.1) — 영구보존/30일은 오류 |
| 6 | 가디언 무료 기준 | `멤버당 2명` (§09.3) — "여행당"은 오류 |
| 7 | 가디언 유료 금액 | `1,900원/여행` 3~5번째 (§09.3) |
| 8 | 여행 기간 최대 | `15일` (§02.3) |
| 9 | 프라이버시 등급 | `안전최우선/표준/프라이버시우선` 3등급 (§04) |
| 10 | SOS 시나리오 수 | `6가지` (§05.1) |
| 11 | B2B 분기 | §12 반영 여부 (해당 문서만) |
| 12 | 외부 API 목록 | §14 목록과 일치 (해당 문서만) |

---

## 기준 문서 경로

- **비즈니스 원칙**: `/mnt/d/Project/15_SafeTrip_New/Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- **DB 설계**: `/mnt/d/Project/15_SafeTrip_New/Master_docs/07_T2_DB_설계_및_관계_v3_4.md`

---

## ━━━━━━━━━━━━ PHASE 1: EXPLORE (병렬 실행) ━━━━━━━━━━━━

> **중요**: Task 1~6은 서로 독립적이므로 6개 에이전트를 동시에 투입한다.
> `superpowers:dispatching-parallel-agents` 스킬 적용.

---

### Task 1: Explore G1 — Master + #02~#06

**대상 파일:**
- Read: `Master_docs/Master_SafeTrip_마스터_원칙_거버넌스_v2_0.md`
- Read: `Master_docs/02_T0_SafeTrip_개인정보처리방침_원칙_v1_0.md`
- Read: `Master_docs/03_T0_SafeTrip_위치기반서비스_이용약관_원칙_v1_0.md`
- Read: `Master_docs/04_T0_SafeTrip_서비스_이용약관_원칙_v1_0.md`
- Read: `Master_docs/05_T0_SafeTrip_미성년자_보호_원칙_v1_0.md`
- Read: `Master_docs/06_T0_SafeTrip_긴급_구조기관_연동_원칙_v1_0.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 중 §09.3, §13.1, §14.4, §02.3, §04, §05.1

**Step 1: Grep으로 오류 패턴 빠른 스캔**

각 파일에 대해 다음 패턴을 Grep:
```
- "v5\.0" (버전 오류)
- "v3\.3" (DB 버전 오류)
- "30일" (계정 삭제 유예 오류 후보)
- "영구 보존" (채팅 오류 후보)
- "여행당 최대 2명" (가디언 기준 오류)
- "별도 고지" (가디언 금액 오류)
```

**Step 2: 각 파일 전체 읽기 및 상세 점검**

파일별로 위 12개 체크 항목을 직접 확인한다.

**Step 3: 불일치 목록 출력**

출력 형식:
```
## G1 Explore 결과

### Master_SafeTrip_마스터_원칙_거버넌스_v2_0.md
- [없음] / [있음: 목록]

### 02_T0_..._개인정보처리방침_원칙_v1_0.md
- 불일치 없음 (오늘 수정 완료)

... (각 파일별)
```

---

### Task 2: Explore G2 — #07~#10

**대상 파일:**
- Read: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
- Read: `Master_docs/08_T2_SafeTrip_아키텍처_구조_v3_0.md`
- Read: `Master_docs/09_T1_SafeTrip_위치_데이터_수집_저장_삭제_정책_v1_0.md`
- Read: `Master_docs/10_T2_화면구성원칙.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 관련 섹션

**Step 1: Grep으로 오류 패턴 빠른 스캔**

위 Task 1과 동일한 패턴으로 스캔.

**Step 2: 각 파일 전체 읽기 및 상세 점검**

#10 화면구성원칙은 오늘 이전에 생성된 파일이므로 특히 꼼꼼히 확인한다.

**Step 3: 불일치 목록 출력**

동일 형식.

---

### Task 3: Explore G3 — #11~#16

**대상 파일:**
- Read: `Master_docs/11_T2_바텀시트_동작_규칙.md`
- Read: `Master_docs/12_T1_국제_데이터_처리_원칙.md`
- Read: `Master_docs/13_T3_SOS_원칙.md`
- Read: `Master_docs/14_T3_온보딩_UX_시나리오.md`
- Read: `Master_docs/15_T3_설정_메뉴_원칙.md`
- Read: `Master_docs/16_T2_오프라인_동작_통합_원칙.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 관련 섹션

**Step 1~3: Task 1과 동일한 프로세스**

추가 확인 항목:
- #13 SOS: SOS 6가지 시나리오 모두 포함 여부 (§05.1)
- #14 온보딩: 약관 동의 체계 §06.5 반영 여부
- #15 설정: 가디언 과금 UI §09.3 반영 여부

---

### Task 4: Explore G4 — #17~#22

**대상 파일:**
- Read: `Master_docs/17_T3_지도_기본화면_고유_원칙.md`
- Read: `Master_docs/18_T3_일정탭_원칙.md`
- Read: `Master_docs/19_T3_멤버탭_원칙.md`
- Read: `Master_docs/20_T3_채팅탭_원칙.md`
- Read: `Master_docs/21_T3_안전가이드_원칙.md`
- Read: `Master_docs/22_T3_알림버튼_원칙.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 관련 섹션

**Step 1~3: Task 1과 동일한 프로세스**

추가 확인 항목:
- #18 일정탭: 여행 기간 15일 제한 §02.3 반영 여부
- #19 멤버탭: 가디언 무료 2명/유료 §09.3 반영 여부
- #20 채팅탭: 채팅 메시지 보존 90일 §13.1 반영 여부

---

### Task 5: Explore G5 — #23~#28

**대상 파일:**
- Read: `Master_docs/23_T3_초대코드_원칙.md`
- Read: `Master_docs/24_T3_여행정보카드_원칙.md`
- Read: `Master_docs/25_T3_멤버별_이동기록_원칙.md`
- Read: `Master_docs/26_T3_AI_기능_원칙.md`
- Read: `Master_docs/27_T3_프로필화면_원칙.md`
- Read: `Master_docs/28_T3_스플래시_화면_원칙.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 관련 섹션

**Step 1~3: Task 1과 동일한 프로세스**

추가 확인 항목:
- #23 초대코드: B2B CSV 일괄 생성 §12.3 반영 여부
- #26 AI기능: 기준 문서 v5.0→v5.1 전환 여부 (특히 주의)

---

### Task 6: Explore G6 — #29~#34

**대상 파일:**
- Read: `Master_docs/29_T3_웰컴화면_원칙.md`
- Read: `Master_docs/30_T3_데모_투어_체험_원칙.md`
- Read: `Master_docs/31_T4_앱_성능_안정성_모니터링_원칙.md`
- Read: `Master_docs/32_T4_사고_대응_면책_투명성_원칙.md`
- Read: `Master_docs/33_T4_외부_API_연동_관리_원칙.md`
- Read: `Master_docs/34_T1_프로젝트_구조.md`
- Read (기준): `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` 관련 섹션

**Step 1~3: Task 1과 동일한 프로세스**

추가 확인 항목:
- #31 앱 성능: SLA 기준이 아키텍처 #08과 일치하는지
- #33 외부 API: §14 외부 서비스 목록과 일치 여부

---

## ━━━━━━━━━━━━ PHASE 1 → 2 전환 ━━━━━━━━━━━━

### Task 7: Consolidate — Phase 1 결과 통합

> **이 Task는 Controller(주 에이전트)가 직접 수행한다.**

**Step 1: Task 1~6 결과 수집**

6개 Explore 에이전트의 결과를 모아 다음 형식으로 정리:

```
## 마스터 불일치 목록

### 수정 필요 문서:
- Master_doc: [항목들]
- #10 화면구성원칙: [항목들]
- #11 ...: [항목들]
...

### 수정 불필요 문서 (이상 없음):
- #02, #03, ... (오늘 이미 수정된 문서 포함)
```

**Step 2: Fix Phase 태스크 계획**

불일치가 있는 문서들을 그룹화하여 Phase 2 Fix 태스크를 동적으로 계획한다.
- 불일치 없는 문서: 스킵
- 불일치 있는 문서: 아래 Fix 태스크 템플릿으로 처리

---

## ━━━━━━━━━━━━ PHASE 2: FIX (순차 실행) ━━━━━━━━━━━━

> Phase 2 태스크는 Phase 1 결과 기반으로 동적으로 생성된다.
> 아래는 각 Fix 태스크의 공통 템플릿이다.

---

### Task 8+: Fix [문서명] — [불일치 건수]건 수정

> Phase 1에서 불일치가 발견된 문서마다 이 구조로 처리한다.

**대상 파일:**
- Modify: `Master_docs/[파일명].md`

**Step 1: Explore 결과 확인**

Task 7에서 통합된 마스터 불일치 목록 중 이 문서의 항목을 확인한다.

**Step 2: Edit 도구로 불일치 수정**

각 불일치 항목에 대해:
```
현재값: [Explore에서 발견된 오류값]
변경값: [v5.1 기준값]
위치: [파일 내 섹션/행]
```

**주의사항:**
- Edit 도구만 사용 (전체 파일 재작성 금지)
- 불일치 부분 외 NO TOUCH
- 문서 구조/문체/원본 내용 최대한 보존

**Step 3: 변경 이력 추가**

문서 내 변경 이력 섹션에 추가:
```markdown
| [날짜] | v[버전+1] | 비즈니스 원칙 v5.1 기준 [수정 항목] 수정 |
```

**Step 4: Grep으로 수정 검증**

수정된 항목이 실제로 변경되었는지 Grep으로 확인:
```bash
# 오류 패턴이 남아있지 않은지 확인
Grep "v5\.0" [파일명]  # 결과: 없어야 함
Grep "30일" [파일명]   # 결과: 계정삭제 맥락이면 없어야 함
```

---

## ━━━━━━━━━━━━ 완료 후 처리 ━━━━━━━━━━━━

### Task N (최종): Notion 기록

**Step 1: Notion 오늘 날짜 페이지에 기록**

`mcp__claude_ai_Notion__notion-update-page` 사용:
- 페이지 ID: `316a19580398815cb74bc9d09481cb4b` (2026-03-02 개발사항)
- 블록 형식: 토글, 제목 = `HH:MM — SafeTrip 전체 문서(34개) v5.1 일관성 점검 완료`
- 내용: 수정된 문서 목록 + 총 수정 건수

---

## 처리 흐름 요약

```
Phase 1 (병렬):
  Task 1: Explore G1 ─┐
  Task 2: Explore G2 ─┤
  Task 3: Explore G3 ─┼─ 동시 실행 → Task 7: 결과 통합
  Task 4: Explore G4 ─┤
  Task 5: Explore G5 ─┤
  Task 6: Explore G6 ─┘

Phase 2 (순차, 불일치 문서만):
  Task 8:  Fix 문서A
  Task 9:  Fix 문서B
  Task 10: Fix 문서C
  ...

완료:
  Task N: Notion 기록
```
