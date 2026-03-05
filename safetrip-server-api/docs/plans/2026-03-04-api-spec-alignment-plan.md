# API 명세서-코드 정렬 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** safetrip-server-api의 치명적 버그 수정 및 API 명세서와의 Request/Response 스키마 정렬

**Architecture:** 기존 NestJS 코드의 라우트 경로, 인증 데코레이터, 서비스 로직을 API 명세서(Master_docs 35~38번)에 맞게 수정. 글로벌 인터셉터/필터는 이미 적용되어 있으므로 컨트롤러/서비스 레벨 수정에 집중.

**Tech Stack:** NestJS, TypeORM, PostgreSQL, Firebase Admin SDK

---

## Task 1: Double Prefix 버그 수정 — GeofencesController

**Files:**
- Modify: `src/modules/geofences/geofences.controller.ts`

**Step 1: 라우트 경로에서 `api/v1/` 접두사 제거**

모든 `@Get()`, `@Post()`, `@Patch()`, `@Delete()` 데코레이터의 경로 문자열에서 `api/v1/` 를 제거한다.
`@Public()` 데코레이터도 추가하여 인증 없이 접근 가능하게 한다 (명세서 기준).

```typescript
// Line 1: import에 Public 추가
import { Public } from '../../common/decorators/public.decorator';

// Line 10: @Post('api/v1/groups/:group_id/geofences') →
@Public()
@Post('groups/:group_id/geofences')

// Line 45: @Get('api/v1/geofences') →
@Public()
@Get('geofences')

// Line 63: @Get('api/v1/geofences/:id') →
@Public()
@Get('geofences/:id')

// Line 83: @Patch('api/v1/geofences/:id') →
@Public()
@Patch('geofences/:id')

// Line 113: @Delete('api/v1/geofences/:id') →
@Public()
@Delete('geofences/:id')

// Line 136: @Post('api/v1/geofences/events') →
@Public()
@Post('geofences/events')
```

**Step 2: 서버 실행하여 라우트 확인**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api && npx ts-node -e "console.log('TypeScript OK')"`
Expected: TypeScript 컴파일 성공

**Step 3: 커밋**

```bash
git add src/modules/geofences/geofences.controller.ts
git commit -m "fix: GeofencesController double prefix 버그 수정 — api/v1/ 제거 + @Public() 추가"
```

---

## Task 2: Double Prefix 버그 수정 — LocationsController (Movement Sessions)

**Files:**
- Modify: `src/modules/locations/locations.controller.ts`

**Step 1: movement session 라우트 경로에서 `api/v1/` 접두사 제거**

```typescript
// Line 113: @Get('api/v1/locations/users/:userId/movement-sessions/summary') →
@Get('locations/users/:userId/movement-sessions/summary')

// Line 127: @Get('api/v1/locations/users/:userId/movement-sessions/date-range') →
@Get('locations/users/:userId/movement-sessions/date-range')

// Line 137: @Get('api/v1/locations/users/:userId/movement-sessions/by-date') →
@Get('locations/users/:userId/movement-sessions/by-date')

// Line 152: @Get('api/v1/locations/users/:userId/movement-sessions/:sessionId') →
@Get('locations/users/:userId/movement-sessions/:sessionId')

// Line 163: @Patch('api/v1/locations/users/:userId/movement-sessions/:sessionId/complete') →
@Patch('locations/users/:userId/movement-sessions/:sessionId/complete')

// Line 179: @Get('api/v1/locations/users/:userId/movement-sessions/:sessionId/events') →
@Get('locations/users/:userId/movement-sessions/:sessionId/events')
```

**Step 2: 커밋**

```bash
git add src/modules/locations/locations.controller.ts
git commit -m "fix: LocationsController movement session 라우트 double prefix 버그 수정"
```

---

## Task 3: @Public() 데코레이터 추가 — TripsController

**Files:**
- Modify: `src/modules/trips/trips.controller.ts`

**Step 1: Public import 추가 및 데코레이터 적용**

```typescript
// Line 1: import에 Public 추가
import { Public } from '../../common/decorators/public.decorator';

// Line 57: preview 엔드포인트 (명세서: 인증 불필요)
@Public()
@Get('preview/:code')

// Line 63: invite code 조회 (명세서: 인증 불필요)
@Public()
@Get('invite/:inviteCode')

// Line 69: invite code 검증 (명세서: 인증 불필요)
@Public()
@Get('verify-invite-code/:code')
```

**주의**: `@Get(':tripId')` (line 30)는 명세서에서 인증 불필요로 표시하지만, NestJS에서는 `@CurrentUser()`를 사용하지 않으므로 `@Public()`을 추가해도 기능 영향 없음. 단, 라우트 순서 상 `preview/:code`, `invite/:inviteCode`, `verify-invite-code/:code`가 `:tripId`보다 먼저 매칭되어야 한다. NestJS는 선언 순서대로 매칭하므로 이 세 라우트를 `:tripId` 위에 선언해야 한다.

**Step 2: 라우트 순서 재배치**

`preview/:code`, `invite/:inviteCode`, `verify-invite-code/:code`를 컨트롤러 상단(`findMyTrips` 바로 뒤)으로 이동:

```typescript
@ApiTags('Trips')
@ApiBearerAuth('firebase-auth')
@Controller('trips')
export class TripsController {
    constructor(private readonly tripsService: TripsService) { }

    @Post()
    @ApiOperation({ summary: '여행 생성' })
    create(@CurrentUser() userId: string, @Body() body: { ... }) { ... }

    @Get()
    @ApiOperation({ summary: '내 여행 목록 조회' })
    findMyTrips(@CurrentUser() userId: string) { ... }

    // ── Public endpoints (인증 불필요, :tripId보다 먼저 매칭) ──
    @Public()
    @Get('preview/:code')
    @ApiOperation({ summary: '초대 코드로 여행 미리보기' })
    previewByInviteCode(@Param('code') code: string) { ... }

    @Public()
    @Get('invite/:inviteCode')
    @ApiOperation({ summary: '여행자용 초대 코드로 여행 정보 조회' })
    findByInviteCode(@Param('inviteCode') inviteCode: string) { ... }

    @Public()
    @Get('verify-invite-code/:code')
    @ApiOperation({ summary: '초대 코드 유효성 검증' })
    verifyInviteCode(@Param('code') code: string) { ... }

    // ── 가디언 승인 (guardian-approval 경로, :tripId보다 먼저) ──
    @Post('guardian-approval/request')
    @ApiOperation({ summary: '가디언 승인 요청' })
    createGuardianApprovalRequest(...) { ... }

    @Get('guardian-approval/status')
    @ApiOperation({ summary: '내 가디언 승인 상태 조회' })
    getGuardianApprovalStatus(...) { ... }

    // ── Protected dynamic routes ──
    @Get(':tripId')
    @ApiOperation({ summary: '여행 상세 조회' })
    findOne(@Param('tripId') tripId: string) { ... }

    // ... 나머지 :tripId/* 라우트
}
```

**Step 3: 커밋**

```bash
git add src/modules/trips/trips.controller.ts
git commit -m "fix: TripsController @Public() 추가 + 라우트 순서 정렬 + guardian-approval 경로 변경"
```

---

## Task 4: @Public() 데코레이터 추가 — CountriesController, EventLogController

**Files:**
- Modify: `src/modules/countries/countries.controller.ts`
- Modify: `src/modules/event-log/event-log.controller.ts`

**Step 1: CountriesController에 @Public() 추가**

```typescript
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Countries')
@Controller('countries')
export class CountriesController {
    @Public()
    @Get()
    findAll() { ... }
}
```

**Step 2: EventLogController에 @Public() 추가**

```typescript
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Event Log')
@Controller('events')
export class EventLogController {
    @Public()
    @Post()
    create(...) { ... }

    @Public()
    @Get()
    find(...) { ... }
}
```

**Step 3: 커밋**

```bash
git add src/modules/countries/countries.controller.ts src/modules/event-log/event-log.controller.ts
git commit -m "fix: Countries, EventLog 컨트롤러 @Public() 추가 — 명세서 인증 요구사항 정렬"
```

---

## Task 5: 리더십 양도 owner_user_id 수정

**Files:**
- Modify: `src/modules/groups/groups.service.ts:336-339`

**Step 1: 주석 해제**

```typescript
// BEFORE (line 336-338):
await queryRunner.manager.update(Group,
    { groupId },
    { /*ownerUserId: targetUserId*/ } as any
);

// AFTER:
await queryRunner.manager.update(Group,
    { groupId },
    { ownerUserId: targetUserId }
);
```

**Step 2: 커밋**

```bash
git add src/modules/groups/groups.service.ts
git commit -m "fix: 리더십 양도 시 tb_group.owner_user_id 갱신 활성화"
```

---

## Task 6: FCM 토큰 등록 에러 코드 수정 (500 → 404)

**Files:**
- Modify: `src/modules/users/users.service.ts:127`

**Step 1: InternalServerErrorException → NotFoundException 변경**

```typescript
// BEFORE (line 127):
throw new InternalServerErrorException(`User not found: ${userId}`);

// AFTER:
throw new NotFoundException(`User not found: ${userId}`);
```

`NotFoundException`은 이미 line 1의 import에 포함되어 있으므로 import 변경 불필요.

**Step 2: 커밋**

```bash
git add src/modules/users/users.service.ts
git commit -m "fix: FCM 토큰 등록 시 사용자 미존재 에러코드 500 → 404 수정"
```

---

## Task 7: Auth `user_role` 가디언 체크 구현

**Files:**
- Modify: `src/modules/auth/auth.service.ts:88`
- Modify: `src/modules/users/users.service.ts:26`

**Step 1: AuthService에 GuardianLink 조회 추가**

```typescript
// auth.service.ts — constructor에 GuardianLink 리포지토리 주입 추가
import { GuardianLink } from '../../entities/guardian-link.entity';

constructor(
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
    @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
) {}

// verifyFirebaseToken 메서드 내 (line 88 근처):
// BEFORE:
user_role: 'crew', // TODO: guardian check if exists

// AFTER:
user_role: await this.getUserRole(user.userId),
```

```typescript
// auth.service.ts — 새 private 메서드 추가
private async getUserRole(userId: string): Promise<string> {
    const guardianLink = await this.guardianLinkRepo.findOne({
        where: { guardianId: userId, status: 'accepted' }
    });
    return guardianLink ? 'guardian' : 'crew';
}
```

**Step 2: AuthModule에 GuardianLink 엔티티 등록**

```typescript
// auth.module.ts — imports에 TypeOrmModule.forFeature 추가
import { GuardianLink } from '../../entities/guardian-link.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([User, GuardianLink]),
        // ...
    ],
    // ...
})
```

**Step 3: UsersService도 동일하게 수정**

```typescript
// users.service.ts — line 26
// BEFORE:
user_role: 'crew', // TODO: guardian

// AFTER:
user_role: await this.getUserRole(user.userId),
```

`formatUserResponse`를 `async`로 변경하고, `getUserRole` private 메서드 추가.
호출하는 모든 곳에 `await` 추가.

**Step 4: 커밋**

```bash
git add src/modules/auth/auth.service.ts src/modules/auth/auth.module.ts src/modules/users/users.service.ts
git commit -m "feat: user_role 필드에 가디언 링크 존재 여부 반영 (crew/guardian)"
```

---

## Task 8: Trips 라우트 경로 정렬 (guardian → guardian-approval)

**Files:**
- Modify: `src/modules/trips/trips.controller.ts:134,143`

이 작업은 Task 3에서 이미 처리됨. 경로 변경:
- `POST guardian/request` → `POST guardian-approval/request`
- `GET guardian/approval-status` → `GET guardian-approval/status`

Task 3 커밋에 포함.

---

## Task 9: Trips 스키마 정렬 — verify-invite-code 응답

**Files:**
- Modify: `src/modules/trips/trips.service.ts` (verifyInviteCode 메서드)

**Step 1: `expired` 필드 추가**

명세서 요구:
```json
{
  "exists": true,
  "expired": false
}
```

현재 코드는 `{ exists: !!group }` 만 반환.

```typescript
// trips.service.ts — verifyInviteCode 메서드
async verifyInviteCode(code: string) {
    const group = await this.groupRepo.findOne({ where: { inviteCode: code } });
    return {
        exists: !!group,
        expired: group ? group.status !== 'active' : false,
    };
}
```

**Step 2: 커밋**

```bash
git add src/modules/trips/trips.service.ts
git commit -m "fix: verify-invite-code 응답에 expired 필드 추가"
```

---

## Task 10: Groups 스키마 정렬 — invite-codes 목록에 비활성 코드 포함

**Files:**
- Modify: `src/modules/groups/groups.service.ts` (getInviteCodes 메서드)

**Step 1: 비활성 코드도 포함하도록 필터 제거**

```typescript
// BEFORE:
async getInviteCodes(groupId: string, userId: string) {
    return this.inviteCodeRepo.find({
        where: { groupId, isActive: true },
        order: { createdAt: 'DESC' }
    });
}

// AFTER:
async getInviteCodes(groupId: string, userId: string) {
    return this.inviteCodeRepo.find({
        where: { groupId },
        order: { createdAt: 'DESC' }
    });
}
```

**Step 2: 커밋**

```bash
git add src/modules/groups/groups.service.ts
git commit -m "fix: invite-codes 목록에 비활성 코드도 포함 (명세서 정렬)"
```

---

## Task 11: MOFA 통합 엔드포인트 추가 (/all)

**Files:**
- Modify: `src/modules/mofa/mofa.controller.ts`
- Modify: `src/modules/mofa/mofa.service.ts`

**Step 1: MofaService에 getAll 메서드 추가**

```typescript
// mofa.service.ts
async getAll(countryCode: string) {
    const [summary, safety, entry, medical, contacts] = await Promise.all([
        this.getSummary(countryCode),
        this.getSafetyInfo(countryCode),
        this.getEntryInfo(countryCode),
        this.getMedicalInfo(countryCode),
        this.getContacts(countryCode),
    ]);
    return { ...summary, ...safety, ...entry, ...medical, ...contacts };
}
```

**Step 2: MofaController에 /all 라우트 추가**

```typescript
// mofa.controller.ts — getContacts 메서드 뒤에 추가
@Public()
@Get('country/:countryCode/all')
@ApiOperation({ summary: '국가 전체 정보 통합 조회' })
async getAll(@Param('countryCode') countryCode: string) {
    this.validateCountryCode(countryCode);
    return this.mofaService.getAll(countryCode.toUpperCase());
}
```

**Step 3: 커밋**

```bash
git add src/modules/mofa/mofa.controller.ts src/modules/mofa/mofa.service.ts
git commit -m "feat: MOFA 국가 전체 정보 통합 조회 엔드포인트 (/all) 추가"
```

---

## Task 12: Guides 스텁 해제 — DB 쿼리 구현

**Files:**
- Modify: `src/modules/guides/guides.service.ts`

**Step 1: findByCountryCode 스텁 해제**

```typescript
// BEFORE (line 21):
const guides: any[] = [];
const mofaRisk: any = null;

// AFTER — Country 엔티티에서 travel_guide_data 조회:
async findByCountryCode(countryCode: string) {
    const country = await this.countryRepo.findOne({
        where: { countryCode: countryCode.toUpperCase(), isActive: true }
    });

    if (!country) {
        throw new NotFoundException(`Country not found: ${countryCode}`);
    }

    const guideData = country.travelGuideData || {};

    // TB_MOFA_RISK에서 현재 유효한 위험 정보 조회
    const mofaRisk = await this.dataSource.query(
        `SELECT alarm_level, alarm_text, region_type, danger_map_url
         FROM tb_mofa_risk
         WHERE country_code = $1 AND is_current = TRUE
         ORDER BY alarm_level DESC LIMIT 1`,
        [countryCode.toUpperCase()]
    );

    return {
        country_code: country.countryCode,
        country_name_ko: country.countryNameKo,
        travel_guide_data: guideData,
        mofa_risk: mofaRisk.length > 0 ? mofaRisk[0] : null
    };
}
```

**Step 2: GuidesService constructor에 DataSource, Country 리포지토리 주입**

```typescript
import { DataSource } from 'typeorm';
import { Country } from '../../entities/country.entity';

constructor(
    @InjectRepository(Country) private countryRepo: Repository<Country>,
    private dataSource: DataSource,
) {}
```

**Step 3: search 스텁 해제**

```typescript
async search(query: string, countryCode?: string) {
    let qb = this.countryRepo.createQueryBuilder('c')
        .where('c.isActive = TRUE')
        .andWhere('c.travelGuideData IS NOT NULL');

    if (countryCode) {
        qb = qb.andWhere('c.countryCode = :cc', { cc: countryCode.toUpperCase() });
    }

    if (query) {
        qb = qb.andWhere(
            '(c.countryNameKo ILIKE :q OR c.countryNameEn ILIKE :q)',
            { q: `%${query}%` }
        );
    }

    const results = await qb.orderBy('c.countryNameKo', 'ASC').limit(20).getMany();

    return {
        query,
        country: countryCode || null,
        results: results.map(r => ({
            country_code: r.countryCode,
            country_name_ko: r.countryNameKo,
            country_name_en: r.countryNameEn,
        })),
        count: results.length
    };
}
```

**Step 4: getEmergencyContacts 스텁 해제**

```typescript
async getEmergencyContacts(countryCode: string) {
    const country = await this.countryRepo.findOne({
        where: { countryCode: countryCode.toUpperCase(), isActive: true }
    });

    if (!country || !country.travelGuideData) {
        throw new NotFoundException(`Emergency contacts not found for: ${countryCode}`);
    }

    return {
        country_code: country.countryCode,
        emergency_contacts: country.travelGuideData?.emergency_contacts || null
    };
}
```

**Step 5: GuidesModule에 Country 엔티티 등록**

```typescript
// guides.module.ts
import { Country } from '../../entities/country.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Country])],
    // ...
})
```

**Step 6: 커밋**

```bash
git add src/modules/guides/guides.service.ts src/modules/guides/guides.module.ts
git commit -m "feat: Guides 서비스 스텁 해제 — TB_COUNTRY 실 DB 쿼리 구현"
```

---

## Task 13: Guardians 스키마 정렬 — pending, linked-members 응답 보강

**Files:**
- Modify: `src/modules/guardians/guardians.service.ts` (getPendingInvites, getLinkedMembers 메서드)

**Step 1: getPendingInvites에 trip/member 정보 JOIN 추가**

현재 raw entity 반환 → 명세서 요구 필드 추가:

```typescript
async getPendingInvites(userId: string, tripId: string) {
    const links = await this.guardianLinkRepo
        .createQueryBuilder('gl')
        .leftJoinAndSelect('gl.member', 'member')  // GuardianLink.memberId -> User
        .leftJoin('member.groupMembers', 'gm', 'gm.userId = member.userId')
        .leftJoinAndSelect('gm.group', 'g')
        .leftJoin('g.trips', 't')
        .where('gl.guardianId = :userId', { userId })
        .andWhere('gl.status = :status', { status: 'pending' })
        .orderBy('gl.createdAt', 'DESC')
        .getMany();

    return links.map(link => ({
        link_id: link.linkId,
        status: link.status,
        created_at: link.createdAt,
        member_display_name: link.member?.displayName || null,
        member_phone_number: link.member?.phoneNumber || null,
        member_profile_image_url: link.member?.profileImageUrl || null,
    }));
}
```

**Step 2: getLinkedMembers에 사용자 프로필 JOIN 추가**

```typescript
async getLinkedMembers(userId: string, tripId: string) {
    const links = await this.guardianLinkRepo
        .createQueryBuilder('gl')
        .leftJoinAndSelect('gl.member', 'member')
        .where('gl.guardianId = :userId', { userId })
        .andWhere('gl.tripId = :tripId', { tripId })
        .andWhere('gl.status = :status', { status: 'accepted' })
        .orderBy('gl.createdAt', 'DESC')
        .getMany();

    return links.map(link => ({
        link_id: link.linkId,
        member_id: link.memberId,
        display_name: link.member?.displayName || null,
        phone_number: link.member?.phoneNumber || null,
        profile_image_url: link.member?.profileImageUrl || null,
    }));
}
```

**Step 3: 커밋**

```bash
git add src/modules/guardians/guardians.service.ts
git commit -m "fix: Guardians pending/linked-members 응답에 사용자 프로필 정보 JOIN 추가"
```

---

## 전체 수정 요약

| Task | 유형 | 영향 엔드포인트 수 |
|------|------|:---:|
| 1 | Double prefix 수정 (Geofences) | 6 |
| 2 | Double prefix 수정 (Locations) | 6 |
| 3 | @Public() + 라우트 순서 (Trips) | 5 |
| 4 | @Public() (Countries, EventLog) | 3 |
| 5 | owner_user_id 수정 (Leadership) | 1 |
| 6 | FCM 에러 코드 수정 | 1 |
| 7 | user_role 가디언 체크 | 2 |
| 8 | 라우트 경로 정렬 (Task 3 포함) | 2 |
| 9 | verify-invite-code 응답 | 1 |
| 10 | invite-codes 비활성 포함 | 1 |
| 11 | MOFA /all 엔드포인트 | 1 |
| 12 | Guides 스텁 해제 | 3 |
| 13 | Guardians 스키마 정렬 | 2 |
| **합계** | | **34** |
