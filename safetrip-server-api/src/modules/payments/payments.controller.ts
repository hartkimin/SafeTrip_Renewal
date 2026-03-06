import { Controller, Get, Post, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaymentsService } from './payments.service';

@ApiTags('Payments')
@ApiBearerAuth('firebase-auth')
@Controller('payments')
export class PaymentsController {
    constructor(private readonly paymentsService: PaymentsService) { }

    @Post('transaction')
    @ApiOperation({ summary: '결제 시작' })
    createPayment(@CurrentUser() userId: string, @Body() body: any) {
        return this.paymentsService.createPayment(userId, body);
    }

    @Post('transaction/:id/verify')
    @ApiOperation({ summary: '영수증 검증 및 결제 완료' })
    verify(@CurrentUser() userId: string, @Param('id') id: string, @Body() body: { externalPaymentId: string, receiptData: string, storeType: 'ios' | 'android' }) {
        return this.paymentsService.verifyAndComplete(userId, id, body.externalPaymentId, body.receiptData, body.storeType);
    }

    @Get('transactions')
    @ApiOperation({ summary: '결제 이력 조회' })
    getPayments(@CurrentUser() userId: string) {
        return this.paymentsService.getPayments(userId);
    }

    @Get('subscription')
    @ApiOperation({ summary: '활성 구독 조회' })
    getSubscription(@CurrentUser() userId: string) {
        return this.paymentsService.getActiveSubscription(userId);
    }

    @Post('subscription')
    @ApiOperation({ summary: '구독 생성' })
    createSubscription(@CurrentUser() userId: string, @Body() body: any) {
        return this.paymentsService.createSubscription(userId, body);
    }

    // ── Admin Endpoints ──

    @Get('admin/transactions')
    @ApiOperation({ summary: '[Admin] 전체 결제 이력 조회 (페이지네이션)' })
    async getAllTransactions(@Query() query: { page?: string; limit?: string; status?: string }) {
        return this.paymentsService.getAllTransactions(query);
    }

    @Get('admin/stats')
    @ApiOperation({ summary: '[Admin] 결제 통계' })
    async getPaymentStats() {
        return this.paymentsService.getPaymentStats();
    }
}
