import { Controller, Get, Param, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiParam } from '@nestjs/swagger';
import { MofaService } from './mofa.service';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('MOFA')
@Controller('mofa')
export class MofaController {
    constructor(private readonly mofaService: MofaService) { }

    private validateCountryCode(countryCode: string) {
        if (!countryCode || countryCode.length !== 2) {
            throw new BadRequestException('Valid 2-letter country code is required');
        }
        return countryCode.toUpperCase();
    }

    @Public()
    @Get('country/:countryCode/all')
    @ApiOperation({ summary: '국가 전체 정보 통합 조회 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getAll(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getAll(code);
    }

    @Public()
    @Get('country/:countryCode/summary')
    @ApiOperation({ summary: '국가 종합 요약 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드 (정확히 2자리)' })
    async getSummary(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getSummary(code);
    }

    @Public()
    @Get('country/:countryCode/safety')
    @ApiOperation({ summary: '국가 안전 정보 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true })
    async getSafetyInfo(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getSafetyInfo(code);
    }

    @Public()
    @Get('country/:countryCode/entry')
    @ApiOperation({ summary: '국가 입국 정보 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true })
    async getEntryInfo(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getEntryInfo(code);
    }

    @Public()
    @Get('country/:countryCode/medical')
    @ApiOperation({ summary: '국가 의료 정보 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true })
    async getMedicalInfo(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getMedicalInfo(code);
    }

    @Public()
    @Get('country/:countryCode/contacts')
    @ApiOperation({ summary: '국가 연락처 정보 (MOFA)' })
    @ApiParam({ name: 'countryCode', required: true })
    async getContacts(@Param('countryCode') countryCode: string) {
        const code = this.validateCountryCode(countryCode);
        return this.mofaService.getContacts(code);
    }
}
