import { Injectable, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AiUsage, User, Subscription, Payment } from '../../entities';
import { PaymentsService } from '../payments/payments.service';

@Injectable()
export class AiService {
    constructor(
        @InjectRepository(AiUsage) private aiUsageRepo: Repository<AiUsage>,
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(Payment) private paymentRepo: Repository<Payment>,
        private paymentsService: PaymentsService,
    ) { }

    /**
     * AI 기능 사용 권한 및 횟수 제한 확인
     */
    async checkAccess(userId: string, feature: 'recommendation' | 'optimization' | 'chat' | 'briefing' | 'intelligence', tripId?: string) {
        const user = await this.userRepo.findOne({ where: { userId }, select: ['minorStatus'] });
        if (!user) throw new ForbiddenException('User not found');

        // §10.2 미성년자 Intelligence AI 차단
        if (feature === 'intelligence' && user.minorStatus === 'minor') {
            throw new ForbiddenException('Intelligence AI is not available for minors.');
        }

        const sub = await this.paymentsService.getActiveSubscription(userId);
        const plan = sub?.planType || 'free';

        // 해당 여행에 대한 개별 구매(Add-on) 확인
        let hasTripAddon = false;
        if (tripId) {
            const addon = await this.paymentRepo.findOne({
                where: {
                    userId,
                    tripId,
                    paymentType: feature === 'optimization' || feature === 'intelligence' ? 'addon_ai_pro' : 'addon_ai_plus',
                    status: 'completed'
                }
            });
            if (addon) hasTripAddon = true;
        }

        // 플랜별 기능 접근 제어
        if (!hasTripAddon && plan === 'free') {
            if (feature === 'optimization' || feature === 'briefing' || feature === 'intelligence') {
                throw new BadRequestException(`Feature '${feature}' requires AI Plus/Pro plan.`);
            }
        }

        // 횟수 제한 체크 (Daily)
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const usage = await this.aiUsageRepo.findOne({
            where: { userId, featureType: feature, usageDate: today }
        });

        const currentCount = usage?.useCount || 0;
        const limit = this.getLimit(plan, feature, hasTripAddon);

        if (limit !== -1 && currentCount >= limit) {
            throw new BadRequestException(`Daily limit reached for '${feature}'. (Limit: ${limit})`);
        }

        return { plan, hasTripAddon, currentCount, limit };
    }

    private getLimit(plan: string, feature: string, hasAddon: boolean): number {
        if (hasAddon || plan === 'guardian_premium') return -1; // Unlimited for Pro/Addon

        if (plan === 'free') {
            if (feature === 'recommendation') return 1;
            if (feature === 'chat') return 5;
            return 0;
        }

        if (plan === 'guardian_basic') { // AI Plus
            if (feature === 'recommendation') return 10;
            if (feature === 'chat') return -1;
            if (feature === 'briefing') return 3;
            return 0;
        }

        return -1;
    }

    /** 사용 횟수 기록 */
    async recordUsage(userId: string, feature: string, tripId?: string) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        let usage = await this.aiUsageRepo.findOne({
            where: { userId, featureType: feature, usageDate: today }
        });

        if (usage) {
            usage.useCount += 1;
            usage.tripId = tripId || usage.tripId;
            await this.aiUsageRepo.save(usage);
        } else {
            usage = this.aiUsageRepo.create({
                userId,
                featureType: feature,
                usageDate: today,
                useCount: 1,
                tripId: tripId || null
            });
            await this.aiUsageRepo.save(usage);
        }
    }

    // ── AI 기능 Mock (실제 구현 시 LLM 연동) ──

    async getRecommendation(userId: string, tripId: string, query: string) {
        await this.checkAccess(userId, 'recommendation', tripId);
        
        // Mock AI Logic
        const result = {
            recommended_places: [
                { name: 'Eiffel Tower', reason: 'Iconic landmark' },
                { name: 'Louvre Museum', reason: 'World-class art' }
            ],
            suggested_time: '10:00 AM'
        };

        await this.recordUsage(userId, 'recommendation', tripId);
        return result;
    }
}
