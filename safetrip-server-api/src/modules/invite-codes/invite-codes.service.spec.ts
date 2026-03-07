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

    // --- Mock Repositories ---
    const mockInviteCodeRepo = {
        create: jest.fn(),
        save: jest.fn(),
        find: jest.fn(),
        findOne: jest.fn(),
        count: jest.fn(),
    };

    const mockGroupRepo = {
        findOne: jest.fn(),
    };

    const mockMemberRepo = {
        findOne: jest.fn(),
    };

    const mockTripRepo = {
        findOne: jest.fn(),
    };

    // --- Mock QueryRunner for transactional useCode ---
    const mockQueryRunner = {
        connect: jest.fn(),
        startTransaction: jest.fn(),
        commitTransaction: jest.fn(),
        rollbackTransaction: jest.fn(),
        release: jest.fn(),
        query: jest.fn().mockResolvedValue([]),
        manager: {
            findOne: jest.fn(),
            find: jest.fn(),
            count: jest.fn(),
            create: jest.fn().mockImplementation((_entity: any, data: any) => ({ memberId: 'new-member-1', ...data })),
            save: jest.fn().mockImplementation((_entity: any, data: any) => data),
            update: jest.fn(),
            query: jest.fn().mockResolvedValue([]),
            createQueryBuilder: jest.fn().mockReturnValue({
                where: jest.fn().mockReturnThis(),
                andWhere: jest.fn().mockReturnThis(),
                orderBy: jest.fn().mockReturnThis(),
                getOne: jest.fn().mockResolvedValue(null),
            }),
        },
    };

    const mockDataSource = {
        createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
    };

    // --- Shared test data ---
    const tripId = 'trip-001';
    const userId = 'user-captain-001';
    const groupId = 'group-001';

    const mockTrip = {
        tripId,
        groupId,
        destination: 'Tokyo',
        startDate: new Date('2026-06-01'),
        endDate: new Date('2026-06-10'),
        status: 'scheduled',
    };

    const mockCaptainMember = {
        memberId: 'member-001',
        groupId,
        userId,
        memberRole: 'captain',
        status: 'active',
    };

    const mockCrewChiefMember = {
        memberId: 'member-002',
        groupId,
        userId: 'user-cc-001',
        memberRole: 'crew_chief',
        status: 'active',
    };

    const mockCrewMember = {
        memberId: 'member-003',
        groupId,
        userId: 'user-crew-001',
        memberRole: 'crew',
        status: 'active',
    };

    beforeEach(async () => {
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

        jest.clearAllMocks();
        // Re-attach default implementations after clearAllMocks
        mockDataSource.createQueryRunner.mockReturnValue(mockQueryRunner);
        mockQueryRunner.manager.create.mockImplementation((_entity: any, data: any) => ({ memberId: 'new-member-1', ...data }));
        mockQueryRunner.manager.save.mockImplementation((_entity: any, data: any) => data);
        mockQueryRunner.manager.query.mockResolvedValue([]);
        mockQueryRunner.manager.createQueryBuilder.mockReturnValue({
            where: jest.fn().mockReturnThis(),
            andWhere: jest.fn().mockReturnThis(),
            orderBy: jest.fn().mockReturnThis(),
            getOne: jest.fn().mockResolvedValue(null),
        });
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    // ==========================================
    // createCode
    // ==========================================
    describe('createCode', () => {
        const baseDto = { target_role: 'crew' };

        it('should create a valid 7-char code without O/0/I/l characters', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null); // no collision
            mockInviteCodeRepo.create.mockImplementation((data: any) => ({ inviteCodeId: 'ic-001', ...data }));
            mockInviteCodeRepo.save.mockImplementation((data: any) => Promise.resolve(data));

            const result = await service.createCode(tripId, userId, baseDto);

            expect(result.code).toBeDefined();
            expect(result.code.length).toBe(7);
            // Verify no forbidden characters
            const forbidden = /[O0Il]/;
            expect(forbidden.test(result.code)).toBe(false);
        });

        it('should reject crew_chief creating crew_chief codes (ForbiddenException)', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);

            await expect(
                service.createCode(tripId, mockCrewChiefMember.userId, { target_role: 'crew_chief' }),
            ).rejects.toThrow(ForbiddenException);
            await expect(
                service.createCode(tripId, mockCrewChiefMember.userId, { target_role: 'crew_chief' }),
            ).rejects.toThrow('Crew chief can only create crew invite codes');
        });

        it('should reject crew creating any codes (ForbiddenException)', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewMember);

            await expect(
                service.createCode(tripId, mockCrewMember.userId, { target_role: 'crew' }),
            ).rejects.toThrow(ForbiddenException);
            await expect(
                service.createCode(tripId, mockCrewMember.userId, { target_role: 'crew' }),
            ).rejects.toThrow('Only captain or crew_chief can create invite codes');
        });

        it('should allow crew_chief to create crew codes', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            mockInviteCodeRepo.create.mockImplementation((data: any) => ({ inviteCodeId: 'ic-002', ...data }));
            mockInviteCodeRepo.save.mockImplementation((data: any) => Promise.resolve(data));

            const result = await service.createCode(tripId, mockCrewChiefMember.userId, { target_role: 'crew' });

            expect(result.target_role).toBe('crew');
            expect(result.code).toBeDefined();
        });

        it('should reject when active code limit reached (BadRequestException)', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            // Captain limit is 10
            mockInviteCodeRepo.count.mockResolvedValue(10);

            await expect(
                service.createCode(tripId, userId, baseDto),
            ).rejects.toThrow(BadRequestException);
            await expect(
                service.createCode(tripId, userId, baseDto),
            ).rejects.toThrow('Active code limit reached');
        });

        it('should default to 72h expiry and max_uses=1', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            mockInviteCodeRepo.count.mockResolvedValue(0);
            mockInviteCodeRepo.findOne.mockResolvedValue(null);
            mockInviteCodeRepo.create.mockImplementation((data: any) => ({ inviteCodeId: 'ic-003', ...data }));
            mockInviteCodeRepo.save.mockImplementation((data: any) => Promise.resolve(data));

            const result = await service.createCode(tripId, userId, { target_role: 'crew' });

            expect(result.max_uses).toBe(1);
            // Verify expiry is roughly 72h from now (within 5 seconds tolerance)
            const expiresAt = new Date(result.expires_at as Date);
            const expected = new Date();
            expected.setTime(expected.getTime() + 72 * 60 * 60 * 1000);
            const diff = Math.abs(expiresAt.getTime() - expected.getTime());
            expect(diff).toBeLessThan(5000);
        });
    });

    // ==========================================
    // validateCode
    // ==========================================
    describe('validateCode', () => {
        const validInvite = {
            inviteCodeId: 'ic-001',
            code: 'ABCDE12',
            groupId,
            tripId,
            targetRole: 'crew',
            maxUses: 5,
            currentUses: 2,
            isActive: true,
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h from now
        };

        it('should throw ERR_CODE_NOT_FOUND for unknown code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue(null);

            await expect(service.validateCode('UNKNOWN')).rejects.toThrow(BadRequestException);
            await expect(service.validateCode('UNKNOWN')).rejects.toThrow('ERR_CODE_NOT_FOUND');
        });

        it('should throw ERR_CODE_INACTIVE for deactivated code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({ ...validInvite, isActive: false });

            await expect(service.validateCode('ABCDE12')).rejects.toThrow(BadRequestException);
            await expect(service.validateCode('ABCDE12')).rejects.toThrow('ERR_CODE_INACTIVE');
        });

        it('should throw ERR_CODE_EXPIRED for expired code', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({
                ...validInvite,
                expiresAt: new Date('2020-01-01'), // well in the past
            });

            await expect(service.validateCode('ABCDE12')).rejects.toThrow(BadRequestException);
            await expect(service.validateCode('ABCDE12')).rejects.toThrow('ERR_CODE_EXPIRED');
        });

        it('should throw ERR_CODE_EXHAUSTED when uses depleted', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue({
                ...validInvite,
                maxUses: 3,
                currentUses: 3, // fully used
            });

            await expect(service.validateCode('ABCDE12')).rejects.toThrow(BadRequestException);
            await expect(service.validateCode('ABCDE12')).rejects.toThrow('ERR_CODE_EXHAUSTED');
        });

        it('should throw ERR_TRIP_INVALID for completed trip', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue(validInvite);
            mockTripRepo.findOne.mockResolvedValue({ ...mockTrip, status: 'completed' });

            await expect(service.validateCode('ABCDE12')).rejects.toThrow(BadRequestException);
            await expect(service.validateCode('ABCDE12')).rejects.toThrow('ERR_TRIP_INVALID');
        });

        it('should normalize lowercase input to uppercase (verify findOne is called with uppercase)', async () => {
            mockInviteCodeRepo.findOne.mockResolvedValue(validInvite);
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockGroupRepo.findOne.mockResolvedValue({ groupId, groupName: 'Tokyo Trip' });

            await service.validateCode('abcde12');

            expect(mockInviteCodeRepo.findOne).toHaveBeenCalledWith({
                where: { code: 'ABCDE12' },
            });
        });
    });

    // ==========================================
    // useCode
    // ==========================================
    describe('useCode', () => {
        const validInvite = {
            inviteCodeId: 'ic-001',
            code: 'ABCDE12',
            groupId,
            tripId,
            targetRole: 'crew',
            maxUses: 5,
            currentUses: 2,
            isActive: true,
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        };

        const mockGroup = {
            groupId,
            groupName: 'Tokyo Trip',
            maxMembers: 50,
        };

        const joiningUserId = 'user-joiner-001';

        function setupSuccessfulUseCode() {
            // Sequential findOne calls within queryRunner.manager:
            // 1. InviteCode lookup
            // 2. Trip lookup
            // 3. GroupMember existing check (null = not a member)
            // 4. Group lookup (capacity check)
            // 5. GroupMember guardian overlap check (only for guardian role, not for 'crew')
            mockQueryRunner.manager.findOne
                .mockResolvedValueOnce(validInvite)          // InviteCode
                .mockResolvedValueOnce(mockTrip)             // Trip
                .mockResolvedValueOnce(null)                 // no existing membership
                .mockResolvedValueOnce(mockGroup);           // Group

            mockQueryRunner.manager.count.mockResolvedValue(5); // current member count
        }

        it('should commit transaction on success', async () => {
            setupSuccessfulUseCode();

            const result = await service.useCode('ABCDE12', joiningUserId);

            expect(mockQueryRunner.connect).toHaveBeenCalled();
            expect(mockQueryRunner.startTransaction).toHaveBeenCalled();
            expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
            expect(mockQueryRunner.release).toHaveBeenCalled();
            expect(mockQueryRunner.rollbackTransaction).not.toHaveBeenCalled();

            expect(result.group.group_id).toBe(groupId);
            expect(result.member.member_role).toBe('crew');
            expect(result.target_role).toBe('crew');
            expect(result.trip_id).toBe(tripId);
        });

        it('should rollback on ERR_ALREADY_MEMBER', async () => {
            mockQueryRunner.manager.findOne
                .mockResolvedValueOnce(validInvite)          // InviteCode
                .mockResolvedValueOnce(mockTrip)             // Trip
                .mockResolvedValueOnce({ memberId: 'existing-001', status: 'active' }); // already a member

            await expect(service.useCode('ABCDE12', joiningUserId)).rejects.toThrow(BadRequestException);
            await expect(
                // Need to re-setup because the first call consumed the mocks
                (async () => {
                    mockQueryRunner.manager.findOne
                        .mockResolvedValueOnce(validInvite)
                        .mockResolvedValueOnce(mockTrip)
                        .mockResolvedValueOnce({ memberId: 'existing-001', status: 'active' });
                    return service.useCode('ABCDE12', joiningUserId);
                })(),
            ).rejects.toThrow('ERR_ALREADY_MEMBER');

            expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
            expect(mockQueryRunner.release).toHaveBeenCalled();
        });

        it('should increment currentUses within transaction', async () => {
            setupSuccessfulUseCode();

            await service.useCode('ABCDE12', joiningUserId);

            expect(mockQueryRunner.query).toHaveBeenCalledWith(
                `UPDATE tb_invite_code SET current_uses = current_uses + 1 WHERE invite_code_id = $1`,
                [validInvite.inviteCodeId],
            );
        });
    });

    // ==========================================
    // listCodes
    // ==========================================
    describe('listCodes', () => {
        const mockCodes = [
            {
                inviteCodeId: 'ic-001',
                code: 'ABC1234',
                targetRole: 'crew',
                maxUses: 1,
                currentUses: 0,
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                isActive: true,
                modelType: 'direct',
                createdBy: 'user-cc-001',
                createdAt: new Date(),
                groupId,
            },
            {
                inviteCodeId: 'ic-002',
                code: 'DEF5678',
                targetRole: 'crew_chief',
                maxUses: 3,
                currentUses: 1,
                expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000),
                isActive: true,
                modelType: 'direct',
                createdBy: userId,
                createdAt: new Date(),
                groupId,
            },
        ];

        it('should filter by createdBy for crew_chief role', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);
            mockInviteCodeRepo.find.mockResolvedValue([mockCodes[0]]);

            await service.listCodes(tripId, mockCrewChiefMember.userId);

            expect(mockInviteCodeRepo.find).toHaveBeenCalledWith({
                where: { groupId, isActive: true, createdBy: mockCrewChiefMember.userId },
                order: { createdAt: 'DESC' },
            });
        });

        it('should return all codes for captain', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCaptainMember);
            mockInviteCodeRepo.find.mockResolvedValue(mockCodes);

            const result = await service.listCodes(tripId, userId);

            expect(mockInviteCodeRepo.find).toHaveBeenCalledWith({
                where: { groupId, isActive: true },
                order: { createdAt: 'DESC' },
            });
            expect(result.length).toBe(2);
            expect(result[0]).toHaveProperty('invite_code_id');
            expect(result[0]).toHaveProperty('code');
            expect(result[0]).toHaveProperty('is_expired');
        });
    });

    // ==========================================
    // deactivateCode
    // ==========================================
    describe('deactivateCode', () => {
        const activeInvite = {
            inviteCodeId: 'ic-001',
            groupId,
            code: 'ABCDE12',
            isActive: true,
            createdBy: 'user-cc-001', // created by crew_chief
        };

        it('should reject crew_chief deactivating other\'s codes', async () => {
            mockTripRepo.findOne.mockResolvedValue(mockTrip);
            mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);
            // Code was created by someone else
            mockInviteCodeRepo.findOne.mockResolvedValue({
                ...activeInvite,
                createdBy: 'user-other-001',
            });

            await expect(
                service.deactivateCode(tripId, 'ic-001', mockCrewChiefMember.userId),
            ).rejects.toThrow(ForbiddenException);
            await expect(
                (async () => {
                    mockTripRepo.findOne.mockResolvedValue(mockTrip);
                    mockMemberRepo.findOne.mockResolvedValue(mockCrewChiefMember);
                    mockInviteCodeRepo.findOne.mockResolvedValue({
                        ...activeInvite,
                        createdBy: 'user-other-001',
                    });
                    return service.deactivateCode(tripId, 'ic-001', mockCrewChiefMember.userId);
                })(),
            ).rejects.toThrow('Crew chief can only deactivate own codes');
        });
    });

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

            const result = await service.createCode(tripId, mockCrewChiefMember.userId, {
                target_role: 'crew',
                max_uses: 10,
                expires_hours: 168,
            });

            expect(result.max_uses).toBe(1);
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
                .mockResolvedValueOnce(crewChiefInvite)
                .mockResolvedValueOnce(mockTrip)
                .mockResolvedValueOnce(null)
                .mockResolvedValueOnce({ groupId, groupName: 'Test', maxMembers: 50 });

            mockQueryRunner.manager.count
                .mockResolvedValueOnce(10)
                .mockResolvedValueOnce(5);

            await expect(service.useCode('CCQUOTA', 'user-new-001')).rejects.toThrow('ERR_ROLE_UNAVAILABLE');
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
});
