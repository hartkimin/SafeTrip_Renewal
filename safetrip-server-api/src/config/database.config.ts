import { registerAs } from '@nestjs/config';

export const databaseConfig = registerAs('database', () => ({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    name: process.env.DB_NAME || 'safetrip_local',
    user: process.env.DB_USER || 'safetrip',
    password: process.env.DB_PASSWORD || '',
    ssl: process.env.DB_SSL === 'true',
}));
