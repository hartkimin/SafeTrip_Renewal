import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';
import { AttendanceCheck, AttendanceResponse } from '../../entities/attendance.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([AttendanceCheck, AttendanceResponse, GroupMember]),
    ],
    controllers: [AttendanceController],
    providers: [AttendanceService],
    exports: [AttendanceService],
})
export class AttendanceModule {}
