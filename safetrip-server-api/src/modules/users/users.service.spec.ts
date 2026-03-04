import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { NotFoundException } from '@nestjs/common';

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

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                UsersService,
                { provide: getRepositoryToken(User), useValue: mockUserRepo },
                { provide: getRepositoryToken(FcmToken), useValue: mockFcmRepo },
                { provide: getRepositoryToken(Guardian), useValue: mockGuardianRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
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
    });
});
