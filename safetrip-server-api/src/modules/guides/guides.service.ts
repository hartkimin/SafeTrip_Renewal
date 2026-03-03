import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Country } from '../../entities/country.entity';
// import { MofaRisk } from '../../entities/mofa-risk.entity';

@Injectable()
export class GuidesService {
    constructor(
        @InjectRepository(Country)
        private countryRepository: Repository<Country>,
    ) { }

    async findByCountryCode(countryCode: string) {
        const country = await this.countryRepository.findOne({
            where: { countryCode: countryCode }
        });

        if (!country) return null;

        const guides: any[] = []; // await this.travelGuideRepository.find(...)

        const mofaRisk: any = null; // await this.mofaRiskRepository.findOne(...)

        const guideData = {};
        guides.forEach(g => {
            guideData[g.guideType] = { title: g.title, content: g.content, tags: g.tags };
        });

        return {
            country_code: country.countryCode,
            country_name_ko: country.countryNameKo,
            travel_guide_data: guideData,
            mofa_risk: mofaRisk ? {
                risk_level: mofaRisk.riskLevel,
                risk_description: mofaRisk.riskDescription,
                special_alerts: mofaRisk.specialAlerts,
                is_current: mofaRisk.isCurrent
            } : undefined,
            last_updated: country.updatedAt
        };
    }

    async getEmergencyContacts(countryCode: string) {
        const guides: any[] = []; // await this.travelGuideRepository.find(...)

        if (!guides.length) {
            return null;
        }

        // According to specs, it expects an object with specific emergency contact shape.
        // Assuming guide.content contains JSON or text we can return directly. Let's return the content block.
        // If content is text, we'll format it into a simpler structure or just parse if JSON.
        try {
            return JSON.parse(guides[0].content);
        } catch {
            return { raw_content: guides[0].content };
        }
    }

    async search(query: string, countryCode?: string) {
        return [];
    }
}
