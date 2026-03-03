import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { catchError, map } from 'rxjs/operators';
import { firstValueFrom, of } from 'rxjs';

@Injectable()
export class MofaService {
    private readonly logger = new Logger(MofaService.name);
    private readonly mofaBaseUrl = 'https://apis.data.go.kr/1262000';
    private readonly serviceKey = process.env.MOFA_API_KEY || 'TEST_KEY'; // Replace with ConfigService in prod

    constructor(private readonly httpService: HttpService) { }

    // Actual fetch to the MOFA API endpoints
    private async fetchMofaApi(endpoint: string, countryCode: string, additionalParams: Record<string, string> = {}) {
        const url = `${this.mofaBaseUrl}/${endpoint}`;
        const params = {
            serviceKey: this.serviceKey,
            'cond[country_iso_alp2_nm::EQ]': countryCode,
            pageNo: 1,
            numOfRows: 10,
            returnType: 'JSON',
            ...additionalParams
        };
        try {
            const response = await firstValueFrom(this.httpService.get(url, { params }));
            return response.data?.data || { items: [], totalCount: 0 };
        } catch (error) {
            this.logger.error(`Failed to fetch MOFA API [${endpoint}]:`, error.message);
            return { items: [], totalCount: 0 };
        }
    }

    async getSummary(countryCode: string) {
        const [travel_alarm, country_basic, overview_info, country_flag] = await Promise.all([
            this.fetchMofaApi('TravelAlarmService2/getTravelAlarmList2', countryCode),
            this.fetchMofaApi('CountryBasicService/getCountryBasicList', countryCode),
            this.fetchMofaApi('OverviewGnrlInfoService/getOverviewGnrlInfoList', countryCode),
            this.fetchMofaApi('CountryFlagService2/getCountryFlagList2', countryCode)
        ]);

        return {
            country_code: countryCode,
            travel_alarm: Array.isArray(travel_alarm?.items) ? travel_alarm.items : [],
            country_basic: country_basic || { items: [], totalCount: 0 },
            overview_info: overview_info || { items: [], totalCount: 0 },
            country_flag: country_flag?.items?.[0] || null
        };
    }

    async getSafetyInfo(countryCode: string) {
        const [safety_notices, accidents, security_env] = await Promise.all([
            this.fetchMofaApi('CountrySafetyService6/getCountrySafetyList6', countryCode),
            this.fetchMofaApi('CountryAccidentService2/getCountryAccidentList2', countryCode),
            this.fetchMofaApi('SecurityEnvironmentService/getSecurityEnvironmentList', countryCode)
        ]);

        return {
            country_code: countryCode,
            safety_notices: safety_notices || { items: [], totalCount: 0 },
            accidents: accidents || { items: [], totalCount: 0 },
            security_env: security_env || { items: [], totalCount: 0 }
        };
    }

    async getEntryInfo(countryCode: string) {
        const entrance_visa = await this.fetchMofaApi('EntranceVisaService2/getEntranceVisaList2', countryCode);
        return {
            country_code: countryCode,
            entrance_visa: entrance_visa || { items: [], totalCount: 0 }
        };
    }

    async getMedicalInfo(countryCode: string) {
        const medical_env = await this.fetchMofaApi('MedicalEnvironmentService/getMedicalEnvironmentList', countryCode);
        return {
            country_code: countryCode,
            medical_env: medical_env || { items: [], totalCount: 0 }
        };
    }

    async getContacts(countryCode: string) {
        const [embassy, local_contact] = await Promise.all([
            this.fetchMofaApi('EmbassyService2/getEmbassyList2', countryCode),
            this.fetchMofaApi('LocalContactService2/getLocalContactList2', countryCode)
        ]);

        return {
            country_code: countryCode,
            embassy: embassy || { items: [], totalCount: 0 },
            local_contact: local_contact || { items: [], totalCount: 0 }
        };
    }
}
