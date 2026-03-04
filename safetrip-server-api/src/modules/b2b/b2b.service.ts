import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig } from '../../entities/b2b.entity';

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
        return this.orgRepo.find({ where: { isActive: true } });
    }

    async getOrganization(orgId: string) {
        const org = await this.orgRepo.findOne({ where: { orgId } });
        if (!org) throw new NotFoundException('Organization not found');
        return org;
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
        
        return contract.currentTripCount < contract.maxTrips;
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
