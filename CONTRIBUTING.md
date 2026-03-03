# SafeTrip 기여 가이드

## 목차

1. [시작하기](#시작하기)
2. [코드 스타일](#코드-스타일)
3. [커밋 메시지 규칙](#커밋-메시지-규칙)
4. [Pull Request 프로세스](#pull-request-프로세스)
5. [코드 리뷰 가이드](#코드-리뷰-가이드)
6. [이슈 리포트](#이슈-리포트)

---

## 시작하기

### 개발 환경 설정

1. 저장소 포크
2. 로컬에 클론
```bash
git clone https://github.com/your-username/SafeTrip.git
cd SafeTrip
```

3. 개발 환경 설정
   - [개발 환경 설정 가이드](./safetrip-document/01-getting-started/development-setup.md) 참고

4. 브랜치 생성
```bash
git checkout -b feature/your-feature-name
```

---

## 코드 스타일

### Flutter/Dart

#### 포맷팅

```bash
# 자동 포맷팅
flutter format .

# 분석
flutter analyze
```

#### 네이밍 규칙

- **클래스**: PascalCase (`UserService`)
- **함수/변수**: camelCase (`getUserById`)
- **상수**: lowerCamelCase with `const` (`const apiBaseUrl`)
- **파일명**: snake_case (`user_service.dart`)

#### 예제

```dart
// ✅ 좋은 예
class UserService {
  static const String apiBaseUrl = 'https://api.safetrip.io';
  
  Future<User?> getUserById(String userId) async {
    // 구현
  }
}

// ❌ 나쁜 예
class user_service {
  static String API_BASE_URL = 'https://api.safetrip.io';
  
  Future getUser_by_id(String user_id) async {
    // 구현
  }
}
```

### TypeScript/Node.js

#### 포맷팅

```bash
# Prettier 사용
npx prettier --write "src/**/*.ts"

# ESLint
npm run lint
```

#### 네이밍 규칙

- **클래스/인터페이스**: PascalCase (`UserService`)
- **함수/변수**: camelCase (`getUserById`)
- **상수**: UPPER_SNAKE_CASE (`API_BASE_URL`)
- **파일명**: kebab-case (`user-service.ts`)

#### 예제

```typescript
// ✅ 좋은 예
export class UserService {
  private static readonly API_BASE_URL = 'https://api.safetrip.io';
  
  async getUserById(userId: string): Promise<User | null> {
    // 구현
  }
}

// ❌ 나쁜 예
export class user_service {
  private static api_base_url = 'https://api.safetrip.io';
  
  async get_user_by_id(user_id: string) {
    // 구현
  }
}
```

---

## 커밋 메시지 규칙

### 커밋 메시지 형식

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

- **feat**: 새로운 기능
- **fix**: 버그 수정
- **docs**: 문서 수정
- **style**: 코드 포맷팅 (기능 변경 없음)
- **refactor**: 리팩토링
- **test**: 테스트 추가/수정
- **chore**: 빌드 프로세스 또는 보조 도구 변경

### Scope

- **flutter**: Flutter 앱 관련
- **api**: 백엔드 API 관련
- **docs**: 문서 관련
- **ci**: CI/CD 관련

### 예제

```
feat(api): 사용자 위치 조회 API 추가

- GET /api/v1/users/:userId/location 엔드포인트 추가
- 위치 데이터 캐싱 로직 구현
- 단위 테스트 추가

Closes #123
```

```
fix(flutter): 위치 권한 요청 오류 수정

Android 12 이상에서 백그라운드 위치 권한 요청이
실패하는 문제를 수정했습니다.

Fixes #456
```

---

## Pull Request 프로세스

### PR 생성 전 체크리스트

- [ ] 코드가 프로젝트 스타일 가이드를 따름
- [ ] 자체 테스트 완료
- [ ] 관련 테스트 추가/수정
- [ ] 문서 업데이트 (필요 시)
- [ ] 커밋 메시지가 규칙을 따름

### PR 제목 형식

```
[Type] Brief description
```

예:
- `[Feature] 사용자 위치 조회 API 추가`
- `[Fix] 위치 권한 요청 오류 수정`
- `[Docs] API 가이드 업데이트`

### PR 설명 템플릿

```markdown
## 변경 사항
- 변경 내용 1
- 변경 내용 2

## 관련 이슈
Closes #123

## 테스트
- [ ] 단위 테스트 통과
- [ ] 통합 테스트 통과
- [ ] 수동 테스트 완료

## 스크린샷 (UI 변경 시)
<!-- 스크린샷 첨부 -->
```

### PR 리뷰 프로세스

1. **자동 검사**: CI/CD 파이프라인 실행
   - 테스트 실행
   - Lint 검사
   - 코드 품질 검사

2. **코드 리뷰**: 최소 1명의 승인 필요

3. **병합**: 승인 후 병합

---

## 코드 리뷰 가이드

### 리뷰어 가이드

#### 확인 사항

1. **기능 정확성**
   - 요구사항을 올바르게 구현했는가?
   - 엣지 케이스를 처리했는가?

2. **코드 품질**
   - 코드가 읽기 쉬운가?
   - 중복 코드가 없는가?
   - 적절한 네이밍을 사용했는가?

3. **성능**
   - 불필요한 쿼리나 연산이 없는가?
   - 적절한 캐싱을 사용했는가?

4. **보안**
   - 입력 검증이 있는가?
   - SQL Injection 방지가 되어 있는가?
   - 인증/인가가 올바르게 구현되었는가?

5. **테스트**
   - 충분한 테스트가 있는가?
   - 테스트가 의미 있는가?

#### 리뷰 코멘트 작성

```markdown
<!-- 건설적인 피드백 -->
💡 제안: 이 부분을 함수로 분리하면 재사용성이 높아질 것 같습니다.

<!-- 질문 -->
❓ 질문: 이 쿼리가 인덱스를 사용하는지 확인해보셨나요?

<!-- 칭찬 -->
✅ 좋습니다: 에러 처리가 잘 되어 있네요!
```

### 작성자 가이드

#### 리뷰 대응

1. **피드백 수용**: 건설적인 피드백은 수용
2. **질문 답변**: 불명확한 부분은 명확히 설명
3. **수정 사항 반영**: 요청된 수정 사항 반영 후 재요청

---

## 이슈 리포트

### 버그 리포트

#### 템플릿

```markdown
## 버그 설명
명확하고 간결한 버그 설명

## 재현 단계
1. '...'로 이동
2. '...' 클릭
3. '...' 스크롤
4. 오류 확인

## 예상 동작
예상했던 동작 설명

## 실제 동작
실제로 발생한 동작 설명

## 스크린샷
가능하면 스크린샷 첨부

## 환경
- OS: [예: iOS 16.0]
- 앱 버전: [예: 1.0.0]
- 디바이스: [예: iPhone 14 Pro]

## 추가 정보
기타 관련 정보
```

### 기능 요청

#### 템플릿

```markdown
## 기능 설명
요청하는 기능에 대한 명확한 설명

## 문제점
이 기능이 해결할 문제점

## 제안하는 해결책
기능이 어떻게 동작해야 하는지 설명

## 대안
고려한 다른 해결책

## 추가 정보
기타 관련 정보
```

---

## 참고 문서

- [개발 환경 설정](./safetrip-document/01-getting-started/development-setup.md)
- [코드 스타일 가이드](./safetrip-document/07-guides/code-style-guide.md) (작성 예정)
- [테스트 가이드](./safetrip-document/07-guides/testing-guide.md)
- [API 가이드](./safetrip-document/05-api/api-guide.md)

---

## 문의

질문이나 제안사항이 있으시면 이슈를 생성해주세요.

---

**작성일**: 2025-01-15  
**버전**: 1.0

