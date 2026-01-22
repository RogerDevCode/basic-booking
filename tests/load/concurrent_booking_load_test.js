// FIX-03 + FIX-05: Load Tests for Concurrent Bookings
// Tests database pool exhaustion and distributed locking under load

import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Metrics
const errorRate = new Rate('errors');
const bookingSuccess = new Rate('booking_success');
const bookingConflict = new Rate('booking_conflict');
const gcalFailures = new Rate('gcal_failures');
const poolTimeouts = new Rate('pool_timeouts');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:5678';
const PROFESSIONAL_ID = '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4';
const USER_ID = 'b9f03843-eee6-4607-ac5a-496c6faa9ea1';
const SERVICE_ID = 'a7a019cb-3442-4f57-8877-1b04a1749c01';

export let options = {
  stages: [
    { duration: '30s', target: 10, name: 'Warm up' },  // 10 concurrent users
    { duration: '2m', target: 25, name: 'Normal load' },  // 25 concurrent users
    { duration: '3m', target: 50, name: 'High load' },   // 50 concurrent users
    { duration: '2m', target: 100, name: 'Peak load' }, // 100 concurrent users (exceeds default pool)
    { duration: '1m', target: 50, name: 'Recovery' },   // Back to 50
    { duration: '30s', target: 10, name: 'Cool down' },  // 10 concurrent
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],  // 95% under 500ms
    'http_req_duration': ['p(99)<1000'], // 99% under 1s
    'errors': ['rate<0.05'],  // < 5% error rate
    'booking_success': ['rate>0.9'],  // > 90% booking success
  },
};

export default function () {
  const bookingTimes = generateBookingTimes();
  let timeIndex = 0;
  
  // Create booking for different time slots to spread load
  const response = http.post(`${BASE_URL}/webhook/book`, JSON.stringify({
    professional_id: PROFESSIONAL_ID,
    user_id: USER_ID,
    start_time: bookingTimes[timeIndex],
    end_time: getEndTime(bookingTimes[timeIndex]),
    service_id: SERVICE_ID
  }), {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'CreateBooking' },
  });
  
  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'has booking_id': (r) => r.json('booking_id') !== undefined,
  });

  bookingSuccess.add(success);

  if (!success) {
    errorRate.add(1);
    
    // Check if it's a conflict (expected under high concurrency)
    const isConflict = response.json('message')?.includes('occupied') || 
                       response.json('message')?.includes('LOCKED') ||
                       response.status === 409;
    
    if (isConflict) {
      bookingConflict.add(1);
    }
    
    // Check if it's a pool timeout
    const isTimeout = response.status === 503 || response.json('message')?.includes('capacity');
    if (isTimeout) {
      poolTimeouts.add(1);
    }
    
    // Check if it's a GCal failure
    const isGCalFail = response.json('sync') === 'failed' || response.json('error')?.includes('GCal');
    if (isGCalFail) {
      gcalFailures.add(1);
    }
  } else {
    // Success - log booking time for debugging
    console.log(`Booking created: ${response.json('booking_id')} at ${bookingTimes[timeIndex]}`);
  }

  // Next time slot (with wrap-around)
  timeIndex = (timeIndex + 1) % bookingTimes.length;
}

// Helper: Generate booking times for testing (spread across multiple days)
function generateBookingTimes() {
  const times = [];
  const baseDate = new Date('2026-02-01T09:00:00');
  
  // Generate 50 time slots over 3 days (spread across different dates to avoid conflict)
  for (let day = 0; day < 3; day++) {
    for (let hour = 9; hour < 18; hour++) {
      for (let min = 0; min < 60; min += 30) {
        if (times.length >= 50) break;
        const date = new Date(baseDate);
        date.setDate(date.getDate() + day);
        date.setHours(hour, min, 0, 0);
        times.push(date.toISOString());
      }
    }
  }
  
  return times;
}

// Helper: Get end time (30 min after start)
function getEndTime(startTime) {
  const start = new Date(startTime);
  start.setMinutes(start.getMinutes() + 30);
  return start.toISOString();
}
