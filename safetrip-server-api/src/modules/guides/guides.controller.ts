import {
    Controller, Get, Param, Query,
    BadRequestException, NotFoundException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiParam } from '@nestjs/swagger';
import { GuidesService } from './guides.service';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Guides')
@Controller('guides')
export class GuidesController {
    constructor(private readonly guidesService: GuidesService) { }

    // ─── Search (must be BEFORE :countryCode to avoid route conflict) ─

    @Public()
    @Get('search')
    @ApiOperation({ summary: '가이드 검색' })
    @ApiQuery({ name: 'q', required: true, description: '검색어' })
    @ApiQuery({ name: 'country', required: false, description: '국가 코드 필터' })
    async searchGuides(
        @Query('q') query: string,
        @Query('country') country?: string,
    ) {
        if (!query) {
            throw new BadRequestException('Query parameter (q) is required');
        }
        return this.guidesService.search(query, country);
    }

    // ─── Tab-specific endpoints ──────────────────────────────────────

    @Public()
    @Get(':countryCode/overview')
    @ApiOperation({ summary: '국가 개요 탭' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getOverview(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getOverview(countryCode.toUpperCase());
    }

    @Public()
    @Get(':countryCode/safety')
    @ApiOperation({ summary: '안전 정보 탭' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getSafety(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getSafety(countryCode.toUpperCase());
    }

    @Public()
    @Get(':countryCode/medical')
    @ApiOperation({ summary: '의료 정보 탭' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getMedical(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getMedical(countryCode.toUpperCase());
    }

    @Public()
    @Get(':countryCode/entry')
    @ApiOperation({ summary: '입국 정보 탭' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getEntry(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getEntry(countryCode.toUpperCase());
    }

    @Public()
    @Get(':countryCode/emergency')
    @ApiOperation({ summary: '긴급 연락처 조회' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getEmergencyContacts(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getEmergency(countryCode.toUpperCase());
    }

    @Public()
    @Get(':countryCode/local-life')
    @ApiOperation({ summary: '현지 생활 탭' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getLocalLife(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getLocalLife(countryCode.toUpperCase());
    }

    // ─── Full guide (all 6 tabs) ─────────────────────────────────────

    @Public()
    @Get(':countryCode')
    @ApiOperation({ summary: '국가별 전체 가이드 조회 (6탭 통합)' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getGuideByCountry(@Param('countryCode') countryCode: string) {
        this.validateCountryCode(countryCode);
        return this.guidesService.getAll(countryCode.toUpperCase());
    }

    // ─── Helpers ─────────────────────────────────────────────────────

    private validateCountryCode(countryCode: string): void {
        if (!countryCode) {
            throw new BadRequestException('countryCode is required');
        }
    }
}
