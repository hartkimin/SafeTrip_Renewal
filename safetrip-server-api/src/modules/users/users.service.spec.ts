import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { EmergencyContact } from '../../entities/emergency.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { NotFoundException, BadRequestException } from '@nestjs/common';

describe('UsersService', () => {
    let service: UsersService;

    const mockUserRepo = {
        findOne: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        update: jest.fn(),
        createQueryBuilder: jest.fn(),
    };

    const mockFcmRepo = {
        findOne: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        update: jest.fn(),
    };

    const mockGuardianRepo = {
        findOne: jest.fn(),
    };

    const mockGuardianLinkRepo = {
        findOne: jest.fn(),
    };

    const mockEmergencyContactRepo = {
        find: jest.fn(),
        findOne: jest.fn(),
        count: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        delete: jest.fn(),
    };

    const mockGroupMemberRepo = {
        findOne: jest.fn(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                UsersService,
                { provide: getRepositoryToken(User), useValue: mockUserRepo },
                { provide: getRepositoryToken(FcmToken), useValue: mockFcmRepo },
                { provide: getRepositoryToken(Guardian), useValue: mockGuardianRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
                { provide: getRepositoryToken(EmergencyContact), useValue: mockEmergencyContactRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockGroupMemberRepo },
            ],
        }).compile();

        service = module.get<UsersService>(UsersService);

        // Reset mocks before each test
        jest.clearAllMocks();
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    describe('findByPhone', () => {
        it('should return formatted user when found', async () => {
            const mockDate = new Date();
            const mockUser = {
                userId: 'user123',
                phoneNumber: '+821012345678',
                phoneCountryCode: '+82',
                displayName: 'Test User',
                profileImageUrl: 'http://img.com',
                dateOfBirth: mockDate,
                locationSharingMode: 'always',
                lastVerificationAt: mockDate,
                createdAt: mockDate,
                lastActiveAt: mockDate,
            };

            mockUserRepo.findOne.mockResolvedValue(mockUser);
            mockGuardianRepo.findOne.mockResolvedValue(null);

            const result = await service.findByPhone('+821012345678');

            expect(result.user_id).toBe('user123');
            expect(result.phone_number).toBe('+821012345678');
            expect(result.date_of_birth).toBe(mockDate.toISOString().split('T')[0]);
            expect(mockUserRepo.findOne).toHaveBeenCalledWith({
                where: { phoneNumber: '+821012345678' }
            });
        });

        it('should throw NotFoundException when user not found', async () => {
            mockUserRepo.findOne.mockResolvedValue(null);

            await expect(service.findByPhone('000')).rejects.toThrow(NotFoundException);
            await expect(service.findByPhone('000')).rejects.toThrow('해당 전화번호 사용자 없음');
        });
    });

    describe('getProfile', () => {
        it('should return user profile if user exists', async () => {
            const mockDate = new Date();
            const mockUser = {
                userId: 'user123',
                phoneNumber: '+821012345678',
            };
            mockUserRepo.findOne.mockResolvedValue(mockUser);
            mockGuardianRepo.findOne.mockResolvedValue(null);

            const result = await service.getProfile('user123');
            expect(result.user_id).toBe('user123');
            expect(mockUserRepo.findOne).toHaveBeenCalledWith({
                where: { userId: 'user123' }
            });
        });

        it('should throw NotFoundException if user does not exist', async () => {
            mockUserRepo.findOne.mockResolvedValue(null);
            await expect(service.getProfile('unknown')).rejects.toThrow(NotFoundException);
        });

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
    });

    describe('Nickname validation', () => {
        it('should reject nicknames shorter than 2 chars', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'user1', displayName: 'old' });
            await expect(service.updateProfile('user1', { displayName: 'A' }))
                .rejects.toThrow(BadRequestException);
        });

        it('should reject nicknames longer than 20 chars', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'user1', displayName: 'old' });
            await expect(service.updateProfile('user1', { displayName: 'A'.repeat(21) }))
                .rejects.toThrow(BadRequestException);
        });

        it('should reject nicknames with special characters', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'user1', displayName: 'old' });
            await expect(service.updateProfile('user1', { displayName: 'test@user!' }))
                .rejects.toThrow(BadRequestException);
        });

        it('should allow underscores and dots in nicknames', async () => {
            const mockUser = {
                userId: 'user1', displayName: 'test.user_1',
                phoneNumber: '+821012345678', phoneCountryCode: '+82',
                profileImageUrl: null, dateOfBirth: null,
                locationSharingMode: 'in_trip', avatarId: null,
                privacyLevel: 'standard', imageReviewStatus: 'none',
                onboardingCompleted: true, lastVerificationAt: new Date(),
                createdAt: new Date(), lastActiveAt: new Date(), minorStatus: 'adult',
            };
            mockUserRepo.findOne.mockResolvedValue(mockUser);
            mockUserRepo.update.mockResolvedValue({});
            mockGuardianRepo.findOne.mockResolvedValue(null);

            // Mock createQueryBuilder for duplicate check
            mockUserRepo.createQueryBuilder = jest.fn().mockReturnValue({
                where: jest.fn().mockReturnThis(),
                andWhere: jest.fn().mockReturnThis(),
                getOne: jest.fn().mockResolvedValue(null),
            });

            const result = await service.updateProfile('user1', { displayName: 'test.user_1' });
            expect(result).toHaveProperty('display_name', 'test.user_1');
        });
    });

    describe('Emergency Contact CRUD', () => {
        it('getEmergencyContacts should return contacts for user', async () => {
            const mockContacts = [
                { contactId: 'c1', userId: 'user1', contactName: '엄마', phoneNumber: '+821000001111', phoneCountryCode: '+82', relationship: 'parent', priority: 1 },
            ];
            mockEmergencyContactRepo.find.mockResolvedValue(mockContacts);

            const result = await service.getEmergencyContacts('user1');
            expect(result).toHaveLength(1);
            expect(result[0]).toHaveProperty('contact_name', '엄마');
            expect(result[0]).toHaveProperty('contact_order', 1);
        });

        it('createEmergencyContact should enforce max 2 contacts', async () => {
            mockEmergencyContactRepo.count.mockResolvedValue(2);

            await expect(service.createEmergencyContact('user1', {
                contactName: '새연락처',
                phoneNumber: '+821099998888',
            })).rejects.toThrow(BadRequestException);
        });

        it('deleteEmergencyContact should block for minors with only 1 contact', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'minor1', minorStatus: 'minor' });
            mockEmergencyContactRepo.count.mockResolvedValue(1);

            await expect(service.deleteEmergencyContact('minor1', 'c1'))
                .rejects.toThrow(BadRequestException);
        });

        it('deleteEmergencyContact should allow for adults', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'adult1', minorStatus: 'adult' });
            mockEmergencyContactRepo.delete.mockResolvedValue({ affected: 1 });

            const result = await service.deleteEmergencyContact('adult1', 'c1');
            expect(result).toEqual({ deleted: true });
        });
    });

    describe('Role-based profile filtering', () => {
        const mockTargetUser = {
            userId: 'target-1',
            displayName: 'TargetUser',
            profileImageUrl: null,
            avatarId: 'avatar_airplane',
            deletedAt: null,
            minorStatus: 'adult',
        };

        it('should return basic info only when no trip context', async () => {
            mockUserRepo.findOne.mockResolvedValue(mockTargetUser);

            const result = await service.getFilteredProfile('requester', 'target-1', null);
            expect(result).toHaveProperty('display_name', 'TargetUser');
            expect(result).not.toHaveProperty('emergency_contacts');
            expect(result).not.toHaveProperty('travel_status');
        });

        it('captain should see emergency contacts and location', async () => {
            mockUserRepo.findOne.mockResolvedValue(mockTargetUser);
            mockGroupMemberRepo.findOne
                .mockResolvedValueOnce({ userId: 'captain-1', tripId: 'trip-1', memberRole: 'captain', status: 'active', groupId: 'g1' })
                .mockResolvedValueOnce({ userId: 'target-1', tripId: 'trip-1', memberRole: 'crew', status: 'active', groupId: 'g1' });
            mockEmergencyContactRepo.find.mockResolvedValue([]);

            const result = await service.getFilteredProfile('captain-1', 'target-1', 'trip-1');
            expect(result).toHaveProperty('emergency_contacts');
            expect(result).toHaveProperty('last_location', true);
            expect(result).toHaveProperty('assigned_group', 'g1');
        });

        it('crew should NOT see emergency contacts or location', async () => {
            mockUserRepo.findOne.mockResolvedValue(mockTargetUser);
            mockGroupMemberRepo.findOne
                .mockResolvedValueOnce({ userId: 'crew-1', tripId: 'trip-1', memberRole: 'crew', status: 'active', groupId: 'g1' })
                .mockResolvedValueOnce({ userId: 'target-1', tripId: 'trip-1', memberRole: 'crew', status: 'active', groupId: 'g2' });

            const result = await service.getFilteredProfile('crew-1', 'target-1', 'trip-1');
            expect(result).not.toHaveProperty('emergency_contacts');
            expect(result).not.toHaveProperty('last_location');
            expect(result).toHaveProperty('travel_status', '여행 중');
        });

        it('should return deleted user placeholder', async () => {
            mockUserRepo.findOne.mockResolvedValue({ ...mockTargetUser, deletedAt: new Date() });

            const result = await service.getFilteredProfile('requester', 'target-1', null);
            expect(result).toHaveProperty('display_name', '탈퇴한 사용자');
            expect(result).toHaveProperty('is_deleted', true);
        });
    });
});
