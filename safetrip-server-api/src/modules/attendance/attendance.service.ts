import {
    Injectable, NotFoundException, BadRequestException, ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AttendanceCheck, AttendanceResponse } from '../../entities/attendance.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Injectable()
export class AttendanceService {
    constructor(
        @InjectRepository(AttendanceCheck) private checkRepo: Repository<AttendanceCheck>,
        @InjectRepository(AttendanceResponse) private responseRepo: Repository<AttendanceResponse>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
    ) {}

    // ── [GET] /trips/:tripId/attendance ──────────────────────────────
    async listChecks(tripId: string) {
        const checks = await this.checkRepo.find({
            where: { tripId },
            order: { createdAt: 'DESC' },
            take: 10,
        });

        return checks.map((c) => ({
            check_id: c.checkId,
            trip_id: c.tripId,
            group_id: c.groupId,
            initiated_by: c.initiatedBy,
            status: c.status,
            deadline_at: c.deadlineAt,
            created_at: c.createdAt,
            completed_at: c.completedAt,
        }));
    }

    // ── [POST] /trips/:tripId/attendance ─────────────────────────────
    async startCheck(tripId: string, initiatedBy: string, groupId: string) {
        // Validate no ongoing check exists for this group
        const ongoing = await this.checkRepo.findOne({
            where: { tripId, groupId, status: 'ongoing' },
        });
        if (ongoing) {
            throw new ConflictException('이 그룹에 이미 진행 중인 출석 체크가 있습니다');
        }

        // Set deadline 10 minutes from now
        const deadlineAt = new Date(Date.now() + 10 * 60 * 1000);

        const check = this.checkRepo.create({
            tripId,
            groupId,
            initiatedBy,
            status: 'ongoing',
            deadlineAt,
        });

        const saved = await this.checkRepo.save(check);

        // Pre-create 'unknown' responses for all active group members
        const members = await this.memberRepo.find({
            where: { groupId, status: 'active' },
        });

        if (members.length > 0) {
            const responses = members.map((m) =>
                this.responseRepo.create({
                    checkId: saved.checkId,
                    userId: m.userId,
                    responseType: 'unknown',
                    respondedAt: null,
                }),
            );
            await this.responseRepo.save(responses);
        }

        return {
            check_id: saved.checkId,
            trip_id: saved.tripId,
            group_id: saved.groupId,
            status: saved.status,
            deadline_at: saved.deadlineAt,
            created_at: saved.createdAt,
        };
    }

    // ── [PATCH] /trips/:tripId/attendance/:checkId/respond ───────────
    async respond(tripId: string, checkId: string, userId: string, responseType: 'present' | 'absent') {
        const check = await this.checkRepo.findOne({
            where: { checkId, tripId },
        });
        if (!check) {
            throw new NotFoundException('출석 체크를 찾을 수 없습니다');
        }
        if (check.status !== 'ongoing') {
            throw new BadRequestException('이미 종료된 출석 체크입니다');
        }
        if (new Date() > check.deadlineAt) {
            throw new BadRequestException('출석 체크 마감 시간이 지났습니다');
        }

        // Upsert: update if exists, create if not
        const existing = await this.responseRepo.findOne({
            where: { checkId, userId },
        });

        if (existing) {
            existing.responseType = responseType;
            existing.respondedAt = new Date();
            const updated = await this.responseRepo.save(existing);
            return {
                response_id: updated.responseId,
                check_id: updated.checkId,
                user_id: updated.userId,
                response_type: updated.responseType,
                responded_at: updated.respondedAt,
            };
        }

        const response = this.responseRepo.create({
            checkId,
            userId,
            responseType,
            respondedAt: new Date(),
        });
        const saved = await this.responseRepo.save(response);

        return {
            response_id: saved.responseId,
            check_id: saved.checkId,
            user_id: saved.userId,
            response_type: saved.responseType,
            responded_at: saved.respondedAt,
        };
    }

    // ── [PATCH] /trips/:tripId/attendance/:checkId/close ─────────────
    async closeCheck(tripId: string, checkId: string, userId: string) {
        const check = await this.checkRepo.findOne({
            where: { checkId, tripId },
        });
        if (!check) {
            throw new NotFoundException('출석 체크를 찾을 수 없습니다');
        }
        if (check.status !== 'ongoing') {
            throw new BadRequestException('이미 종료된 출석 체크입니다');
        }

        // Auto-mark unknown responses as absent
        await this.responseRepo
            .createQueryBuilder()
            .update(AttendanceResponse)
            .set({ responseType: 'absent', respondedAt: new Date() })
            .where('checkId = :checkId AND responseType = :type', {
                checkId,
                type: 'unknown',
            })
            .execute();

        // Mark check as completed
        check.status = 'completed';
        check.completedAt = new Date();
        const saved = await this.checkRepo.save(check);

        return {
            check_id: saved.checkId,
            status: saved.status,
            completed_at: saved.completedAt,
        };
    }

    // ── [GET] /trips/:tripId/attendance/:checkId/responses ───────────
    async listResponses(tripId: string, checkId: string) {
        // Verify check belongs to trip
        const check = await this.checkRepo.findOne({
            where: { checkId, tripId },
        });
        if (!check) {
            throw new NotFoundException('출석 체크를 찾을 수 없습니다');
        }

        const responses = await this.responseRepo.find({
            where: { checkId },
            order: { createdAt: 'ASC' },
        });

        return responses.map((r) => ({
            response_id: r.responseId,
            check_id: r.checkId,
            user_id: r.userId,
            response_type: r.responseType,
            responded_at: r.respondedAt,
            created_at: r.createdAt,
        }));
    }
}
