-- 17-view-trip-card.sql
-- TB_TRIP_CARD_VIEW: 여행정보카드 렌더링 전용 뷰 (DOC-T3-TIC-024 §11.3)

CREATE OR REPLACE VIEW tb_trip_card_view AS
SELECT
    t.trip_id,
    t.trip_name,
    t.status,
    t.start_date,
    t.end_date,
    t.end_date - t.start_date                          AS trip_days,
    t.privacy_level,
    t.sharing_mode,
    t.schedule_type,
    t.country_code,
    t.country_name,
    t.destination_city,
    t.has_minor_members,
    t.reactivated_at,
    t.reactivation_count,
    t.group_id,
    t.updated_at,
    -- D-day 계산 (§03.2)
    CASE
        WHEN t.status = 'active'    THEN 0
        WHEN t.status = 'planning'  THEN (t.start_date - CURRENT_DATE)
        ELSE NULL
    END                                                 AS d_day,
    -- 현재 진행 일차
    CASE
        WHEN t.status = 'active'
            THEN (CURRENT_DATE - t.start_date + 1)
        ELSE NULL
    END                                                 AS current_day,
    -- 활성 멤버 수 (가디언 제외)
    (
        SELECT COUNT(*)
        FROM tb_group_member gm
        WHERE gm.trip_id = t.trip_id
          AND gm.status = 'active'
          AND gm.member_role IN ('captain', 'crew_chief', 'crew')
    )                                                   AS member_count,
    -- 재활성화 가능 여부 (§04.5: 종료 후 24시간 이내 + 0회)
    CASE
        WHEN t.status = 'completed'
         AND t.reactivation_count = 0
         AND t.updated_at > NOW() - INTERVAL '24 hours'
            THEN TRUE
        ELSE FALSE
    END                                                 AS can_reactivate
FROM tb_trip t
WHERE t.deleted_at IS NULL;
