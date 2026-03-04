import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TasksService } from './tasks.service';
import { User } from '../../entities/user.entity';

@Module({
    imports: [TypeOrmModule.forFeature([User])],
    providers: [TasksService],
    exports: [TasksService],
})
export class TasksModule {}
