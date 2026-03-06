# Profile Screen (P0~P2) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement profile screen features P0~P2 from DOC-T3-PRF-027: profile editing with validation, role-based profile viewing, emergency contact CRUD, guardian badges, avatar system, privacy level display, and offline draft storage.

**Architecture:** Extend existing `tb_user` table with new columns (avatar_id, privacy_level, image_review_status, onboarding_completed). Add emergency contact CRUD to users module. Create role-based profile filtering endpoint that queries GroupMember for trip role context. Flutter changes extend existing screens and add new view/avatar widgets.

**Tech Stack:** NestJS/TypeORM (server), Flutter/Dart (mobile), PostgreSQL, Jest (server tests), flutter_test (widget tests)

---

### Task 1: DB Migration — Add Profile Columns to tb_user

**Files:**
- Create: `safetrip-server-api/sql/11-migration-profile-columns.sql`

**Step 1: Write migration SQL**

```sql
-- 11-migration-profile-columns.sql
-- Profile Screen P0~P2: Add profile columns to tb_user (DOC-T3-PRF-027 §11)

-- New columns
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS avatar_id VARCHAR(30);
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS privacy_level VARCHAR(20) DEFAULT 'standard';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS image_review_status VARCHAR(20) DEFAULT 'none';
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- Migrate existing location_sharing_mode → privacy_level
UPDATE tb_user SET privacy_level = CASE
  WHEN location_sharing_mode = 'always' THEN 'safety_first'
  WHEN location_sharing_mode = 'in_trip' THEN 'standard'
  WHEN location_sharing_mode = 'off' THEN 'privacy_first'
  ELSE 'standard'
END WHERE privacy_level IS NULL OR privacy_level = 'standard';

-- Sync onboarding_completed from is_onboarding_complete
UPDATE tb_user SET onboarding_completed = COALESCE(is_onboarding_complete, FALSE);

-- Nickname uniqueness (display_name used as nickname, §3.1)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_nickname_unique
  ON tb_user(display_name) WHERE deleted_at IS NULL AND display_name IS NOT NULL AND display_name != '';
```

**Step 2: Run migration**

Run: `cd safetrip-server-api && psql "$DATABASE_URL" -f sql/11-migration-profile-columns.sql`
Expected: ALTER TABLE, UPDATE, CREATE INDEX succeed

**Step 3: Commit**

```bash
git add safetrip-server-api/sql/11-migration-profile-columns.sql
git commit -m "feat(db): add profile columns — avatar_id, privacy_level, image_review_status, onboarding_completed"
```

---

### Task 2: Server Entity — Extend User Entity with New Columns

**Files:**
- Modify: `safetrip-server-api/src/entities/user.entity.ts`

**Step 1: Write failing test**

Create: `safetrip-server-api/src/modules/users/users.service.spec.ts` (extend existing)

Add test verifying formatUserResponse includes new fields:

```typescript
it('getProfile should return avatar_id and privacy_level', async () => {
    const mockUser = {
        userId: 'test-user-1',
        displayName: 'TestNick',
        phoneNumber: '+821012345678',
        phoneCountryCode: '+82',
        profileImageUrl: null,
        dateOfBirth: null,
        locationSharingMode: 'in_trip',
        avatarId: 'avatar_airplane',
        privacyLevel: 'standard',
        imageReviewStatus: 'none',
        onboardingCompleted: true,
        lastVerificationAt: new Date(),
        createdAt: new Date(),
        lastActiveAt: new Date(),
        minorStatus: 'adult',
    };
    mockUserRepo.findOne.mockResolvedValue(mockUser);
    mockGuardianRepo.findOne.mockResolvedValue(null);

    const result = await service.getProfile('test-user-1');

    expect(result).toHaveProperty('avatar_id', 'avatar_airplane');
    expect(result).toHaveProperty('privacy_level', 'standard');
    expect(result).toHaveProperty('image_review_status', 'none');
    expect(result).toHaveProperty('onboarding_completed', true);
    expect(result).toHaveProperty('minor_status', 'adult');
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: FAIL — avatar_id not in response

**Step 3: Add columns to User entity**

Modify `safetrip-server-api/src/entities/user.entity.ts`, after line 33 (`locationSharingMode`):

```typescript
    @Column({ name: 'avatar_id', type: 'varchar', length: 30, nullable: true })
    avatarId: string | null;

    @Column({ name: 'privacy_level', type: 'varchar', length: 20, default: 'standard' })
    privacyLevel: string; // 'safety_first' | 'standard' | 'privacy_first'

    @Column({ name: 'image_review_status', type: 'varchar', length: 20, default: 'none' })
    imageReviewStatus: string; // 'none' | 'pending' | 'approved' | 'rejected'

    @Column({ name: 'onboarding_completed', type: 'boolean', default: false })
    onboardingCompleted: boolean;

    @Column({ name: 'deletion_reason', type: 'text', nullable: true })
    deletionReason: string | null;
```

**Step 4: Update formatUserResponse in users.service.ts**

Add to the return object in `formatUserResponse()` (after line 48):

```typescript
    avatar_id: user.avatarId,
    privacy_level: user.privacyLevel,
    image_review_status: user.imageReviewStatus,
    onboarding_completed: user.onboardingCompleted,
    minor_status: user.minorStatus,
```

**Step 5: Run test to verify it passes**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: PASS

**Step 6: Commit**

```bash
git add safetrip-server-api/src/entities/user.entity.ts safetrip-server-api/src/modules/users/users.service.ts safetrip-server-api/src/modules/users/users.service.spec.ts
git commit -m "feat(server): extend User entity with avatar_id, privacy_level, image_review_status, onboarding_completed"
```

---

### Task 3: Server — Nickname Validation & UpdateProfileDto Enhancement

**Files:**
- Modify: `safetrip-server-api/src/modules/users/dto/update-profile.dto.ts`
- Modify: `safetrip-server-api/src/modules/users/users.service.ts`
- Modify: `safetrip-server-api/src/modules/users/users.controller.ts`

**Step 1: Write failing test for nickname validation**

Add to `users.service.spec.ts`:

```typescript
describe('validateNickname', () => {
    it('should reject nicknames shorter than 2 chars', async () => {
        await expect(service.updateProfile('user1', { displayName: 'A' }))
            .rejects.toThrow(BadRequestException);
    });

    it('should reject nicknames longer than 20 chars', async () => {
        await expect(service.updateProfile('user1', { displayName: 'A'.repeat(21) }))
            .rejects.toThrow(BadRequestException);
    });

    it('should reject nicknames with special characters', async () => {
        await expect(service.updateProfile('user1', { displayName: 'test@user!' }))
            .rejects.toThrow(BadRequestException);
    });

    it('should allow underscores and dots', async () => {
        mockUserRepo.findOne.mockResolvedValue({ userId: 'user1', displayName: 'old' });
        mockUserRepo.update.mockResolvedValue({});
        mockGuardianRepo.findOne.mockResolvedValue(null);
        // No duplicate
        mockUserRepo.createQueryBuilder.mockReturnValue({
            where: jest.fn().mockReturnThis(),
            andWhere: jest.fn().mockReturnThis(),
            getOne: jest.fn().mockResolvedValue(null),
        });

        await expect(service.updateProfile('user1', { displayName: 'test.user_1' }))
            .resolves.toBeDefined();
    });
});
```

**Step 2: Run test to verify it fails**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: FAIL — no validation logic yet

**Step 3: Add validation in UsersService.updateProfile**

Add private method to `users.service.ts`:

```typescript
private validateNickname(nickname: string) {
    if (nickname.length < 2 || nickname.length > 20) {
        throw new BadRequestException('닉네임은 2자 이상 20자 이하로 입력해 주세요');
    }
    // Allow letters, numbers, Korean, underscores, dots only
    if (!/^[\w가-힣ㄱ-ㅎㅏ-ㅣ.]+$/u.test(nickname)) {
        throw new BadRequestException('특수문자는 사용할 수 없습니다 (밑줄·점 제외)');
    }
}

private async checkNicknameDuplicate(nickname: string, excludeUserId: string) {
    const existing = await this.userRepo.createQueryBuilder('u')
        .where('u.displayName = :nickname', { nickname })
        .andWhere('u.userId != :excludeUserId', { excludeUserId })
        .andWhere('u.deletedAt IS NULL')
        .getOne();
    if (existing) {
        throw new BadRequestException('이미 사용 중인 닉네임입니다. 다른 닉네임을 입력해 주세요');
    }
}
```

Update `updateProfile()` to call validation before update:

```typescript
async updateProfile(userId: string, data: any) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (!user) throw new NotFoundException('User not found');

    if (data.displayName !== undefined) {
        this.validateNickname(data.displayName);
        await this.checkNicknameDuplicate(data.displayName, userId);
    }

    await this.userRepo.update(userId, { ...data, updatedAt: new Date() });
    const updated = await this.userRepo.findOne({ where: { userId } });
    return await this.formatUserResponse(updated!);
}
```

**Step 4: Update UpdateProfileDto with new fields**

```typescript
export class UpdateProfileDto {
    @Expose({ name: 'display_name' })
    @IsString() @IsOptional()
    displayName?: string;

    @Expose({ name: 'profile_image_url' })
    @IsString() @IsOptional()
    profileImageUrl?: string;

    @Expose({ name: 'date_of_birth' })
    @IsString() @IsOptional()
    dateOfBirth?: string;

    @Expose({ name: 'location_sharing_mode' })
    @IsString() @IsOptional()
    locationSharingMode?: string;

    @Expose({ name: 'avatar_id' })
    @IsString() @IsOptional()
    avatarId?: string;

    @Expose({ name: 'privacy_level' })
    @IsString() @IsOptional()
    privacyLevel?: string;
}
```

**Step 5: Update controller to pass new fields**

In `users.controller.ts` `updateMyProfile()`, add:

```typescript
if (body.avatarId !== undefined) updateData.avatarId = body.avatarId;
if (body.privacyLevel !== undefined) updateData.privacyLevel = body.privacyLevel;
```

**Step 6: Add nickname check endpoint to controller**

```typescript
@Get('check-nickname')
@ApiOperation({ summary: '닉네임 중복 검사' })
@ApiQuery({ name: 'nickname', required: true })
async checkNickname(
    @CurrentUser() userId: string,
    @Query('nickname') nickname: string,
) {
    if (!nickname || nickname.length < 2) {
        throw new BadRequestException('닉네임은 2자 이상 입력해 주세요');
    }
    await this.usersService.checkNicknameDuplicate(nickname, userId);
    return { success: true, data: { available: true } };
}
```

NOTE: Place this BEFORE the `@Get('me')` route.

**Step 7: Run tests**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: PASS

**Step 8: Commit**

```bash
git add safetrip-server-api/src/modules/users/dto/update-profile.dto.ts safetrip-server-api/src/modules/users/users.service.ts safetrip-server-api/src/modules/users/users.controller.ts safetrip-server-api/src/modules/users/users.service.spec.ts
git commit -m "feat(server): nickname validation (2-20 chars, special char filter, duplicate check)"
```

---

### Task 4: Server — Emergency Contact CRUD Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/users/users.module.ts` (add EmergencyContact)
- Modify: `safetrip-server-api/src/modules/users/users.service.ts` (add CRUD methods)
- Modify: `safetrip-server-api/src/modules/users/users.controller.ts` (add routes)
- Create: `safetrip-server-api/src/modules/users/dto/emergency-contact.dto.ts`

**Step 1: Write failing tests**

Add to `users.service.spec.ts`:

```typescript
describe('Emergency Contact CRUD', () => {
    it('getEmergencyContacts should return contacts for user', async () => {
        const mockContacts = [
            { contactId: 'c1', userId: 'user1', contactName: '엄마', phoneNumber: '+821000001111', priority: 1 },
        ];
        mockEmergencyContactRepo.find.mockResolvedValue(mockContacts);

        const result = await service.getEmergencyContacts('user1');
        expect(result).toHaveLength(1);
        expect(result[0]).toHaveProperty('contact_name', '엄마');
    });

    it('createEmergencyContact should enforce max 2 contacts', async () => {
        mockEmergencyContactRepo.count.mockResolvedValue(2);

        await expect(service.createEmergencyContact('user1', {
            contactName: '새연락처',
            phoneNumber: '+821099998888',
            contactOrder: 1,
        })).rejects.toThrow(BadRequestException);
    });

    it('deleteEmergencyContact should block for minors', async () => {
        mockUserRepo.findOne.mockResolvedValue({ userId: 'minor1', minorStatus: 'minor' });
        mockEmergencyContactRepo.count.mockResolvedValue(1);

        await expect(service.deleteEmergencyContact('minor1', 'c1'))
            .rejects.toThrow(BadRequestException);
    });
});
```

**Step 2: Run test to verify fails**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: FAIL — methods don't exist

**Step 3: Create DTO**

`safetrip-server-api/src/modules/users/dto/emergency-contact.dto.ts`:

```typescript
import { IsString, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Expose } from 'class-transformer';

export class CreateEmergencyContactDto {
    @Expose({ name: 'contact_name' })
    @IsString()
    contactName: string;

    @Expose({ name: 'phone_number' })
    @IsString()
    phoneNumber: string;

    @Expose({ name: 'phone_country_code' })
    @IsString() @IsOptional()
    phoneCountryCode?: string;

    @Expose({ name: 'relationship' })
    @IsString() @IsOptional()
    relationship?: string;

    @Expose({ name: 'contact_order' })
    @IsInt() @Min(1) @Max(2) @IsOptional()
    contactOrder?: number;
}

export class UpdateEmergencyContactDto {
    @Expose({ name: 'contact_name' })
    @IsString() @IsOptional()
    contactName?: string;

    @Expose({ name: 'phone_number' })
    @IsString() @IsOptional()
    phoneNumber?: string;

    @Expose({ name: 'phone_country_code' })
    @IsString() @IsOptional()
    phoneCountryCode?: string;

    @Expose({ name: 'relationship' })
    @IsString() @IsOptional()
    relationship?: string;
}
```

**Step 4: Add EmergencyContact to UsersModule**

In `users.module.ts`:

```typescript
import { EmergencyContact } from '../../entities/emergency.entity';
// ...
imports: [TypeOrmModule.forFeature([User, FcmToken, Guardian, GuardianLink, EmergencyContact])],
```

**Step 5: Add CRUD methods to UsersService**

Inject `EmergencyContact` repository:

```typescript
@InjectRepository(EmergencyContact) private emergencyContactRepo: Repository<EmergencyContact>,
```

Add methods:

```typescript
async getEmergencyContacts(userId: string) {
    const contacts = await this.emergencyContactRepo.find({
        where: { userId },
        order: { priority: 'ASC' },
    });
    return contacts.map(c => ({
        contact_id: c.contactId,
        contact_name: c.contactName,
        phone_number: c.phoneNumber,
        phone_country_code: c.phoneCountryCode,
        relationship: c.relationship,
        contact_order: c.priority,
    }));
}

async createEmergencyContact(userId: string, data: { contactName: string; phoneNumber: string; phoneCountryCode?: string; relationship?: string; contactOrder?: number }) {
    const count = await this.emergencyContactRepo.count({ where: { userId } });
    if (count >= 2) {
        throw new BadRequestException('긴급 연락처는 최대 2명까지 등록 가능합니다');
    }

    const contact = this.emergencyContactRepo.create({
        userId,
        contactName: data.contactName,
        phoneNumber: data.phoneNumber,
        phoneCountryCode: data.phoneCountryCode || '+82',
        relationship: data.relationship || null,
        priority: data.contactOrder || (count + 1),
    });
    await this.emergencyContactRepo.save(contact);

    return {
        contact_id: contact.contactId,
        contact_name: contact.contactName,
        phone_number: contact.phoneNumber,
        phone_country_code: contact.phoneCountryCode,
        relationship: contact.relationship,
        contact_order: contact.priority,
    };
}

async updateEmergencyContact(userId: string, contactId: string, data: any) {
    const contact = await this.emergencyContactRepo.findOne({ where: { contactId, userId } });
    if (!contact) throw new NotFoundException('긴급 연락처를 찾을 수 없습니다');

    if (data.contactName) contact.contactName = data.contactName;
    if (data.phoneNumber) contact.phoneNumber = data.phoneNumber;
    if (data.phoneCountryCode) contact.phoneCountryCode = data.phoneCountryCode;
    if (data.relationship !== undefined) contact.relationship = data.relationship;
    contact.updatedAt = new Date();

    await this.emergencyContactRepo.save(contact);
    return {
        contact_id: contact.contactId,
        contact_name: contact.contactName,
        phone_number: contact.phoneNumber,
        phone_country_code: contact.phoneCountryCode,
        relationship: contact.relationship,
        contact_order: contact.priority,
    };
}

async deleteEmergencyContact(userId: string, contactId: string) {
    const user = await this.userRepo.findOne({ where: { userId } });
    if (user && user.minorStatus !== 'adult') {
        const count = await this.emergencyContactRepo.count({ where: { userId } });
        if (count <= 1) {
            throw new BadRequestException('미성년자 계정의 긴급 연락처는 삭제할 수 없습니다');
        }
    }

    const result = await this.emergencyContactRepo.delete({ contactId, userId });
    if (result.affected === 0) throw new NotFoundException('긴급 연락처를 찾을 수 없습니다');
    return { deleted: true };
}

// Captain-only: view another user's emergency contacts
async getEmergencyContactsForCaptain(requesterId: string, targetUserId: string, tripId: string) {
    // Verify requester is captain of the trip
    const memberRepo = this.userRepo.manager.getRepository('tb_group_member');
    const requesterMember = await memberRepo.findOne({
        where: { userId: requesterId, tripId, memberRole: 'captain', status: 'active' },
    });
    if (!requesterMember) {
        throw new ForbiddenException('캡틴만 타인의 긴급 연락처를 조회할 수 있습니다');
    }

    return this.getEmergencyContacts(targetUserId);
}
```

**Step 6: Add routes to UsersController**

Place BEFORE `:userId` param routes:

```typescript
// ── Emergency Contacts ──

@Get('me/emergency-contacts')
@ApiOperation({ summary: '내 긴급연락처 목록 조회' })
async getMyEmergencyContacts(@CurrentUser() userId: string) {
    const contacts = await this.usersService.getEmergencyContacts(userId);
    return { success: true, data: contacts };
}

@Post('me/emergency-contacts')
@ApiOperation({ summary: '긴급연락처 추가 (최대 2명)' })
async createEmergencyContact(
    @CurrentUser() userId: string,
    @Body() body: CreateEmergencyContactDto,
) {
    const contact = await this.usersService.createEmergencyContact(userId, {
        contactName: body.contactName,
        phoneNumber: body.phoneNumber,
        phoneCountryCode: body.phoneCountryCode,
        relationship: body.relationship,
        contactOrder: body.contactOrder,
    });
    return { success: true, data: contact };
}

@Put('me/emergency-contacts/:contactId')
@ApiOperation({ summary: '긴급연락처 수정' })
async updateEmergencyContact(
    @CurrentUser() userId: string,
    @Param('contactId') contactId: string,
    @Body() body: UpdateEmergencyContactDto,
) {
    const contact = await this.usersService.updateEmergencyContact(userId, contactId, body);
    return { success: true, data: contact };
}

@Delete('me/emergency-contacts/:contactId')
@ApiOperation({ summary: '긴급연락처 삭제 (미성년자 차단)' })
async deleteEmergencyContact(
    @CurrentUser() userId: string,
    @Param('contactId') contactId: string,
) {
    await this.usersService.deleteEmergencyContact(userId, contactId);
    return { success: true, data: { message: '긴급 연락처가 삭제되었습니다' } };
}
```

**Step 7: Run tests**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: PASS

**Step 8: Commit**

```bash
git add safetrip-server-api/src/modules/users/
git commit -m "feat(server): emergency contact CRUD — max 2 contacts, minor delete protection"
```

---

### Task 5: Server — Role-Based Profile Filtering (§5 Matrix)

**Files:**
- Modify: `safetrip-server-api/src/modules/users/users.service.ts`
- Modify: `safetrip-server-api/src/modules/users/users.controller.ts`
- Modify: `safetrip-server-api/src/modules/users/users.module.ts` (add GroupMember)

**Step 1: Write failing test**

Add to `users.service.spec.ts`:

```typescript
describe('Role-based profile filtering', () => {
    it('captain viewing crew should see all fields including emergency contacts', async () => {
        const result = await service.getFilteredProfile('captain-id', 'crew-id', 'trip-1');
        expect(result).toHaveProperty('emergency_contacts');
        expect(result).toHaveProperty('last_location');
        expect(result).toHaveProperty('assigned_group');
    });

    it('crew viewing crew should only see basic info', async () => {
        const result = await service.getFilteredProfile('crew-id', 'other-crew-id', 'trip-1');
        expect(result).not.toHaveProperty('emergency_contacts');
        expect(result).not.toHaveProperty('last_location');
    });

    it('unconnected guardian should only see nickname and photo', async () => {
        const result = await service.getFilteredProfile('guardian-id', 'crew-id', null);
        expect(result).toHaveProperty('display_name');
        expect(result).toHaveProperty('profile_image_url');
        expect(result).not.toHaveProperty('travel_status');
    });
});
```

**Step 2: Run test to verify fails**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: FAIL — `getFilteredProfile` doesn't exist

**Step 3: Add GroupMember to UsersModule**

```typescript
import { GroupMember } from '../../entities/group-member.entity';
// imports: [..., GroupMember]
```

**Step 4: Implement getFilteredProfile in UsersService**

Inject GroupMember repo:

```typescript
@InjectRepository(GroupMember) private groupMemberRepo: Repository<GroupMember>,
```

Add:

```typescript
async getFilteredProfile(requesterId: string, targetUserId: string, tripId: string | null) {
    const targetUser = await this.userRepo.findOne({ where: { userId: targetUserId } });
    if (!targetUser) throw new NotFoundException('존재하지 않는 사용자입니다');
    if (targetUser.deletedAt) {
        return {
            display_name: '탈퇴한 사용자',
            profile_image_url: null,
            avatar_id: null,
            is_deleted: true,
        };
    }

    // Base profile (minimum: nickname + photo — §5.2)
    const base = {
        user_id: targetUser.userId,
        display_name: targetUser.displayName,
        profile_image_url: targetUser.profileImageUrl,
        avatar_id: targetUser.avatarId,
    };

    // No trip context → basic info only
    if (!tripId) return base;

    // Get requester's role in this trip
    const requesterMember = await this.groupMemberRepo.findOne({
        where: { userId: requesterId, tripId, status: 'active' },
    });
    const targetMember = await this.groupMemberRepo.findOne({
        where: { userId: targetUserId, tripId, status: 'active' },
    });

    if (!requesterMember || !targetMember) return base;

    const requesterRole = requesterMember.memberRole; // captain | crew_chief | crew
    const result: any = {
        ...base,
        travel_status: targetMember.status === 'active' ? '여행 중' : '미참여',
        member_role: targetMember.memberRole,
    };

    // Captain sees everything (§5.1 row 1-3)
    if (requesterRole === 'captain') {
        result.emergency_contacts = await this.getEmergencyContacts(targetUserId);
        result.last_location = true; // placeholder: actual location from location service
        result.assigned_group = targetMember.groupId;
        return result;
    }

    // Crew chief sees own group members' location (§5.1 row 4)
    if (requesterRole === 'crew_chief') {
        const sameGroup = requesterMember.groupId === targetMember.groupId;
        if (sameGroup) {
            result.last_location = true;
            result.assigned_group = targetMember.groupId;
        }
        return result;
    }

    // Crew sees basic + travel status (§5.1 row 6-8)
    if (requesterRole === 'crew') {
        if (targetMember.memberRole === 'crew_chief') {
            result.assigned_group = targetMember.groupId;
        }
        return result;
    }

    // Guardian: check if connected
    const isGuardian = await this.checkGuardianConnection(requesterId, targetUserId);
    if (isGuardian) {
        result.last_location = true;
        return result;
    }

    // Unconnected guardian → basic only
    return base;
}

private async checkGuardianConnection(guardianUserId: string, memberUserId: string): Promise<boolean> {
    const guardian = await this.guardianRepo.findOne({ where: { userId: guardianUserId } });
    if (!guardian) return false;

    const link = await this.guardianLinkRepo.findOne({
        where: {
            guardianId: guardian.guardianId,
            travelerUserId: memberUserId,
            status: 'active',
        },
    });
    return !!link;
}
```

**Step 5: Add endpoint to controller**

Place before `:userId` GET route:

```typescript
@Get(':userId/profile')
@ApiOperation({ summary: '타인 프로필 조회 (역할별 필터링)' })
@ApiQuery({ name: 'trip_id', required: false })
async getUserProfile(
    @CurrentUser() requesterId: string,
    @Param('userId') targetUserId: string,
    @Query('trip_id') tripId?: string,
) {
    const profile = await this.usersService.getFilteredProfile(requesterId, targetUserId, tripId || null);
    return { success: true, data: profile };
}
```

**Step 6: Run tests**

Run: `cd safetrip-server-api && npx jest --testPathPattern users.service.spec --verbose`
Expected: PASS

**Step 7: Commit**

```bash
git add safetrip-server-api/src/modules/users/
git commit -m "feat(server): role-based profile filtering — §5 matrix (captain/crew_chief/crew/guardian)"
```

---

### Task 6: Server — Account Deletion Enhancement

**Files:**
- Modify: `safetrip-server-api/src/modules/auth/auth.service.ts`
- Modify: `safetrip-server-api/src/modules/auth/auth.controller.ts`

**Step 1: Write failing test**

Add to `auth.service.spec.ts`:

```typescript
it('requestDeletion should block when user has active trip', async () => {
    mockGroupMemberRepo.findOne.mockResolvedValue({ tripId: 'trip-1', memberRole: 'crew', status: 'active' });
    await expect(service.requestDeletion('user1', '앱을 더 이상 사용하지 않음'))
        .rejects.toThrow(BadRequestException);
});

it('requestDeletion should block captain without delegation', async () => {
    mockGroupMemberRepo.findOne.mockResolvedValue({ tripId: 'trip-1', memberRole: 'captain', status: 'active' });
    await expect(service.requestDeletion('captain1', '서비스 불만족'))
        .rejects.toThrow(BadRequestException);
});
```

**Step 2: Run test to verify fails**

Run: `cd safetrip-server-api && npx jest --testPathPattern auth.service.spec --verbose`
Expected: FAIL

**Step 3: Implement enhanced deletion**

Update `requestDeletion` in `auth.service.ts`:

```typescript
async requestDeletion(uid: string, reason?: string) {
    // Check active trip participation
    const groupMemberRepo = this.userRepo.manager.getRepository('tb_group_member');
    const activeMember = await groupMemberRepo.findOne({
        where: { userId: uid, status: 'active' },
    });

    if (activeMember) {
        if (activeMember.memberRole === 'captain') {
            throw new BadRequestException('리더십을 위임하거나 여행을 종료한 후 삭제해 주세요');
        }
        throw new BadRequestException('현재 참여 중인 여행이 있습니다. 여행 종료 또는 탈퇴 후 계정 삭제가 가능합니다');
    }

    await this.userRepo.update(uid, {
        deletionRequestedAt: new Date(),
        deletionReason: reason || null,
        isActive: false,
    });
    return { message: '계정 삭제가 요청되었습니다. 7일 후 최종 삭제됩니다.' };
}
```

Update controller to accept deletion_reason:

```typescript
@Delete('account')
@ApiBearerAuth('firebase-auth')
@HttpCode(HttpStatus.OK)
@ApiOperation({ summary: '계정 삭제 요청 (7일 유예)' })
async deleteAccount(
    @CurrentUser() userId: string,
    @Body() body?: { deletion_reason?: string },
) {
    return this.authService.requestDeletion(userId, body?.deletion_reason);
}
```

**Step 4: Run tests**

Run: `cd safetrip-server-api && npx jest --testPathPattern auth.service.spec --verbose`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/auth/
git commit -m "feat(server): enhanced account deletion — trip check, captain block, deletion reason"
```

---

### Task 7: Flutter — Avatar System (10 Travel Themes)

**Files:**
- Create: `safetrip-mobile/lib/core/constants/avatar_constants.dart`
- Create: `safetrip-mobile/lib/widgets/avatar_selector.dart`
- Create: `safetrip-mobile/assets/images/avatars/` (10 placeholder assets)

**Step 1: Create avatar constants**

```dart
// safetrip-mobile/lib/core/constants/avatar_constants.dart

class AvatarConstants {
  static const List<AvatarTheme> themes = [
    AvatarTheme(id: 'avatar_airplane', name: '비행기', icon: '✈️', color: 0xFF4FC3F7),
    AvatarTheme(id: 'avatar_camping', name: '캠핑', icon: '⛺', color: 0xFF81C784),
    AvatarTheme(id: 'avatar_mountain', name: '산', icon: '🏔️', color: 0xFF7986CB),
    AvatarTheme(id: 'avatar_city', name: '도시', icon: '🏙️', color: 0xFFFFB74D),
    AvatarTheme(id: 'avatar_beach', name: '해변', icon: '🏖️', color: 0xFF4DD0E1),
    AvatarTheme(id: 'avatar_train', name: '기차', icon: '🚂', color: 0xFFE57373),
    AvatarTheme(id: 'avatar_ship', name: '크루즈', icon: '🚢', color: 0xFF90A4AE),
    AvatarTheme(id: 'avatar_backpack', name: '배낭여행', icon: '🎒', color: 0xFFA1887F),
    AvatarTheme(id: 'avatar_camera', name: '사진여행', icon: '📷', color: 0xFFBA68C8),
    AvatarTheme(id: 'avatar_compass', name: '탐험', icon: '🧭', color: 0xFFFF8A65),
  ];

  static AvatarTheme? getById(String? id) {
    if (id == null) return null;
    try {
      return themes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

class AvatarTheme {
  final String id;
  final String name;
  final String icon;
  final int color;

  const AvatarTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}
```

**Step 2: Create avatar selector widget**

```dart
// safetrip-mobile/lib/widgets/avatar_selector.dart

import 'package:flutter/material.dart';
import '../core/constants/avatar_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class AvatarSelector extends StatelessWidget {
  final String? selectedAvatarId;
  final ValueChanged<String> onSelected;

  const AvatarSelector({
    super.key,
    this.selectedAvatarId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: AvatarConstants.themes.length,
      itemBuilder: (context, index) {
        final avatar = AvatarConstants.themes[index];
        final isSelected = avatar.id == selectedAvatarId;

        return GestureDetector(
          onTap: () => onSelected(avatar.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color(avatar.color).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primaryTeal : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(avatar.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                avatar.name,
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**Step 3: Write widget test**

`safetrip-mobile/test/widgets/avatar_selector_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/core/constants/avatar_constants.dart';
import 'package:safetrip/widgets/avatar_selector.dart';

void main() {
  testWidgets('AvatarSelector renders 10 avatar options', (tester) async {
    String? selectedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarSelector(
            selectedAvatarId: null,
            onSelected: (id) => selectedId = id,
          ),
        ),
      ),
    );

    expect(find.text('비행기'), findsOneWidget);
    expect(find.text('캠핑'), findsOneWidget);
    expect(find.text('탐험'), findsOneWidget);
  });

  test('AvatarConstants has 10 themes', () {
    expect(AvatarConstants.themes.length, 10);
  });

  test('AvatarConstants.getById returns correct theme', () {
    final theme = AvatarConstants.getById('avatar_camping');
    expect(theme?.name, '캠핑');
  });

  test('AvatarConstants.getById returns null for unknown id', () {
    expect(AvatarConstants.getById('unknown'), isNull);
  });
}
```

**Step 4: Run test**

Run: `cd safetrip-mobile && flutter test test/widgets/avatar_selector_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/core/constants/avatar_constants.dart safetrip-mobile/lib/widgets/avatar_selector.dart safetrip-mobile/test/widgets/avatar_selector_test.dart
git commit -m "feat(mobile): avatar system — 10 travel theme avatars with selector grid"
```

---

### Task 8: Flutter — Guardian Badge Widget

**Files:**
- Create: `safetrip-mobile/lib/widgets/guardian_badge.dart`
- Create: `safetrip-mobile/test/widgets/guardian_badge_test.dart`

**Step 1: Write failing test**

```dart
// safetrip-mobile/test/widgets/guardian_badge_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/widgets/guardian_badge.dart';

void main() {
  testWidgets('GuardianBadge shows 가디언 for free guardian', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuardianBadge(isPaid: false)),
      ),
    );
    expect(find.text('가디언'), findsOneWidget);
  });

  testWidgets('GuardianBadge shows 가디언+ for paid guardian', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuardianBadge(isPaid: true)),
      ),
    );
    expect(find.text('가디언+'), findsOneWidget);
  });

  testWidgets('GuardianBadge.icon shows small circle badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuardianBadge.icon(isPaid: true)),
      ),
    );
    // Should render a small container with specific size
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container, isNotNull);
  });
}
```

**Step 2: Run to verify fails**

Run: `cd safetrip-mobile && flutter test test/widgets/guardian_badge_test.dart`
Expected: FAIL — GuardianBadge doesn't exist

**Step 3: Implement**

```dart
// safetrip-mobile/lib/widgets/guardian_badge.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// 가디언 배지 위젯 (DOC-T3-PRF-027 §4)
///
/// 무료 가디언: "가디언" (기본 브랜드 컬러)
/// 유료 가디언: "가디언+" (골드 프리미엄)
class GuardianBadge extends StatelessWidget {
  final bool isPaid;

  const GuardianBadge({super.key, required this.isPaid});

  /// 프로필 사진 우하단 원형 배지 아이콘 (§4.2)
  const factory GuardianBadge.icon({Key? key, required bool isPaid}) = _GuardianBadgeIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFFFF3E0) // gold background
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid
              ? const Color(0xFFFFB300) // gold border
              : AppColors.outline,
          width: 1,
        ),
      ),
      child: Text(
        isPaid ? '가디언+' : '가디언',
        style: AppTypography.labelSmall.copyWith(
          color: isPaid
              ? const Color(0xFFE65100) // gold text
              : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GuardianBadgeIcon extends GuardianBadge {
  const _GuardianBadgeIcon({super.key, required super.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFFFB300) : AppColors.outline,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Icon(
          Icons.shield,
          size: 12,
          color: isPaid ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
```

**Step 4: Run test**

Run: `cd safetrip-mobile && flutter test test/widgets/guardian_badge_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/widgets/guardian_badge.dart safetrip-mobile/test/widgets/guardian_badge_test.dart
git commit -m "feat(mobile): guardian badge widget — free/paid badge (§4.1)"
```

---

### Task 9: Flutter — Enhanced Profile Edit Screen

**Files:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_profile_edit.dart`
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: Update ApiService with new profile methods**

Add to `api_service.dart`:

```dart
// Emergency Contact CRUD
Future<List<Map<String, dynamic>>> getMyEmergencyContacts() async {
  final response = await _dio.get('/api/v1/users/me/emergency-contacts');
  final data = response.data['data'] as List? ?? [];
  return data.cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>?> createEmergencyContact({
  required String contactName,
  required String phoneNumber,
  String? relationship,
  int? contactOrder,
}) async {
  final response = await _dio.post('/api/v1/users/me/emergency-contacts', data: {
    'contact_name': contactName,
    'phone_number': phoneNumber,
    if (relationship != null) 'relationship': relationship,
    if (contactOrder != null) 'contact_order': contactOrder,
  });
  return response.data['data'];
}

Future<void> deleteEmergencyContact(String contactId) async {
  await _dio.delete('/api/v1/users/me/emergency-contacts/$contactId');
}

// Nickname check
Future<bool> checkNicknameAvailable(String nickname) async {
  final response = await _dio.get('/api/v1/users/check-nickname', queryParameters: {'nickname': nickname});
  return response.data['data']?['available'] == true;
}

// Profile with new fields
Future<Map<String, dynamic>?> getMyProfile() async {
  final response = await _dio.get('/api/v1/users/me');
  return response.data['data'];
}
```

**Step 2: Rewrite profile edit screen**

Modify `screen_profile_edit.dart` to add:
- Nickname validation (2-20 chars, special char filter)
- Emergency contacts section (list + add/delete)
- Privacy level read-only display
- Avatar selector (bottom sheet)
- Guardian badge display

The screen should now have sections:
1. Profile photo + avatar selector
2. Nickname field (with validation)
3. Phone number (read-only, masked)
4. Emergency contacts (expandable list)
5. Privacy level (read-only with link to settings)
6. Account deletion link

Full implementation in the existing file — replace the `build()` children list to include new sections.

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/settings/screen_profile_edit.dart safetrip-mobile/lib/services/api_service.dart
git commit -m "feat(mobile): enhanced profile edit — nickname validation, emergency contacts, avatar, privacy display"
```

---

### Task 10: Flutter — Profile View Screen (New)

**Files:**
- Create: `safetrip-mobile/lib/screens/profile/screen_profile_view.dart`

**Step 1: Create profile view screen**

This is a half-sheet/full-screen for viewing another user's profile.

```dart
// Key elements:
// - Avatar + guardian badge (if applicable)
// - Nickname
// - Travel status (if in trip)
// - Travel context (if viewer has permission): status, last location, assigned group
// - Emergency contacts (captain only)
```

The screen calls `GET /api/v1/users/:userId/profile?trip_id=X` and renders fields based on what the server returns (server handles filtering).

**Step 2: Register route in GoRouter**

Add to the existing router configuration.

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/screens/profile/
git commit -m "feat(mobile): profile view screen — role-filtered display with badge and travel context"
```

---

### Task 11: Flutter — Onboarding Improvements

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_profile_setup.dart`

**Step 1: Update privacy level values**

Change from `public/friends_only/private` to `safety_first/standard/privacy_first`.

Update the radio options:
```dart
{'value': 'safety_first', 'label': '안전최우선', 'desc': '캡틴·가디언·크루장에게 실시간 위치 공유'}
{'value': 'standard', 'label': '표준', 'desc': '일정 공유 시간대만 위치 공유 (기본값)'}
{'value': 'privacy_first', 'label': '프라이버시우선', 'desc': '위치를 공유하지 않음'}
```

**Step 2: Minor enforcement for emergency contact**

If user is minor (from birth date), make emergency contact required:
- Hide "나중에 설정" button
- Show "미성년자는 긴급 연락처 등록이 필요합니다" if empty

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/onboarding/
git commit -m "feat(mobile): onboarding — privacy_level value migration, minor emergency contact enforcement"
```

---

### Task 12: Flutter — Offline Draft Storage

**Files:**
- Create: `safetrip-mobile/lib/services/profile_draft_service.dart`

**Step 1: Implement draft service**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProfileDraftService {
  static const _draftKey = 'profile_draft';

  static Future<void> saveDraft(Map<String, dynamic> changes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(changes));
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_draftKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  static Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_draftKey);
  }
}
```

**Step 2: Integrate with profile edit screen**

In `screen_profile_edit.dart`:
- On save failure due to network → call `ProfileDraftService.saveDraft()`
- On screen init → check `hasDraft()` → show sync prompt when online

**Step 3: Write test**

`safetrip-mobile/test/services/profile_draft_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safetrip/services/profile_draft_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveDraft and loadDraft round-trips data', () async {
    await ProfileDraftService.saveDraft({'display_name': 'NewNick'});
    final draft = await ProfileDraftService.loadDraft();
    expect(draft?['display_name'], 'NewNick');
  });

  test('clearDraft removes saved data', () async {
    await ProfileDraftService.saveDraft({'display_name': 'Test'});
    await ProfileDraftService.clearDraft();
    expect(await ProfileDraftService.hasDraft(), isFalse);
  });
}
```

**Step 4: Run test**

Run: `cd safetrip-mobile && flutter test test/services/profile_draft_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/services/profile_draft_service.dart safetrip-mobile/test/services/profile_draft_service_test.dart
git commit -m "feat(mobile): offline profile draft storage with sync-on-reconnect"
```

---

### Task 13: Integration Testing & Verification (Iteration 1)

**Step 1: Run all server tests**

Run: `cd safetrip-server-api && npx jest --verbose`
Expected: All tests PASS

**Step 2: Run all Flutter tests**

Run: `cd safetrip-mobile && flutter test`
Expected: All tests PASS

**Step 3: Start server and test API manually**

```bash
cd safetrip-server-api && npm run dev
```

Test endpoints with curl:
```bash
# Nickname check
curl -X GET "http://localhost:3001/api/v1/users/check-nickname?nickname=테스트닉" -H "Authorization: Bearer $TOKEN"

# Emergency contacts
curl -X POST "http://localhost:3001/api/v1/users/me/emergency-contacts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"contact_name":"엄마","phone_number":"+821012345678"}'

# Profile with new fields
curl -X GET "http://localhost:3001/api/v1/users/me" -H "Authorization: Bearer $TOKEN"
```

**Step 4: Verify against §14 checklist items 1-12**

Walk through each checklist item from the requirements document and verify.

**Step 5: Commit verification results**

```bash
git commit --allow-empty -m "test: iteration 1 verification complete"
```

---

### Task 14: Fix Issues from Iteration 1 (Iteration 2)

Review all test failures and edge cases from Task 13:
- Fix any failing tests
- Address missing validation
- Ensure error messages match §10 exactly
- Verify minor enforcement works end-to-end

**Step 1: Re-run all tests after fixes**

Run: `cd safetrip-server-api && npx jest --verbose && cd ../safetrip-mobile && flutter test`
Expected: All PASS

**Step 2: Commit fixes**

```bash
git commit -m "fix: iteration 2 — address test failures and edge cases"
```

---

### Task 15: Final Verification (Iteration 3)

**Step 1: Full test suite**

```bash
cd safetrip-server-api && npx jest --coverage
cd ../safetrip-mobile && flutter test
```

**Step 2: Verify all §14 checklist items pass**

| # | Item | Status |
|:-:|------|--------|
| 1 | Nickname required in onboarding | Verify |
| 2 | Minor emergency contact required | Verify |
| 3 | Captain-only emergency contact view | Verify |
| 4 | Connected guardian access only | Verify |
| 5 | Unconnected guardian basic info only | Verify |
| 6 | Free/paid guardian badges | Verify |
| 7 | Badge FCM real-time update | Verify (placeholder) |
| 8 | Active trip blocks deletion | Verify |
| 9 | 7-day grace period | Verify |
| 10 | Re-login cancels deletion | Verify |
| 11 | Chat nickname anonymization | Verify (placeholder) |
| 12 | 5MB image upload limit | Verify |

**Step 3: Final commit**

```bash
git commit --allow-empty -m "test: iteration 3 final verification — all §14 checks passed"
```

---

## Summary of All Files

### Created
- `safetrip-server-api/sql/11-migration-profile-columns.sql`
- `safetrip-server-api/src/modules/users/dto/emergency-contact.dto.ts`
- `safetrip-mobile/lib/core/constants/avatar_constants.dart`
- `safetrip-mobile/lib/widgets/avatar_selector.dart`
- `safetrip-mobile/lib/widgets/guardian_badge.dart`
- `safetrip-mobile/lib/screens/profile/screen_profile_view.dart`
- `safetrip-mobile/lib/services/profile_draft_service.dart`
- `safetrip-mobile/test/widgets/avatar_selector_test.dart`
- `safetrip-mobile/test/widgets/guardian_badge_test.dart`
- `safetrip-mobile/test/services/profile_draft_service_test.dart`

### Modified
- `safetrip-server-api/src/entities/user.entity.ts`
- `safetrip-server-api/src/modules/users/users.module.ts`
- `safetrip-server-api/src/modules/users/users.service.ts`
- `safetrip-server-api/src/modules/users/users.service.spec.ts`
- `safetrip-server-api/src/modules/users/users.controller.ts`
- `safetrip-server-api/src/modules/users/dto/update-profile.dto.ts`
- `safetrip-server-api/src/modules/auth/auth.service.ts`
- `safetrip-server-api/src/modules/auth/auth.service.spec.ts`
- `safetrip-server-api/src/modules/auth/auth.controller.ts`
- `safetrip-mobile/lib/screens/settings/screen_profile_edit.dart`
- `safetrip-mobile/lib/services/api_service.dart`
- `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_profile_setup.dart`
