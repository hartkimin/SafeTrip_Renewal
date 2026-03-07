# 초대코드 원칙 적용 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 23_T3_초대코드_원칙 v1.1 문서의 모든 P0+P1 요구사항을 반영하는 전용 InviteCodesModule을 구현한다.

**Architecture:** 기존 GroupsService/TripsService에 분산된 초대코드 로직을 새 InviteCodesModule로 통합한다. 문서 §14.1 API 스펙에 맞는 새 라우트를 생성하고, 레거시 라우트는 새 서비스로 위임한다. Flutter 클라이언트의 API 경로도 새 스펙으로 전환한다.

**Tech Stack:** NestJS (TypeORM, PostgreSQL), Flutter (Dart), Jest

---

## Task 1: DB 마이그레이션 — model_type 컬럼 + b2b 인덱스

**Files:**
- Create: `safetrip-server-api/sql/migration-invite-code-model-type.sql`

**Step 1: 마이그레이션 SQL 작성**

```sql
-- §02.3, §13.1: model_type 컬럼 추가 및 b2b_batch_id 부분 인덱스 생성
ALTER TABLE tb_invite_code
  ADD COLUMN IF NOT EXISTS model_type VARCHAR(20) DEFAULT 'direct';

CREATE INDEX IF NOT EXISTS idx_invite_code_batch
  ON tb_invite_code(b2b_batch_id) WHERE b2b_batch_id IS NOT NULL;
```

**Step 2: 마이그레이션 실행**

Run: `cd safetrip-server-api && psql "$DATABASE_URL" -f sql/migration-invite-code-model-type.sql`

또는 Firebase Emulator 환경이면 스키마 파일(`sql/01-schema-user-group-trip.sql`)에도 반영:
- `b2b_batch_id UUID` 행 다음에 `model_type VARCHAR(20) DEFAULT 'direct',` 추가
- `idx_invite_code_code` 인덱스 다음에 `CREATE INDEX idx_invite_code_batch ...` 추가

**Step 3: 엔티티에 modelType 추가**

Modify: `safetrip-server-api/src/entities/invite-code.entity.ts`

기존 `b2bBatchId` 컬럼 아래에 추가:
```typescript
@Column({ name: 'model_type', type: 'varchar', length: 20, default: 'direct' })
modelType: string; // 'direct' | 'system'
```

**Step 4: 커밋**

```bash
git add safetrip-server-api/sql/migration-invite-code-model-type.sql \
        safetrip-server-api/sql/01-schema-user-group-trip.sql \
        safetrip-server-api/src/entities/invite-code.entity.ts
git commit -m "feat(db): add model_type column and b2b_batch_id index to tb_invite_code (§02.3, §13.1)"
```

---

## Task 2: InviteCodesModule 스캐폴딩 — 모듈 + 빈 서비스 + 컨트롤러

**Files:**
- Create: `safetrip-server-api/src/modules/invite-codes/invite-codes.module.ts`
- Create: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`
- Create: `safetrip-server-api/src/modules/invite-codes/invite-codes.controller.ts`
- Create: `safetrip-server-api/src/modules/invite-codes/dto/create-invite-code.dto.ts`
- Modify: `safetrip-server-api/src/app.module.ts`

**Step 1: DTO 생성**

```typescript
// dto/create-invite-code.dto.ts
export class CreateInviteCodeDto {
    target_role: string;   // 'crew_chief' | 'crew' | 'guardian'
    max_uses?: number;     // default 1
    expires_hours?: number; // default 72
}
```

**Step 2: 빈 서비스 생성**

```typescript
// invite-codes.service.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';

@Injectable()
export class InviteCodesService {
    constructor(
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private dataSource: DataSource,
    ) {}

    // Methods will be added in subsequent tasks
}
```

**Step 3: 컨트롤러 생성 (라우트 정의만, 메서드는 stub)**

```typescript
// invite-codes.controller.ts
import { Controller, Get, Post, Patch, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { InviteCodesService } from './invite-codes.service';
import { CreateInviteCodeDto } from './dto/create-invite-code.dto';

@ApiTags('InviteCodes')
@ApiBearerAuth('firebase-auth')
@Controller()
export class InviteCodesController {
    constructor(private readonly service: InviteCodesService) {}

    // §14.1: POST /trips/:tripId/invite-codes
    @Post('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '초대코드 생성 (§03, §04)' })
    createCode(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body() dto: CreateInviteCodeDto,
    ) {
        return this.service.createCode(tripId, userId, dto);
    }

    // §14.1: GET /trips/:tripId/invite-codes
    @Get('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '초대코드 목록 조회 (§04.1)' })
    listCodes(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
    ) {
        return this.service.listCodes(tripId, userId);
    }

    // §14.1: POST /invite-codes/validate
    @Post('invite-codes/validate')
    @ApiOperation({ summary: '초대코드 사전 검증 (§05)' })
    validateCode(@Body() body: { code: string }) {
        return this.service.validateCode(body.code);
    }

    // §14.1: POST /invite-codes/use
    @Post('invite-codes/use')
    @ApiOperation({ summary: '초대코드 사용/합류 (§05, §11)' })
    useCode(
        @CurrentUser() userId: string,
        @Body() body: { code: string },
    ) {
        return this.service.useCode(body.code, userId);
    }

    // §14.1: PATCH /trips/:tripId/invite-codes/:codeId/deactivate
    @Patch('trips/:tripId/invite-codes/:codeId/deactivate')
    @ApiOperation({ summary: '초대코드 비활성화 (§04.1)' })
    deactivateCode(
        @Param('tripId') tripId: string,
        @Param('codeId') codeId: string,
        @CurrentUser() userId: string,
    ) {
        return this.service.deactivateCode(tripId, codeId, userId);
    }
}
```

**Step 4: 모듈 생성**

```typescript
// invite-codes.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { InviteCodesController } from './invite-codes.controller';
import { InviteCodesService } from './invite-codes.service';

@Module({
    imports: [TypeOrmModule.forFeature([InviteCode, Group, GroupMember, Trip])],
    controllers: [InviteCodesController],
    providers: [InviteCodesService],
    exports: [InviteCodesService],
})
export class InviteCodesModule {}
```

**Step 5: AppModule에 등록**

Modify: `safetrip-server-api/src/app.module.ts`

imports 배열에 추가:
```typescript
import { InviteCodesModule } from './modules/invite-codes/invite-codes.module';
// ... in @Module imports:
InviteCodesModule,
```

**Step 6: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 컴파일 성공 (서비스 메서드는 아직 stub이므로 에러 가능 — 빈 메서드 추가)

**Step 7: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/ \
        safetrip-server-api/src/app.module.ts
git commit -m "feat(invite-codes): scaffold InviteCodesModule with routes (§14.1)"
```

---

## Task 3: generateCode + createCode 구현 — §03, §04

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`

**Step 1: 7자리 코드 생성 헬퍼 구현 (§03.1)**

`InviteCodesService`에 private 메서드 추가:

```typescript
/** §03.1: 7자리 알파뉴메릭 코드 생성 (O/0/I/l 제외) */
private generateCode(): string {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ123456789'; // 31 chars, excludes O,0,I,l
    let code = '';
    for (let i = 0; i < 7; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}
```

**Step 2: createCode 구현 (§03, §04)**

```typescript
async createCode(tripId: string, userId: string, dto: CreateInviteCodeDto) {
    // tripId → groupId 조회
    const trip = await this.tripRepo.findOne({ where: { tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const groupId = trip.groupId;

    // §04.1: 권한 매트릭스 확인
    const member = await this.memberRepo.findOne({
        where: { groupId, userId, status: 'active' },
    });
    if (!member) throw new ForbiddenException('Not a member of this trip');

    const role = member.memberRole;
    const targetRole = dto.target_role;

    if (!['crew_chief', 'crew', 'guardian'].includes(targetRole)) {
        throw new BadRequestException('target_role must be one of: crew_chief, crew, guardian');
    }

    // §04.1: 캡틴은 모든 역할, 크루장은 crew만
    if (role === 'crew_chief' && targetRole !== 'crew') {
        throw new ForbiddenException('Crew chief can only create crew invite codes');
    }
    if (role !== 'captain' && role !== 'crew_chief') {
        throw new ForbiddenException('Only captain or crew_chief can create invite codes');
    }

    // §04.2: 활성 코드 수 제한
    const activeCodeCount = await this.inviteCodeRepo.count({
        where: {
            groupId,
            createdBy: userId,
            isActive: true,
            ...(role === 'captain' ? { targetRole } : {}),
        },
    });

    const limit = role === 'captain' ? 10 : 5; // §04.2
    if (activeCodeCount >= limit) {
        throw new BadRequestException(
            `Active code limit reached (max ${limit}). Deactivate existing codes first.`,
        );
    }

    // §03.2: 기본값 적용
    const maxUses = dto.max_uses ?? 1;
    const expiresHours = dto.expires_hours ?? 72;

    const expiresAt = new Date();
    expiresAt.setTime(expiresAt.getTime() + expiresHours * 60 * 60 * 1000);

    // §03.1: 코드 생성 (최대 5회 재시도)
    let code = '';
    for (let attempt = 0; attempt < 5; attempt++) {
        code = this.generateCode();
        const exists = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!exists) break;
        if (attempt === 4) throw new BadRequestException('Failed to generate unique code after 5 attempts');
    }

    const invite = this.inviteCodeRepo.create({
        groupId,
        tripId,
        code,
        targetRole,
        maxUses,
        expiresAt,
        createdBy: userId,
        modelType: 'direct',
    });

    const saved = await this.inviteCodeRepo.save(invite);

    return {
        invite_code_id: saved.inviteCodeId,
        code: saved.code,
        target_role: saved.targetRole,
        max_uses: saved.maxUses,
        expires_at: saved.expiresAt,
        model_type: saved.modelType,
    };
}
```

**Step 3: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`

**Step 4: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts
git commit -m "feat(invite-codes): implement createCode with permission matrix (§03, §04)"
```

---

## Task 4: validateCode 구현 — §05 8단계 검증 (읽기 전용)

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`

**Step 1: validateCode 구현**

```typescript
async validateCode(code: string) {
    // §06.1: 대문자 정규화
    code = code.toUpperCase();

    // §05 Step 1: 코드 존재
    const invite = await this.inviteCodeRepo.findOne({ where: { code } });
    if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

    // §05 Step 2: 활성 상태
    if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

    // §05 Step 3: 만료 미도래
    if (invite.expiresAt && new Date() >= invite.expiresAt) {
        throw new BadRequestException('ERR_CODE_EXPIRED');
    }

    // §05 Step 4: 사용 횟수 미초과
    if (invite.maxUses !== null && invite.usedCount >= invite.maxUses) {
        throw new BadRequestException('ERR_CODE_EXHAUSTED');
    }

    // §05 Step 5: 여행 유효성
    const trip = await this.tripRepo.findOne({ where: { tripId: invite.tripId } });
    if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
        throw new BadRequestException('ERR_TRIP_INVALID');
    }

    // trip 미리보기 정보
    const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });

    return {
        target_role: invite.targetRole,
        uses_remaining: invite.maxUses !== null ? invite.maxUses - invite.usedCount : null,
        trip: {
            trip_id: trip.tripId,
            group_id: trip.groupId,
            destination: trip.destination,
            start_date: trip.startDate,
            end_date: trip.endDate,
            status: trip.status,
            title: group?.groupName || '',
        },
    };
}
```

**Step 2: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts
git commit -m "feat(invite-codes): implement validateCode 8-step read-only validation (§05)"
```

---

## Task 5: useCode 구현 — §05 + §11 트랜잭션 합류

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`

**Step 1: useCode 구현 (트랜잭션)**

```typescript
async useCode(code: string, userId: string) {
    // §06.1: 대문자 정규화
    code = code.toUpperCase();

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
        // §05 Step 1: 코드 존재
        const invite = await queryRunner.manager.findOne(InviteCode, { where: { code } });
        if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

        // §05 Step 2: 활성 상태
        if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

        // §05 Step 3: 만료 미도래
        if (invite.expiresAt && new Date() >= invite.expiresAt) {
            throw new BadRequestException('ERR_CODE_EXPIRED');
        }

        // §05 Step 4: 사용 횟수 미초과
        if (invite.maxUses !== null && invite.usedCount >= invite.maxUses) {
            throw new BadRequestException('ERR_CODE_EXHAUSTED');
        }

        // §05 Step 5: 여행 유효성
        const trip = await queryRunner.manager.findOne(Trip, {
            where: { tripId: invite.tripId },
        });
        if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
            throw new BadRequestException('ERR_TRIP_INVALID');
        }

        const groupId = invite.groupId;

        // §05 Step 6: 중복 참여
        const existingMember = await queryRunner.manager.findOne(GroupMember, {
            where: { groupId, userId, status: 'active' },
        });
        if (existingMember) throw new BadRequestException('ERR_ALREADY_MEMBER');

        // §05 Step 7: 정원 미초과
        const group = await queryRunner.manager.findOne(Group, { where: { groupId } });
        if (group?.maxMembers) {
            const currentCount = await queryRunner.manager.count(GroupMember, {
                where: { groupId, status: 'active' },
            });
            if (currentCount >= group.maxMembers) {
                throw new BadRequestException('ERR_TRIP_FULL');
            }
        }

        // §05 Step 8: 역할 배정 가능 여부 (크루장 정원 등)
        // 가디언인 경우: 멤버-가디언 중복 체크 (§12.1 #11)
        if (invite.targetRole === 'guardian') {
            const isMember = await queryRunner.manager.findOne(GroupMember, {
                where: {
                    tripId: invite.tripId,
                    userId,
                    status: 'active',
                    memberRole: 'crew' as any,  // crew/crew_chief/captain
                },
            });
            // 동일 여행 내 멤버이면서 가디언 시도
            const isMemberAny = await queryRunner.manager.findOne(GroupMember, {
                where: { tripId: invite.tripId, userId, status: 'active' },
            });
            if (isMemberAny) {
                throw new BadRequestException('ERR_GUARDIAN_MEMBER_OVERLAP');
            }
        }

        // §12.1 #10: 탈퇴 후 재참여 쿨다운 (24시간)
        const recentLeft = await queryRunner.manager.findOne(GroupMember, {
            where: { groupId, userId, status: 'left' as any },
            order: { leftAt: 'DESC' },
        });
        if (recentLeft?.leftAt) {
            const cooldownMs = 24 * 60 * 60 * 1000; // 24h
            if (new Date().getTime() - new Date(recentLeft.leftAt).getTime() < cooldownMs) {
                throw new BadRequestException('ERR_REJOIN_COOLDOWN');
            }
        }

        // §02.2: 일정 겹침 체크 (captain/crew_chief/crew 대상)
        if (['captain', 'crew_chief', 'crew'].includes(invite.targetRole)) {
            const overlapping = await queryRunner.manager.query(`
                SELECT t.trip_id, t.destination
                FROM tb_group_member gm
                JOIN tb_trip t ON gm.trip_id = t.trip_id
                WHERE gm.user_id = $1
                  AND gm.status = 'active'
                  AND gm.member_role IN ('captain', 'crew_chief', 'crew')
                  AND t.status IN ('planning', 'active', 'scheduled', 'ongoing')
                  AND t.trip_id != $2
                  AND t.start_date <= $4
                  AND t.end_date >= $3
            `, [userId, trip.tripId, trip.startDate, trip.endDate]);

            if (overlapping.length > 0) {
                throw new BadRequestException(
                    `일정이 겹치는 다른 여행(${overlapping[0].destination})에 이미 참여 중입니다. (비즈니스 원칙 §02.2)`,
                );
            }
        }

        // §11.1: 합류 처리 (트랜잭션 내)
        const targetRole = invite.targetRole;
        const newMember = queryRunner.manager.create(GroupMember, {
            groupId,
            userId,
            tripId: invite.tripId,
            memberRole: targetRole,
            isAdmin: targetRole === 'captain',
            canEditSchedule: targetRole === 'captain' || targetRole === 'crew_chief',
            canManageMembers: targetRole === 'captain',
            canSendNotifications: targetRole === 'captain' || targetRole === 'crew_chief',
            canViewLocation: true,
            canManageGeofences: targetRole === 'captain' || targetRole === 'crew_chief',
        });
        const savedMember = await queryRunner.manager.save(GroupMember, newMember);

        // §11.1: used_count + 1
        await queryRunner.manager.update(InviteCode,
            { inviteCodeId: invite.inviteCodeId },
            { usedCount: invite.usedCount + 1 },
        );

        await queryRunner.commitTransaction();

        return {
            group: { group_id: groupId, group_name: group?.groupName },
            member: {
                member_id: savedMember.memberId,
                member_role: savedMember.memberRole,
                is_admin: savedMember.isAdmin,
            },
            target_role: invite.targetRole,
            trip_id: invite.tripId,
        };
    } catch (error) {
        await queryRunner.rollbackTransaction();
        // 알 수 없는 에러인 경우 ERR_JOIN_FAILED로 래핑
        if (error instanceof BadRequestException || error instanceof ForbiddenException || error instanceof NotFoundException) {
            throw error;
        }
        throw new BadRequestException('ERR_JOIN_FAILED');
    } finally {
        await queryRunner.release();
    }
}
```

**Step 2: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`

**Step 3: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts
git commit -m "feat(invite-codes): implement useCode with 8-step validation + transaction (§05, §11)"
```

---

## Task 6: listCodes + deactivateCode 구현 — §04.1

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`

**Step 1: listCodes 구현 (§04.1 역할별 필터링)**

```typescript
async listCodes(tripId: string, userId: string) {
    const trip = await this.tripRepo.findOne({ where: { tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const groupId = trip.groupId;

    const member = await this.memberRepo.findOne({
        where: { groupId, userId, status: 'active' },
    });
    if (!member) throw new ForbiddenException('Not a member');

    const role = member.memberRole;
    if (role !== 'captain' && role !== 'crew_chief') {
        throw new ForbiddenException('Only captain or crew_chief can view invite codes');
    }

    // §04.1: 캡틴은 전체, 크루장은 본인 생성 코드만
    const where: any = { groupId };
    if (role === 'crew_chief') {
        where.createdBy = userId;
    }

    const codes = await this.inviteCodeRepo.find({
        where,
        order: { createdAt: 'DESC' },
    });

    return codes.map(c => ({
        invite_code_id: c.inviteCodeId,
        code: c.code,
        target_role: c.targetRole,
        max_uses: c.maxUses,
        used_count: c.usedCount,
        expires_at: c.expiresAt,
        is_active: c.isActive,
        model_type: c.modelType,
        created_by: c.createdBy,
        created_at: c.createdAt,
        is_expired: c.expiresAt ? new Date() >= c.expiresAt : false,
    }));
}
```

**Step 2: deactivateCode 구현 (§04.1 권한 체크)**

```typescript
async deactivateCode(tripId: string, codeId: string, userId: string) {
    const trip = await this.tripRepo.findOne({ where: { tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const groupId = trip.groupId;

    const member = await this.memberRepo.findOne({
        where: { groupId, userId, status: 'active' },
    });
    if (!member) throw new ForbiddenException('Not a member');

    const role = member.memberRole;
    if (role !== 'captain' && role !== 'crew_chief') {
        throw new ForbiddenException('Only captain or crew_chief can deactivate codes');
    }

    const invite = await this.inviteCodeRepo.findOne({
        where: { inviteCodeId: codeId, groupId },
    });
    if (!invite) throw new NotFoundException('Invite code not found');

    // §04.1: 크루장은 본인 생성 코드만 비활성화 가능
    if (role === 'crew_chief' && invite.createdBy !== userId) {
        throw new ForbiddenException('Crew chief can only deactivate own codes');
    }

    invite.isActive = false;
    await this.inviteCodeRepo.save(invite);

    return { invite_code_id: codeId, is_active: false };
}
```

**Step 3: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts
git commit -m "feat(invite-codes): implement listCodes + deactivateCode with role filtering (§04.1)"
```

---

## Task 7: 레거시 라우트 위임 — GroupsController + TripsController

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.module.ts`
- Modify: `safetrip-server-api/src/modules/groups/groups.controller.ts`
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts`
- Modify: `safetrip-server-api/src/modules/trips/trips.controller.ts`
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts`
- Modify: `safetrip-server-api/src/modules/trips/trips.module.ts`

**Step 1: GroupsModule에 InviteCodesModule import**

`groups.module.ts`의 imports에 추가:
```typescript
import { InviteCodesModule } from '../invite-codes/invite-codes.module';
// ... in imports:
InviteCodesModule,
```

**Step 2: GroupsController의 레거시 라우트 → 새 서비스 위임**

기존 `GroupsController`에서:

1. `InviteCodesService`를 constructor에 주입
2. `joinByCode` → `this.inviteCodesService.useCode(code, userId)`로 위임
3. `previewByCode` → `this.inviteCodesService.validateCode(code)`로 위임
4. `createInviteCode` → 그룹ID → tripId 변환 후 `this.inviteCodesService.createCode()`로 위임
5. `getInviteCodes` → 그룹ID → tripId 변환 후 `this.inviteCodesService.listCodes()`로 위임
6. `deactivateInviteCode` → 그룹ID → tripId 변환 후 `this.inviteCodesService.deactivateCode()`로 위임

GroupsController에 주입할 때:
```typescript
constructor(
    private readonly groupsService: GroupsService,
    private readonly inviteCodesService: InviteCodesService,
) {}
```

각 메서드 내부에서 groupId → tripId 변환 헬퍼:
```typescript
// GroupsService에 추가 또는 인라인
const trip = await this.tripRepo.findOne({ where: { groupId } });
if (!trip) throw new NotFoundException('Trip not found for group');
return this.inviteCodesService.createCode(trip.tripId, userId, dto);
```

**Step 3: TripsModule에 InviteCodesModule import**

**Step 4: TripsController의 acceptInvite → 새 서비스 위임**

`TripsController`의:
- `acceptInvite` → `this.inviteCodesService.useCode(body.inviteCode, userId)`로 위임
- `findByInviteCode` → `this.inviteCodesService.validateCode(inviteCode)`로 위임

**Step 5: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`

**Step 6: 커밋**

```bash
git add safetrip-server-api/src/modules/groups/ \
        safetrip-server-api/src/modules/trips/
git commit -m "refactor(invite-codes): delegate legacy routes to InviteCodesService"
```

---

## Task 8: 테스트 작성 — InviteCodesService 단위 테스트

**Files:**
- Create: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.spec.ts`

**Step 1: 테스트 파일 생성**

테스트 구조:
```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { InviteCodesService } from './invite-codes.service';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';

describe('InviteCodesService', () => {
    let service: InviteCodesService;
    let mockInviteCodeRepo: any;
    let mockGroupRepo: any;
    let mockMemberRepo: any;
    let mockTripRepo: any;
    let mockDataSource: any;
    let mockQueryRunner: any;

    beforeEach(async () => {
        mockQueryRunner = {
            connect: jest.fn(),
            startTransaction: jest.fn(),
            commitTransaction: jest.fn(),
            rollbackTransaction: jest.fn(),
            release: jest.fn(),
            manager: {
                findOne: jest.fn(),
                find: jest.fn(),
                count: jest.fn(),
                create: jest.fn().mockImplementation((_, data) => ({ memberId: 'member-1', ...data })),
                save: jest.fn().mockImplementation((_, data) => data),
                update: jest.fn(),
                query: jest.fn().mockResolvedValue([]),
            },
        };

        mockInviteCodeRepo = {
            findOne: jest.fn(),
            find: jest.fn(),
            count: jest.fn(),
            create: jest.fn().mockImplementation((data) => ({ inviteCodeId: 'code-1', ...data })),
            save: jest.fn().mockImplementation((data) => data),
        };
        mockGroupRepo = { findOne: jest.fn() };
        mockMemberRepo = { findOne: jest.fn(), count: jest.fn() };
        mockTripRepo = { findOne: jest.fn() };
        mockDataSource = { createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner) };

        const module: TestingModule = await Test.createTestingModule({
            providers: [
                InviteCodesService,
                { provide: getRepositoryToken(InviteCode), useValue: mockInviteCodeRepo },
                { provide: getRepositoryToken(Group), useValue: mockGroupRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockMemberRepo },
                { provide: getRepositoryToken(Trip), useValue: mockTripRepo },
                { provide: DataSource, useValue: mockDataSource },
            ],
        }).compile();

        service = module.get<InviteCodesService>(InviteCodesService);
    });
```

**Step 2: 코드 생성 테스트**

```typescript
    describe('createCode', () => {
        const tripId = 'trip-1';
        const userId = 'user-captain';
        const dto = { target_role: 'crew', max_uses: 1, expires_hours: 72 };

        beforeEach(() => {
            mockTripRepo.findOne.mockResolvedValue({ tripId, groupId: 'group-1' });
            mockMemberRepo.findOne.mockResolvedValue({
                memberRole: 'captain', userId, groupId: 'group-1',
            });
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null); // no collision
        });

        it('should create a valid 7-char code without O/0/I/l', async () => {
            const result = await service.createCode(tripId, userId, dto);
            expect(result.code).toHaveLength(7);
            expect(result.code).not.toMatch(/[O0Il]/);
        });

        it('should reject crew_chief creating crew_chief codes', async () => {
            mockMemberRepo.findOne.mockResolvedValue({
                memberRole: 'crew_chief', userId,
            });
            await expect(
                service.createCode(tripId, userId, { ...dto, target_role: 'crew_chief' }),
            ).rejects.toThrow(ForbiddenException);
        });

        it('should reject crew creating any codes', async () => {
            mockMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew', userId });
            await expect(
                service.createCode(tripId, userId, dto),
            ).rejects.toThrow(ForbiddenException);
        });

        it('should reject when active code limit reached', async () => {
            mockInviteCodeRepo.count.mockResolvedValue(10); // at limit
            await expect(
                service.createCode(tripId, userId, dto),
            ).rejects.toThrow(BadRequestException);
        });

        it('should default to 72h expiry and max_uses=1', async () => {
            const result = await service.createCode(tripId, userId, { target_role: 'crew' });
            expect(result.max_uses).toBe(1);
            // expires_at should be ~72h from now
            const diffMs = new Date(result.expires_at).getTime() - Date.now();
            expect(diffMs).toBeGreaterThan(71 * 3600 * 1000);
            expect(diffMs).toBeLessThan(73 * 3600 * 1000);
        });
    });
```

**Step 3: 8단계 검증 테스트**

```typescript
    describe('validateCode', () => {
        it('should throw ERR_CODE_NOT_FOUND for unknown code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            await expect(service.validateCode('AAAAAAA')).rejects.toThrow('ERR_CODE_NOT_FOUND');
        });

        it('should throw ERR_CODE_INACTIVE for deactivated code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({ isActive: false });
            await expect(service.validateCode('AAAAAAA')).rejects.toThrow('ERR_CODE_INACTIVE');
        });

        it('should throw ERR_CODE_EXPIRED for expired code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({
                isActive: true,
                expiresAt: new Date(Date.now() - 1000), // 1 second ago
                maxUses: 1, usedCount: 0,
            });
            await expect(service.validateCode('AAAAAAA')).rejects.toThrow('ERR_CODE_EXPIRED');
        });

        it('should throw ERR_CODE_EXHAUSTED when uses depleted', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({
                isActive: true,
                expiresAt: new Date(Date.now() + 86400000),
                maxUses: 1, usedCount: 1,
            });
            await expect(service.validateCode('AAAAAAA')).rejects.toThrow('ERR_CODE_EXHAUSTED');
        });

        it('should normalize lowercase input to uppercase', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            await expect(service.validateCode('aaaaaaa')).rejects.toThrow('ERR_CODE_NOT_FOUND');
            expect(mockInviteCodeRepo.findOne).toHaveBeenCalledWith({ where: { code: 'AAAAAAA' } });
        });
    });
```

**Step 4: useCode 트랜잭션 테스트**

```typescript
    describe('useCode', () => {
        const validInvite = {
            inviteCodeId: 'ic-1', code: 'A3B7X9K', isActive: true,
            expiresAt: new Date(Date.now() + 86400000), maxUses: 1, usedCount: 0,
            groupId: 'group-1', tripId: 'trip-1', targetRole: 'crew',
        };
        const validTrip = { tripId: 'trip-1', groupId: 'group-1', status: 'scheduled', startDate: new Date(), endDate: new Date() };
        const validGroup = { groupId: 'group-1', maxMembers: 50, groupName: 'Test' };

        beforeEach(() => {
            mockQueryRunner.manager.findOne
                .mockResolvedValueOnce(validInvite)   // Step 1: invite
                .mockResolvedValueOnce(validTrip)     // Step 5: trip
                .mockResolvedValueOnce(null)          // Step 6: no existing member
                .mockResolvedValueOnce(validGroup)    // Step 7: group
                .mockResolvedValueOnce(null);         // rejoin cooldown: no left member
            mockQueryRunner.manager.count.mockResolvedValue(5); // under capacity
        });

        it('should commit transaction on success', async () => {
            await service.useCode('A3B7X9K', 'user-1');
            expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
            expect(mockQueryRunner.rollbackTransaction).not.toHaveBeenCalled();
        });

        it('should rollback on ERR_ALREADY_MEMBER', async () => {
            mockQueryRunner.manager.findOne
                .mockReset()
                .mockResolvedValueOnce(validInvite)
                .mockResolvedValueOnce(validTrip)
                .mockResolvedValueOnce({ memberId: 'existing' }); // already member
            await expect(service.useCode('A3B7X9K', 'user-1')).rejects.toThrow('ERR_ALREADY_MEMBER');
            expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
        });

        it('should increment used_count within transaction', async () => {
            await service.useCode('A3B7X9K', 'user-1');
            expect(mockQueryRunner.manager.update).toHaveBeenCalledWith(
                InviteCode,
                { inviteCodeId: 'ic-1' },
                { usedCount: 1 },
            );
        });
    });
```

**Step 5: 테스트 실행**

Run: `cd safetrip-server-api && npx jest src/modules/invite-codes/invite-codes.service.spec.ts --verbose`

Expected: 모든 테스트 PASS

**Step 6: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.spec.ts
git commit -m "test(invite-codes): add unit tests for createCode, validateCode, useCode"
```

---

## Task 9: Flutter API 경로 마이그레이션

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_code_management_modal.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/add_member_modal.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_modal.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 1: api_service.dart — 경로 전환**

1. `createInviteCode`: `groupId` → `tripId` 파라미터, 경로 `/api/v1/trips/$tripId/invite-codes`로 변경
2. `getInviteCodesByGroup` → `getInviteCodesByTrip`: 경로 `/api/v1/trips/$tripId/invite-codes`
3. `deactivateInviteCode`: `groupId` → `tripId` 파라미터, 경로 `/api/v1/trips/$tripId/invite-codes/$codeId/deactivate`, HTTP method DELETE → PATCH
4. `previewInviteCode`: 경로 `/api/v1/invite-codes/validate`, GET → POST, body에 code 전송
5. `acceptInvite`: 경로 `/api/v1/invite-codes/use`, body 키 `inviteCode` → `code`

변경 후 메서드 시그니처:

```dart
// createInviteCode: groupId → tripId
Future<Map<String, dynamic>?> createInviteCode({
    required String tripId,  // was: groupId
    String? targetRole,
    int? maxUses,
    int? expiresHours,  // was: expiresInDays → hours (§03.2 기본값 72시간)
}) async {
    final data = <String, dynamic>{};
    if (targetRole != null) data['target_role'] = targetRole;
    if (maxUses != null) data['max_uses'] = maxUses;
    if (expiresHours != null) data['expires_hours'] = expiresHours;
    final response = await _dio.post('/api/v1/trips/$tripId/invite-codes', data: data);
    ...
}

// getInviteCodesByTrip (renamed)
Future<List<Map<String, dynamic>>> getInviteCodesByTrip(String tripId) async {
    final response = await _dio.get('/api/v1/trips/$tripId/invite-codes');
    ...
}

// deactivateInviteCode: groupId → tripId, DELETE → PATCH
Future<bool> deactivateInviteCode({
    required String tripId,  // was: groupId
    required String codeId,
}) async {
    final response = await _dio.patch('/api/v1/trips/$tripId/invite-codes/$codeId/deactivate');
    ...
}

// previewInviteCode: GET → POST /invite-codes/validate
Future<Map<String, dynamic>?> previewInviteCode(String code) async {
    final response = await _dio.post('/api/v1/invite-codes/validate', data: {'code': code});
    ...
}

// acceptInvite: POST /invite-codes/use
Future<Map<String, dynamic>?> acceptInvite(String code) async {
    final response = await _dio.post('/api/v1/invite-codes/use', data: {'code': code});
    ...
}
```

**Step 2: invite_code_management_modal.dart — groupId → tripId**

1. `widget.groupId` → `widget.tripId` (프로퍼티 변경)
2. `_apiService.getInviteCodesByGroup(widget.groupId)` → `_apiService.getInviteCodesByTrip(widget.tripId)`
3. `_apiService.createInviteCode(groupId: widget.groupId, ...)` → `_apiService.createInviteCode(tripId: widget.tripId, ...)`
4. `_apiService.deactivateInviteCode(groupId: widget.groupId, ...)` → `_apiService.deactivateInviteCode(tripId: widget.tripId, ...)`

**Step 3: add_member_modal.dart — groupId → tripId 전달**

1. `AddMemberModal`에 `tripId` 파라미터 추가
2. `InviteCodeManagementModal(groupId: widget.groupId)` → `InviteCodeManagementModal(tripId: widget.tripId)`

**Step 4: bottom_sheet_2_member.dart — tripId 전달**

`_showAddMemberModal`에서:
```dart
builder: (_) => AddMemberModal(groupId: groupId, tripId: state.tripId ?? ''),
```

**Step 5: invite_modal.dart — 동일 패턴 적용 (해당되면)**

**Step 6: screen_trip_join_code.dart — 자동 대문자**

코드 입력 TextField에 `textCapitalization: TextCapitalization.characters` 추가

**Step 7: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze`
Expected: 분석 경고/에러 없음

**Step 8: 커밋**

```bash
git add safetrip-mobile/lib/services/api_service.dart \
        safetrip-mobile/lib/screens/main/bottom_sheets/modals/ \
        safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart \
        safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart
git commit -m "feat(flutter): migrate invite code APIs to §14.1 spec paths"
```

---

## Task 10: 통합 검증 + 서버 기동 테스트

**Step 1: 서버 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 에러 0

**Step 2: 단위 테스트 전체 실행**

Run: `cd safetrip-server-api && npx jest --verbose`
Expected: 모든 테스트 PASS

**Step 3: Flutter 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze`
Expected: 이슈 없음

**Step 4: 서버 기동 테스트 (선택)**

Run: `cd safetrip-server-api && npm run dev`

Swagger 확인: `http://localhost:3001/api-docs`에서 새 라우트 확인:
- `POST /api/v1/trips/{tripId}/invite-codes`
- `GET /api/v1/trips/{tripId}/invite-codes`
- `POST /api/v1/invite-codes/validate`
- `POST /api/v1/invite-codes/use`
- `PATCH /api/v1/trips/{tripId}/invite-codes/{codeId}/deactivate`

**Step 5: 최종 커밋 (필요 시)**

모든 검증 통과 후 미커밋 변경사항 커밋.

---

## 요약: 원칙 적용 체크리스트

| 원칙 조항 | 구현 태스크 | 상태 |
|---------|----------|------|
| §02.3 model_type | Task 1 | |
| §03.1 7자리 코드 형식 | Task 3 | |
| §03.2 기본 72h 만료 | Task 3 | |
| §04.1 권한 매트릭스 | Task 3, 6 | |
| §04.2 활성 코드 수 제한 | Task 3 | |
| §05 8단계 검증 | Task 4, 5 | |
| §06.1 대문자 정규화 | Task 4, 5, 9 | |
| §11.1 트랜잭션 합류 | Task 5 | |
| §12.1 에러 코드 | Task 4, 5 | |
| §12.1 #10 재참여 쿨다운 | Task 5 | |
| §12.1 #11 가디언-멤버 중복 | Task 5 | |
| §13.1 인덱스 | Task 1 | |
| §14.1 API 경로 | Task 2, 7, 9 | |
