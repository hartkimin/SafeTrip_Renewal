-- B2B Tables Creation Script
CREATE TABLE IF NOT EXISTS tb_b2b_organization (
    org_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    org_name VARCHAR(200) NOT NULL,
    org_type VARCHAR(30) NOT NULL DEFAULT 'corporate',
    business_number VARCHAR(20),
    contact_name VARCHAR(50),
    contact_email VARCHAR(200),
    contact_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS tb_b2b_contract (
    contract_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    contract_code VARCHAR(20) UNIQUE,
    contract_type VARCHAR(20),
    company_name VARCHAR(200),
    contact_name VARCHAR(100),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    max_groups INT DEFAULT 1,
    max_members_per_group INT DEFAULT 50,
    max_trips INT,
    guardian_model VARCHAR(20) DEFAULT 'A',
    sla_level VARCHAR(20) DEFAULT 'standard',
    started_at DATE,
    expires_at DATE,
    status VARCHAR(20) DEFAULT 'active',
    school_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    org_id UUID,
    contract_name VARCHAR(200),
    start_date DATE,
    end_date DATE,
    max_members INT,
    current_trip_count INT,
    forced_privacy_level VARCHAR(30),
    forced_sharing_mode VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_b2b_contract_type ON tb_b2b_contract (contract_type);
CREATE INDEX IF NOT EXISTS idx_b2b_contract_status ON tb_b2b_contract (status);
CREATE TABLE IF NOT EXISTS tb_b2b_admin (
    admin_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    org_id UUID NOT NULL,
    user_id VARCHAR(128) NOT NULL,
    admin_role VARCHAR(20) DEFAULT 'org_admin',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS tb_b2b_dashboard_config (
    config_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    org_id UUID NOT NULL,
    contract_id UUID,
    config_key VARCHAR(100) NOT NULL,
    config_value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS tb_b2b_school (
    school_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    school_name VARCHAR(200) NOT NULL,
    school_code VARCHAR(50),
    region VARCHAR(100),
    district VARCHAR(100),
    school_type VARCHAR(20),
    contact_teacher VARCHAR(100),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS tb_b2b_invite_batch (
    batch_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    contract_id UUID NOT NULL,
    group_id UUID,
    batch_name VARCHAR(200),
    target_role VARCHAR(30) NOT NULL,
    total_count INT NOT NULL,
    used_count INT DEFAULT 0,
    csv_file_url TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_by VARCHAR(128),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_b2b_invite_batch_contract ON tb_b2b_invite_batch (contract_id);
CREATE TABLE IF NOT EXISTS tb_b2b_member_log (
    log_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    batch_id UUID NOT NULL,
    user_id VARCHAR(128),
    invite_code VARCHAR(7),
    joined_at TIMESTAMPTZ,
    member_role VARCHAR(30),
    minor_consent_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
