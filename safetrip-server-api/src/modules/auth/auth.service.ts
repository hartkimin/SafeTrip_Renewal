import { Injectable, Inject, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { User } from '../../entities/user.entity';

@Injectable()
export class AuthService {
    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
    ) { }

    /**
     * POST /auth/firebase-verify
     */
    async verifyFirebaseToken(data: { id_token: string; phone_country_code?: string; install_id?: string; is_test_device?: boolean; test_phone_number?: string }) {
        try {
            const decodedToken = await this.firebaseApp.auth().verifyIdToken(data.id_token);
            const uid = decodedToken.uid;

            let phoneNumber = decodedToken.phone_number;

            if (!phoneNumber) {
                if (data.is_test_device && data.test_phone_number && /^\+82109999000[1-9]$/.test(data.test_phone_number)) {
                    phoneNumber = data.test_phone_number;
                } else {
                    throw new BadRequestException('Phone number not found in token');
                }
            }

            const countryCode = data.phone_country_code || '+82';

            let user = await this.userRepo.findOne({ where: { userId: uid } });
            let isNewUser = false;

            if (!user) {
                // Check if user exists by phone
                user = await this.userRepo.findOne({ where: { phoneNumber } });

                if (user) {
                    // 기기 변경 등으로 UID 변경 시
                    await this.userRepo.update({ phoneNumber }, { userId: uid, installId: data.install_id || null, lastVerificationAt: new Date(), lastActiveAt: new Date() });
                    user.userId = uid;
                    user.installId = data.install_id || null;
                    user.lastVerificationAt = new Date();
                    user.lastActiveAt = new Date();
                } else {
                    // 신규 사용자
                    user = this.userRepo.create({
                        userId: uid,
                        phoneNumber,
                        phoneCountryCode: countryCode,
                        displayName: '',
                        installId: data.install_id || null,
                        lastVerificationAt: new Date(),
                        lastActiveAt: new Date()
                    });
                    await this.userRepo.save(user);
                    isNewUser = true;
                }
            } else {
                // 기존 사용자
                await this.userRepo.update(uid, {
                    installId: data.install_id || null,
                    lastVerificationAt: new Date(),
                    lastActiveAt: new Date()
                });
                user.installId = data.install_id || null;
                user.lastVerificationAt = new Date();
                user.lastActiveAt = new Date();
            }

            return {
                success: true,
                data: {
                    user_id: user.userId,
                    phone_number: user.phoneNumber,
                    phone_country_code: user.phoneCountryCode,
                    display_name: user.displayName,
                    profile_image_url: user.profileImageUrl,
                    install_id: user.installId,
                    location_sharing_mode: user.locationSharingMode,
                    last_verification_at: user.lastVerificationAt,
                    created_at: user.createdAt,
                    last_active_at: user.lastActiveAt,
                    user_role: 'crew', // TODO: guardian check if exists
                    is_new_user: isNewUser
                }
            };
        } catch (error) {
            if (error instanceof BadRequestException) throw error;
            throw new UnauthorizedException('Invalid or expired token');
        }
    }

    /**
     * POST /auth/verify — Firebase 토큰 검증 후 사용자 정보 반환
     */
    async verifyAndGetUser(uid: string) {
        const user = await this.userRepo.findOne({ where: { userId: uid } });
        if (!user) {
            throw new UnauthorizedException('User not found');
        }
        return user;
    }

    /**
     * POST /auth/register — 온보딩 완료 처리
     */
    async completeOnboarding(
        uid: string,
        data: {
            displayName?: string;
            dateOfBirth?: string;
            profileImageUrl?: string;
        },
    ) {
        await this.userRepo.update(uid, {
            displayName: data.displayName || undefined,
            dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : undefined,
            profileImageUrl: data.profileImageUrl || undefined,
            isOnboardingComplete: true,
            onboardingStep: 'completed',
        });
        return this.userRepo.findOne({ where: { userId: uid } });
    }

    /**
     * POST /auth/consent — 동의 기록
     */
    async recordConsent(
        uid: string,
        consentType: string,
        consentVersion: string,
        isGranted: boolean,
    ) {
        return null;
    }

    /**
     * DELETE /auth/account — 계정 삭제 요청 (7일 유예)
     */
    async requestDeletion(uid: string) {
        await this.userRepo.update(uid, {
            deletionRequestedAt: new Date(),
            isActive: false,
        });
        return { message: '계정 삭제가 요청되었습니다. 7일 후 최종 삭제됩니다.' };
    }

    /**
     * POST /auth/cancel-deletion — 삭제 취소
     */
    async cancelDeletion(uid: string) {
        await this.userRepo.update(uid, {
            deletionRequestedAt: null,
            isActive: true,
        });
        return { message: '계정 삭제가 취소되었습니다.' };
    }
}
