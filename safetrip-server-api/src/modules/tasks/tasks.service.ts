import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { User } from '../../entities/user.entity';

@Injectable()
export class TasksService {
    private readonly logger = new Logger(TasksService.name);

    constructor(
        @InjectRepository(User)
        private readonly userRepo: Repository<User>,
    ) {}

    /**
     * §14.4 계정 삭제 7일 유예 처리
     * 매일 자정에 실행하여 7일이 경과한 삭제 요청 계정을 영구 삭제 (또는 익명화)
     */
    @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
    async handlePermanentAccountDeletion() {
        this.logger.log('Running permanent account deletion task...');

        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

        // deletionRequestedAt이 7일 이전인 사용자 검색
        const usersToDelete = await this.userRepo.find({
            where: {
                deletionRequestedAt: LessThan(sevenDaysAgo),
            },
            select: ['userId'],
        });

        if (usersToDelete.length === 0) {
            this.logger.log('No accounts to permanently delete.');
            return;
        }

        this.logger.log(`Found ${usersToDelete.length} accounts to delete.`);

        for (const user of usersToDelete) {
            try {
                // 실제 서비스에서는 여기서 연쇄 삭제 로직(위치 데이터 익명화 등)을 수행
                // 현재는 사용자 테이블에서 물리 삭제 (또는 isActive=false 상태 유지하며 데이터 소거)
                await this.userRepo.delete(user.userId);
                this.logger.log(`User ${user.userId} permanently deleted.`);
            } catch (error) {
                this.logger.error(`Failed to delete user ${user.userId}: ${error.message}`);
            }
        }

        this.logger.log('Permanent account deletion task completed.');
    }
}
