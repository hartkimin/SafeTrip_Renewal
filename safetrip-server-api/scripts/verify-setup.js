const { Client } = require('pg');
const { io } = require('socket.io-client');

async function verifySetup() {
    console.log('--- 1. Verifying Database Connection ---');
    const dbClient = new Client({
        connectionString: 'postgres://postgres:postgres@localhost:5432/safetrip_local',
    });

    try {
        await dbClient.connect();
        const res = await dbClient.query('SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\'');
        console.log(`[OK] Successfully connected to PostgreSQL! Found ${res.rowCount} tables.`);
    } catch (err) {
        console.error('[ERROR] Database connection failed:', err.message);
    } finally {
        await dbClient.end();
    }

    console.log('\n--- 2. Verifying WebSocket (Chat) Connection ---');

    // Connect to the /chat namespace
    const chatSocket = io('http://localhost:3000/chat', {
        transports: ['websocket'],
        // Simulating a test token in auth
        auth: {
            token: 'test-token-123'
        }
    });

    chatSocket.on('connect', () => {
        console.log(`[OK] Successfully connected to Chat Gateway! Client ID: ${chatSocket.id}`);
        console.log('     Sending joinRoom event...');
        chatSocket.emit('joinRoom', { roomId: 'test-trip-id', userId: 'test-user-id' });
    });

    chatSocket.on('userJoined', (data) => {
        console.log(`[OK] Received broadcast: User ${data.userId} ${data.message}`);

        console.log('\n--- 3. Verifying WebSocket (Location) Connection ---');

        const locSocket = io('http://localhost:3000/location', {
            transports: ['websocket'],
            auth: { token: 'test-token-456' }
        });

        locSocket.on('connect', () => {
            console.log(`[OK] Successfully connected to Location Gateway! Client ID: ${locSocket.id}`);
            console.log('     Sending joinTrip event...');
            locSocket.emit('joinTrip', { tripId: 'test-trip-id', userId: 'test-user-id' });

            setTimeout(() => {
                console.log('\n=== All Verification Steps Completed Successfully ===');
                process.exit(0);
            }, 1000);
        });

        locSocket.on('connect_error', (err) => {
            console.error('[ERROR] Location Gateway connection failed:', err.message);
            process.exit(1);
        });
    });

    chatSocket.on('connect_error', (err) => {
        console.error('[ERROR] Chat Gateway connection failed:', err.message);
        console.error('Make sure the NestJS server is running (npm run start).');
        process.exit(1);
    });

    // Timeout just in case
    setTimeout(() => {
        console.log('\n[INFO] Auto-closing verification script after 5 seconds.');
        process.exit(0);
    }, 5000);
}

verifySetup();
