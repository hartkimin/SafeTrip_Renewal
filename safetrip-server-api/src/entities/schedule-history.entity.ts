import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
} from 'typeorm';

/**
 * TB_SCHEDULE_HISTORY -- 일정 수정 이력 (도메인 D)
 * 일정탭 원칙 §8.2: field-level audit trail
 */
@Entity('tb_schedule_history')
export class ScheduleHistory {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'schedule_id', type: 'uuid' })
    scheduleId: string;

    @Column({ name: 'modified_by', type: 'varchar', length: 128 })
    modifiedBy: string;

    @Column({ name: 'field_name', type: 'varchar', length: 50 })
    fieldName: string;

    @Column({ name: 'old_value', type: 'text', nullable: true })
    oldValue: string | null;

    @Column({ name: 'new_value', type: 'text', nullable: true })
    newValue: string | null;

    @Column({ name: 'modified_at', type: 'timestamptz', default: () => 'NOW()' })
    modifiedAt: Date;
}
