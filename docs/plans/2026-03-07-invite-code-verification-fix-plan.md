# 초대코드 아키텍처 원칙 정합성 수정 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 23_T3_초대코드_원칙 v1.1 대비 기존 InviteCodesModule 구현의 불일치 10건을 수정하여 완전한 정합성을 확보한다.

**Architecture:** 계층별 배치 수정(Approach B) — DB 마이그레이션 → Entity → DTO → Service → Controller → Test 순서로 진행. 각 계층 수정 후 테스트를 실행하여 리그레션 확인.

**Tech Stack:** NestJS, TypeORM, PostgreSQL, @nestjs/throttler, class-validator, Jest

---

## Task 1: DB 마이그레이션 — 컬럼명 변경 + NOT NULL 제약

**Files:**
- Create: `safetrip-server-api/sql/migration-invite-code-verification-fix.sql`
- Modify: `safetrip-server-api/sql/01-schema-user-group-trip.sql:139-157`

**Step 1: 마이그레이션 SQL 파일 작성**

```sql
-- 초대코드 아키텍처 원칙 정합성 수정 (#2, #6)
-- 기준 문서: 23_T3_초대코드_원칙 v1.1 §13.1

-- #2: 컬럼명 변경 used_count → current_uses (§13.1 정합)
ALTER TABLE tb_invite_code RENAME COLUMN used_count TO current_uses;

-- #6: NOT NULL 제약 추가 (§13.1: code, target_role, expires_at 모두 NOT NULL)
-- 기존 데이터에 NULL이 있을 수 있으므로 안전 처리
UPDATE tb_invite_code SET code = 'INVALID' WHERE code IS NULL;
UPDATE tb_invite_code SET target_role = 'crew' WHERE target_role IS NULL;
UPDATE tb_invite_code SET expires_at = NOW() WHERE expires_at IS NULL;

ALTER TABLE tb_invite_code ALTER COLUMN code SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN target_role SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN expires_at SET NOT NULL;
```

**Step 2: 기준 스키마(01-schema) 동기화**

`safetrip-server-api/sql/01-schema-user-group-trip.sql` 139-157줄을 아래로 교체:

```sql
CREATE TABLE tb_invite_code (
    invite_code_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID REFERENCES tb_group(group_id),
    trip_id         UUID REFERENCES tb_trip(trip_id),
    code            VARCHAR(7) UNIQUE NOT NULL,
    target_role     VARCHAR(30) NOT NULL,
    max_uses        INTEGER DEFAULT 1,
    current_uses    INTEGER DEFAULT 0,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_by      VARCHAR(128) REFERENCES tb_user(user_id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    is_active       BOOLEAN DEFAULT TRUE,
    b2b_batch_id    UUID,
    model_type      VARCHAR(20) DEFAULT 'direct'
);

CREATE INDEX idx_invite_code_group ON tb_invite_code(group_id);
CREATE INDEX idx_invite_code_code  ON tb_invite_code(code) WHERE is_active = TRUE;
CREATE INDEX idx_invite_code_batch ON tb_invite_code(b2b_batch_id) WHERE b2b_batch_id IS NOT NULL;
```

**Step 3: 커밋**

```bash
git add safetrip-server-api/sql/migration-invite-code-verification-fix.sql safetrip-server-api/sql/01-schema-user-group-trip.sql
git commit -m "fix(db): 초대코드 컬럼명 current_uses 정합 + NOT NULL 제약 (§13.1)"
```

---

## Task 2: Entity 수정 — 컬럼명 + nullable 반영

**Files:**
- Modify: `safetrip-server-api/src/entities/invite-code.entity.ts`

**Step 1: Entity 컬럼 수정**

변경 사항:
1. `usedCount` → `currentUses` (프로퍼티명)
2. `used_count` → `current_uses` (DB 컬럼 매핑)
3. `targetRole`: `nullable: true` 제거
4. `expiresAt`: `nullable: true` 제거, 타입을 `Date`로 변경 (null 불허)
5. `code`: 이미 nullable 아니므로 그대로

최종 Entity (`safetrip-server-api/src/entities/invite-code.entity.ts`):

```typescript
import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_INVITE_CODE -- 역할별 초대코드 (도메인 B)
 * DB 설계 v3.6 §4.6, 초대코드 원칙 §13.1
 */
@Entity('tb_invite_code')
export class InviteCode {
    @PrimaryGeneratedColumn('uuid', { name: 'invite_code_id' })
    inviteCodeId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'code', type: 'varchar', length: 7, unique: true })
    code: string;

    @Column({ name: 'target_role', type: 'varchar', length: 30 })
    targetRole: string; // 'crew_chief' | 'crew' | 'guardian'

    @Column({ name: 'max_uses', type: 'int', default: 1 })
    maxUses: number;

    @Column({ name: 'current_uses', type: 'int', default: 0 })
    currentUses: number;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'b2b_batch_id', type: 'uuid', nullable: true })
    b2bBatchId: string | null;

    @Column({ name: 'model_type', type: 'varchar', length: 20, default: 'direct' })
    modelType: string; // 'direct' | 'system'
}
```

**Step 2: 커밋**

```bash
git add safetrip-server-api/src/entities/invite-code.entity.ts
git commit -m "fix(entity): InviteCode 컬럼명 currentUses + NOT NULL 정합 (§13.1)"
```

---

## Task 3: DTO 검증 강화 — expires_hours/max_uses 상한, 크루장 제한 표시

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/dto/create-invite-code.dto.ts`

**Step 1: DTO 검증 규칙 추가**

```typescript
import { IsString, IsOptional, IsInt, IsIn, Min, Max } from 'class-validator';

export class CreateInviteCodeDto {
    @IsString()
    @IsIn(['crew_chief', 'crew', 'guardian'])
    target_role: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(100)  // §03.3: 다중 사용 최대 100
    max_uses?: number;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(168)  // §03.2: 최대 7일(168시간)
    expires_hours?: number;
}
```

**Step 2: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/dto/create-invite-code.dto.ts
git commit -m "fix(dto): expires_hours @Max(168) + max_uses @Max(100) 상한 추가 (§03.2, §03.3)"
```

---

## Task 4: Service 비즈니스 로직 수정 — 6건 일괄

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts`

**이 태스크에서 수정하는 이슈:**
- #2: `usedCount` → `currentUses` 전체 교체
- #5: 크루장 고급 설정 제한 (max_uses/expires_hours 기본값 강제)
- #7: Step 8 역할 정원 검증 (크루장 최대 5명)
- #8: createCode 응답에 qr_url 포함
- #9: listCodes에 isActive 필터 적용

**Step 1: 전체 서비스 파일 수정**

아래가 최종 `invite-codes.service.ts`:

```typescript
import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { CreateInviteCodeDto } from './dto/create-invite-code.dto';

/** §05 Step 8: 역할별 최대 인원 (tb_trip_settings에 컬럼이 없으므로 상수로 관리) */
const MAX_CREW_CHIEFS_PER_GROUP = 5;

@Injectable()
export class InviteCodesService {
    constructor(
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private dataSource: DataSource,
    ) {}

    /** §03.1: 7-char alphanumeric code excluding O/0/I/l */
    private generateCode(): string {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ123456789';
        let code = '';
        for (let i = 0; i < 7; i++) {
            code += chars[Math.floor(Math.random() * chars.length)];
        }
        return code;
    }

    /** §03 + §04: Create invite code */
    async createCode(tripId: string, userId: string, dto: CreateInviteCodeDto) {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const groupId = trip.groupId;

        // §04.1: Permission matrix
        const member = await this.memberRepo.findOne({
            where: { groupId, userId, status: 'active' },
        });
        if (!member) throw new ForbiddenException('Not a member of this trip');

        const role = member.memberRole;
        const targetRole = dto.target_role;

        if (!['crew_chief', 'crew', 'guardian'].includes(targetRole)) {
            throw new BadRequestException('target_role must be one of: crew_chief, crew, guardian');
        }

        // §04.1: Captain = all roles, crew_chief = crew only
        if (role === 'crew_chief' && targetRole !== 'crew') {
            throw new ForbiddenException('Crew chief can only create crew invite codes');
        }
        if (role !== 'captain' && role !== 'crew_chief') {
            throw new ForbiddenException('Only captain or crew_chief can create invite codes');
        }

        // §04.2: Active code limit
        const whereClause: any = { createdBy: userId, isActive: true };
        if (role === 'captain') {
            whereClause.targetRole = targetRole;
            whereClause.groupId = groupId;
        } else {
            whereClause.groupId = groupId;
        }
        const activeCodeCount = await this.inviteCodeRepo.count({ where: whereClause });

        const limit = role === 'captain' ? 10 : 5;
        if (activeCodeCount >= limit) {
            throw new BadRequestException(
                `Active code limit reached (max ${limit}). Deactivate existing codes first.`,
            );
        }

        // §03.2 + §03.3: Defaults — direct 타입에서 max_uses=NULL 불허
        if (dto.max_uses === null || dto.max_uses === 0) {
            throw new BadRequestException('max_uses must be a positive number for direct model');
        }

        // §04.1: 크루장은 고급 설정 불가 — max_uses=1, expires_hours=72 강제
        let maxUses: number;
        let expiresHours: number;
        if (role === 'crew_chief') {
            maxUses = 1;
            expiresHours = 72;
        } else {
            maxUses = dto.max_uses ?? 1;
            expiresHours = dto.expires_hours ?? 72;
        }

        const expiresAt = new Date();
        expiresAt.setTime(expiresAt.getTime() + expiresHours * 60 * 60 * 1000);

        // §03.1: Generate code with 5 retry attempts
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
            qr_url: `https://api.safetrip.app/qr/${saved.code}`,  // §14.2
        };
    }

    /** §05: 8-step read-only validation */
    async validateCode(code: string) {
        // §06.1: Uppercase normalization
        code = code.toUpperCase();

        // §05 Step 1: Code exists
        const invite = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

        // §05 Step 2: Active
        if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

        // §05 Step 3: Not expired
        if (new Date() >= invite.expiresAt) {
            throw new BadRequestException('ERR_CODE_EXPIRED');
        }

        // §05 Step 4: Uses remaining
        if (invite.maxUses !== null && invite.currentUses >= invite.maxUses) {
            throw new BadRequestException('ERR_CODE_EXHAUSTED');
        }

        // §05 Step 5: Trip valid
        const trip = await this.tripRepo.findOne({ where: { tripId: invite.tripId as string } });
        if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
            throw new BadRequestException('ERR_TRIP_INVALID');
        }

        const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });

        return {
            target_role: invite.targetRole,
            uses_remaining: invite.maxUses !== null ? invite.maxUses - invite.currentUses : null,
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

    /** §05 + §11: Transaction join via invite code */
    async useCode(code: string, userId: string) {
        // §06.1: Uppercase normalization
        code = code.toUpperCase();

        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            // §05 Step 1: Code exists (with pessimistic lock for TOCTOU safety)
            const invite = await queryRunner.manager.findOne(InviteCode, {
                where: { code },
                lock: { mode: 'pessimistic_write' },
            });
            if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

            // §05 Step 2: Active
            if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

            // §05 Step 3: Not expired
            if (new Date() >= invite.expiresAt) {
                throw new BadRequestException('ERR_CODE_EXPIRED');
            }

            // §05 Step 4: Uses remaining
            if (invite.maxUses !== null && invite.currentUses >= invite.maxUses) {
                throw new BadRequestException('ERR_CODE_EXHAUSTED');
            }

            // §05 Step 5: Trip valid
            const trip = await queryRunner.manager.findOne(Trip, { where: { tripId: invite.tripId as string } });
            if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
                throw new BadRequestException('ERR_TRIP_INVALID');
            }

            const groupId = invite.groupId;

            // §05 Step 6: Not already a member
            const existingMember = await queryRunner.manager.findOne(GroupMember, {
                where: { groupId, userId, status: 'active' },
            });
            if (existingMember) throw new BadRequestException('ERR_ALREADY_MEMBER');

            // §05 Step 7: Capacity check
            const group = await queryRunner.manager.findOne(Group, { where: { groupId } });
            if (group?.maxMembers) {
                const currentCount = await queryRunner.manager.count(GroupMember, {
                    where: { groupId, status: 'active' },
                });
                if (currentCount >= group.maxMembers) {
                    throw new BadRequestException('ERR_TRIP_FULL');
                }
            }

            // §05 Step 8: Role availability
            if (!['crew_chief', 'crew', 'guardian'].includes(invite.targetRole)) {
                throw new BadRequestException('ERR_ROLE_UNAVAILABLE');
            }

            // §05 Step 8: 크루장 정원 검증
            if (invite.targetRole === 'crew_chief') {
                const crewChiefCount = await queryRunner.manager.count(GroupMember, {
                    where: { groupId, memberRole: 'crew_chief', status: 'active' },
                });
                if (crewChiefCount >= MAX_CREW_CHIEFS_PER_GROUP) {
                    throw new BadRequestException('ERR_ROLE_UNAVAILABLE');
                }
            }

            // Guardian-member overlap check (§12.1 #11)
            if (invite.targetRole === 'guardian') {
                const isMemberAny = await queryRunner.manager.findOne(GroupMember, {
                    where: { tripId: invite.tripId as string, userId, status: 'active' },
                });
                if (isMemberAny) {
                    throw new BadRequestException('ERR_GUARDIAN_MEMBER_OVERLAP');
                }
            }

            // §12.1 #10: Rejoin cooldown (24h)
            const recentLeft = await queryRunner.manager
                .createQueryBuilder(GroupMember, 'gm')
                .where('gm.groupId = :groupId', { groupId })
                .andWhere('gm.userId = :userId', { userId })
                .andWhere('gm.status IN (:...statuses)', { statuses: ['left', 'removed'] })
                .andWhere('gm.leftAt IS NOT NULL')
                .orderBy('gm.leftAt', 'DESC')
                .getOne();

            if (recentLeft?.leftAt) {
                const cooldownMs = 24 * 60 * 60 * 1000;
                if (new Date().getTime() - new Date(recentLeft.leftAt).getTime() < cooldownMs) {
                    throw new BadRequestException('ERR_REJOIN_COOLDOWN');
                }
            }

            // §02.2: Schedule overlap check (for crew roles)
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

            // §11.1: Join within transaction
            const targetRole = invite.targetRole;
            const newMember = queryRunner.manager.create(GroupMember, {
                groupId,
                userId,
                tripId: invite.tripId as string,
                memberRole: targetRole,
                isAdmin: targetRole === 'captain',
                canEditSchedule: targetRole === 'captain' || targetRole === 'crew_chief',
                canEditGeofence: targetRole === 'captain' || targetRole === 'crew_chief',
                canViewAllLocations: true,
                canAttendanceCheck: targetRole === 'captain' || targetRole === 'crew_chief',
                isGuardian: targetRole === 'guardian',
            });
            const savedMember = await queryRunner.manager.save(GroupMember, newMember);

            // §11.1: Atomic current_uses increment
            await queryRunner.query(
                `UPDATE tb_invite_code SET current_uses = current_uses + 1 WHERE invite_code_id = $1`,
                [invite.inviteCodeId],
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
            if (error instanceof BadRequestException || error instanceof ForbiddenException || error instanceof NotFoundException) {
                throw error;
            }
            throw new BadRequestException('ERR_JOIN_FAILED');
        } finally {
            await queryRunner.release();
        }
    }

    /** §04.1: List active invite codes for a trip */
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

        // §04.1: Captain sees all, crew_chief sees own. §14.1: 활성 코드만 반환
        const where: any = { groupId, isActive: true };
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
            current_uses: c.currentUses,
            expires_at: c.expiresAt,
            is_active: c.isActive,
            model_type: c.modelType,
            created_by: c.createdBy,
            created_at: c.createdAt,
            is_expired: new Date() >= c.expiresAt,
        }));
    }

    /** §04.1: Deactivate an invite code */
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

        // §04.1: Crew chief can only deactivate own codes
        if (role === 'crew_chief' && invite.createdBy !== userId) {
            throw new ForbiddenException('Crew chief can only deactivate own codes');
        }

        invite.isActive = false;
        await this.inviteCodeRepo.save(invite);

        return { invite_code_id: codeId, is_active: false };
    }
}
```

**Step 2: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.ts
git commit -m "fix(service): 크루장 고급설정 제한, Step8 정원검증, qr_url, 활성필터, currentUses (§03-§14)"
```

---

## Task 5: Controller 수정 — @Public 제거 + Rate Limiting

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.controller.ts`

**Step 1: Controller 수정**

```typescript
import { Controller, Get, Post, Patch, Param, Body } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { InviteCodesService } from './invite-codes.service';
import { CreateInviteCodeDto } from './dto/create-invite-code.dto';
import { ValidateCodeDto } from './dto/validate-code.dto';
import { UseCodeDto } from './dto/use-code.dto';

@ApiTags('InviteCodes')
@ApiBearerAuth('firebase-auth')
@Controller()
export class InviteCodesController {
    constructor(private readonly service: InviteCodesService) {}

    @Post('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '초대코드 생성 (§03, §04)' })
    createCode(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body() dto: CreateInviteCodeDto,
    ) {
        return this.service.createCode(tripId, userId, dto);
    }

    @Get('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '활성 초대코드 목록 조회 (§04.1, §14.1)' })
    listCodes(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
    ) {
        return this.service.listCodes(tripId, userId);
    }

    @Throttle({ default: { ttl: 60000, limit: 10 } })
    @Post('invite-codes/validate')
    @ApiOperation({ summary: '초대코드 사전 검증 — 인증 필요 (§05, §14.1)' })
    validateCode(
        @CurrentUser() userId: string,
        @Body() dto: ValidateCodeDto,
    ) {
        return this.service.validateCode(dto.code);
    }

    @Throttle({ default: { ttl: 60000, limit: 5 } })
    @Post('invite-codes/use')
    @ApiOperation({ summary: '초대코드 사용/합류 (§05, §11)' })
    useCode(
        @CurrentUser() userId: string,
        @Body() dto: UseCodeDto,
    ) {
        return this.service.useCode(dto.code, userId);
    }

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

핵심 변경:
- `@Public()` 제거 (§14.1: validate는 인증 필요)
- `@Throttle({ default: { ttl: 60000, limit: 10 } })` → validate 엔드포인트 (§12.3: 1분 10회)
- `@Throttle({ default: { ttl: 60000, limit: 5 } })` → use 엔드포인트
- `Public` import 제거
- validateCode에 `@CurrentUser() userId: string` 파라미터 추가 (인증 유저 확인용)

**Step 2: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.controller.ts
git commit -m "fix(controller): validate @Public 제거 + Rate Limiting 적용 (§12.3, §14.1)"
```

---

## Task 6: 테스트 보강 — 10건 불일치 커버

**Files:**
- Modify: `safetrip-server-api/src/modules/invite-codes/invite-codes.service.spec.ts`

**Step 1: 기존 테스트의 usedCount → currentUses 교체**

기존 spec 파일에서 모든 `usedCount` 참조를 `currentUses`로 교체.

**Step 2: 신규 테스트 케이스 추가**

기존 테스트 파일 끝(493줄 `});` 바로 앞)에 다음 테스트 블록 추가:

```typescript
    // ==========================================
    // 아키텍처 원칙 정합성 검증 추가 테스트
    // ==========================================
    describe('Architecture Compliance Tests', () => {
        // #5: 크루장 고급 설정 제한 (§04.1)
        it('should force defaults for crew_chief (max_uses=1, expires_hours=72)', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            mockInviteCodeRepo.create.mockImplementation((data: any) => ({ inviteCodeId: 'ic-cc-001', ...data }));
            mockInviteCodeRepo.save.mockImplementation((data: any) => Promise.resolve(data));

            // 크루장이 max_uses=10, expires_hours=168을 전달해도 기본값 강제
            const result = await service.createCode(tripId, mockCrewChiefMember.userId, {
                target_role: 'crew',
                max_uses: 10,
                expires_hours: 168,
            });

            expect(result.max_uses).toBe(1);
            // expires_at should be ~72h from now, not 168h
            const expiresAt = new Date(result.expires_at as Date);
            const expected72h = new Date();
            expected72h.setTime(expected72h.getTime() + 72 * 60 * 60 * 1000);
            const diff = Math.abs(expiresAt.getTime() - expected72h.getTime());
            expect(diff).toBeLessThan(5000);
        });

        // #7: 크루장 정원 초과 시 ERR_ROLE_UNAVAILABLE (§05 Step 8)
        it('should throw ERR_ROLE_UNAVAILABLE when crew_chief quota exceeded', async () => {
            const crewChiefInvite = {
                inviteCodeId: 'ic-cc-quota',
                code: 'CCQUOTA',
                groupId,
                tripId,
                targetRole: 'crew_chief',
                maxUses: 5,
                currentUses: 0,
                isActive: true,
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            };

            mockQueryRunner.manager.findOne
                .mockResolvedValueOnce(crewChiefInvite)   // InviteCode
                .mockResolvedValueOnce(mockTrip)           // Trip
                .mockResolvedValueOnce(null)               // no existing member
                .mockResolvedValueOnce({ groupId, groupName: 'Test', maxMembers: 50 }); // Group

            mockQueryRunner.manager.count
                .mockResolvedValueOnce(10)   // capacity check: 10 < 50, OK
                .mockResolvedValueOnce(5);   // crew_chief count: 5 >= MAX(5), FAIL

            await expect(service.useCode('CCQUOTA', 'user-new-001')).rejects.toThrow(BadRequestException);
            await expect(
                (async () => {
                    mockQueryRunner.manager.findOne
                        .mockResolvedValueOnce(crewChiefInvite)
                        .mockResolvedValueOnce(mockTrip)
                        .mockResolvedValueOnce(null)
                        .mockResolvedValueOnce({ groupId, groupName: 'Test', maxMembers: 50 });
                    mockQueryRunner.manager.count
                        .mockResolvedValueOnce(10)
                        .mockResolvedValueOnce(5);
                    return service.useCode('CCQUOTA', 'user-new-001');
                })(),
            ).rejects.toThrow('ERR_ROLE_UNAVAILABLE');
        });

        // #8: createCode 응답에 qr_url 포함 (§14.2)
        it('should include qr_url in createCode response', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            mockInviteCodeRepo.create.mockImplementation((data: any) => ({ inviteCodeId: 'ic-qr', ...data }));
            mockInviteCodeRepo.save.mockImplementation((data: any) => Promise.resolve(data));

            const result = await service.createCode(tripId, userId, { target_role: 'crew' });

            expect(result.qr_url).toBeDefined();
            expect(result.qr_url).toContain('https://api.safetrip.app/qr/');
            expect(result.qr_url).toContain(result.code);
        });

        // #9: listCodes는 isActive=true만 반환 (§14.1)
        it('should filter only active codes in listCodes', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            mockInviteCodeRepo.find.mockResolvedValue([]);

            await service.listCodes(tripId, userId);

            expect(mockInviteCodeRepo.find).toHaveBeenCalledWith({
                where: { groupId, isActive: true },
                order: { createdAt: 'DESC' },
            });
        });

        // #2: currentUses 컬럼명 사용 확인
        it('should use current_uses column in atomic increment', async () => {
            // Setup successful join
            const validInvite = {
                inviteCodeId: 'ic-cu',
                code: 'CURUSES',
                groupId,
                tripId,
                targetRole: 'crew',
                maxUses: 5,
                currentUses: 2,
                isActive: true,
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            };
            mockQueryRunner.manager.findOne
                .mockResolvedValueOnce(validInvite)
                .mockResolvedValueOnce(mockTrip)
                .mockResolvedValueOnce(null)
                .mockResolvedValueOnce({ groupId, groupName: 'Test', maxMembers: 50 });
            mockQueryRunner.manager.count.mockResolvedValue(5);

            await service.useCode('CURUSES', 'user-new-002');

            expect(mockQueryRunner.query).toHaveBeenCalledWith(
                `UPDATE tb_invite_code SET current_uses = current_uses + 1 WHERE invite_code_id = $1`,
                ['ic-cu'],
            );
        });

        // #2: validateCode에서 currentUses 사용 확인
        it('should check currentUses for exhaustion in validateCode', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({
                inviteCodeId: 'ic-exh',
                code: 'EXHAUST',
                groupId,
                tripId,
                targetRole: 'crew',
                maxUses: 3,
                currentUses: 3,
                isActive: true,
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });

            await expect(service.validateCode('EXHAUST')).rejects.toThrow('ERR_CODE_EXHAUSTED');
        });
    });
```

**Step 3: 테스트 실행**

```bash
cd safetrip-server-api && npx jest --testPathPattern invite-codes --verbose
```

Expected: 모든 테스트(기존 19 + 신규 6 = 25개) PASS

**Step 4: 커밋**

```bash
git add safetrip-server-api/src/modules/invite-codes/invite-codes.service.spec.ts
git commit -m "test(invite-codes): 아키텍처 원칙 정합성 검증 테스트 6건 추가 (§03-§14)"
```

---

## Task 7: Flutter 클라이언트 영향 확인

**Files:**
- Verify: `safetrip-mobile/lib/services/api_service.dart` (used_count 참조 여부)
- Verify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/invite_code_management_modal.dart`

**Step 1: Flutter 코드에서 `used_count` → `current_uses` 참조 교체**

Flutter 클라이언트에서 API 응답의 `used_count` 필드를 참조하는 모든 곳을 `current_uses`로 변경한다.

검색 대상: `used_count`가 포함된 Dart 파일

**Step 2: 커밋 (변경 있을 경우)**

```bash
git add safetrip-mobile/
git commit -m "fix(mobile): API 응답 필드 used_count → current_uses 정합 (§13.1)"
```

---

## 실행 순서 요약

| Task | 대상 계층 | 수정 이슈 | 의존성 |
|------|----------|----------|--------|
| 1 | DB (SQL) | #2 컬럼명, #6 NOT NULL | 없음 |
| 2 | Entity | #2 컬럼명, nullable | Task 1 |
| 3 | DTO | #3 expires_hours Max, #4 max_uses Max | 없음 |
| 4 | Service | #2, #5, #7, #8, #9 | Task 2, 3 |
| 5 | Controller | #1 @Public, #10 Rate Limiting | Task 4 |
| 6 | Test | 전체 검증 | Task 4, 5 |
| 7 | Flutter | #2 응답 필드명 | Task 4 |
