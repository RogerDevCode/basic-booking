# 🚀 DEPLOYMENT GUIDE: BB_06 Availability Visualization

## Quick Start (5 Minutes)

### Step 1: Import Workflow

```bash
# Open n8n UI
xdg-open https://n8n.stax.ink

# Manual Import:
# 1. Click menu (☰) → "Import from File"
# 2. Select: workflows/BB_06_Admin_Dashboard.json
# 3. Click "Import" (replaces existing)
# 4. Click "Active" toggle
```

### Step 2: Verify BB_03 is Active

```bash
# Check if BB_03 responds
curl -X POST https://n8n.stax.ink/webhook/availability-v2 \
  -H "Content-Type: application/json" \
  -d '{"professional_id":"2eebc9bc-c2f8-46f8-9e78-7da0909fcca4","service_id":"0833b301-4b02-44f4-92a4-f862575f5f6c","date":"2026-01-20"}'
```

### Step 3: Test Availability Endpoint

```bash
cd "/home/manager/Sync/N8N Projects/basic-booking"
./tests/test_bb06_availability.sh
```

### Step 4: Open Dashboard

```bash
xdg-open https://n8n.stax.ink/webhook/admin
```

**Expected Result:**

- ✅ Green events = Bookings
- ✅ Blue background = Available slots
- ✅ Metrics show correct counts

---

## API Reference

### GET /webhook/api/availability

**Query Parameters:**

- `date` (required): Date in YYYY-MM-DD format

**Example Request:**

```bash
curl "https://n8n.stax.ink/webhook/api/availability?date=2026-01-20"
```

**Success Response (200):**

```json
{
  "status": "success",
  "date": "2026-01-20",
  "slots": [
    {
      "start": "09:00",
      "end": "09:30",
      "label": "09:00 - 09:30",
      "start_iso": "2026-01-20T09:00:00.000Z",
      "end_iso": "2026-01-20T09:30:00.000Z"
    }
  ]
}
```

**Error Response (400):**

```json
{
  "error": true,
  "message": "Missing 'date' parameter",
  "status": 400
}
```

---

## Troubleshooting

### Issue: Availability endpoint returns 404

**Cause:** BB_06 not imported or not active  
**Fix:** Import workflow and activate

### Issue: Empty slots array on weekday

**Cause:** Day fully booked OR no schedule defined  
**Fix:** Check `schedules` table in database

### Issue: Calendar shows only bookings, no blue slots

**Cause:** JavaScript error in frontend OR BB_03 not responding  
**Fix:**

1. Open browser console (F12)
2. Check for errors
3. Verify BB_03 is active

### Issue: Metrics show "--" for available slots

**Cause:** Availability API call failed  
**Fix:** Check network tab in browser, verify endpoint URL

---

## Files Modified

- ✅ `workflows/BB_06_Admin_Dashboard.json` (16 nodes, 11 connections)
- ✅ `builder_bb06_availability.py` (Python generator)
- ✅ `tests/test_bb06_availability.sh` (Test suite)

---

**Last Updated:** 2026-01-18  
**Status:** Ready for Deployment
