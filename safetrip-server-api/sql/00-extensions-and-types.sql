-- ============================================================
-- SafeTrip DB Schema v3.4.1
-- 00: Extensions & Types
-- 기준 문서: 07_T2_DB_설계_및_관계_v3_4.md
-- ============================================================

-- PostGIS (지리 데이터 지원)
CREATE EXTENSION IF NOT EXISTS postgis;

-- UUID 생성
CREATE EXTENSION IF NOT EXISTS pgcrypto;
