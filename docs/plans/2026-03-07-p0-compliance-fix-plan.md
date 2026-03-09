# P0 비즈니스 원칙 정합성 수정 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 비즈니스 원칙 v5.1 정합성 감사에서 발견된 6건의 CRITICAL FAIL(F4~F9)을 서버 비즈니스 로직 검증으로 수정한다.

**Architecture:** 기존 NestJS 서비스 파일(groups.service.ts, guardians.service.ts)에 검증 로직을 추가한다. 신규 파일 없이 기존 메서드를 보강하며, DB 변경 없이 애플리케이션 레벨 검증만 수행한다. groups.module.ts에 GuardianLink와 LocationSharing 엔티티를 추가 import한다.

**Tech Stack:** NestJS, TypeORM, Jest, PostgreSQL

**설계 문서:** `docs/plans/2026-03-07-p0-compliance-audit-design.md`

**기준 문서:** `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`

---

## Task 1: F6 — 동일 여행 내 동일 유저 중복 멤버 방지 (§17#3)

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts:73-100` (`addMember()`)
- Test: `safetrip-server-api/src/modules/groups/groups.service.spec.ts` (신규 생성)

**Step 1: Write the failing test**

파일 `safetrip-server-api/src/modules/groups/groups.service.spec.ts` 생성:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { GroupsService } from './groups.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Trip } from '../../entities/trip.entity';
import { Schedule } from '../../entities/schedule.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { LocationSharing } from '../../entities/location.entity';
import { DataSource } from 'typeorm';
import { BadRequestException, ForbiddenException } from '@nestjs/common';

describe('GroupsService — P0 비즈니스 원칙 정합성', () => {
    let service: GroupsService;

    const mockGroupRepo = { create: jest.fn(), save: jest.fn(), findOne: jest.fn() };
    const mockMemberRepo = {
        create: jest.fn().mockReturnValue({}),
        save: jest.fn().mockResolvedValue({ memberId: 'mem-1', memberRole: 'crew' }),
        findOne: jest.fn(),
        find: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
    };
    const mockInviteCodeRepo = { findOne: jest.fn() };
    const mockTripRepo = { findOne: jest.fn() };
    const mockScheduleRepo = {};
    const mockGuardianLinkRepo = { findOne: jest.fn(), find: jest.fn() };
    const mockLocationSharingRepo = { find: jest.fn(), save: jest.fn() };
    const mockDataSource = { query: jest.fn().mockResolvedValue([]), createQueryRunner: jest.fn() };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                GroupsService,
                { provide: getRepositoryToken(Group), useValue: mockGroupRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockMemberRepo },
                { provide: getRepositoryToken(InviteCode), useValue: mockInviteCodeRepo },
                { provide: getRepositoryToken(Trip), useValue: mockTripRepo },
                { provide: getRepositoryToken(Schedule), useValue: mockScheduleRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
                { provide: getRepositoryToken(LocationSharing), useValue: mockLocationSharingRepo },
                { provide: DataSource, useValue: mockDataSource },
            ],
        }).compile();

        service = module.get<GroupsService>(GroupsService);
        jest.clearAllMocks();
    });

    describe('F6: addMember — 동일 여행 중복 멤버 방지 (§17#3)', () => {
        it('이미 active 멤버인 유저를 같은 여행에 추가하면 BadRequestException', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'existing', userId: 'user-1', tripId: 'trip-1', status: 'active', memberRole: 'crew',
            });
            mockTripRepo.findOne.mockResolvedValueOnce({
                tripId: 'trip-1', startDate: new Date('2026-04-01'), endDate: new Date('2026-04-05'),
            });

            await expect(
                service.addMember('group-1', 'trip-1', 'user-1', 'crew'),
            ).rejects.toThrow(BadRequestException);
        });
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F6" 2>&1 | tail -20`
Expected: FAIL — `addMember()` does not check for existing active member (except captain)

**Step 3: Write minimal implementation**

`groups.service.ts` 의 `addMember()` 메서드 상단(line 73 이후)에 중복 체크 추가:

```typescript
async addMember(groupId: string, tripId: string, userId: string, role = 'crew') {
    // §17#3: 동일 여행 내 동일 유저 중복 멤버 방지
    const existingMember = await this.memberRepo.findOne({
        where: { tripId, userId, status: 'active' },
    });
    if (existingMember) {
        throw new BadRequestException(
            `이미 이 여행에 참여 중입니다 (현재 역할: ${existingMember.memberRole}). (비즈니스 원칙 §17#3)`,
        );
    }

    // §02.2: 일정 겹침 체크 (captain/crew_chief/crew 대상)
    // ... (기존 코드 유지)
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F6" 2>&1 | tail -10`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/groups/groups.service.ts safetrip-server-api/src/modules/groups/groups.service.spec.ts
git commit -m "fix(groups): 동일 여행 중복 멤버 방지 검증 추가 (§17#3, 아키텍처 원칙 적용)"
```

---

## Task 2: F5 — 멤버+가디언 겸직 방지 (§01.2, §17#4)

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts:73-100` (`addMember()`)
- Modify: `safetrip-server-api/src/modules/groups/groups.module.ts` (GuardianLink import 추가)
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts:29-76` (`createLink()`)
- Test: `safetrip-server-api/src/modules/groups/groups.service.spec.ts` (테스트 추가)

**Step 1: Write the failing tests**

`groups.service.spec.ts` 에 테스트 추가:

```typescript
describe('F5: addMember — 멤버+가디언 겸직 방지 (§17#4)', () => {
    it('이미 가디언인 유저를 같은 여행의 멤버로 추가하면 BadRequestException', async () => {
        // 기존 멤버 없음
        mockMemberRepo.findOne.mockResolvedValueOnce(null);
        // 일정 겹침 없음
        mockTripRepo.findOne.mockResolvedValueOnce({
            tripId: 'trip-1', startDate: new Date('2026-04-01'), endDate: new Date('2026-04-05'),
        });
        mockDataSource.query.mockResolvedValueOnce([]);
        // 가디언 링크 존재
        mockGuardianLinkRepo.findOne.mockResolvedValueOnce({
            linkId: 'link-1', tripId: 'trip-1', guardianId: 'user-1', status: 'accepted',
        });

        await expect(
            service.addMember('group-1', 'trip-1', 'user-1', 'crew'),
        ).rejects.toThrow(BadRequestException);
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F5" 2>&1 | tail -20`
Expected: FAIL

**Step 3: Write implementation**

3a. `groups.module.ts` — GuardianLink, LocationSharing 엔티티 import 추가:

```typescript
import { GuardianLink } from '../../entities/guardian.entity';
import { LocationSharing } from '../../entities/location.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([Group, GroupMember, InviteCode, Trip, Schedule, GuardianLink, LocationSharing]),
        InviteCodesModule,
    ],
    // ...
})
```

3b. `groups.service.ts` — constructor에 GuardianLink, LocationSharing 리포지토리 주입 + addMember()에 겸직 체크 추가:

```typescript
import { GuardianLink } from '../../entities/guardian.entity';
import { LocationSharing } from '../../entities/location.entity';

constructor(
    // ... 기존 주입
    @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
    @InjectRepository(LocationSharing) private locationSharingRepo: Repository<LocationSharing>,
    private dataSource: DataSource
) { }

async addMember(groupId: string, tripId: string, userId: string, role = 'crew') {
    // §17#3: 동일 여행 내 동일 유저 중복 멤버 방지
    // ... (Task 1에서 추가한 코드)

    // §17#4: 멤버+가디언 겸직 방지 — 가디언이 같은 여행의 멤버로 참여할 수 없음
    if (['captain', 'crew_chief', 'crew'].includes(role)) {
        const existingGuardianLink = await this.guardianLinkRepo.findOne({
            where: [
                { tripId, guardianId: userId, status: 'accepted' },
                { tripId, guardianId: userId, status: 'pending' },
            ],
        });
        if (existingGuardianLink) {
            throw new BadRequestException(
                '이 여행의 가디언으로 등록되어 있어 멤버로 참여할 수 없습니다. (비즈니스 원칙 §01.2, §17#4)',
            );
        }
    }

    // §02.2: 일정 겹침 체크
    // ... (기존 코드)
```

3c. `guardians.service.ts` — `createLink()`에 역방향 겸직 체크 추가 (멤버가 같은 여행의 가디언이 되려할 때):

```typescript
async createLink(tripId: string, memberId: string, guardianPhone: string) {
    const targetUser = await this.userRepo.findOne({ where: { phoneNumber: guardianPhone } });
    if (!targetUser) {
        throw new NotFoundException('해당 전화번호로 가입된 사용자를 찾을 수 없습니다');
    }

    if (targetUser.userId === memberId) {
        throw new BadRequestException('본인을 가디언으로 추가할 수 없습니다');
    }

    // §17#4: 멤버+가디언 겸직 방지 — 같은 여행의 멤버가 가디언이 될 수 없음
    const existingMember = await this.groupMemberRepo.findOne({
        where: { tripId, userId: targetUser.userId, status: 'active' },
    });
    if (existingMember && ['captain', 'crew_chief', 'crew'].includes(existingMember.memberRole)) {
        throw new BadRequestException(
            '이 여행의 멤버로 참여 중인 사용자는 같은 여행의 가디언이 될 수 없습니다. (비즈니스 원칙 §01.2, §17#4)',
        );
    }

    // §05.4 쿼터 확인
    // ... (기존 코드)
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F5" 2>&1 | tail -10`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/groups/groups.module.ts safetrip-server-api/src/modules/groups/groups.service.ts safetrip-server-api/src/modules/guardians/guardians.service.ts safetrip-server-api/src/modules/groups/groups.service.spec.ts
git commit -m "fix(groups,guardians): 멤버+가디언 겸직 방지 양방향 검증 추가 (§01.2, §17#4, 아키텍처 원칙 적용)"
```

---

## Task 3: F4 — 캡틴 탈퇴 시 위임 강제 (§07.2, §17#8, #9)

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts:141-157` (`removeMember()`)
- Test: `safetrip-server-api/src/modules/groups/groups.service.spec.ts` (테스트 추가)

**Step 1: Write the failing tests**

`groups.service.spec.ts` 에 추가:

```typescript
describe('F4: removeMember — 캡틴 탈퇴 시 위임 강제 (§07.2, §17#8, #9)', () => {
    it('캡틴이 active 여행에서 다른 멤버가 있을 때 탈퇴 시도 → ForbiddenException (위임 먼저)', async () => {
        mockMemberRepo.findOne.mockResolvedValueOnce({
            memberId: 'mem-captain', userId: 'captain-1', tripId: 'trip-1',
            memberRole: 'captain', status: 'active',
        });
        mockTripRepo.findOne.mockResolvedValueOnce({
            tripId: 'trip-1', status: 'active',
        });
        mockMemberRepo.count.mockResolvedValueOnce(3); // 다른 멤버 3명

        await expect(
            service.removeMember('trip-1', 'captain-1', 'captain-1'),
        ).rejects.toThrow(ForbiddenException);
    });

    it('캡틴만 남은 active 여행에서 탈퇴 시도 → ForbiddenException (종료/삭제 먼저)', async () => {
        mockMemberRepo.findOne.mockResolvedValueOnce({
            memberId: 'mem-captain', userId: 'captain-1', tripId: 'trip-1',
            memberRole: 'captain', status: 'active',
        });
        mockTripRepo.findOne.mockResolvedValueOnce({
            tripId: 'trip-1', status: 'planning',
        });
        mockMemberRepo.count.mockResolvedValueOnce(0); // 혼자

        await expect(
            service.removeMember('trip-1', 'captain-1', 'captain-1'),
        ).rejects.toThrow(ForbiddenException);
    });

    it('캡틴이 completed 여행에서 탈퇴 → 성공', async () => {
        mockMemberRepo.findOne.mockResolvedValueOnce({
            memberId: 'mem-captain', userId: 'captain-1', tripId: 'trip-1',
            memberRole: 'captain', status: 'active',
        });
        mockTripRepo.findOne.mockResolvedValueOnce({
            tripId: 'trip-1', status: 'completed',
        });
        mockMemberRepo.update.mockResolvedValueOnce({});

        const result = await service.removeMember('trip-1', 'captain-1', 'captain-1');
        expect(result).toEqual({ message: 'Member removed' });
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F4" 2>&1 | tail -20`
Expected: FAIL — 현재 `removeMember()`는 캡틴을 무조건 거부(`Cannot remove captain`)

**Step 3: Write implementation**

`groups.service.ts` 의 `removeMember()` 전면 재작성:

```typescript
async removeMember(tripId: string, userId: string, removedBy: string) {
    const member = await this.memberRepo.findOne({
        where: { tripId, userId, status: 'active' },
    });
    if (!member) throw new NotFoundException('Member not found');

    // §07.2: 캡틴 탈퇴 규칙
    if (member.memberRole === 'captain') {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        // completed 상태 → 위임 없이 탈퇴 가능
        if (trip.status === 'completed') {
            await this.memberRepo.update(member.memberId, {
                status: 'left',
                leftAt: new Date(),
            });
            return { message: 'Member removed' };
        }

        // active/planning 상태
        const otherMemberCount = await this.memberRepo.count({
            where: { tripId, status: 'active', userId: Not(userId) },
        });

        if (otherMemberCount > 0) {
            throw new ForbiddenException(
                '다른 멤버가 있는 여행에서 캡틴은 리더 권한을 위임한 후에만 탈퇴할 수 있습니다. (비즈니스 원칙 §07.2)',
            );
        } else {
            throw new ForbiddenException(
                '캡틴만 남은 여행에서는 여행을 종료(completed)하거나 삭제한 후 탈퇴해야 합니다. (비즈니스 원칙 §07.2)',
            );
        }
    }

    await this.memberRepo.update(member.memberId, {
        status: 'removed',
        leftAt: new Date(),
    });
    return { message: 'Member removed' };
}
```

**import에 Not 추가:**

```typescript
import { Repository, DataSource, Not } from 'typeorm';
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F4" 2>&1 | tail -10`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/groups/groups.service.ts safetrip-server-api/src/modules/groups/groups.service.spec.ts
git commit -m "fix(groups): 캡틴 탈퇴 시 위임/종료 강제 검증 추가 (§07.2, §17#8, #9, 아키텍처 원칙 적용)"
```

---

## Task 4: F8 — 개인 가디언 카운트 시 guardian_type 분리 (§03.1, §17#6)

**Files:**
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts:39-51` (`createLink()` 쿼터 체크)
- Test: `safetrip-server-api/src/modules/guardians/guardians.service.spec.ts` (신규 생성)

**Step 1: Write the failing test**

파일 `safetrip-server-api/src/modules/guardians/guardians.service.spec.ts` 생성:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { GuardiansService } from './guardians.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
    Guardian, GuardianLink, GuardianPause,
    GuardianLocationRequest, GuardianSnapshot, GuardianReleaseRequest,
} from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Schedule } from '../../entities/schedule.entity';
import { PaymentsService } from '../payments/payments.service';
import { BadRequestException } from '@nestjs/common';

describe('GuardiansService — P0 비즈니스 원칙 정합성', () => {
    let service: GuardiansService;

    const mockGuardianRepo = { create: jest.fn(), save: jest.fn(), findOne: jest.fn() };
    const mockLinkRepo = {
        create: jest.fn().mockReturnValue({}),
        save: jest.fn().mockResolvedValue({ linkId: 'link-1', status: 'pending' }),
        findOne: jest.fn(),
        find: jest.fn(),
        count: jest.fn(),
    };
    const mockPauseRepo = {};
    const mockLocReqRepo = { count: jest.fn() };
    const mockSnapshotRepo = {};
    const mockReleaseRequestRepo = {};
    const mockUserRepo = { findOne: jest.fn() };
    const mockGroupMemberRepo = { findOne: jest.fn() };
    const mockScheduleRepo = {};
    const mockPaymentsService = {
        checkGuardianQuota: jest.fn().mockResolvedValue({ maxGuardians: 2 }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                GuardiansService,
                { provide: getRepositoryToken(Guardian), useValue: mockGuardianRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockLinkRepo },
                { provide: getRepositoryToken(GuardianPause), useValue: mockPauseRepo },
                { provide: getRepositoryToken(GuardianLocationRequest), useValue: mockLocReqRepo },
                { provide: getRepositoryToken(GuardianSnapshot), useValue: mockSnapshotRepo },
                { provide: getRepositoryToken(GuardianReleaseRequest), useValue: mockReleaseRequestRepo },
                { provide: getRepositoryToken(User), useValue: mockUserRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockGroupMemberRepo },
                { provide: getRepositoryToken(Schedule), useValue: mockScheduleRepo },
                { provide: PaymentsService, useValue: mockPaymentsService },
            ],
        }).compile();

        service = module.get<GuardiansService>(GuardiansService);
        jest.clearAllMocks();
    });

    describe('F8: createLink — 개인 가디언 카운트 시 guardian_type 분리 (§17#6)', () => {
        it('개인 가디언 2명 + 전체 가디언 1명 → 개인 3번째 추가 시 BadRequestException', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-3', phoneNumber: '010-3333-3333' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce(null); // 겸직 체크 통과
            mockPaymentsService.checkGuardianQuota.mockResolvedValueOnce({ maxGuardians: 2 });
            // 개인 가디언만 2명 (전체 가디언 제외)
            mockLinkRepo.count.mockResolvedValueOnce(2);
            mockLinkRepo.findOne.mockResolvedValueOnce(null); // 중복 없음

            await expect(
                service.createLink('trip-1', 'member-1', '010-3333-3333'),
            ).rejects.toThrow(BadRequestException);
        });

        it('개인 가디언 1명 + 전체 가디언 2명 → 개인 2번째 추가 성공', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-2', phoneNumber: '010-2222-2222' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce(null); // 겸직 체크 통과
            mockPaymentsService.checkGuardianQuota.mockResolvedValueOnce({ maxGuardians: 2 });
            // 개인 가디언만 1명
            mockLinkRepo.count.mockResolvedValueOnce(1);
            mockLinkRepo.findOne.mockResolvedValueOnce(null); // 중복 없음

            const result = await service.createLink('trip-1', 'member-1', '010-2222-2222');
            expect(result).toHaveProperty('link_id');
        });
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/guardians/guardians.service.spec.ts --no-coverage -t "F8" 2>&1 | tail -20`
Expected: FAIL — count 시 guardianType 필터 없음

**Step 3: Write implementation**

`guardians.service.ts` 의 `createLink()` 쿼터 체크 수정:

```typescript
// §03.1, §17#6: 개인 가디언만 카운트 (전체 가디언은 별도 관리)
const currentPersonalLinks = await this.linkRepo.count({
    where: [
        { memberId, tripId, guardianType: 'personal', status: 'pending' },
        { memberId, tripId, guardianType: 'personal', status: 'accepted' },
    ]
});

if (currentPersonalLinks >= maxGuardians) {
    throw new BadRequestException(
        `개인 가디언 등록 제한을 초과했습니다. (현재 플랜 제한: ${maxGuardians}명, 비즈니스 원칙 §03.1)`,
    );
}
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/guardians/guardians.service.spec.ts --no-coverage -t "F8" 2>&1 | tail -10`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/guardians/guardians.service.ts safetrip-server-api/src/modules/guardians/guardians.service.spec.ts
git commit -m "fix(guardians): 개인 가디언 카운트 시 guardian_type 분리 (§03.1, §17#6, 아키텍처 원칙 적용)"
```

---

## Task 5: F7 — 전체 가디언 여행당 2명 상한 검증 (§03.1, §17#7)

**Files:**
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts:29-76` (`createLink()`)
- Test: `safetrip-server-api/src/modules/guardians/guardians.service.spec.ts` (테스트 추가)

**Step 1: Write the failing test**

```typescript
describe('F7: createLink — 전체 가디언 여행당 2명 상한 (§17#7)', () => {
    it('전체 가디언 3번째 추가 시 BadRequestException', async () => {
        mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-3', phoneNumber: '010-3333-3333' });
        mockGroupMemberRepo.findOne.mockResolvedValueOnce(null);
        mockPaymentsService.checkGuardianQuota.mockResolvedValueOnce({ maxGuardians: 5 });
        mockLinkRepo.count
            .mockResolvedValueOnce(0)   // 개인 가디언 카운트 → 0
            .mockResolvedValueOnce(2);  // 전체 가디언 카운트 → 2
        mockLinkRepo.findOne.mockResolvedValueOnce(null);

        await expect(
            service.createLink('trip-1', 'member-1', '010-3333-3333', 'group'),
        ).rejects.toThrow(BadRequestException);
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/guardians/guardians.service.spec.ts --no-coverage -t "F7" 2>&1 | tail -20`
Expected: FAIL

**Step 3: Write implementation**

`guardians.service.ts` 의 `createLink()` 시그니처 변경 + 전체 가디언 검증 추가:

```typescript
async createLink(tripId: string, memberId: string, guardianPhone: string, guardianType: 'personal' | 'group' = 'personal') {
    // ... (기존 유저 확인, self-check, 겸직 체크)

    if (guardianType === 'group') {
        // §03.1, §17#7: 전체 가디언 여행당 2명 상한
        const currentGroupLinks = await this.linkRepo.count({
            where: [
                { tripId, guardianType: 'group', status: 'pending' },
                { tripId, guardianType: 'group', status: 'accepted' },
            ]
        });
        if (currentGroupLinks >= 2) {
            throw new BadRequestException(
                '전체 가디언은 여행당 최대 2명까지 등록할 수 있습니다. (비즈니스 원칙 §03.1, §17#7)',
            );
        }
    } else {
        // §03.1, §17#6: 개인 가디언 쿼터 체크
        const { maxGuardians } = await this.paymentsService.checkGuardianQuota(memberId, tripId);
        const currentPersonalLinks = await this.linkRepo.count({
            where: [
                { memberId, tripId, guardianType: 'personal', status: 'pending' },
                { memberId, tripId, guardianType: 'personal', status: 'accepted' },
            ]
        });
        if (currentPersonalLinks >= maxGuardians) {
            throw new BadRequestException(
                `개인 가디언 등록 제한을 초과했습니다. (현재 플랜 제한: ${maxGuardians}명, 비즈니스 원칙 §03.1)`,
            );
        }
    }

    // 중복 체크 (기존)
    // ...

    const link = this.linkRepo.create({
        tripId,
        memberId,
        guardianId: targetUser.userId,
        guardianPhone,
        guardianType,   // ← guardianType 반영
        status: 'pending'
    });
    // ...
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/guardians/guardians.service.spec.ts --no-coverage -t "F7" 2>&1 | tail -10`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/guardians/guardians.service.ts safetrip-server-api/src/modules/guardians/guardians.service.spec.ts
git commit -m "fix(guardians): 전체 가디언 여행당 2명 상한 검증 추가 (§03.1, §17#7, 아키텍처 원칙 적용)"
```

---

## Task 6: F9 — 멤버 탈퇴 시 공개범위 자동 정리 (§08.5)

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts:141-157` (`removeMember()`)
- Modify: `safetrip-server-api/src/modules/groups/groups.module.ts` (이미 Task 2에서 LocationSharing 추가됨)
- Test: `safetrip-server-api/src/modules/groups/groups.service.spec.ts` (테스트 추가)

**Step 1: Write the failing test**

```typescript
describe('F9: removeMember — 멤버 탈퇴 시 공개범위 자동 정리 (§08.5)', () => {
    it('멤버 탈퇴 시 다른 멤버의 visibility_member_ids에서 제거됨', async () => {
        const departingUserId = 'user-departing';
        mockMemberRepo.findOne.mockResolvedValueOnce({
            memberId: 'mem-1', userId: departingUserId, tripId: 'trip-1',
            memberRole: 'crew', status: 'active',
        });
        mockMemberRepo.update.mockResolvedValueOnce({});

        // visibility_member_ids에 떠나는 유저가 포함된 레코드
        const sharingRecord = {
            locationSharingId: 'ls-1', tripId: 'trip-1', userId: 'other-user',
            visibilityType: 'specified',
            visibilityMemberIds: ['user-stay', departingUserId, 'user-stay2'],
        };
        mockLocationSharingRepo.find.mockResolvedValueOnce([sharingRecord]);
        mockLocationSharingRepo.save.mockResolvedValueOnce({});

        await service.removeMember('trip-1', departingUserId, 'admin-1');

        expect(mockLocationSharingRepo.save).toHaveBeenCalledWith(
            expect.objectContaining({
                visibilityMemberIds: ['user-stay', 'user-stay2'],
            }),
        );
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F9" 2>&1 | tail -20`
Expected: FAIL — removeMember()에 공개범위 정리 로직 없음

**Step 3: Write implementation**

`groups.service.ts` 의 `removeMember()` 하단에 정리 로직 추가:

```typescript
async removeMember(tripId: string, userId: string, removedBy: string) {
    // ... (기존 멤버 조회 + 캡틴 검증 from Task 3)

    await this.memberRepo.update(member.memberId, {
        status: 'removed',
        leftAt: new Date(),
    });

    // §08.5: 멤버 탈퇴 시 다른 멤버의 visibility_member_ids에서 자동 제거
    await this.cleanupVisibilityOnDeparture(tripId, userId);

    return { message: 'Member removed' };
}

/**
 * §08.5: 탈퇴한 멤버를 다른 멤버의 공개 범위 설정에서 자동 제거
 */
private async cleanupVisibilityOnDeparture(tripId: string, departedUserId: string) {
    const sharings = await this.locationSharingRepo.find({
        where: { tripId, visibilityType: 'specified' },
    });

    for (const sharing of sharings) {
        if (Array.isArray(sharing.visibilityMemberIds) && sharing.visibilityMemberIds.includes(departedUserId)) {
            sharing.visibilityMemberIds = sharing.visibilityMemberIds.filter(
                (id: string) => id !== departedUserId,
            );
            await this.locationSharingRepo.save(sharing);
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts --no-coverage -t "F9" 2>&1 | tail -10`
Expected: PASS

**Step 5: Run all tests**

Run: `cd safetrip-server-api && npx jest src/modules/groups/groups.service.spec.ts src/modules/guardians/guardians.service.spec.ts --no-coverage 2>&1 | tail -20`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add safetrip-server-api/src/modules/groups/groups.service.ts safetrip-server-api/src/modules/groups/groups.service.spec.ts
git commit -m "fix(groups): 멤버 탈퇴 시 visibility_member_ids 자동 정리 (§08.5, 아키텍처 원칙 적용)"
```

---

## Task 7: 전체 테스트 실행 및 기존 테스트 호환성 확인

**Step 1: 전체 테스트 실행**

Run: `cd safetrip-server-api && npx jest --no-coverage 2>&1 | tail -30`
Expected: 기존 테스트 + 신규 테스트 모두 PASS

**Step 2: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit 2>&1 | tail -20`
Expected: No errors

**Step 3: 최종 커밋 (필요 시)**

기존 테스트 호환성 문제가 있으면 수정 후 커밋.

---

## 수정 파일 요약

| 파일 | 변경 내용 |
|------|----------|
| `groups.module.ts` | GuardianLink, LocationSharing 엔티티 import 추가 |
| `groups.service.ts` | addMember() 중복/겸직 검증, removeMember() 캡틴 위임 강제 + visibility 정리 |
| `guardians.service.ts` | createLink() guardian_type 분리 카운트 + 전체 가디언 상한 + 겸직 방지 |
| `groups.service.spec.ts` | 신규 — F4,F5,F6,F9 테스트 6건 |
| `guardians.service.spec.ts` | 신규 — F7,F8 테스트 3건 |
