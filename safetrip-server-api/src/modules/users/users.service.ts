import { Injectable, NotFoundException, InternalServerErrorException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, Not } from 'typeorm';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';

@Injectable()
export class UsersService {
    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(FcmToken) private fcmRepo: Repository<FcmToken>,
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
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

    private async formatUserResponse(user: User) {
        const userRole = await this.getUserRole(user.userId);
        let dobStr = null;
        if (user.dateOfBirth) {
            const dob = user.dateOfBirth instanceof Date ? user.dateOfBirth : new Date(user.dateOfBirth);
            dobStr = dob.toISOString().split('T')[0];
        }
        return {
            user_id: user.userId,
            phone_number: user.phoneNumber,
            phone_country_code: user.phoneCountryCode,
            display_name: user.displayName,
            profile_image_url: user.profileImageUrl,
            date_of_birth: dobStr,
            location_sharing_mode: user.locationSharingMode,
            last_verification_at: user.lastVerificationAt,
            created_at: user.createdAt,
            last_active_at: user.lastActiveAt,
            user_role: userRole,
        };
    }

    async registerTestUser(data: { user_id: string; display_name?: string; phone_number?: string; phone_country_code?: string }) {
        const uid = data.user_id;
        let displayName = data.display_name;
        if (!displayName) {
            displayName = `User_${uid.substring(0, 5)}`;
        }

        let phoneNumber = data.phone_number;
        if (!phoneNumber) {
            phoneNumber = `+8210${Math.floor(10000000 + Math.random() * 90000000)}`;
        }

        const phoneCountryCode = data.phone_country_code || '+82';

        let user = await this.userRepo.findOne({ where: { userId: uid } });
        if (user) {
            await this.userRepo.update(uid, {
                displayName,
                phoneNumber,
                phoneCountryCode,
                lastVerificationAt: new Date(),
                lastActiveAt: new Date()
            });
        } else {
            user = this.userRepo.create({
                userId: uid,
                displayName,
                phoneNumber,
                phoneCountryCode,
                lastVerificationAt: new Date(),
                lastActiveAt: new Date()
            });
            await this.userRepo.save(user);
        }

        const saved = await this.userRepo.findOne({ where: { userId: uid } });
        return await this.formatUserResponse(saved!);
    }

    async findByPhone(phoneNumber: string, countryCode?: string) {
        const user = await this.userRepo.findOne({
            where: { phoneNumber }
        });

        if (!user) {
            throw new NotFoundException('해당 전화번호 사용자 없음');
        }

        return await this.formatUserResponse(user);
    }

    async searchUsers(query: string, excludeUserId: string) {
        const users = await this.userRepo.createQueryBuilder('user')
            .where('user.userId != :excludeUserId', { excludeUserId })
            .andWhere('(user.displayName ILIKE :query OR user.phoneNumber ILIKE :query)', { query: `%${query}%` })
            .limit(20)
            .getMany();

        return users.map(user => ({
            user_id: user.userId,
            display_name: user.displayName,
            phone_number: user.phoneNumber,
            phone_country_code: user.phoneCountryCode,
            profile_image_url: user.profileImageUrl
        }));
    }

    async getProfile(userId: string) {
        const user = await this.userRepo.findOne({ where: { userId, ...(false ? { isActive: true } : {}) } }); // soft-deleted logic check needed if isActive exists
        if (!user) throw new NotFoundException('User not found');
        return await this.formatUserResponse(user);
    }

    async updateProfile(userId: string, data: any) {
        // Find first
        const user = await <any>this.userRepo.findOne({ where: { userId } });
        if (!user) throw new NotFoundException('User not found');

        await this.userRepo.update(userId, { ...data, updatedAt: new Date() });
        const updated = await this.userRepo.findOne({ where: { userId } });
        return await this.formatUserResponse(updated!);
    }

    async updateLocationSharingMode(userId: string, mode: string) {
        await this.userRepo.update(userId, { locationSharingMode: mode });
        return this.getProfile(userId);
    }

    async registerDevice(userId: string, data: { installId: string; deviceModel?: string; osType?: string; osVersion?: string; appVersion?: string }) {
        await this.userRepo.update(userId, { installId: data.installId, lastActiveAt: new Date() });
        return null;
    }

    async registerOrUpdateFcmToken(userId: string, data: { device_token: string; platform: string; device_id?: string; device_model?: string; os_version?: string; app_version?: string }) {
        // check if user exists
        const user = await this.userRepo.findOne({ where: { userId } });
        if (!user) {
            throw new NotFoundException(`User not found: ${userId}`);
        }

        let fcmToken = await this.fcmRepo.findOne({
            where: {
                userId,
                token: data.device_token,
                deviceType: data.platform
            }
        });

        let isNew = false;

        if (fcmToken) {
            await this.fcmRepo.update(fcmToken.tokenId, {
                isActive: true,
                lastUsedAt: new Date()
            });
        } else {
            // New token
            fcmToken = this.fcmRepo.create({
                userId,
                token: data.device_token,
                deviceType: data.platform,
                isActive: true,
                lastUsedAt: new Date()
            });
            await this.fcmRepo.save(fcmToken);
            isNew = true;
        }

        return {
            token_id: fcmToken.tokenId,
            is_new: isNew,
            last_used_at: fcmToken.lastUsedAt || new Date()
        };
    }

    async deactivateFcmToken(userId: string, tokenId: string) {
        const result = await this.fcmRepo.update({ userId, tokenId }, { isActive: false });
        // Assume success even if not found for idempotence
        return true;
    }

    async agreeToTerms(userId: string, termsVersion: string) {
        const user = await this.userRepo.findOne({ where: { userId } });
        if (!user) {
            throw new InternalServerErrorException('User not found');
        }

        await this.userRepo.update(userId, {
            termsAgreedAt: new Date(),
            termsVersion: termsVersion,
            updatedAt: new Date()
        });

        const updated = await this.userRepo.findOne({ where: { userId } });
        return updated!;
    }
}
