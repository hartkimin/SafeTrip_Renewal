// 사용자 관련 타입

export interface User {
  user_id: string;
  phone_number: string;
  display_name?: string;
  created_at: string;
  is_phone_verified: boolean;
  last_active_at?: string;
}

export interface Guardian {
  guardian_id: string;
  user_id: string;
  guardian_phone_number: string;
  guardian_name: string;
  relationship: string;
  created_at: string;
}

