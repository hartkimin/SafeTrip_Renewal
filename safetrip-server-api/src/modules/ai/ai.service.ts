import { Injectable, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { AiUsage, User, Subscription, Payment, Trip } from '../../entities';
import { PaymentsService } from '../payments/payments.service';

@Injectable()
export class AiService {
    private readonly logger = new Logger(AiService.name);

    constructor(
        @InjectRepository(AiUsage) private aiUsageRepo: Repository<AiUsage>,
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(Payment) private paymentRepo: Repository<Payment>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private paymentsService: PaymentsService,
        private readonly httpService: HttpService,
    ) { }

    /**
     * AI 기능 사용 권한 및 횟수 제한 확인
     */
    async checkAccess(userId: string, feature: 'recommendation' | 'optimization' | 'chat' | 'briefing' | 'intelligence', tripId?: string) {
        const user = await this.userRepo.findOne({ where: { userId }, select: ['minorStatus', 'dateOfBirth'] });
        if (!user) throw new ForbiddenException('User not found');

        // §26 §10.2~10.4 미성년자 AI 제한
        if (user.minorStatus === 'minor') {
            const age = user.dateOfBirth ? this.calcAge(user.dateOfBirth) : 0;
            // 14세 미만: AI 챗봇 완전 차단
            if (age < 14 && feature === 'chat') {
                throw new ForbiddenException('AI chatbot is not available for users under 14.');
            }
            // 모든 미성년자: Intelligence AI 차단
            if (feature === 'intelligence') {
                throw new ForbiddenException('Intelligence AI is not available for minors.');
            }
        }

        // §26 §9 프라이버시 등급별 AI 제한 (privacy_level is on Trip, not User)
        if (tripId) {
            const trip = await this.tripRepo.findOne({ where: { tripId }, select: ['privacyLevel'] });
            if (trip?.privacyLevel === 'privacy_first') {
                if (feature === 'recommendation' || feature === 'optimization') {
                    throw new ForbiddenException('Location-based AI features are disabled for privacy_first trips.');
                }
            }
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

    // ── AI 기능: 장소 추천 ──
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

    /** §26 §5.1 LLM 전송 전 데이터 마스킹 */
    private maskForLlm(text: string): string {
        // 전화번호 제거
        let masked = text.replace(/(\+?\d{1,4}[\s-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}/g, '[PHONE]');
        // 이메일 제거
        masked = masked.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, '[EMAIL]');
        return masked;
    }

    private calcAge(dateOfBirth: Date): number {
        const now = new Date();
        let age = now.getFullYear() - dateOfBirth.getFullYear();
        const monthDiff = now.getMonth() - dateOfBirth.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dateOfBirth.getDate())) {
            age--;
        }
        return age;
    }

    // ── AI 기능: 안전 가이드 생성 (LLM 연동) ──
    async generateSafetyGuide(userId: string, destination: string, tripId?: string) {
        await this.checkAccess(userId, 'intelligence', tripId);

        try {
            const llmApiUrl = process.env.LLM_API_URL || 'https://api.openai.com/v1/chat/completions';
            const apiKey = process.env.LLM_API_KEY;

            // §26 §5.1 destination 마스킹
            const maskedDestination = this.maskForLlm(destination);

            if (!apiKey) {
                this.logger.warn('LLM_API_KEY is not set. Returning mock safety guide.');
                await this.recordUsage(userId, 'intelligence', tripId);
                return {
                    destination,
                    guide: `[Mock] ${destination} 지역은 현재 소매치기 주의 구역입니다. 가방을 앞으로 매고 다니시길 권장합니다.`,
                    emergency_contacts: ['112', '911'],
                };
            }

            const prompt = `Create a brief travel safety guide for ${maskedDestination}. Include common risks and emergency contacts. Format as JSON with 'guide' and 'emergency_contacts' keys.`;

            const response = await firstValueFrom(this.httpService.post(llmApiUrl, {
                model: 'gpt-3.5-turbo',
                messages: [{ role: 'user', content: prompt }],
                temperature: 0.7
            }, {
                headers: { 'Authorization': `Bearer ${apiKey}` }
            }));

            const content = response.data.choices[0].message.content;
            const parsed = JSON.parse(content);

            await this.recordUsage(userId, 'intelligence', tripId);
            return {
                destination,
                ...parsed
            };

        } catch (error) {
            this.logger.error(`Failed to generate safety guide: ${error.message}`);
            throw new BadRequestException('안전 가이드 생성에 실패했습니다.');
        }
    }

    // ── AI 기능: 비정상 위치 감지 (Anomaly Detection) ──
    async detectAnomaly(userId: string, locationData: { latitude: number; longitude: number; speed: number; timestamp: string }) {
        // AI 기반 또는 휴리스틱 룰 기반 엔진
        let anomalyType: string | null = null;
        let severity = 'low';

        // 룰 1: 비정상적인 속도 (예: 150km/h 초과 시 이상 징후 - KTX 등 열차 제외 로직 필요)
        if (locationData.speed > 41.6) { // 41.6 m/s ≒ 150 km/h
            anomalyType = 'high_speed';
            severity = 'medium';
        }

        // 룰 2: LLM 또는 ML 모델 연동을 통한 패턴 분석 
        // (ex: 보통 걷는 속도인데 GPS 튀는 현상이 잦은 경우)
        // 로컬 모델이나 외부 API를 호출하여 Score 계산...
        const anomalyScore = Math.random(); // 0.0 ~ 1.0 (임시)
        if (anomalyScore > 0.9) {
            anomalyType = 'route_deviation';
            severity = 'high';
        }

        if (anomalyType) {
            this.logger.warn(`Anomaly detected for user ${userId}: ${anomalyType} (Severity: ${severity})`);
        }

        return {
            is_anomalous: anomalyType !== null,
            anomaly_type: anomalyType,
            severity,
            score: anomalyScore
        };
    }
}
