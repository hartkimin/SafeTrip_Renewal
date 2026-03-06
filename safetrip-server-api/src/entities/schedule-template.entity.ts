import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
} from 'typeorm';

/**
 * TB_SCHEDULE_TEMPLATE -- 일정 템플릿 (도메인 D)
 * P3 템플릿: 사전 정의된 일정 세트를 여행에 적용
 */
@Entity('tb_schedule_template')
export class ScheduleTemplate {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'name', type: 'varchar', length: 200 })
    name: string;

    @Column({ name: 'category', type: 'varchar', length: 50, nullable: true })
    category: string | null;

    @Column({ name: 'items', type: 'jsonb', default: '[]' })
    items: any;

    @Column({ name: 'created_at', type: 'timestamptz', default: () => 'NOW()' })
    createdAt: Date;
}
