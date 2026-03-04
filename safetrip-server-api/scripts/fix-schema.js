const { Client } = require('pg');
require('dotenv').config();

async function fixSchema() {
    const dbNames = ['safetrip_local', 'safetrip_dev', 'safetrip'];
    
    for (const dbName of dbNames) {
        console.log(`Attempting to connect to database: ${dbName}...`);
        const client = new Client({
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432'),
            user: process.env.DB_USER || 'safetrip',
            password: process.env.DB_PASSWORD || '',
            database: dbName,
        });

        try {
            await client.connect();
            console.log(`Connected to ${dbName}.`);
            
            const queries = [
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS user_role VARCHAR(20) DEFAULT 'crew'",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS is_onboarding_complete BOOLEAN DEFAULT FALSE",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS onboarding_step VARCHAR(50)",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS terms_version VARCHAR(20)",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS terms_agreed_at TIMESTAMPTZ",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS minor_status VARCHAR(20) DEFAULT 'adult'",
                "ALTER TABLE tb_user ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ"
            ];

            for (const q of queries) {
                await client.query(q);
            }
            
            console.log(`Columns added successfully to ${dbName}.`);
            await client.end();
        } catch (err) {
            console.error(`Failed to fix ${dbName}:`, err.message);
        }
    }
}

fixSchema();
