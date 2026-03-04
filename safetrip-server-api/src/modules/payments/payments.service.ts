import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, IsNull } from 'typeorm';
import { Payment, Subscription } from '../../entities/payment.entity';

@Injectable()
export class PaymentsService {
    constructor(
        @InjectRepository(Payment) private paymentRepo: Repository<Payment>,
        @InjectRepository(Subscription) private subRepo: Repository<Subscription>,
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
    async verifyAndComplete(userId: string, paymentId: string, externalPaymentId: string, receiptData: string) {
        const payment = await this.paymentRepo.findOne({ where: { paymentId, userId } });
        if (!payment) throw new NotFoundException('Payment not found');

        // Mock Store Receipt Verification
        this.mockVerifyStoreReceipt(receiptData);

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

    private mockVerifyStoreReceipt(receipt: string) {
        if (receipt.includes('invalid')) {
            throw new BadRequestException('Invalid receipt from store');
        }
        // Mock success
        return true;
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
            return { maxGuardians: 2, currentPlan: 'paid_slot' };
        }

        // 3. 기본 무료 (1명)
        return { maxGuardians: 1, currentPlan: 'free' };
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
}
