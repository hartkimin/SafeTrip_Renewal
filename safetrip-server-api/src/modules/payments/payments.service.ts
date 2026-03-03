import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
    async verifyAndComplete(paymentId: string, externalPaymentId: string) {
        const payment = await this.paymentRepo.findOne({ where: { paymentId } });
        if (!payment) throw new NotFoundException('Payment not found');

        // TODO: 실제 앱스토어/플레이스토어 영수증 검증 로직
        await this.paymentRepo.update(paymentId, {
            status: 'completed',
            externalPaymentId,
            completedAt: new Date(),
        });

        return this.paymentRepo.findOne({ where: { paymentId } });
    }

    async getPayments(userId: string) {
        return this.paymentRepo.find({ where: { userId }, order: { createdAt: 'DESC' } });
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
            where: { userId, status: 'active' },
            order: { expiresAt: 'DESC' },
        });
    }
}
