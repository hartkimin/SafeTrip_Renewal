import { Controller, Get, Post, Patch, Param, Body } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { InviteCodesService } from './invite-codes.service';
import { CreateInviteCodeDto } from './dto/create-invite-code.dto';
import { ValidateCodeDto } from './dto/validate-code.dto';
import { UseCodeDto } from './dto/use-code.dto';

@ApiTags('InviteCodes')
@ApiBearerAuth('firebase-auth')
@Controller()
export class InviteCodesController {
    constructor(private readonly service: InviteCodesService) {}

    @Post('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '초대코드 생성 (§03, §04)' })
    createCode(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body() dto: CreateInviteCodeDto,
    ) {
        return this.service.createCode(tripId, userId, dto);
    }

    @Get('trips/:tripId/invite-codes')
    @ApiOperation({ summary: '활성 초대코드 목록 조회 (§04.1, §14.1)' })
    listCodes(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
    ) {
        return this.service.listCodes(tripId, userId);
    }

    @Throttle({ default: { ttl: 60000, limit: 10 } })
    @Post('invite-codes/validate')
    @ApiOperation({ summary: '초대코드 사전 검증 — 인증 필요 (§05, §14.1)' })
    validateCode(
        @CurrentUser() userId: string,
        @Body() dto: ValidateCodeDto,
    ) {
        return this.service.validateCode(dto.code);
    }

    @Throttle({ default: { ttl: 60000, limit: 5 } })
    @Post('invite-codes/use')
    @ApiOperation({ summary: '초대코드 사용/합류 (§05, §11)' })
    useCode(
        @CurrentUser() userId: string,
        @Body() dto: UseCodeDto,
    ) {
        return this.service.useCode(dto.code, userId);
    }

    @Patch('trips/:tripId/invite-codes/:codeId/deactivate')
    @ApiOperation({ summary: '초대코드 비활성화 (§04.1)' })
    deactivateCode(
        @Param('tripId') tripId: string,
        @Param('codeId') codeId: string,
        @CurrentUser() userId: string,
    ) {
        return this.service.deactivateCode(tripId, codeId, userId);
    }
}
