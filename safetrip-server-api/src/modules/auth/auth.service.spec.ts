import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User, ParentalConsent } from '../../entities/user.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
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

    const mockConsentRepo = {
        findOne: jest.fn(),
        create: jest.fn(),
        save: jest.fn(),
    };

    const mockGuardianRepo = {
        findOne: jest.fn(),
    };

    const mockGuardianLinkRepo = {
        findOne: jest.fn(),
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
                { provide: getRepositoryToken(ParentalConsent), useValue: mockConsentRepo },
                { provide: getRepositoryToken(Guardian), useValue: mockGuardianRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
                { provide: FIREBASE_APP, useValue: mockFirebaseApp },
            ],
        }).compile();

        service = module.get<AuthService>(AuthService);
        jest.clearAllMocks();
    });

    describe('completeOnboarding - Minor Protection', () => {
        it('should fail for < 14 years old without verified consent', async () => {
            const dob = new Date();
            dob.setFullYear(dob.getFullYear() - 10); // 10 years old

            mockConsentRepo.findOne.mockResolvedValue(null);

            const data = {
                displayName: 'Young Minor',
                dateOfBirth: dob.toISOString(),
            };

            await expect(service.completeOnboarding('uid123', data))
                .rejects.toThrow(BadRequestException);
            
            expect(mockConsentRepo.findOne).toHaveBeenCalled();
        });

        it('should succeed for < 14 years old WITH verified consent', async () => {
            const dob = new Date();
            dob.setFullYear(dob.getFullYear() - 10); // 10 years old

            mockConsentRepo.findOne.mockResolvedValue({ isVerified: true });
            mockUserRepo.update.mockResolvedValue({ affected: 1 });
            mockUserRepo.findOne.mockResolvedValue({ userId: 'uid123', minorStatus: 'minor' });

            const data = {
                displayName: 'Verified Minor',
                dateOfBirth: dob.toISOString(),
            };

            const result = await service.completeOnboarding('uid123', data);

            expect(result!.minorStatus).toBe('minor');
            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                minorStatus: 'minor'
            }));
        });

        it('should set status as minor for 14-17 years old without explicit consent check', async () => {
            const dob = new Date();
            dob.setFullYear(dob.getFullYear() - 16); // 16 years old

            mockUserRepo.update.mockResolvedValue({ affected: 1 });
            mockUserRepo.findOne.mockResolvedValue({ userId: 'uid123', minorStatus: 'minor' });

            const data = {
                displayName: 'Older Minor',
                dateOfBirth: dob.toISOString(),
            };

            const result = await service.completeOnboarding('uid123', data);

            expect(result!.minorStatus).toBe('minor');
            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                minorStatus: 'minor'
            }));
        });

        it('should set status as adult for 18+ years old', async () => {
            const dob = new Date();
            dob.setFullYear(dob.getFullYear() - 25); // 25 years old

            mockUserRepo.update.mockResolvedValue({ affected: 1 });
            mockUserRepo.findOne.mockResolvedValue({ userId: 'uid123', minorStatus: 'adult' });

            const data = {
                displayName: 'Adult User',
                dateOfBirth: dob.toISOString(),
            };

            const result = await service.completeOnboarding('uid123', data);

            expect(result!.minorStatus).toBe('adult');
            expect(mockUserRepo.update).toHaveBeenCalledWith('uid123', expect.objectContaining({
                minorStatus: 'adult'
            }));
        });
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
