import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_TRIP_SETTINGS -- 여행 설정 (도메인 B)
 * DB 설계 v3.5.1 $4.7
 */
@Entity('tb_trip_settings')
export class TripSettings {
    @PrimaryGeneratedColumn('uuid', { name: 'setting_id' })
    settingId: string;

    @Column({ name: 'trip_id', type: 'uuid', unique: true })
    tripId: string;

    /** 캡틴이 가디언 메시지를 수신할지 여부 */
    @Column({ name: 'captain_receive_guardian_msg', type: 'boolean', default: true })
    captainReceiveGuardianMsg: boolean;

    /** 가디언 메시지 기능 활성화 */
    @Column({ name: 'guardian_msg_enabled', type: 'boolean', default: true })
    guardianMsgEnabled: boolean;

    /** Heartbeat 기반 자동 SOS */
    @Column({ name: 'sos_auto_trigger_enabled', type: 'boolean', default: true })
    sosAutoTriggerEnabled: boolean;

    /** SOS 타임아웃 기준 (분) */
    @Column({ name: 'sos_heartbeat_timeout_min', type: 'int', default: 30 })
    sosHeartbeatTimeoutMin: number;

    /** 출석 체크 기능 활성화 */
    @Column({ name: 'attendance_check_enabled', type: 'boolean', default: true })
    attendanceCheckEnabled: boolean;

    /** 가디언에게 지오펜스 알림 전달 여부 */
    @Column({ name: 'geofence_guardian_notify', type: 'boolean', default: true })
    geofenceGuardianNotify: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}
