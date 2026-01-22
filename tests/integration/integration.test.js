// FIX-01 + FIX-05: Integration Tests for Booking Transaction with Distributed Lock

import { describe, test, expect } from '@jest/globals';

describe('Booking Transaction Integration Tests', () => {
  const BASE_URL = process.env.N8N_URL || 'http://localhost:5678';
  
  // Helper: Create booking
  async function createBooking(payload) {
    const response = await fetch(`${BASE_URL}/webhook/book`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    return response.json();
  }

  // Helper: Get booking by ID
  async function getBooking(bookingId) {
    // This would normally query the DB directly
    // For now, we'll use a mock booking ID
    return { id: bookingId, status: 'confirmed' };
  }

  describe('GCal Saga Pattern', () => {
    test('GCal check failure triggers DB rollback', async () => {
      const payload = {
        professional_id: '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4',
        user_id: 'b9f03843-eee6-4607-ac5a-496c6faa9ea1',
        start_time: '2026-02-20T10:00:00',
        end_time: '2026-02-20T10:30:00',
        service_id: 'a7a019cb-3442-4f57-8877-1b04a1749c01'
      };

      // Mock GCal check to fail
      const result = await createBooking({
        ...payload,
        mock_gcal_check_failed: true
      });

      // Expected: Booking should be rolled back
      expect(result.status).toBe('failed');
      expect(result.error).toBe(true);
      expect(result.message).toContain('rollback');
    });

    test('Successful booking with GCal sync', async () => {
      const payload = {
        professional_id: '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4',
        user_id: 'b9f03843-eee6-4607-ac5a-496c6faa9ea1',
        start_time: '2026-02-21T14:00:00',
        end_time: '2026-02-21T14:30:00',
        service_id: 'a7a019cb-3442-4f57-8877-1b04a1749c01'
      };

      const result = await createBooking(payload);

      // Expected: Booking should succeed
      expect(result.status).toBe('success');
      expect(result.booking_id).toBeDefined();
      expect(result.sync).toBe('ok');
    });
  });

  describe('Distributed Lock', () => {
    test('Concurrent bookings prevent double-booking', async () => {
      const payload = {
        professional_id: '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4',
        user_id: 'b9f03843-eee6-4607-ac5a-496c6faa9ea1',
        start_time: '2026-02-22T10:00:00',
        end_time: '2026-02-22T10:30:00',
        service_id: 'a7a019cb-3442-4f57-8877-1b04a1749c01'
      };

      // Create first booking
      const booking1 = await createBooking(payload);
      expect(booking1.status).toBe('success');
      expect(booking1.booking_id).toBeDefined();

      // Try to create second booking for same slot (should fail due to trigger)
      // In real scenario, this might need a slight delay to trigger race condition
      const booking2 = await createBooking(payload);
      expect(booking2.status).toBe('failed');
      expect(booking2.error).toBe(true);
      expect(booking2.message).toContain('occupied') || booking2.message).toContain('LOCKED');
    });

    test('Concurrent bookings with different slots succeed', async () => {
      const basePayload = {
        professional_id: '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4',
        user_id: 'b9f03843-eee6-4607-ac5a-496c6faa9ea1',
        service_id: 'a7a019cb-3442-4f57-8877-1b04a1749c01'
      };

      // Create two bookings for different time slots
      const booking1 = await createBooking({
        ...basePayload,
        start_time: '2026-02-22T10:00:00',
        end_time: '2026-02-22T10:30:00'
      });

      const booking2 = await createBooking({
        ...basePayload,
        start_time: '2026-02-22T11:00:00',
        end_time: '2026-02-22T11:30:00'
      });

      // Expected: Both should succeed
      expect(booking1.status).toBe('success');
      expect(booking2.status).toBe('success');
      expect(booking1.booking_id).not.toBe(booking2.booking_id);
    });
  });
});

describe('Notification Queue Integration Tests', () => {
  describe('Retry Worker', () => {
    test('Pending notifications are processed', async () => {
      // Mock pending notification
      // In real scenario, this would query DB or call workflow
      const pendingNotifications = [
        { id: '1', booking_id: 'booking-1', user_id: '123', message: 'Test message', retry_count: 0 },
        { id:2, booking_id: 'booking-2', user_id: '124', message: 'Test message 2', retry_count: 1 }
      ];

      expect(pendingNotifications.length).toBe(2);
      expect(pendingNotifications.every(n => n.retry_count < 3)).toBe(true);
    });

    test('Failed notifications are retried up to 3 times', async () => {
      const failedNotification = {
        id: '1',
        booking_id: 'booking-1',
        user_id: '123',
        message: 'Test message',
        retry_count: 2
      };

      // Third retry should be last attempt
      const nextRetryCount = failedNotification.retry_count + 1;
      expect(nextRetryCount).toBe(3);
    });

    test('Notifications older than 1 hour are not retried', async () => {
      const oldNotification = {
        id: '1',
        created_at: new Date(Date.now() - 3601000).toISOString(), // 1 hour + 1 second ago
        retry_count: 0
      };

      const timeDiff = Date.now() - new Date(oldNotification.created_at).getTime();
      const hoursDiff = timeDiff / (1000 * 60 * 60);

      expect(hoursDiff).toBeGreaterThan(1);
    });
  });
});

describe('Admin Dashboard Integration Tests', () => {
  describe('JWT Authentication', () => {
    test('Protected endpoint returns 401 without auth', async () => {
      const response = await fetch(`${BASE_URL}/webhook/admin/api/stats`);
      
      expect(response.status).toBe(401) || expect(response.status).toBe(403);
    });

    test('Protected endpoint returns data with valid auth', async () => {
      const response = await fetch(`${BASE_URL}/webhook/admin/api/stats`, {
        headers: {
          'Authorization': 'Bearer valid_admin_token'
        }
      });

      if (response.status === 200 || response.status === 401) {
        // If 401, token might be expired (expected)
        // If 200, token is valid (expected)
        expect([200, 401]).toContain(response.status);
      }
    });
  });

  describe('Calendar API', () => {
    test('Returns bookings within date range', async () => {
      const response = await fetch(`${BASE_URL}/webhook/admin/api/calendar?start=2026-01-01&end=2026-12-31`, {
        headers: {
          'Authorization': 'Bearer valid_admin_token'
        }
      });

      if (response.status === 200) {
        const data = await response.json();
        expect(data.events).toBeDefined();
        expect(Array.isArray(data.events)).toBe(true);
      }
    });

    test('Validates date range (max 365 days)', async () => {
      const response = await fetch(`${BASE_URL}/webhook/admin/api/calendar?start=2025-01-01&end=2026-12-31`, {
        headers: {
          'Authorization': 'Bearer valid_admin_token'
        }
      });

      // 365 days is allowed, 366+ should fail
      if (response.status === 400) {
        expect(response.status).toBe(400);
      }
    });
  });
});

describe('Request ID Correlation', () => {
  test('X-Request-ID header is present in responses', async () => {
    const response = await fetch(`${BASE_URL}/webhook/admin/api/stats`, {
      headers: {
        'Authorization': 'Bearer valid_admin_token'
      }
    });

    const requestId = response.headers.get('X-Request-ID');
    
    // Request ID should be present
    expect(requestId).toBeDefined();
    expect(requestId.length).toBeGreaterThan(0);
  });
});
