import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User } from '../../entities/user.entity';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { UnauthorizedException, BadRequestException } from '@nestjs/common';

describe('AuthService', () => {
    let service: AuthService;

    const mockUserRepo = {
        findOne: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
        update: jest.fn(),
    };

    const mockFirebaseApp = {
        auth: jest.fn().mockReturnValue({
            verifyIdToken: jest.fn(),
        }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                AuthService,
                { provide: getRepositoryToken(User), useValue: mockUserRepo },
                { provide: FIREBASE_APP, useValue: mockFirebaseApp },
            ],
        }).compile();

        service = module.get<AuthService>(AuthService);
        jest.clearAllMocks();
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    describe('verifyAndGetUser', () => {
        it('should return user when found by uid', async () => {
            const mockUser = { userId: 'uid123', phoneNumber: '+821012341234' };
            mockUserRepo.findOne.mockResolvedValue(mockUser);

            const result = await service.verifyAndGetUser('uid123');
            expect(result).toEqual(mockUser);
            expect(mockUserRepo.findOne).toHaveBeenCalledWith({ where: { userId: 'uid123' } });
        });

        it('should throw UnauthorizedException when user not found', async () => {
            mockUserRepo.findOne.mockResolvedValue(null);
            await expect(service.verifyAndGetUser('notfound')).rejects.toThrow(UnauthorizedException);
        });
    });

    describe('completeOnboarding', () => {
        it('should update user information and return the updated user', async () => {
            const mockUser = {
                userId: 'uid123',
                displayName: 'New Name',
                isOnboardingComplete: true,
                onboardingStep: 'completed',
            };

            // First update finishes, second findOne returns updated user
            mockUserRepo.update.mockResolvedValue({ affected: 1 });
            mockUserRepo.findOne.mockResolvedValue(mockUser);

            const data = {
                displayName: 'New Name',
                dateOfBirth: '1990-01-01',
                profileImageUrl: 'http://img.url',
            };

            const result = await service.completeOnboarding('uid123', data);

            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                displayName: 'New Name',
                profileImageUrl: 'http://img.url',
                isOnboardingComplete: true,
                onboardingStep: 'completed',
            }));

            // Make sure dateOfBirth was converted properly
            const updateCall = mockUserRepo.update.mock.calls[0][1];
            expect(updateCall.dateOfBirth).toBeInstanceOf(Date);

            expect(result).toEqual(mockUser);
        });
    });

    describe('requestDeletion', () => {
        it('should mark the user as inactive and log deletion requested time', async () => {
            mockUserRepo.update.mockResolvedValue({ affected: 1 });

            const result = await service.requestDeletion('uid123');

            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                isActive: false,
            }));

            expect(result.message).toContain('7일 후 최종 삭제됩니다');
        });
    });

    describe('cancelDeletion', () => {
        it('should mark the user active and remove deletion requested time', async () => {
            mockUserRepo.update.mockResolvedValue({ affected: 1 });

            const result = await service.cancelDeletion('uid123');

            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                deletionRequestedAt: null,
                isActive: true,
            }));

            expect(result.message).toContain('계정 삭제가 취소되었습니다');
        });
    });
});
