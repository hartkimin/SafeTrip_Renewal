// 여행 관련 타입

export interface Trip {
  trip_id: string;
  group_id: string; // 그룹 ID (1:N 관계)
  country_code: string;
  start_date: string;
  end_date: string;
  trip_type: 'individual' | 'group';
  status: 'planned' | 'active' | 'completed' | 'cancelled';
  created_at: string;
}

export interface Group {
  group_id: string;
  // trip_id 제거 (N:M 관계로 변경, TB_GROUP_TRIP 중간 테이블 사용)
  group_name: string;
  group_code: string;
  max_members: number;
  created_at: string;
}

