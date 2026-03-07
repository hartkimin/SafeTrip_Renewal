import { Injectable, Inject, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { User, ParentalConsent } from '../../entities/user.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';

@Injectable()
export class AuthService {
    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(ParentalConsent) private consentRepo: Repository<ParentalConsent>,
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
        @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
    ) { }

    /**
     * 사용자가 활성 가디언 링크를 가진 가디언인지 확인
     */
    private async getUserRole(userId: string): Promise<'guardian' | 'crew'> {
        const guardian = await this.guardianRepo.findOne({ where: { userId } });
        if (!guardian) return 'crew';

        const activeLink = await this.guardianLinkRepo.findOne({
            where: { guardianId: guardian.guardianId, status: 'active' },
        });
        return activeLink ? 'guardian' : 'crew';
    }

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

            const userRole = await this.getUserRole(user.userId);

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
                    user_role: userRole,
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
        const dateOfBirth = data.dateOfBirth ? new Date(data.dateOfBirth) : null;
        let minorStatus = 'adult';

        if (dateOfBirth) {
            const today = new Date();
            let age = today.getFullYear() - dateOfBirth.getFullYear();
            const m = today.getMonth() - dateOfBirth.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < dateOfBirth.getDate())) {
                age--;
            }

            if (age < 18) {
                minorStatus = 'minor';
                // 14세 미만은 법정대리인 동의 필수 확인
                if (age < 14) {
                    const consent = await this.consentRepo.findOne({ where: { userId: uid, isVerified: true } });
                    if (!consent) {
                        throw new BadRequestException('Parental consent required for users under 14');
                    }
                }
            }
        }

        await this.userRepo.update(uid, {
            displayName: data.displayName || undefined,
            dateOfBirth: dateOfBirth || undefined,
            profileImageUrl: data.profileImageUrl || undefined,
            minorStatus,
            isOnboardingComplete: true,
            onboardingStep: 'completed',
        });
        return this.userRepo.findOne({ where: { userId: uid } });
    }

    /**
     * POST /auth/minor-consent-otp — 미성년자 보호자 동의 OTP 발송 (Mock)
     */
    async sendMinorConsentOtp(userId: string, phone: string) {
        // 실제 운영 시에는 SMS 발송 API 연동
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        let consent = await this.consentRepo.findOne({ where: { userId } });
        if (!consent) {
            consent = this.consentRepo.create({ userId, parentPhone: phone, consentOtp: otp });
        } else {
            consent.parentPhone = phone;
            consent.consentOtp = otp;
        }
        await this.consentRepo.save(consent);

        console.log(`[Parental Consent OTP for ${userId}]: ${otp}`);
        return { success: true, message: 'OTP sent successfully' };
    }

    /**
     * POST /auth/submit-parental-consent — 법정대리인 동의 제출
     */
    async submitParentalConsent(userId: string, data: {
        parentName: string;
        parentPhone: string;
        relationship: string;
        otp: string;
    }) {
        const consent = await this.consentRepo.findOne({ where: { userId } });
        if (!consent || consent.consentOtp !== data.otp) {
            throw new BadRequestException('Invalid OTP or consent record not found');
        }

        consent.parentName = data.parentName;
        consent.relationship = data.relationship;
        consent.isVerified = true;
        consent.verifiedAt = new Date();
        consent.consentOtp = null; // Clear OTP after use
        await this.consentRepo.save(consent);

        return { success: true, message: 'Parental consent verified' };
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
    async requestDeletion(uid: string, reason?: string) {
        // Check active trip participation (§9.2 Step 1)
        const groupMemberRepo = this.userRepo.manager.getRepository('tb_group_member');
        const activeMember = await groupMemberRepo.findOne({
            where: { userId: uid, status: 'active' },
        });

        if (activeMember) {
            const memberRole = (activeMember as any).memberRole || (activeMember as any).member_role;
            if (memberRole === 'captain') {
                throw new BadRequestException('리더십을 위임하거나 여행을 종료한 후 삭제해 주세요');
            }
            throw new BadRequestException('현재 참여 중인 여행이 있습니다. 여행 종료 또는 탈퇴 후 계정 삭제가 가능합니다');
        }

        const updateData: any = {
            deletionRequestedAt: new Date(),
            isActive: false,
        };
        if (reason) {
            updateData.deletionReason = reason;
        }

        await this.userRepo.update(uid, updateData);
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
