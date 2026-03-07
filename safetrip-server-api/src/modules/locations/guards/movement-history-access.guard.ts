import {
    Injectable,
    CanActivate,
    ExecutionContext,
    ForbiddenException,
    Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GroupMember } from '../../../entities/group-member.entity';
import { GuardianLink } from '../../../entities/guardian.entity';

/**
 * 이동 이력 접근 제어 가드 (DB 설계 v3.6 SS7)
 *
 * Access Matrix:
 *   1. Self (requestUserId === targetUserId)  -> ALWAYS ALLOW (M1 투명성 원칙)
 *   2. Captain                                -> 여행 내 모든 멤버 조회 가능
 *   3. Crew Chief                             -> 동일 groupId 내 멤버만 조회 가능
 *   4. Crew                                   -> 본인만 조회 가능 (규칙 1로 처리, 나머지 거부)
 *   5. Guardian                               -> accepted + canViewLocation인 연결 멤버만 조회 가능
 *
 * 사용:
 *   @UseGuards(MovementHistoryAccessGuard)
 *   async handler(@Req() req) { req.movementHistoryAccess }
 */
export interface MovementHistoryAccess {
    role: 'self' | 'captain' | 'crew_chief' | 'crew' | 'guardian';
    isGuardian: boolean;
    isPaid?: boolean;
    linkId?: string;
}

@Injectable()
export class MovementHistoryAccessGuard implements CanActivate {
    private readonly logger = new Logger(MovementHistoryAccessGuard.name);

    constructor(
        @InjectRepository(GroupMember)
        private readonly groupMemberRepo: Repository<GroupMember>,
        @InjectRepository(GuardianLink)
        private readonly guardianLinkRepo: Repository<GuardianLink>,
    ) {}

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();

        const requestUserId: string | undefined = request.userId;
        const tripId: string | undefined = request.params.tripId;
        const targetUserId: string | undefined =
            request.params.targetUserId || request.params.userId;

        if (!requestUserId) {
            throw new ForbiddenException('인증 정보가 없습니다.');
        }

        if (!targetUserId) {
            throw new ForbiddenException('대상 사용자 정보가 필요합니다.');
        }

        // -----------------------------------------------------------
        // Rule 1: Self access -> ALWAYS ALLOW (M1 transparency)
        // -----------------------------------------------------------
        if (requestUserId === targetUserId) {
            this.setAccess(request, { role: 'self', isGuardian: false });
            return true;
        }

        // For non-self access, tripId is required to determine role
        if (!tripId) {
            throw new ForbiddenException(
                '다른 사용자의 이동 이력을 조회하려면 여행 ID가 필요합니다.',
            );
        }

        // -----------------------------------------------------------
        // Look up the requester's membership in this trip
        // -----------------------------------------------------------
        const requesterMember = await this.groupMemberRepo.findOne({
            where: { userId: requestUserId, tripId, status: 'active' },
        });

        // -----------------------------------------------------------
        // Rule 5: Guardian access (no group membership required)
        // -----------------------------------------------------------
        if (!requesterMember || requesterMember.memberRole === 'guardian') {
            return this.checkGuardianAccess(request, requestUserId, targetUserId, tripId);
        }

        // -----------------------------------------------------------
        // Rule 2: Captain -> can view ALL members in the trip
        // -----------------------------------------------------------
        if (requesterMember.memberRole === 'captain') {
            // Verify target actually belongs to this trip
            const targetMember = await this.groupMemberRepo.findOne({
                where: { userId: targetUserId, tripId, status: 'active' },
            });

            if (!targetMember) {
                throw new ForbiddenException(
                    '해당 사용자는 이 여행의 멤버가 아닙니다.',
                );
            }

            this.setAccess(request, {
                role: 'captain',
                isGuardian: false,
            });
            return true;
        }

        // -----------------------------------------------------------
        // Rule 3: Crew Chief -> can view members in SAME group only
        // -----------------------------------------------------------
        if (requesterMember.memberRole === 'crew_chief') {
            const targetMember = await this.groupMemberRepo.findOne({
                where: {
                    userId: targetUserId,
                    tripId,
                    groupId: requesterMember.groupId,
                    status: 'active',
                },
            });

            if (!targetMember) {
                throw new ForbiddenException(
                    '같은 그룹에 속하지 않은 멤버의 이동 이력은 조회할 수 없습니다.',
                );
            }

            this.setAccess(request, {
                role: 'crew_chief',
                isGuardian: false,
            });
            return true;
        }

        // -----------------------------------------------------------
        // Rule 4: Crew -> self only (self already handled above, deny all others)
        // -----------------------------------------------------------
        throw new ForbiddenException(
            '일반 멤버(crew)는 본인의 이동 이력만 조회할 수 있습니다.',
        );
    }

    /**
     * Guardian access check (Rule 5).
     * Guardian must have an accepted link with canViewLocation=true
     * for the specific target member.
     */
    private async checkGuardianAccess(
        request: any,
        requestUserId: string,
        targetUserId: string,
        tripId: string,
    ): Promise<boolean> {
        const guardianLink = await this.guardianLinkRepo.findOne({
            where: {
                guardianId: requestUserId,
                memberId: targetUserId,
                tripId,
                status: 'accepted',
            },
        });

        if (!guardianLink) {
            this.logger.warn(
                `Guardian access denied: no accepted link for guardian=${requestUserId} -> member=${targetUserId} in trip=${tripId}`,
            );
            throw new ForbiddenException(
                '해당 멤버에 대한 가디언 연결이 없거나 승인되지 않았습니다.',
            );
        }

        if (!guardianLink.canViewLocation) {
            this.logger.warn(
                `Guardian access denied: canViewLocation=false for link=${guardianLink.linkId}`,
            );
            throw new ForbiddenException(
                '해당 멤버의 위치 조회 권한이 비활성화되어 있습니다.',
            );
        }

        this.setAccess(request, {
            role: 'guardian',
            isGuardian: true,
            isPaid: guardianLink.isPaid,
            linkId: guardianLink.linkId,
        });
        return true;
    }

    /**
     * Attach access metadata to the request for downstream controllers/services.
     */
    private setAccess(request: any, access: MovementHistoryAccess): void {
        request.movementHistoryAccess = access;
    }
}
