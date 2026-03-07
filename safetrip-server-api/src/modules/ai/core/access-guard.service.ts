import { Injectable, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { User } from '../../../entities/user.entity';
import { GroupMember } from '../../../entities/group-member.entity';
import { Trip } from '../../../entities/trip.entity';
import { AiSubscription, AiUsage } from '../../../entities/ai.entity';

/**
 * §3.2 AI 기능명 -- 문서 과금 테이블 기반
 */
export type AiFeature =
    // Safety AI (무료)
    | 'danger_zone_detect' | 'sos_auto_detect' | 'departure_detect' | 'gathering_delay_detect'
    // Convenience AI (무료)
    | 'schedule_autocomplete' | 'travel_time_estimate' | 'packing_list'
    // Convenience AI (AI Plus)
    | 'place_recommend' | 'ai_chatbot' | 'chat_translate' | 'chat_summary'
    // Intelligence AI (AI Plus)
    | 'travel_insight' | 'pattern_analysis' | 'movement_predict'
    // Intelligence AI (AI Pro)
    | 'safety_briefing' | 'schedule_optimize';

type AiCategory = 'safety' | 'convenience' | 'intelligence';
type RequiredPlan = 'free' | 'ai_plus' | 'ai_pro';

interface FeatureDef {
    category: AiCategory;
    requiredPlan: RequiredPlan;
    locationBased: boolean;
    /** Roles that CANNOT access this feature */
    blockedRoles: string[];
    /** Blocked for any minor? */
    minorBlocked: boolean;
    /** Blocked for under14 only? */
    under14Blocked: boolean;
}

/** §3.2 + §8 + §9 매트릭스를 코드 상수로 정의 */
const FEATURE_DEFS: Record<AiFeature, FeatureDef> = {
    // Safety AI -- 전원 무료
    danger_zone_detect:     { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [],           minorBlocked: false, under14Blocked: false },
    sos_auto_detect:        { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [],           minorBlocked: false, under14Blocked: false },
    departure_detect:       { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [],           minorBlocked: false, under14Blocked: false },
    gathering_delay_detect: { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Convenience AI -- 무료
    schedule_autocomplete:  { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    travel_time_estimate:   { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    packing_list:           { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Convenience AI -- AI Plus
    place_recommend:  { category: 'convenience', requiredPlan: 'ai_plus', locationBased: true,  blockedRoles: ['guardian'], minorBlocked: true,  under14Blocked: false },
    ai_chatbot:       { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: true  },
    chat_translate:   { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    chat_summary:     { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Intelligence AI -- AI Plus
    travel_insight:   { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'],                          minorBlocked: false, under14Blocked: false },
    pattern_analysis: { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: true,  blockedRoles: ['guardian', 'crew'],                  minorBlocked: true,  under14Blocked: false },
    movement_predict: { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: true,  blockedRoles: ['guardian', 'crew'],                  minorBlocked: false, under14Blocked: false },

    // Intelligence AI -- AI Pro
    safety_briefing:   { category: 'intelligence', requiredPlan: 'ai_pro', locationBased: false, blockedRoles: ['guardian', 'crew', 'crew_chief'], minorBlocked: false, under14Blocked: false },
    schedule_optimize: { category: 'intelligence', requiredPlan: 'ai_pro', locationBased: false, blockedRoles: ['guardian', 'crew', 'crew_chief'], minorBlocked: false, under14Blocked: false },
};

export interface AccessCheckResult {
    allowed: boolean;
    plan: string;
    feature: AiFeature;
    category: AiCategory;
}

/**
 * §8 역할별 AI 접근 + §9 프라이버시 등급 + §10 미성년자 제한 + §3.2 과금 분기
 *
 * Check order: role -> minor -> privacy -> subscription
 */
@Injectable()
export class AccessGuardService {
    private readonly logger = new Logger(AccessGuardService.name);

    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        @InjectRepository(AiSubscription) private aiSubRepo: Repository<AiSubscription>,
        @InjectRepository(AiUsage) private aiUsageRepo: Repository<AiUsage>,
    ) {}

    async checkAccess(userId: string, feature: AiFeature, tripId?: string): Promise<AccessCheckResult> {
        const def = FEATURE_DEFS[feature];
        if (!def) throw new BadRequestException(`Unknown AI feature: ${feature}`);

        // 1. 사용자 조회
        const user = await this.userRepo.findOne({ where: { userId } });
        if (!user) throw new ForbiddenException('User not found');

        // 2. 역할 확인 (§8)
        if (tripId) {
            const member = await this.memberRepo.findOne({
                where: { userId, tripId, status: 'active' },
            });
            const role = member?.memberRole ?? 'crew';
            if (def.blockedRoles.includes(role)) {
                throw new ForbiddenException(`Role '${role}' cannot access '${feature}'.`);
            }
        }

        // 3. 미성년자 확인 (§10)
        const isMinor = user.minorStatus !== 'adult';
        if (isMinor) {
            const age = user.dateOfBirth ? this.calcAge(user.dateOfBirth) : 0;
            if (def.under14Blocked && age < 14) {
                throw new ForbiddenException(`AI feature '${feature}' is blocked for users under 14.`);
            }
            if (def.minorBlocked) {
                throw new ForbiddenException(`AI feature '${feature}' is blocked for minors.`);
            }
        }

        // 4. 프라이버시 등급 확인 (§9)
        if (tripId && def.locationBased) {
            const trip = await this.tripRepo.findOne({ where: { tripId } });
            if (trip?.privacyLevel === 'privacy_first') {
                throw new ForbiddenException(
                    `Location-based AI feature '${feature}' is disabled for privacy_first trips.`,
                );
            }
        }

        // 5. 구독 확인 (§3.2)
        if (def.requiredPlan !== 'free') {
            const sub = await this.aiSubRepo.findOne({
                where: { userId, status: In(['active', 'grace_period']) },
                order: { createdAt: 'DESC' },
            });

            const planRank: Record<string, number> = { ai_pro: 2, ai_plus: 1 };
            const requiredRank = planRank[def.requiredPlan] ?? 0;
            const userRank = sub ? (planRank[sub.planType] ?? 0) : 0;

            if (userRank < requiredRank) {
                throw new BadRequestException(
                    `Feature '${feature}' requires ${def.requiredPlan} subscription.`,
                );
            }
        }

        return {
            allowed: true,
            plan: def.requiredPlan,
            feature,
            category: def.category,
        };
    }

    private calcAge(dob: Date): number {
        const now = new Date();
        let age = now.getFullYear() - dob.getFullYear();
        const m = now.getMonth() - dob.getMonth();
        if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
        return age;
    }
}
