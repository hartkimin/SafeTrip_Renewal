import axios from 'axios';

const BASE_URL = 'http://localhost:3001/api/v1';

async function testMinorProtection() {
    console.log('--- Testing Minor Protection ---');
    
    const adultId = 'adult-user-' + Date.now();
    const minorId = 'minor-user-' + Date.now();

    // 1. Register Adult
    await axios.post(`${BASE_URL}/users/register`, {
        user_id: adultId,
        display_name: 'Adult User',
        phone_number: '+821011112222'
    });
    console.log('Adult registered.');

    // 2. Register Minor
    await axios.post(`${BASE_URL}/users/register`, {
        user_id: minorId,
        display_name: 'Minor User',
        phone_number: '+821033334444'
    });
    
    // Update minor's birthdate
    await axios.put(`${BASE_URL}/users/${minorId}`, {
        display_name: 'Minor User',
        date_of_birth: '2015-01-01'
    });
    console.log('Minor registered and birthdate updated.');

    // 3. Adult creates a trip
    const tripRes = await axios.post(`${BASE_URL}/trips`, {
        tripName: 'Family Trip',
        startDate: '2026-06-01',
        endDate: '2026-06-10',
        privacyLevel: 'standard'
    }, {
        headers: { 'x-test-bypass': 'true', 'x-test-user-id': adultId }
    });
    
    const tripId = tripRes.data.tripId;
    const inviteCode = tripRes.data.inviteCode;
    console.log(`Trip created by Adult: ${tripId}, Privacy Level: ${tripRes.data.privacyLevel}`);

    // 4. Minor joins the trip
    console.log('Minor joining the trip...');
    await axios.post(`${BASE_URL}/trips/join`, {
        invite_code: inviteCode
    }, {
        headers: { 'x-test-bypass': 'true', 'x-test-user-id': minorId }
    });

    // 5. Verify Privacy Level became safety_first
    const updatedTripRes = await axios.get(`${BASE_URL}/trips/${tripId}`);
    console.log(`Updated Trip Privacy Level: ${updatedTripRes.data.data.privacyLevel}`);
    
    if (updatedTripRes.data.data.privacyLevel === 'safety_first' && updatedTripRes.data.data.hasMinorMembers === true) {
        console.log('✅ Minor Protection Enforcement: Success');
    } else {
        console.log('❌ Minor Protection Enforcement: Failed');
    }

    // 6. Attempt to change privacyLevel back to standard
    try {
        await axios.patch(`${BASE_URL}/trips/${tripId}`, {
            privacyLevel: 'standard'
        }, {
            headers: { 'x-test-bypass': 'true', 'x-test-user-id': adultId }
        });
        console.log('❌ Privacy Level modification restriction: Failed (Should have thrown error)');
    } catch (error: any) {
        if (error.response?.status === 400 && error.response.data.message.includes('safety_first')) {
            console.log('✅ Privacy Level modification restriction: Success');
        } else {
            console.log('❌ Privacy Level modification restriction: Failed', error.response?.data);
        }
    }
}

async function run() {
    try {
        await testMinorProtection();
    } catch (error: any) {
        console.error('Test execution error:', error.response?.data || error.message);
    }
    process.exit(0);
}

run();
