import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike, In } from 'typeorm';
import { Country } from '../../entities/country.entity';
import { SafetyGuideCache } from '../../entities/safety-guide-cache.entity';
import { CountryEmergencyContact } from '../../entities/country-emergency-contact.entity';
import { MofaService } from '../mofa/mofa.service';

/** Default cache TTL: 6 hours */
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;

export interface CacheMeta {
    country_code: string;
    cached: boolean;
    stale: boolean;
    fetched_at: string | null;
    expires_at: string | null;
}

export interface GuideResponse<T = any> {
    data: T | null;
    meta: CacheMeta;
}

@Injectable()
export class GuidesService {
    private readonly logger = new Logger(GuidesService.name);

    constructor(
        @InjectRepository(Country)
        private readonly countryRepository: Repository<Country>,
        @InjectRepository(SafetyGuideCache)
        private readonly cacheRepository: Repository<SafetyGuideCache>,
        @InjectRepository(CountryEmergencyContact)
        private readonly emergencyContactRepository: Repository<CountryEmergencyContact>,
        private readonly mofaService: MofaService,
    ) { }

    // ─── Core cache method ───────────────────────────────────────────

    /**
     * Generic cache-through method.
     * 1. Check tb_safety_guide_cache for non-expired entry
     * 2. If miss or expired, call MOFA fetcher
     * 3. Upsert result into cache
     * 4. On MOFA failure, return stale cache if available
     */
    private async getGuideData(
        countryCode: string,
        dataType: string,
        mofaFetcher: () => Promise<any>,
    ): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();

        // 1) Look up cache
        const cached = await this.cacheRepository.findOne({
            where: { countryCode: cc, dataType },
        });

        // 2) Cache hit and still valid
        if (cached && cached.expiresAt > new Date()) {
            return {
                data: cached.content,
                meta: {
                    country_code: cc,
                    cached: true,
                    stale: false,
                    fetched_at: cached.fetchedAt?.toISOString() ?? null,
                    expires_at: cached.expiresAt?.toISOString() ?? null,
                },
            };
        }

        // 3) Cache miss or expired -- fetch from MOFA
        try {
            const mofaResult = await mofaFetcher();
            const now = new Date();
            const expiresAt = new Date(now.getTime() + CACHE_TTL_MS);

            // Upsert (TypeORM save with existing entity or new)
            if (cached) {
                cached.content = mofaResult;
                cached.fetchedAt = now;
                cached.expiresAt = expiresAt;
                cached.updatedAt = now;
                await this.cacheRepository.save(cached);
            } else {
                const newCache = this.cacheRepository.create({
                    countryCode: cc,
                    dataType,
                    content: mofaResult,
                    fetchedAt: now,
                    expiresAt,
                });
                await this.cacheRepository.save(newCache);
            }

            return {
                data: mofaResult,
                meta: {
                    country_code: cc,
                    cached: false,
                    stale: false,
                    fetched_at: now.toISOString(),
                    expires_at: expiresAt.toISOString(),
                },
            };
        } catch (error) {
            this.logger.error(
                `MOFA fetch failed [${dataType}] for ${cc}: ${error.message}`,
            );

            // 4) MOFA failed but stale cache exists
            if (cached) {
                return {
                    data: cached.content,
                    meta: {
                        country_code: cc,
                        cached: true,
                        stale: true,
                        fetched_at: cached.fetchedAt?.toISOString() ?? null,
                        expires_at: cached.expiresAt?.toISOString() ?? null,
                    },
                };
            }

            // 5) No cache at all
            return {
                data: null,
                meta: {
                    country_code: cc,
                    cached: false,
                    stale: true,
                    fetched_at: null,
                    expires_at: null,
                },
            };
        }
    }

    // ─── Tab methods ─────────────────────────────────────────────────

    async getOverview(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'overview', async () => {
            const [mofaSummary, country] = await Promise.all([
                this.mofaService.getSummary(cc),
                this.countryRepository.findOne({ where: { countryCode: cc } }),
            ]);

            const travelAlarm = mofaSummary.travel_alarm?.[0] || {};
            const basicInfo = mofaSummary.country_basic?.items?.[0] || {};

            return {
                country_code: cc,
                country_name_ko: country?.countryNameKo ?? basicInfo.country_nm ?? null,
                country_name_en: country?.countryNameEn ?? basicInfo.country_eng_nm ?? null,
                flag_emoji: country?.countryFlagEmoji ?? null,
                travel_alert_level: travelAlarm.alarm_lvl ?? country?.mofaTravelAlert ?? 'none',
                capital: basicInfo.capital ?? null,
                currency: basicInfo.currency ?? null,
                language: basicInfo.language ?? null,
                timezone: basicInfo.timezone ?? null,
            };
        });
    }

    async getSafety(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'safety', async () => {
            const mofaSafety = await this.mofaService.getSafetyInfo(cc);

            const safetyNotices = mofaSafety.safety_notices?.items || [];
            const securityEnv = mofaSafety.security_env?.items?.[0] || {};

            return {
                travel_alert_level: securityEnv.alarm_lvl ?? null,
                travel_alert_description: securityEnv.txt_origin_cn ?? null,
                security_status: securityEnv.security_remark ?? null,
                recent_notices: safetyNotices.map((n: any) => ({
                    title: n.title ?? null,
                    content: n.txt_origin_cn ?? null,
                    written_date: n.wrt_dt ?? null,
                })),
                regional_alerts: mofaSafety.accidents?.items?.map((a: any) => ({
                    title: a.title ?? null,
                    content: a.txt_origin_cn ?? null,
                    written_date: a.wrt_dt ?? null,
                })) ?? [],
            };
        });
    }

    async getMedical(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'medical', async () => {
            const mofaMedical = await this.mofaService.getMedicalInfo(cc);
            const medicalEnv = mofaMedical.medical_env?.items?.[0] || {};

            return {
                hospitals: medicalEnv.hospital_info ?? null,
                insurance_guide: medicalEnv.insurance_info ?? null,
                pharmacy_info: medicalEnv.pharmacy_info ?? null,
                emergency_guide: medicalEnv.emergency_info ?? null,
            };
        });
    }

    async getEntry(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'entry', async () => {
            const mofaEntry = await this.mofaService.getEntryInfo(cc);
            const visaInfo = mofaEntry.entrance_visa?.items?.[0] || {};

            return {
                visa_requirement: visaInfo.visa_info ?? null,
                required_documents: visaInfo.required_doc ?? null,
                customs_info: visaInfo.customs_info ?? null,
                passport_validity: visaInfo.passport_validity ?? null,
            };
        });
    }

    async getEmergency(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'emergency', async () => {
            // Fetch from both local DB and MOFA in parallel
            const [dbContacts, mofaContacts] = await Promise.all([
                this.emergencyContactRepository.find({
                    where: { countryCode: In([cc, 'ALL']) },
                }),
                this.mofaService.getContacts(cc),
            ]);

            // Map local DB contacts
            const localContacts = dbContacts.map((c) => ({
                contact_type: c.contactType,
                phone_number: c.phoneNumber,
                description_ko: c.descriptionKo,
                is_24h: c.is24h,
                source: 'local',
            }));

            // Map MOFA embassy contacts
            const embassyContacts = (mofaContacts.embassy?.items || []).map((e: any) => ({
                contact_type: 'embassy',
                phone_number: e.tel_no ?? null,
                description_ko: e.embassy_nm ?? null,
                is_24h: false,
                source: 'mofa',
            }));

            // Map MOFA local contact info
            const mofaLocalContacts = (mofaContacts.local_contact?.items || []).map((l: any) => ({
                contact_type: l.contact_type ?? 'local',
                phone_number: l.tel_no ?? null,
                description_ko: l.contact_nm ?? null,
                is_24h: false,
                source: 'mofa',
            }));

            return {
                contacts: [...localContacts, ...embassyContacts, ...mofaLocalContacts],
            };
        });
    }

    async getLocalLife(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();
        return this.getGuideData(cc, 'local_life', async () => {
            const mofaSummary = await this.mofaService.getSummary(cc);
            const overviewInfo = mofaSummary.overview_info?.items?.[0] || {};
            const basicInfo = mofaSummary.country_basic?.items?.[0] || {};

            return {
                transport: overviewInfo.transport_info ?? null,
                sim_card: overviewInfo.sim_card_info ?? null,
                tipping_culture: overviewInfo.tipping_info ?? null,
                voltage: basicInfo.voltage ?? null,
                cost_reference: overviewInfo.cost_info ?? null,
                cultural_notes: overviewInfo.cultural_info ?? null,
            };
        });
    }

    /**
     * Get all 6 tabs in parallel for a single country.
     */
    async getAll(countryCode: string): Promise<GuideResponse> {
        const cc = countryCode.toUpperCase();

        const [overview, safety, medical, entry, emergency, localLife] =
            await Promise.all([
                this.getOverview(cc),
                this.getSafety(cc),
                this.getMedical(cc),
                this.getEntry(cc),
                this.getEmergency(cc),
                this.getLocalLife(cc),
            ]);

        // Determine aggregate meta -- if any tab is stale, mark overall stale
        const allMetas = [overview.meta, safety.meta, medical.meta, entry.meta, emergency.meta, localLife.meta];
        const anyCached = allMetas.some((m) => m.cached);
        const anyStale = allMetas.some((m) => m.stale);

        // Use the earliest fetched_at and latest expires_at
        const fetchedAts = allMetas.map((m) => m.fetched_at).filter(Boolean) as string[];
        const expiresAts = allMetas.map((m) => m.expires_at).filter(Boolean) as string[];

        return {
            data: {
                overview: overview.data,
                safety: safety.data,
                medical: medical.data,
                entry: entry.data,
                emergency: emergency.data,
                local_life: localLife.data,
            },
            meta: {
                country_code: cc,
                cached: anyCached,
                stale: anyStale,
                fetched_at: fetchedAts.length > 0 ? fetchedAts.sort()[0] : null,
                expires_at: expiresAts.length > 0 ? expiresAts.sort().reverse()[0] : null,
            },
        };
    }

    // ─── Existing methods (preserved) ────────────────────────────────

    async findByCountryCode(countryCode: string) {
        const country = await this.countryRepository.findOne({
            where: { countryCode },
        });

        if (!country) return null;

        return {
            country_code: country.countryCode,
            country_name_ko: country.countryNameKo,
            country_name_en: country.countryNameEn,
            flag_emoji: country.countryFlagEmoji,
            last_updated: country.updatedAt,
        };
    }

    async search(query: string, countryCode?: string) {
        const where: any = {};

        if (countryCode) {
            where.countryCode = countryCode;
        }

        const countries = await this.countryRepository.find({
            where: [
                { ...where, countryNameKo: ILike(`%${query}%`) },
                { ...where, countryNameEn: ILike(`%${query}%`) },
            ],
            take: 20,
        });

        return countries.map((c) => ({
            country_code: c.countryCode,
            country_name_ko: c.countryNameKo,
            country_name_en: c.countryNameEn,
            flag_emoji: c.countryFlagEmoji,
        }));
    }
}
