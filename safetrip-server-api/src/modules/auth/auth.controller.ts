import { Controller, Post, Delete, Body, HttpCode, HttpStatus, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthService } from './auth.service';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @Public()
    @Post('firebase-verify')
    @HttpCode(HttpStatus.OK)
    @ApiOperation({ summary: 'Firebase Token verify & User UPSERT' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                id_token: { type: 'string' },
                phone_country_code: { type: 'string', default: '+82' },
                install_id: { type: 'string' },
                is_test_device: { type: 'boolean' },
                test_phone_number: { type: 'string' },
            },
            required: ['id_token']
        }
    })
    async firebaseVerify(
        @Body() body: { id_token: string; phone_country_code?: string; install_id?: string; is_test_device?: boolean; test_phone_number?: string }
    ) {
        if (!body.id_token) {
            throw new BadRequestException('id_token is required');
        }
        return this.authService.verifyFirebaseToken(body);
    }

    @Public()
    @Post('logout')
    @HttpCode(HttpStatus.OK)
    @ApiOperation({ summary: '로그아웃 처리' })
    async logout() {
        return {
            success: true,
            data: { message: "Logout successful" }
        };
    }


    @Post('verify')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '토큰 검증 + 사용자 정보 반환' })
    async verify(@CurrentUser() userId: string) {
        return this.authService.verifyAndGetUser(userId);
    }

    @Post('register')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '온보딩 완료 처리' })
    async register(
        @CurrentUser() userId: string,
        @Body() body: { displayName?: string; dateOfBirth?: string; profileImageUrl?: string },
    ) {
        return this.authService.completeOnboarding(userId, body);
    }

    @Post('consent')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '동의 기록' })
    async consent(
        @CurrentUser() userId: string,
        @Body() body: { consentType: string; consentVersion: string; isGranted: boolean },
    ) {
        return this.authService.recordConsent(
            userId,
            body.consentType,
            body.consentVersion,
            body.isGranted,
        );
    }

    @Delete('account')
    @ApiBearerAuth('firebase-auth')
    @HttpCode(HttpStatus.OK)
    @ApiOperation({ summary: '계정 삭제 요청 (7일 유예)' })
    async deleteAccount(@CurrentUser() userId: string) {
        return this.authService.requestDeletion(userId);
    }

    @Post('cancel-deletion')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '계정 삭제 취소' })
    async cancelDeletion(@CurrentUser() userId: string) {
        return this.authService.cancelDeletion(userId);
    }

    @Post('minor-consent-otp')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '미성년자 보호자 동의 OTP 발송' })
    async sendMinorConsentOtp(
        @CurrentUser() userId: string,
        @Body() body: { phone: string }
    ) {
        return this.authService.sendMinorConsentOtp(userId, body.phone);
    }

    @Post('submit-parental-consent')
    @ApiBearerAuth('firebase-auth')
    @ApiOperation({ summary: '법정대리인 동의 제출' })
    async submitParentalConsent(
        @CurrentUser() userId: string,
        @Body() body: { parentName: string, parentPhone: string, relationship: string, otp: string }
    ) {
        return this.authService.submitParentalConsent(userId, body);
    }
}
