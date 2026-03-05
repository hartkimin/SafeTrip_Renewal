-- ============================================================
-- SafeTrip DB Schema v3.5.1
-- 00: Extensions & Types
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_5.md
-- ============================================================

-- PostGIS (지리 데이터 지원)
CREATE EXTENSION IF NOT EXISTS postgis;

-- UUID 생성
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- ENUM Types (비즈니스 원칙 v5.1 기반)
-- ============================================================

-- 역할 체계 (§01)
-- 참고: 현재 스키마는 VARCHAR + CHECK 제약조건 사용 (TypeORM 호환)
-- 아래는 참조용 ENUM 정의. 실제 테이블은 VARCHAR + CHECK 방식.

-- member_role: captain | crew_chief | crew | guardian
-- trip_status: planning | active | completed
-- privacy_level: safety_first | standard | privacy_first
-- sharing_mode: forced | voluntary
-- schedule_type: always | time_based | schedule_linked
-- visibility_type: all | admin_only | specified
-- guardian_type: personal | group
-- guardian_link_status: pending | accepted | rejected | cancelled
-- payment_type: trip_base | addon_movement | addon_ai_plus | addon_ai_pro | addon_guardian | b2b_contract
-- notification_type: sos | guardian_alert | geofence | schedule | member_join | location_request
-- user_status: active | inactive | banned
-- minor_status: adult | minor_over14 | minor_under14 | minor_child
-- group_type: travel | b2b_school | b2b_corporate
-- geofence_type: safe | watch | danger
-- guardian_request_status: pending | approved | ignored | expired
-- sos_status: active | resolved | cancelled
-- payment_status: pending | completed | failed | refunded
-- subscription_plan_type: addon_ai_plus | addon_ai_pro
-- refund_policy: planning_full | active_24h_50pct | active_post_24h_0 | completed_0
-- b2b_contract_type: school | agency | corporate | insurance
