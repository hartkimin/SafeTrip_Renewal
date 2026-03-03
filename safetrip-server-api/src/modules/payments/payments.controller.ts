import { Controller, Get, Post, Param, Body } from '@nestjs/common';
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
    verify(@Param('id') id: string, @Body() body: { externalPaymentId: string }) {
        return this.paymentsService.verifyAndComplete(id, body.externalPaymentId);
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
}
