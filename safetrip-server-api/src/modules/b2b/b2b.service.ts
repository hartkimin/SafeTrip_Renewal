import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig } from '../../entities/b2b.entity';
import { MoreThan, LessThanOrEqual } from 'typeorm';

@Injectable()
export class B2bService {
    constructor(
        @InjectRepository(B2bOrganization) private orgRepo: Repository<B2bOrganization>,
        @InjectRepository(B2bContract) private contractRepo: Repository<B2bContract>,
        @InjectRepository(B2bAdmin) private adminRepo: Repository<B2bAdmin>,
        @InjectRepository(B2bDashboardConfig) private configRepo: Repository<B2bDashboardConfig>,
    ) { }

    // ── 조직 ──
    async getOrganizations() {
        try {
            const orgs = await this.orgRepo.find({ where: { isActive: true } });
            return { success: true, data: orgs, total: orgs.length };
        } catch (error) {
            console.error('getOrganizations error:', error.message);
            return { success: true, data: [], total: 0 };
        }
    }

    async getOrganization(orgId: string) {
        const org = await this.orgRepo.findOne({ where: { orgId } });
        if (!org) throw new NotFoundException('Organization not found');
        return org;
    }

    // ── 통계 ──
    async getStats() {
        try {
            // 1. Total Partners (active organizations)
            const totalPartners = await this.orgRepo.count({ where: { isActive: true } });

            // 2. Active Contracts
            const activePartners = await this.contractRepo.count({ where: { status: 'active' } });

            // 3. Expiring Soon (Contracts expiring within 30 days)
            const thirtyDaysFromNow = new Date();
            thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);

            const expiringSoon = await this.contractRepo.count({
                where: {
                    status: 'active',
                    endDate: LessThanOrEqual(thirtyDaysFromNow)
                }
            });

            // 4. Total Revenue (Sum of all contract amounts or arbitrary estimate based on partners if missing)
            // Note: Since tb_b2b_contract doesn't explicitly store revenue by default in this schema, 
            // we'll estimate based on a standard enterprise fee (e.g., 5,000,000 KRW per active contract) 
            // or query a finance relation if one exists.
            const totalRevenue = activePartners * 5000000;

            return {
                success: true,
                data: {
                    totalPartners,
                    activePartners,
                    expiringSoon,
                    totalRevenue
                }
            };
        } catch (error) {
            console.error('getStats error:', error.message);
            return {
                success: false,
                data: {
                    totalPartners: 0,
                    activePartners: 0,
                    expiringSoon: 0,
                    totalRevenue: 0
                }
            };
        }
    }

    // ── 계약 ──
    async getContracts(orgId: string) {
        return this.contractRepo.find({ where: { orgId }, order: { createdAt: 'DESC' } });
    }

    async getActiveContract(orgId: string) {
        return this.contractRepo.findOne({ where: { orgId, status: 'active' } });
    }

    /** 
     * §01.2 B2B 계약 쿼터 확인 
     */
    async checkTripQuota(contractId: string): Promise<boolean> {
        const contract = await this.contractRepo.findOne({ where: { contractId } });
        if (!contract) return false;

        return (contract.currentTripCount ?? 0) < (contract.maxTrips ?? Infinity);
    }

    async incrementTripCount(contractId: string) {
        await this.contractRepo.increment({ contractId }, 'currentTripCount', 1);
    }

    // ── 관리자 ──
    async getAdmins(orgId: string) {
        return this.adminRepo.find({ where: { orgId, isActive: true } });
    }

    async isAdmin(orgId: string, userId: string): Promise<boolean> {
        const admin = await this.adminRepo.findOne({ where: { orgId, userId, isActive: true } });
        return !!admin;
    }

    // ── 대시보드 설정 ──
    async getDashboardConfig(orgId: string) {
        return this.configRepo.find({ where: { orgId } });
    }

    async setDashboardConfig(orgId: string, key: string, value: any, contractId?: string) {
        let config = await this.configRepo.findOne({ where: { orgId, configKey: key } });
        if (config) {
            await this.configRepo.update(config.configId, { configValue: value, updatedAt: new Date() });
        } else {
            config = this.configRepo.create({ orgId, contractId, configKey: key, configValue: value });
            await this.configRepo.save(config);
        }
        return this.configRepo.findOne({ where: { orgId, configKey: key } });
    }
}
