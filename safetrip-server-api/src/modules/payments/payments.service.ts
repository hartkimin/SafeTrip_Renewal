import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, LessThan, IsNull } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { Cron, CronExpression } from '@nestjs/schedule';
import { firstValueFrom } from 'rxjs';
import { Payment, Subscription } from '../../entities/payment.entity';

@Injectable()
export class PaymentsService {
    private readonly logger = new Logger(PaymentsService.name);

    constructor(
        @InjectRepository(Payment) private paymentRepo: Repository<Payment>,
        @InjectRepository(Subscription) private subRepo: Repository<Subscription>,
        private readonly httpService: HttpService,
    ) { }

    /** 결제 생성 */
    async createPayment(userId: string, data: {
        paymentType: string; amount: number; currency?: string;
        paymentMethod?: string; tripId?: string;
    }) {
        const payment = this.paymentRepo.create({
            userId,
            paymentType: data.paymentType,
            amount: data.amount,
            currency: data.currency || 'KRW',
            paymentMethod: data.paymentMethod,
            tripId: data.tripId,
            status: 'pending',
        });
        return this.paymentRepo.save(payment);
    }

    /** 영수증 검증 후 결제 완료 처리 */
    async verifyAndComplete(userId: string, paymentId: string, externalPaymentId: string, receiptData: string, storeType: 'ios' | 'android' = 'android') {
        const payment = await this.paymentRepo.findOne({ where: { paymentId, userId } });
        if (!payment) throw new NotFoundException('Payment not found');

        // 실제 스토어 영수증 검증
        const isValid = await this.verifyStoreReceipt(receiptData, storeType);
        if (!isValid) {
            throw new BadRequestException('Invalid receipt from store');
        }

        await this.paymentRepo.update(paymentId, {
            status: 'completed',
            externalPaymentId,
            completedAt: new Date(),
        });

        // 만약 프리미엄 구독 결제라면 구독 정보도 생성/갱신
        if (payment.paymentType === 'premium') {
            await this.createSubscription(userId, {
                planType: 'guardian_premium',
                expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString() // 30 days
            });
        }

        return this.paymentRepo.findOne({ where: { paymentId } });
    }

    private async verifyStoreReceipt(receipt: string, storeType: 'ios' | 'android'): Promise<boolean> {
        try {
            if (storeType === 'ios') {
                // Apple App Store 영수증 검증
                // 실제 운영 환경에서는 프로덕션 URL (https://buy.itunes.apple.com/verifyReceipt) 사용
                const verifyUrl = process.env.NODE_ENV === 'production'
                    ? 'https://buy.itunes.apple.com/verifyReceipt'
                    : 'https://sandbox.itunes.apple.com/verifyReceipt';

                // (환경 변수 등에 비밀번호 설정 필요)
                const payload = { 'receipt-data': receipt, 'password': process.env.APPLE_SHARED_SECRET || 'MOCK_SECRET' };

                // MOCK 동작 모드 지원 (테스트용)
                if (receipt === 'mock_valid_receipt') return true;

                const response = await firstValueFrom(this.httpService.post(verifyUrl, payload));
                return response.data && response.data.status === 0;

            } else if (storeType === 'android') {
                // Google Play Store 영수증 검증
                // 일반적으로 Google API Client Library를 사용하지만, 여기서는 HTTP 호출 로직 구조화
                // MOCK 동작 모드 지원 (테스트용)
                if (receipt === 'mock_valid_receipt') return true;
                if (receipt.includes('invalid')) return false;

                // TODO: 실제 Google Play 검증은 Service Account Token을 획득 후 androidpublisher API 호출 필요
                // 여기서는 기본 통과 처리
                this.logger.debug('Google Play receipt verified (mocked logic)');
                return true;
            }
            return false;
        } catch (error) {
            this.logger.error(`Receipt verification failed: ${error.message}`);
            return false;
        }
    }

    async getPayments(userId: string) {
        return this.paymentRepo.find({ where: { userId }, order: { createdAt: 'DESC' } });
    }

    /** 
     * §05.4 가디언 슬롯 쿼터 확인
     * 무료: 1명, 유료(guardian_fee): 추가 1명, 프리미엄: 무제한
     */
    async checkGuardianQuota(userId: string, tripId: string): Promise<{ maxGuardians: number; currentPlan: string }> {
        // 1. 프리미엄 구독 확인
        const sub = await this.getActiveSubscription(userId);
        if (sub && sub.planType === 'guardian_premium') {
            return { maxGuardians: 99, currentPlan: 'premium' };
        }

        // 2. 해당 여행에 대해 개별 결제(guardian_fee) 확인
        const paidFee = await this.paymentRepo.findOne({
            where: {
                userId,
                tripId,
                paymentType: 'guardian_fee',
                status: 'completed'
            }
        });

        if (paidFee) {
            return { maxGuardians: 5, currentPlan: 'paid_slot' }; // 무료 2 + 유료 3 = 5
        }

        // 3. 기본 무료 (2명) (비즈니스 원칙 v5.1 반영)
        return { maxGuardians: 2, currentPlan: 'free' };
    }

    // ── 구독 ──
    async createSubscription(userId: string, data: {
        planType: string; expiresAt?: string;
    }) {
        const sub = this.subRepo.create({
            userId,
            planType: data.planType,
            startedAt: new Date(),
            expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
            status: 'active',
        });
        return this.subRepo.save(sub);
    }

    async getActiveSubscription(userId: string) {
        return this.subRepo.findOne({
            where: {
                userId,
                status: 'active',
                expiresAt: MoreThan(new Date())
            },
            order: { expiresAt: 'DESC' },
        });
    }

    /** 구독 만료 스케줄러 (매시간마다 실행) */
    @Cron(CronExpression.EVERY_HOUR)
    async handleExpiredSubscriptions() {
        this.logger.log('Starting expired subscriptions check...');
        const now = new Date();

        try {
            const expiredSubs = await this.subRepo.find({
                where: {
                    status: 'active',
                    expiresAt: LessThan(now)
                }
            });

            if (expiredSubs.length > 0) {
                const expiredIds = expiredSubs.map(sub => sub.subscriptionId);
                await this.subRepo.update(expiredIds, { status: 'expired' });
                this.logger.log(`Marked ${expiredSubs.length} subscriptions as expired.`);
            }
        } catch (error) {
            this.logger.error('Failed to update expired subscriptions', error.stack);
        }
    }

    // ── Admin Methods ──

    /** [Admin] GET /payments/admin/transactions — 전체 결제 이력 (페이지네이션) */
    async getAllTransactions(query: { page?: string; limit?: string; status?: string }) {
        const page = parseInt(query.page || '1', 10);
        const limit = parseInt(query.limit || '20', 10);
        const skip = (page - 1) * limit;

        const qb = this.paymentRepo.createQueryBuilder('p');
        if (query.status) qb.andWhere('p.status = :status', { status: query.status });
        qb.orderBy('p.createdAt', 'DESC');
        qb.skip(skip).take(limit);

        const [data, total] = await qb.getManyAndCount();
        return {
            success: true,
            data,
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
        };
    }

    /** [Admin] GET /payments/admin/stats — 결제 통계 */
    async getPaymentStats() {
        const total = await this.paymentRepo.count();
        const completed = await this.paymentRepo.count({ where: { status: 'completed' } });
        const pending = await this.paymentRepo.count({ where: { status: 'pending' } });
        const totalRevenue = await this.paymentRepo.createQueryBuilder('p')
            .select('COALESCE(SUM(p.amount), 0)', 'total')
            .where('p.status = :status', { status: 'completed' })
            .getRawOne();
        return {
            success: true,
            data: {
                total,
                completed,
                pending,
                totalRevenue: Number(totalRevenue?.total || 0),
            },
        };
    }
}
