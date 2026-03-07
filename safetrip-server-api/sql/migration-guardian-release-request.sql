-- ============================================================
-- SafeTrip DB Migration: TB_GUARDIAN_RELEASE_REQUEST
-- DOC-T3-MBR-019 §10.2 — 미성년자 가디언 해제 요청
-- ============================================================

CREATE TABLE IF NOT EXISTS tb_guardian_release_request (
    request_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id       UUID NOT NULL REFERENCES tb_guardian_link(link_id) ON DELETE CASCADE,
    trip_id       UUID NOT NULL REFERENCES tb_trip(trip_id) ON DELETE CASCADE,
    requested_by  VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
    captain_id    VARCHAR(128) REFERENCES tb_user(user_id),
    responded_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guardian_release_request_link
    ON tb_guardian_release_request(link_id);
CREATE INDEX IF NOT EXISTS idx_guardian_release_request_trip
    ON tb_guardian_release_request(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_guardian_release_request_requested_by
    ON tb_guardian_release_request(requested_by);
