import { Controller, Get, Param, Query, BadRequestException, NotFoundException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiParam } from '@nestjs/swagger';
import { GuidesService } from './guides.service';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Guides')
@Controller('guides')
export class GuidesController {
    constructor(private readonly guidesService: GuidesService) { }

    @Public()
    @Get('search')
    @ApiOperation({ summary: '가이드 검색' })
    @ApiQuery({ name: 'q', required: true, description: '검색어' })
    @ApiQuery({ name: 'country', required: false, description: '국가 코드 필터' })
    async searchGuides(
        @Query('q') query: string,
        @Query('country') country?: string
    ) {
        if (!query) {
            throw new BadRequestException('Query parameter (q) is required');
        }

        const results = await this.guidesService.search(query, country);
        return {
            success: true,
            data: results
        };
    }

    @Public()
    @Get(':countryCode')
    @ApiOperation({ summary: '국가별 가이드 조회' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getGuideByCountry(@Param('countryCode') countryCode: string) {
        if (!countryCode) {
            throw new BadRequestException('countryCode is required');
        }

        const guide = await this.guidesService.findByCountryCode(countryCode.toUpperCase());
        if (!guide) {
            throw new NotFoundException('Guide not found for the specified country');
        }

        return {
            success: true,
            data: guide
        };
    }

    @Public()
    @Get(':countryCode/emergency')
    @ApiOperation({ summary: '긴급 연락처 조회' })
    @ApiParam({ name: 'countryCode', required: true, description: 'ISO alpha-2 국가 코드' })
    async getEmergencyContacts(@Param('countryCode') countryCode: string) {
        if (!countryCode) {
            throw new BadRequestException('countryCode is required');
        }

        const emergencyContacts = await this.guidesService.getEmergencyContacts(countryCode.toUpperCase());
        if (!emergencyContacts) {
            throw new NotFoundException('Emergency contacts not found for the specified country');
        }

        return {
            success: true,
            data: emergencyContacts
        };
    }
}
