# 외교부 공공데이터 API 연동 문서

## 목차
1. [개요](#개요)
2. [인증](#인증)
3. [API 목록](#api-목록)
4. [상세 API 명세](#상세-api-명세)
5. [사용 예시](#사용-예시)
6. [에러 처리](#에러-처리)
7. [캐싱 정책](#캐싱-정책)

---

## 개요

이 문서는 외교부 공공데이터포털의 여행 안전 정보 API들을 연동하기 위한 개발 가이드입니다.

### 기본 정보
- **API 서비스 제공자**: 외교부 공공데이터포털
- **API 기본 URL**: `https://apis.data.go.kr/1262000/`
- **응답 형식**: JSON (일부 API는 XML 지원)
- **인증 방식**: Service Key (URL 파라미터)

### 주요 기능
- 국가별 안전공지 조회
- 사건사고 예방정보 조회
- 여행경보 정보 조회
- 국가별 기본정보 조회
- 입국허가요건 조회
- 재외공관 정보 조회
- 현지연락처 정보 조회
- 기타 여행 관련 정보 조회

---

## 인증

모든 API 호출 시 `serviceKey` 파라미터를 필수로 포함해야 합니다.

### 인증키 설정
```typescript
const mofaApiService = new MofaApiService('YOUR_API_KEY');
```

### 기본 인증키 (개발용)
```
30161f3465842d605964ed8132536b1aa5e789d70bec7c4b8fa14084dc1c1e8e
```

> **주의**: 프로덕션 환경에서는 환경 변수나 보안 설정을 통해 API 키를 관리하세요.

---

## API 목록

### 1. 안전공지 관련
- `getCountrySafetyList` - 국가별 안전공지 목록 조회
- `getAllCountrySafetyList` - 전체 국가 안전공지 목록 조회

### 2. 사건사고 관련
- `getAccidentList` - 사건사고 예방정보 목록 조회
- `getAccidentInfo` - 사건사고 상세 정보 조회
- `getCountryAccidentList` - 국가별 사건사고 유형 조회

### 3. 여행경보 관련
- `getTravelWarningList` - 여행경보 목록 조회

### 4. 최신소식 관련
- `getCountrySafetyNewsList` - 최신안전소식(코로나관련) 목록 조회

### 5. 국가 기본정보 관련
- `getCountryBasicList` - 국가별 기본정보 목록 조회
- `getCountryBasicInfo` - 국가별 기본정보 상세 조회
- `getOverviewGeneralInfoList` - 국가 일반사항 목록 조회

### 6. 입국허가 관련
- `getEntranceVisaList` - 입국허가요건 목록 조회

### 7. 공지사항 관련
- `getCountryNoticeList` - 국가별 공지사항 목록 조회
- `getCountryNoticeInfo` - 국가별 공지사항 상세 조회
- `getGeneralNoticeList` - 외교부 공지사항 목록 조회

### 8. 연락처 관련
- `getLocalContactList` - 현지연락처 목록 조회
- `getEmbassyList` - 재외공관 정보 목록 조회

### 9. 입국자 조치 관련
- `getOverseasArrivalList` - 해외입국자 조치현황 목록 조회

### 10. 환경 정보 관련
- `getSecurityEnvironmentList` - 치안환경 정보 목록 조회
- `getMedicalEnvironmentList` - 의료환경 정보 목록 조회

### 11. 기타
- `getCountryFlagList` - 국가별 국기 이미지 목록 조회

---

## 상세 API 명세

### 1. 국가별 안전공지 목록 조회

**엔드포인트**: `CountrySafetyService6/getCountrySafetyList6`

**메서드**: `getCountrySafetyList(countryCode?, pageNo?, numOfRows?, startDate?, endDate?)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| countryCode | string | 선택 | ISO 3166-1 국가코드(2자리) 또는 한글 국가명 |
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: SafetyNoticeItem[];
  totalCount: number;
}

interface SafetyNoticeItem {
  countryCode: string;
  countryNameKo: string;
  countryNameEn: string;
  continentCode?: string;
  continentName?: string;
  writtenDate?: string;
  title: string;
  content: string;
  fileDownloadUrl?: string;
  fileName?: string;
}
```

**API URL 예시**:
```
https://apis.data.go.kr/1262000/CountrySafetyService6/getCountrySafetyList6?serviceKey=YOUR_KEY&pageNo=1&numOfRows=20&cond[country_iso_alp2::EQ]=TH
```

---

### 2. 사건사고 예방정보 목록 조회

**엔드포인트**: `AccidentService/getAccidentList`

**메서드**: `getAccidentList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryName | string | 선택 | 한글 국가명 |
| countryEnName | string | 선택 | 영문 국가명 |
| isoCode1~10 | string | 선택 | ISO 국가코드 (최대 10개) |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: AccidentItem[];
  totalCount: number;
}

interface AccidentItem {
  id: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  continent?: string;
  title: string;
  content: string;
  writtenDate?: string;
  imgUrl?: string;
  imgUrl2?: string;
}
```

**API URL 예시**:
```
https://apis.data.go.kr/1262000/AccidentService/getAccidentList?serviceKey=YOUR_KEY&pageNo=1&numOfRows=20&isoCode1=THA
```

---

### 3. 사건사고 상세 정보 조회

**엔드포인트**: `AccidentService/getAccidentInfo`

**메서드**: `getAccidentInfo(id)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| id | string | 필수 | 사건사고 ID |

**응답 형식**:
```typescript
AccidentItem | null
```

---

### 4. 여행경보 목록 조회

**엔드포인트**: `TravelWarningServiceV3/getTravelWarningListV3`

**메서드**: `getTravelWarningList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| isoCode | string | 선택 | ISO 국가코드 |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryNameEn | string | 선택 | 영문 국가명 |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: TravelWarningItem[];
  totalCount: number;
}

interface TravelWarningItem {
  countryCode: string;
  countryNameKo: string;
  countryNameEn: string;
  warningLevel?: string;
  warningLevelName?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
}
```

**API URL 예시**:
```
https://apis.data.go.kr/1262000/TravelWarningServiceV3/getTravelWarningListV3?serviceKey=YOUR_KEY&pageNo=1&numOfRows=20&returnType=JSON&cond[iso_code::EQ]=TH
```

---

### 5. 최신안전소식 목록 조회

**엔드포인트**: `SafetyNewsList/getCountrySafetyNewsList`  
**응답 형식**: XML (JSON 미지원)  
**참고**: PDF 기술문서 기준, `returnType` 파라미터 없음

**메서드**: `getCountrySafetyNewsList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 필수 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 필수 | 페이지당 행 수 (기본값: 20) |
| title1 | string | 필수 | 제목1 (예: "입국", "코로나", "운항", "항공권", "격리") |
| title2 | string | 선택 | 제목2 |
| title3 | string | 선택 | 제목3 |
| title4 | string | 선택 | 제목4 |
| title5 | string | 선택 | 제목5 |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**참고**: PDF 기술문서에 따르면 `title1`은 필수 파라미터이며, "입국", "코로나", "운항", "항공권", "격리" 등의 키워드를 사용하여 코로나19 관련 최신안전소식을 조회할 수 있습니다.

**응답 형식** (XML):
```typescript
{
  items: SafetyNewsItem[];
  totalCount: number;
}

interface SafetyNewsItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  title: string;
  content?: string;
  writtenDate?: string;
}
```

---

### 6. 국가별 기본정보 목록 조회

**엔드포인트**: `CountryBasicService/getCountryBasicList`

**메서드**: `getCountryBasicList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryName | string | 선택 | 한글 국가명 |
| countryEnName | string | 선택 | 영문 국가명 |
| isoCode1~10 | string | 선택 | ISO 국가코드 (최대 10개) |

**응답 형식**:
```typescript
{
  items: CountryBasicItem[];
  totalCount: number;
}

interface CountryBasicItem {
  id: string;
  countryCode?: string;
  countryNameKo: string;
  countryNameEn: string;
  continent?: string;
  basic?: string; // HTML 콘텐츠
  writtenDate?: string;
  imgUrl?: string; // 국기 이미지 경로
}
```

**API URL 예시**:
```
https://apis.data.go.kr/1262000/CountryBasicService/getCountryBasicList?serviceKey=YOUR_KEY&pageNo=1&numOfRows=20&isoCode1=TH
```

---

### 7. 국가별 기본정보 상세 조회

**엔드포인트**: `CountryBasicService/getCountryBasicInfo`

**메서드**: `getCountryBasicInfo(id)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| id | string | 필수 | 국가 기본정보 ID |

**응답 형식**:
```typescript
CountryBasicItem | null
```

---

### 8. 국가 일반사항 목록 조회

**엔드포인트**: `OverviewGnrlInfoService/getOverviewGnrlInfoList`

**메서드**: `getOverviewGeneralInfoList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: OverviewGeneralInfoItem[];
  totalCount: number;
}

interface OverviewGeneralInfoItem {
  countryCode: string;
  countryNameKo: string;
  countryNameEn: string;
  capital?: string;
  population?: number;
  populationDesc?: string;
  area?: number;
  areaDesc?: string;
  language?: string;
  religion?: string;
  ethnic?: string;
  climate?: string;
  establish?: string;
  writtenDate?: string;
}
```

---

### 9. 입국허가요건 목록 조회

**엔드포인트**: `EntranceVisaService2/getEntranceVisaList2`

**메서드**: `getEntranceVisaList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: EntranceVisaItem[];
  totalCount: number;
}

interface EntranceVisaItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
}
```

---

### 10. 국가별 공지사항 목록 조회

**엔드포인트**: `CountryNoticeService/getCountryNoticeList`

**메서드**: `getCountryNoticeList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| isoCode1 | string | 선택 | ISO 국가코드 (3자리 권장) |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: CountryNoticeItem[];
  totalCount: number;
}

interface CountryNoticeItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
}
```

---

### 11. 국가별 공지사항 상세 조회

**엔드포인트**: `CountryNoticeService/getCountryNoticeInfo`

**메서드**: `getCountryNoticeInfo(id)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| id | string | 필수 | 공지사항 ID |

**응답 형식**:
```typescript
CountryNoticeItem | null
```

---

### 12. 외교부 공지사항 목록 조회

**엔드포인트**: `NoticeService2/getNoticeList2`

**메서드**: `getGeneralNoticeList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| searchQuery | string | 선택 | 검색어 (제목/내용 검색) |

**응답 형식**:
```typescript
{
  items: GeneralNoticeItem[];
  totalCount: number;
}

interface GeneralNoticeItem {
  id?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
  category?: string;
  viewCount?: number;
}
```

---

### 13. 현지연락처 목록 조회

**엔드포인트**: `LocalContactService2/getLocalContactList2`

**메서드**: `getLocalContactList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: LocalContactItem[];
  totalCount: number;
}

interface LocalContactItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  contactType?: string;
  contactName?: string;
  phone?: string;
  email?: string;
  address?: string;
  writtenDate?: string;
}
```

**API URL 예시**:
```
https://apis.data.go.kr/1262000/LocalContactService2/getLocalContactList2?serviceKey=YOUR_KEY&returnType=JSON&pageNo=1&numOfRows=20&cond[country_iso_alp2::EQ]=TH
```

---

### 14. 해외입국자 조치현황 목록 조회

**엔드포인트**: `CountryOverseasArrivalsService/getCountryOverseasArrivalsList`

**메서드**: `getOverseasArrivalList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: OverseasArrivalItem[];
  totalCount: number;
}

interface OverseasArrivalItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
}
```

---

### 15. 재외공관 정보 목록 조회

**엔드포인트**: `EmbassyService2/getEmbassyList2`

**메서드**: `getEmbassyList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: EmbassyItem[];
  totalCount: number;
}

interface EmbassyItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  embassyName?: string;
  address?: string;
  phone?: string;
  email?: string;
  website?: string;
  writtenDate?: string;
}
```

---

### 16. 국가별 사건사고 유형 목록 조회

**엔드포인트**: `CountryAccidentService2/getCountryAccidentList2`

**메서드**: `getCountryAccidentList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |
| startDate | string | 선택 | 시작일 (YYYY-MM-DD 형식) |
| endDate | string | 선택 | 종료일 (YYYY-MM-DD 형식) |

**응답 형식**:
```typescript
{
  items: CountryAccidentItem[];
  totalCount: number;
}

interface CountryAccidentItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  accidentType?: string;
  accidentTypeName?: string;
  title?: string;
  content?: string;
  writtenDate?: string;
}
```

---

### 17. 국가별 국기 이미지 목록 조회

**엔드포인트**: `CountryFlagService2/getCountryFlagList2`

**메서드**: `getCountryFlagList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: CountryFlagItem[];
  totalCount: number;
}

interface CountryFlagItem {
  countryCode: string;
  countryNameKo: string;
  countryNameEn: string;
  flagUrl: string;
}
```

---

### 18. 치안환경 정보 목록 조회

**엔드포인트**: `SecurityEnvironmentService/getSecurityEnvironmentList`

**메서드**: `getSecurityEnvironmentList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: SecurityEnvironmentItem[];
  totalCount: number;
}

interface SecurityEnvironmentItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  currentTravelAlarm?: string;
  suicideDeathRateYear?: string;
  suicideDeathRate?: string;
  unemploymentRateYear?: string;
  unemploymentRate?: string;
}
```

---

### 19. 의료환경 정보 목록 조회

**엔드포인트**: `MedicalEnvironmentService/getMedicalEnvironmentList`

**메서드**: `getMedicalEnvironmentList(params)`

**파라미터**:
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| pageNo | number | 선택 | 페이지 번호 (기본값: 1) |
| numOfRows | number | 선택 | 페이지당 행 수 (기본값: 20) |
| countryNameKo | string | 선택 | 한글 국가명 |
| countryCode | string | 선택 | ISO 국가코드 (2자리) |

**응답 형식**:
```typescript
{
  items: MedicalEnvironmentItem[];
  totalCount: number;
}

interface MedicalEnvironmentItem {
  id?: string;
  countryCode?: string;
  countryNameKo?: string;
  countryNameEn?: string;
  content?: string;
}
```

---

## 사용 예시

### 기본 사용법

```typescript
import { MofaApiService } from './services/mofaApi';

// 서비스 인스턴스 생성
const mofaApiService = new MofaApiService('YOUR_API_KEY');

// 국가별 안전공지 조회
const safetyNotices = await mofaApiService.getCountrySafetyList('TH', 1, 20);
console.log(safetyNotices.items);
console.log(safetyNotices.totalCount);

// 사건사고 예방정보 조회
const accidents = await mofaApiService.getAccidentList({
  isoCode1: 'THA',
  pageNo: 1,
  numOfRows: 20
});

// 여행경보 조회
const warnings = await mofaApiService.getTravelWarningList({
  isoCode: 'TH',
  pageNo: 1,
  numOfRows: 20
});

// 국가 기본정보 조회
const countryBasics = await mofaApiService.getCountryBasicList({
  isoCode1: 'TH',
  pageNo: 1,
  numOfRows: 20
});
```

### 날짜 필터링 예시

```typescript
// 2024년 1월 1일 이후의 안전공지 조회
const recentNotices = await mofaApiService.getCountrySafetyList(
  'TH',
  1,
  20,
  '2024-01-01',
  undefined
);

// 특정 기간의 사건사고 조회
const accidents = await mofaApiService.getAccidentList({
  isoCode1: 'THA',
  startDate: '2024-01-01',
  endDate: '2024-12-31',
  pageNo: 1,
  numOfRows: 50
});
```

### 여러 국가 동시 조회 예시

```typescript
// 여러 국가의 사건사고 정보 조회
const accidents = await mofaApiService.getAccidentList({
  isoCode1: 'THA',  // 태국
  isoCode2: 'VNM',  // 베트남
  isoCode3: 'PHL',  // 필리핀
  pageNo: 1,
  numOfRows: 50
});
```

### 통합 뷰 구현 예시

```typescript
// 국가별 통합 정보 조회 (모든 API 병렬 호출)
const loadCountryView = async (countryCode: string) => {
  const [
    safetyResult,
    accidentResult,
    warningResult,
    newsResult,
    visaResult,
    basicResult
  ] = await Promise.allSettled([
    mofaApiService.getCountrySafetyList(countryCode, 1, 50),
    mofaApiService.getAccidentList({ isoCode1: countryCode, numOfRows: 50 }),
    mofaApiService.getTravelWarningList({ isoCode: countryCode, numOfRows: 50 }),
    mofaApiService.getCountrySafetyNewsList({ countryCode, numOfRows: 50 }),
    mofaApiService.getEntranceVisaList({ countryCode, numOfRows: 50 }),
    mofaApiService.getCountryBasicList({ isoCode1: countryCode, numOfRows: 50 })
  ]);

  // 성공한 결과만 수집
  const allItems = [];
  
  if (safetyResult.status === 'fulfilled') {
    allItems.push(...safetyResult.value.items.map(item => ({
      type: 'safety',
      data: item,
      timestamp: new Date(item.writtenDate || 0).getTime()
    })));
  }
  
  // ... 다른 결과들도 동일하게 처리
  
  // 시간순 정렬 (최신순)
  allItems.sort((a, b) => b.timestamp - a.timestamp);
  
  return allItems;
};
```

---

## 에러 처리

### 공통 에러 코드

| 에러 코드 | 설명 |
|----------|------|
| 0 | 정상 |
| 00 | 정상 (일부 API) |
| 기타 | 오류 발생 |

### 에러 처리 예시

```typescript
try {
  const result = await mofaApiService.getCountrySafetyList('TH');
  if (result.items.length === 0) {
    console.log('데이터가 없습니다.');
  }
} catch (error) {
  if (error instanceof Error) {
    console.error('API 호출 실패:', error.message);
  } else {
    console.error('알 수 없는 오류:', error);
  }
}
```

### HTTP 상태 코드

- `200`: 정상 응답
- `400`: 잘못된 요청
- `401`: 인증 실패
- `404`: 리소스를 찾을 수 없음
- `500`: 서버 오류

---

## 캐싱 정책

모든 API 호출 결과는 메모리 캐시에 저장됩니다.

### 캐시 유지 시간

| API 종류 | 캐시 시간 |
|---------|----------|
| 안전공지, 사건사고, 여행경보 등 | 30분 |
| 국가 기본정보, 공지사항 등 | 30분 |
| 국기 이미지 | 24시간 |

### 캐시 키 형식

```
{API명}:{파라미터1}:{파라미터2}:...
```

예시:
- `countrySafetyNotice:TH:1:20::`
- `accidentList:1:20::THA::2024-01-01:2024-12-31`

### 캐시 무효화

캐시는 자동으로 만료되며, 수동으로 무효화할 수 없습니다. 필요시 서비스 인스턴스를 재생성하거나 애플리케이션을 재시작하세요.

---

## 주의사항

### 1. ISO 국가코드 형식
- 일부 API는 2자리 코드(예: `TH`)를 사용
- 일부 API는 3자리 코드(예: `THA`)를 사용
- 자동 변환이 지원되는 경우도 있으나, 가능하면 API 명세에 맞는 형식을 사용하세요

### 2. 날짜 형식
- 모든 날짜 파라미터는 `YYYY-MM-DD` 형식을 사용합니다
- 예: `2024-01-01`

### 3. 페이지네이션
- `pageNo`는 1부터 시작합니다
- `numOfRows`는 한 번에 가져올 수 있는 최대 행 수입니다
- `totalCount`를 확인하여 전체 페이지 수를 계산하세요

### 4. 응답 형식
- 대부분의 API는 JSON 형식을 반환합니다
- 일부 API(예: `getAccidentInfo`)는 XML 형식을 반환할 수 있습니다
- 응답 구조는 API마다 다를 수 있으므로, 실제 응답을 확인하세요

### 5. API 호출 제한
- 공공데이터포털의 API 호출 제한 정책을 확인하세요
- 과도한 호출 시 일시적으로 차단될 수 있습니다
- 캐싱을 적극 활용하여 불필요한 호출을 줄이세요

---

## 참고 자료

- [외교부 공공데이터포털](https://www.data.go.kr/)
- [공공데이터포털 API 가이드](https://www.data.go.kr/tcs/dss/selectApiDataDetailView.do)

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-01-26 | 1.0.0 | 초기 문서 작성 |

---

## 문의

API 연동 관련 문의사항이 있으시면 프로젝트 담당자에게 연락해주세요.
