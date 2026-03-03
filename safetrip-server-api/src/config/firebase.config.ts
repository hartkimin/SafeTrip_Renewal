import { registerAs } from '@nestjs/config';

export const firebaseConfig = registerAs('firebase', () => ({
    projectId: process.env.FIREBASE_PROJECT_ID || 'safetrip-urock',
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
    authEmulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
    databaseEmulatorHost: process.env.FIREBASE_DATABASE_EMULATOR_HOST,
    storageEmulatorHost: process.env.FIREBASE_STORAGE_EMULATOR_HOST,
}));
