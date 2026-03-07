/**
 * scripts/verify_api_integration.js
 * 
 * Verifies the Next.js Backoffice to NestJS Backend API integration.
 * Uses x-test-bypass headers to bypass Firebase auth for testing.
 */

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001/api/v1';

const headers = {
    'Content-Type': 'application/json',
    'x-test-bypass': 'true',
    'x-test-user-id': 'backoffice-admin'
};

const endpointsToTest = [
    { name: 'Admin Dashboard Stats (Emergencies)', method: 'GET', path: '/emergencies', query: '?status=active' },
    { name: 'Admin Dashboard Stats (Users)', method: 'GET', path: '/users/admin/stats' },
    { name: 'Admin Dashboard Stats (Trips)', method: 'GET', path: '/trips/admin/stats' },
    { name: 'Admin Dashboard Stats (B2B Org)', method: 'GET', path: '/b2b/organizations' },
    { name: 'Administrative User List', method: 'GET', path: '/users/admin/list?page=1&limit=10' },
    { name: 'Administrative Trip List', method: 'GET', path: '/trips/admin/list?page=1&limit=10' }
];

async function runTests() {
    console.log(`🚀 Starting API Integration Verification against: ${BASE_URL}\n`);
    let passed = 0;
    let failed = 0;

    for (const test of endpointsToTest) {
        const url = `${BASE_URL}${test.path}${test.query || ''}`;
        console.log(`▶ Testing [${test.name}]`);
        console.log(`  Target: ${test.method} ${url}`);

        try {
            const response = await fetch(url, { method: test.method, headers });
            const data = await response.json().catch(() => null);

            if (response.ok) {
                console.log(`  ✅ Success! Status: ${response.status}`);
                // Basic payload validation
                if (data) {
                    const isArray = Array.isArray(data) || Array.isArray(data.data);
                    console.log(`     Payload parsed successfully (Is Array/List: ${isArray})`);
                }
                passed++;
            } else {
                console.error(`  ❌ Failed (Status ${response.status}):`, data?.message || data?.error || 'Unknown Error');
                failed++;
            }
        } catch (error) {
            console.error(`  ❌ Network/Execution Error:`, error.message);
            failed++;
        }
        console.log('');
    }

    console.log(`\n=================================================`);
    console.log(`🏁 Verification Complete: ${passed} Passed | ${failed} Failed`);
    console.log(`=================================================`);

    if (failed > 0) process.exit(1);
}

runTests();
