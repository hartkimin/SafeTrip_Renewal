import { Controller, Get, Post, Param, Body } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { B2bService } from './b2b.service';

@ApiTags('B2B')
@ApiBearerAuth('firebase-auth')
@Controller('b2b')
export class B2bController {
    constructor(private readonly b2bService: B2bService) { }

    @Get('organizations')
    @ApiOperation({ summary: 'B2B 조직 목록' })
    getOrganizations() {
        return this.b2bService.getOrganizations();
    }

    @Get('stats')
    @ApiOperation({ summary: 'B2B 대시보드 통계' })
    getStats() {
        return this.b2bService.getStats();
    }

    @Get('organizations/:orgId')
    @ApiOperation({ summary: 'B2B 조직 상세' })
    getOrganization(@Param('orgId') orgId: string) {
        return this.b2bService.getOrganization(orgId);
    }

    @Get('organizations/:orgId/contracts')
    @ApiOperation({ summary: '조직 계약 목록' })
    getContracts(@Param('orgId') orgId: string) {
        return this.b2bService.getContracts(orgId);
    }

    @Get('organizations/:orgId/admins')
    @ApiOperation({ summary: '조직 관리자 목록' })
    getAdmins(@Param('orgId') orgId: string) {
        return this.b2bService.getAdmins(orgId);
    }

    @Get('organizations/:orgId/dashboard-config')
    @ApiOperation({ summary: '대시보드 설정 조회' })
    getDashboardConfig(@Param('orgId') orgId: string) {
        return this.b2bService.getDashboardConfig(orgId);
    }

    @Post('organizations/:orgId/dashboard-config')
    @ApiOperation({ summary: '대시보드 설정 저장' })
    setDashboardConfig(
        @Param('orgId') orgId: string,
        @Body() body: { key: string; value: any; contractId?: string },
    ) {
        return this.b2bService.setDashboardConfig(orgId, body.key, body.value, body.contractId);
    }
}
