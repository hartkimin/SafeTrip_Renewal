import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';

// Config
import { databaseConfig } from './config/database.config';
import { firebaseConfig } from './config/firebase.config';
import { appConfig } from './config/app.config';

// Core
import { LoggerModule } from './common/logger/logger.module';
import { FirebaseModule } from './config/firebase/firebase.module';
import { HealthModule } from './modules/health/health.module';

// Domain modules
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { GroupsModule } from './modules/groups/groups.module';
import { TripsModule } from './modules/trips/trips.module';
import { GuardiansModule } from './modules/guardians/guardians.module';
import { LocationsModule } from './modules/locations/locations.module';
import { GeofencesModule } from './modules/geofences/geofences.module';
import { EmergenciesModule } from './modules/emergencies/emergencies.module';
import { ChatsModule } from './modules/chats/chats.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { B2bModule } from './modules/b2b/b2b.module';
import { CountriesModule } from './modules/countries/countries.module';
import { GuidesModule } from './modules/guides/guides.module';
import { EventLogModule } from './modules/event-log/event-log.module';
import { MofaModule } from './modules/mofa/mofa.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { AiModule } from './modules/ai/ai.module';

@Module({
    imports: [
        // ── Configuration ──────────────────────────────────────────────
        ConfigModule.forRoot({
            isGlobal: true,
            load: [appConfig, databaseConfig, firebaseConfig],
            envFilePath: ['.env', '.env.local'],
        }),

        // ── Database (TypeORM + PostgreSQL) ────────────────────────────
        TypeOrmModule.forRootAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: (config: ConfigService) => ({
                type: 'postgres',
                host: config.get<string>('database.host'),
                port: config.get<number>('database.port'),
                database: config.get<string>('database.name'),
                username: config.get<string>('database.user'),
                password: config.get<string>('database.password'),
                ssl: config.get<boolean>('database.ssl')
                    ? { rejectUnauthorized: false }
                    : false,
                autoLoadEntities: true,
                synchronize: false, // 프로덕션 절대 true 금지 — 마이그레이션 사용
                logging: config.get<string>('app.nodeEnv') === 'development',
                extra: {
                    max: 20,
                    idleTimeoutMillis: 30000,
                    connectionTimeoutMillis: 2000,
                },
            }),
        }),

        // ── Scheduling (Cron jobs) ─────────────────────────────────────
        ScheduleModule.forRoot(),

        // ── Core ───────────────────────────────────────────────────────
        LoggerModule,
        FirebaseModule,
        HealthModule,

        // ── Domain Modules ────────────────────────────────────────────
        AuthModule,
        UsersModule,
        GroupsModule,
        TripsModule,
        GuardiansModule,
        LocationsModule,
        GeofencesModule,
        EmergenciesModule,
        ChatsModule,
        NotificationsModule,
        PaymentsModule,
        B2bModule,
        CountriesModule,
        GuidesModule,
        EventLogModule,
        MofaModule,
        TasksModule,
        AiModule,
    ],
})
export class AppModule { }
