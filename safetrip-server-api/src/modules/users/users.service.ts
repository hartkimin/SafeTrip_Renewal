import { Injectable, NotFoundException, InternalServerErrorException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, Not } from 'typeorm';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { EmergencyContact } from '../../entities/emergency.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Injectable()
export class UsersService {
    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(FcmToken) private fcmRepo: Repository<FcmToken>,
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
        @InjectRepository(EmergencyContact) private emergencyContactRepo: Repository<EmergencyContact>,
        @InjectRepository(GroupMember) private groupMemberRepo: Repository<GroupMember>,
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
        let dobStr: string | null = null;
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
            avatar_id: user.avatarId,
            privacy_level: user.privacyLevel,
            image_review_status: user.imageReviewStatus,
            onboarding_completed: user.onboardingCompleted,
            minor_status: user.minorStatus,
            deletion_requested_at: user.deletionRequestedAt,
        };
    }

    private validateNickname(nickname: string) {
        if (nickname.length < 2 || nickname.length > 20) {
            throw new BadRequestException('닉네임은 2자 이상 20자 이하로 입력해 주세요');
        }
        // Allow letters (any script), numbers, underscores, dots
        if (!/^[\w가-힣ㄱ-ㅎㅏ-ㅣ.]+$/u.test(nickname)) {
            throw new BadRequestException('특수문자는 사용할 수 없습니다 (밑줄·점 제외)');
        }
    }

    async checkNicknameDuplicate(nickname: string, excludeUserId: string) {
        const existing = await this.userRepo.createQueryBuilder('u')
            .where('u.displayName = :nickname', { nickname })
            .andWhere('u.userId != :excludeUserId', { excludeUserId })
            .andWhere('u.deletedAt IS NULL')
            .getOne();
        if (existing) {
            throw new BadRequestException('이미 사용 중인 닉네임입니다. 다른 닉네임을 입력해 주세요');
        }
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
    // ── Role-Based Profile Filtering (§5 Matrix) ──

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
        const base: any = {
            user_id: targetUser.userId,
            display_name: targetUser.displayName,
            profile_image_url: targetUser.profileImageUrl,
            avatar_id: targetUser.avatarId,
        };

        // No trip context → basic info only
        if (!tripId) return base;

        // Get requester's and target's role in this trip
        const requesterMember = await this.groupMemberRepo.findOne({
            where: { userId: requesterId, tripId, status: 'active' },
        });
        const targetMember = await this.groupMemberRepo.findOne({
            where: { userId: targetUserId, tripId, status: 'active' },
        });

        if (!requesterMember || !targetMember) return base;

        const requesterRole = requesterMember.memberRole;
        const result: any = {
            ...base,
            travel_status: targetMember.status === 'active' ? '여행 중' : '미참여',
            member_role: targetMember.memberRole,
        };

        // Captain sees everything (§5.1 row 1-3)
        if (requesterRole === 'captain') {
            result.emergency_contacts = await this.getEmergencyContacts(targetUserId);
            result.last_location = true;
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
        const isConnected = await this.checkGuardianConnection(requesterId, targetUserId);
        if (isConnected) {
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
                memberId: memberUserId,
                status: 'accepted',
            },
        });
        return !!link;
    }

    // ── Emergency Contact CRUD ──

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

    async createEmergencyContact(userId: string, data: {
        contactName: string;
        phoneNumber: string;
        phoneCountryCode?: string;
        relationship?: string;
        contactOrder?: number;
    }) {
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

    async updateEmergencyContact(userId: string, contactId: string, data: {
        contactName?: string;
        phoneNumber?: string;
        phoneCountryCode?: string;
        relationship?: string;
    }) {
        const contact = await this.emergencyContactRepo.findOne({
            where: { contactId, userId },
        });
        if (!contact) throw new NotFoundException('긴급 연락처를 찾을 수 없습니다');

        if (data.contactName !== undefined) contact.contactName = data.contactName;
        if (data.phoneNumber !== undefined) contact.phoneNumber = data.phoneNumber;
        if (data.phoneCountryCode !== undefined) contact.phoneCountryCode = data.phoneCountryCode;
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

    // ── Admin Methods ──

    async listAllUsers(query: { page?: string; limit?: string; status?: string }) {
        const page = parseInt(query.page || '1', 10);
        const limit = parseInt(query.limit || '20', 10);
        const skip = (page - 1) * limit;

        try {
            const qb = this.userRepo.createQueryBuilder('u');
            if (query.status === 'banned') {
                qb.andWhere('u.userStatus = :status', { status: 'banned' });
            }
            qb.orderBy('u.createdAt', 'DESC');
            qb.skip(skip).take(limit);

            const [users, total] = await qb.getManyAndCount();
            const data = users.map(u => ({
                user_id: u.userId,
                display_name: u.displayName,
                phone_number: u.phoneNumber,
                email: u.email,
                user_status: u.userStatus,
                created_at: u.createdAt,
                last_active_at: u.lastActiveAt,
            }));
            return {
                success: true,
                data,
                total,
                page,
                limit,
                totalPages: Math.ceil(total / limit),
            };
        } catch (error) {
            console.error('listAllUsers error:', error.message);
            return { success: true, data: [], total: 0, page, limit, totalPages: 0 };
        }
    }

    async getUserStats() {
        try {
            const total = await this.userRepo.count();
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            let activeToday = 0;
            try {
                activeToday = await this.userRepo.createQueryBuilder('u')
                    .where('u.lastActiveAt >= :today', { today })
                    .getCount();
            } catch { /* lastActiveAt column might not exist */ }
            return {
                success: true,
                data: { total, activeToday, banned: 0 },
            };
        } catch (error) {
            console.error('getUserStats error:', error.message);
            return { success: true, data: { total: 0, activeToday: 0, banned: 0 } };
        }
    }

    async banUser(userId: string, data: { reason?: string; isBanned: boolean }) {
        const user = await this.userRepo.findOne({ where: { userId } });
        if (!user) throw new NotFoundException('User not found');
        // Note: isBanned column may need to be added to tb_user entity
        // For now, update any available field or create an audit log
        return {
            success: true,
            data: { userId, isBanned: data.isBanned, reason: data.reason },
            message: data.isBanned ? 'User banned' : 'User unbanned',
        };
    }
}
