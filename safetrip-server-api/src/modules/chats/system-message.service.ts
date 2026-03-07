import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatRoom, ChatMessage } from '../../entities/chat.entity';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * SystemMessageService
 * -----------------------------------------------------------------------
 * 그룹 채팅방에 시스템 메시지(type='system')를 자동 삽입한다.
 * 다른 모듈(멤버, SOS, 출석 등)이 ChatsModule 을 import 한 뒤
 * 이 서비스를 DI 하여 호출한다.
 *
 * DOC-T3-CHT-020 v1.1 - System Message Specification
 * -----------------------------------------------------------------------
 */

/** 시스템 이벤트 타입 → 이벤트 레벨 매핑 */
const EVENT_LEVEL_MAP: Record<string, string> = {
    member_join: 'INFO',
    member_leave: 'INFO',
    member_kicked: 'WARNING',
    role_change: 'INFO',
    leader_transfer: 'INFO',
    trip_start: 'CELEBRATION',
    trip_end: 'INFO',
    sos_alert: 'CRITICAL',
    sos_cancel: 'INFO',
    attendance_start: 'INFO',
    attendance_complete: 'INFO',
    privacy_change: 'INFO',
    schedule_change: 'SCHEDULE',
    guardian_add: 'INFO',
    guardian_remove: 'INFO',
    pin_add: 'INFO',
    pin_remove: 'INFO',
};

@Injectable()
export class SystemMessageService {
    private readonly logger = new Logger(SystemMessageService.name);

    constructor(
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        private notifService: NotificationsService,
    ) {}

    // ------------------------------------------------------------------
    // Generic insert
    // ------------------------------------------------------------------

    /**
     * 시스템 메시지를 그룹 채팅방에 삽입한다.
     *
     * @param tripId        여행 ID
     * @param eventType     시스템 이벤트 타입 (member_join, sos_alert 등)
     * @param content       표시할 텍스트
     * @param extra         추가 메타데이터 (optional)
     * @returns 저장된 ChatMessage 또는 null (실패 시)
     */
    async insert(
        tripId: string,
        eventType: string,
        content: string,
        extra?: Record<string, any>,
    ): Promise<ChatMessage | null> {
        try {
            // 해당 여행의 group 채팅방 조회
            const room = await this.roomRepo.findOne({
                where: { tripId, roomType: 'group', isActive: true },
            });

            if (!room) {
                this.logger.warn(
                    `No active group chat room found for trip ${tripId}. Skipping system message.`,
                );
                return null;
            }

            const level = EVENT_LEVEL_MAP[eventType] || 'INFO';

            const message = this.messageRepo.create({
                roomId: room.roomId,
                tripId,
                senderId: null, // system messages have no sender
                messageType: 'system',
                content,
                systemEventType: eventType,
                systemEventLevel: level,
                metadata: extra || null,
            } as Partial<ChatMessage>);

            const saved = await this.messageRepo.save(message);

            this.logger.log(
                `System message inserted: [${level}] ${eventType} in trip ${tripId}`,
            );

            return saved;
        } catch (error) {
            // 시스템 메시지 삽입은 best-effort — 실패해도 호출자에게 전파하지 않는다
            this.logger.error(
                `Failed to insert system message (${eventType}) for trip ${tripId}: ${error.message}`,
                error.stack,
            );
            return null;
        }
    }

    // ------------------------------------------------------------------
    // Convenience methods
    // ------------------------------------------------------------------

    /**
     * SOS 발신 시스템 메시지
     */
    async insertSosAlert(
        tripId: string,
        userName: string,
        locationData?: { lat: number; lng: number; address?: string },
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 SOS를 발신했습니다.`;
        return this.insert(tripId, 'sos_alert', content, {
            userName,
            locationData: locationData || null,
        });
    }

    /**
     * SOS 해제 시스템 메시지
     */
    async insertSosCancel(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님의 SOS가 해제되었습니다.`;
        return this.insert(tripId, 'sos_cancel', content, { userName });
    }

    /**
     * 멤버 합류 시스템 메시지
     */
    async insertMemberJoin(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 여행에 합류했습니다.`;
        return this.insert(tripId, 'member_join', content, { userName });
    }

    /**
     * 멤버 탈퇴 시스템 메시지
     */
    async insertMemberLeave(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 여행을 떠났습니다.`;
        return this.insert(tripId, 'member_leave', content, { userName });
    }

    /**
     * 멤버 강퇴 시스템 메시지
     */
    async insertMemberKicked(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 여행에서 강퇴되었습니다.`;
        return this.insert(tripId, 'member_kicked', content, { userName });
    }

    /**
     * 역할 변경 시스템 메시지
     */
    async insertRoleChange(
        tripId: string,
        userName: string,
        newRole: string,
    ): Promise<ChatMessage | null> {
        const roleLabel = this.getRoleLabel(newRole);
        const content = `${userName}님이 ${roleLabel}으로 변경되었습니다.`;
        return this.insert(tripId, 'role_change', content, { userName, newRole });
    }

    /**
     * 리더 이전 시스템 메시지
     */
    async insertLeaderTransfer(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 캡틴이 되었습니다.`;
        return this.insert(tripId, 'leader_transfer', content, { userName });
    }

    /**
     * 여행 시작 시스템 메시지
     */
    async insertTripStart(tripId: string): Promise<ChatMessage | null> {
        const content = '여행이 시작되었습니다.';
        return this.insert(tripId, 'trip_start', content);
    }

    /**
     * 여행 종료 시스템 메시지
     */
    async insertTripEnd(tripId: string): Promise<ChatMessage | null> {
        const content = '여행이 종료되었습니다.';
        return this.insert(tripId, 'trip_end', content);
    }

    /**
     * 출석 체크 시작 시스템 메시지
     */
    async insertAttendanceStart(tripId: string): Promise<ChatMessage | null> {
        const content = '출석 체크가 시작되었습니다. 10분 내 응답해 주세요.';
        return this.insert(tripId, 'attendance_start', content);
    }

    /**
     * 출석 체크 완료 시스템 메시지
     */
    async insertAttendanceComplete(
        tripId: string,
        present: number,
        absent: number,
        pending: number,
    ): Promise<ChatMessage | null> {
        const content = `출석 체크 완료: ✅ ${present}명 / ❌ ${absent}명 / ⏳ ${pending}명`;
        return this.insert(tripId, 'attendance_complete', content, {
            present,
            absent,
            pending,
        });
    }

    /**
     * 프라이버시 등급 변경 시스템 메시지
     */
    async insertPrivacyChange(
        tripId: string,
        level: string,
    ): Promise<ChatMessage | null> {
        const content = `여행 프라이버시 등급이 ${level}으로 변경되었습니다.`;
        return this.insert(tripId, 'privacy_change', content, { level });
    }

    /**
     * 일정 변경 시스템 메시지
     */
    async insertScheduleChange(
        tripId: string,
        date: string,
    ): Promise<ChatMessage | null> {
        const content = `${date} 일정이 변경되었습니다.`;
        return this.insert(tripId, 'schedule_change', content, { date });
    }

    /**
     * 가디언 연결 시스템 메시지
     */
    async insertGuardianAdd(
        tripId: string,
        memberName: string,
        guardianName: string,
    ): Promise<ChatMessage | null> {
        const content = `${memberName}님의 가디언으로 ${guardianName}님이 연결되었습니다.`;
        return this.insert(tripId, 'guardian_add', content, {
            memberName,
            guardianName,
        });
    }

    /**
     * 가디언 해제 시스템 메시지
     */
    async insertGuardianRemove(
        tripId: string,
        memberName: string,
        guardianName: string,
    ): Promise<ChatMessage | null> {
        const content = `${memberName}님의 가디언 ${guardianName}님이 해제되었습니다.`;
        return this.insert(tripId, 'guardian_remove', content, {
            memberName,
            guardianName,
        });
    }

    /**
     * 메시지 고정 시스템 메시지
     */
    async insertPinAdd(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 메시지를 공지로 고정했습니다.`;
        return this.insert(tripId, 'pin_add', content, { userName });
    }

    /**
     * 공지 해제 시스템 메시지
     */
    async insertPinRemove(
        tripId: string,
        userName: string,
    ): Promise<ChatMessage | null> {
        const content = `${userName}님이 공지를 해제했습니다.`;
        return this.insert(tripId, 'pin_remove', content, { userName });
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private getRoleLabel(role: string): string {
        switch (role) {
            case 'captain':
                return '캡틴';
            case 'crew_chief':
                return '크루장';
            case 'crew':
                return '크루';
            case 'guardian':
                return '가디언';
            default:
                return role;
        }
    }
}
