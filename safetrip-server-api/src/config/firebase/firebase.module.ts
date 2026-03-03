import { Module, Global } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

export const FIREBASE_APP = 'FIREBASE_APP';

@Global()
@Module({
    providers: [
        {
            provide: FIREBASE_APP,
            inject: [ConfigService],
            useFactory: (config: ConfigService): admin.app.App => {
                const projectId = config.get<string>('firebase.projectId');
                const clientEmail = config.get<string>('firebase.clientEmail');
                const privateKey = config.get<string>('firebase.privateKey');
                const databaseURL = config.get<string>('firebase.databaseURL');

                // Emulator 환경 설정
                const authEmulator = config.get<string>('firebase.authEmulatorHost');
                if (authEmulator) {
                    process.env.FIREBASE_AUTH_EMULATOR_HOST = authEmulator;
                }
                const dbEmulator = config.get<string>('firebase.databaseEmulatorHost');
                if (dbEmulator) {
                    process.env.FIREBASE_DATABASE_EMULATOR_HOST = dbEmulator;
                }

                if (admin.apps.length > 0) {
                    return admin.apps[0]!;
                }

                const isMockKey = !privateKey || privateKey.includes('your_') || privateKey.includes('MIIEvA');
                return admin.initializeApp({
                    credential:
                        clientEmail && privateKey && !isMockKey
                            ? admin.credential.cert({ projectId, clientEmail, privateKey: privateKey.replace(/\\n/g, '\n') })
                            : {
                                getAccessToken: async () => ({
                                    access_token: 'mock-token',
                                    expires_in: 3600,
                                })
                            },
                    databaseURL,
                    projectId: isMockKey ? 'demo-safetrip' : projectId,
                });
            },
        },
    ],
    exports: [FIREBASE_APP],
})
export class FirebaseModule { }
