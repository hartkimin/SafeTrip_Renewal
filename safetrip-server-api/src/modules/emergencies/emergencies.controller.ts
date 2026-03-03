import { Controller, Get, Post, Patch, Delete, Param, Body } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { EmergenciesService } from './emergencies.service';

@ApiTags('Emergencies')
@ApiBearerAuth('firebase-auth')
@Controller('emergencies')
export class EmergenciesController {
    constructor(private readonly emergenciesService: EmergenciesService) { }

    @Post()
    @ApiOperation({ summary: '긴급 상황 생성 (SOS 포함, 5분 쿨다운)' })
    createEmergency(@CurrentUser() userId: string, @Body() body: any) {
        return this.emergenciesService.createEmergency(userId, body.tripId, body);
    }

    @Get('trip/:tripId')
    @ApiOperation({ summary: '긴급 상황 이력 조회' })
    getEmergencies(@Param('tripId') tripId: string) {
        return this.emergenciesService.getEmergencies(tripId);
    }

    @Patch(':emergencyId/resolve')
    @ApiOperation({ summary: '긴급 상황 해제' })
    resolveEmergency(
        @CurrentUser() userId: string,
        @Param('emergencyId') emergencyId: string,
        @Body() body: { note?: string },
    ) {
        return this.emergenciesService.resolveEmergency(emergencyId, userId, body.note);
    }

    @Patch(':emergencyId/acknowledge')
    @ApiOperation({ summary: '긴급 상황 확인' })
    acknowledgeEmergency(
        @CurrentUser() userId: string,
        @Param('emergencyId') emergencyId: string,
    ) {
        return this.emergenciesService.acknowledgeEmergency(emergencyId, userId);
    }

    @Get('contacts')
    @ApiOperation({ summary: '비상 연락처 목록' })
    getContacts(@CurrentUser() userId: string) {
        return this.emergenciesService.getContacts(userId);
    }

    @Post('contacts')
    @ApiOperation({ summary: '비상 연락처 추가' })
    addContact(@CurrentUser() userId: string, @Body() body: any) {
        return this.emergenciesService.addContact(userId, body);
    }

    @Delete('contacts/:contactId')
    @ApiOperation({ summary: '비상 연락처 삭제' })
    removeContact(@Param('contactId') contactId: string) {
        return this.emergenciesService.removeContact(contactId);
    }
}
