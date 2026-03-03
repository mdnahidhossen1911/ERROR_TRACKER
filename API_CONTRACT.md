# Error Tracker — REST API Contract

Your server needs **one endpoint** to receive crash reports.

---

## Endpoint

```
POST /v1/crashes
Content-Type: application/json
X-Api-Key: your-secret-key
X-Error-Tracker-Version: 2.0.0
```

---

## Request Body (JSON)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Null check operator used on a null value",
  "type": "FlutterError",
  "level": "ERROR",
  "isFatal": false,
  "fingerprint": "a3f9c120b84d",
  "sessionId": "7b3e1a2c-...",
  "sessionAgeSec": 142,
  "appLaunchTime": "2026-03-03T10:30:00.000Z",
  "createdAt": "2026-03-03T10:32:22.000Z",

  "stackTrace": "#0  main.<closure> (package:myapp/main.dart:42:7)\n#1  ...",

  "breadcrumbs": [
    {
      "message": "Navigate → /cart",
      "type": "navigation",
      "timestamp": "2026-03-03T10:32:10.000Z"
    },
    {
      "message": "tapped_pay_button",
      "type": "userAction",
      "timestamp": "2026-03-03T10:32:18.000Z",
      "data": { "item_count": 3 }
    },
    {
      "message": "POST /api/v1/payments",
      "type": "network",
      "timestamp": "2026-03-03T10:32:20.000Z",
      "data": { "method": "POST", "url": "/api/v1/payments", "status": 500 }
    }
  ],

  "device": {
    "appName": "MyApp",
    "appVersion": "1.0.0",
    "buildNumber": "12",
    "deviceModel": "Pixel 8",
    "deviceBrand": "Google",
    "osVersion": "Android 14",
    "sdkVersion": "34",
    "batteryPercentage": 76,
    "networkType": "WiFi",
    "networkSpeedMbps": 0.0,
    "totalRamMB": 8192,
    "freeRamMB": 3276,
    "totalStorageGB": 128.0,
    "freeStorageGB": 45.0,
    "cpuCores": 8,
    "appMemoryUsageMB": 118.4,
    "devicePerformanceLevel": "HIGH",
    "isPhysicalDevice": true,
    "timestamp": "2026-03-03T10:32:22.000Z"
  },

  "user": {
    "id": "user_42",
    "email": "demo@example.com",
    "name": "Demo User"
  },

  "customKeys": {
    "subscription": "premium",
    "onboarding_complete": true,
    "last_screen": "checkout"
  },

  "endpoint": null,
  "statusCode": null
}
```

> For **API errors** (`type: "ApiError"`), `endpoint` and `statusCode` are populated:
> ```json
> { "type": "ApiError", "endpoint": "/api/v1/orders", "statusCode": 503 }
> ```

---

## Response

| Status | Meaning |
|--------|---------|
| `200 OK` or `201 Created` | Report accepted ✅ |
| `400 Bad Request` | Malformed payload — SDK discards (won't retry) |
| `401 Unauthorized` | Bad API key — SDK discards |
| `5xx` | Server error — SDK retries up to 3× then queues offline |

Minimal success response:
```json
{ "status": "ok" }
```

---

## Issue Grouping (fingerprint)

The `fingerprint` field (12-char hex) is a stable hash of:
- Error class name (e.g. `FormatException`)
- Top 5 stack frames (line numbers stripped)

**Same crash = same fingerprint** regardless of specific values.

Your server should:
1. Save the full report to a `crash_reports` table
2. Upsert an `issues` row keyed by `fingerprint`:
   - Increment `count`
   - Update `last_seen`
   - Set `first_seen` only on first insert

---

## Minimal Node.js / Express Server Example

```javascript
const express = require('express');
const app = express();
app.use(express.json({ limit: '1mb' }));

const API_KEY = process.env.ERROR_TRACKER_API_KEY;

app.post('/v1/crashes', (req, res) => {
  // Auth check
  if (req.headers['x-api-key'] !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const report = req.body;

  // Validate required fields
  if (!report.id || !report.message || !report.type) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Save to your DB (Postgres, MongoDB, SQLite, etc.)
  db.crashReports.insert(report);

  // Upsert issue group
  db.issues.upsert({
    fingerprint: report.fingerprint,
    message: report.message,
    type: report.type,
    level: report.level,
    isFatal: report.isFatal,
    lastSeen: new Date(),
    $inc: { count: 1 },
    $setOnInsert: { firstSeen: new Date() },
  });

  res.status(201).json({ status: 'ok', id: report.id });
});

app.listen(3000);
```

---

## Offline Queue Behaviour

If the device has no internet when a crash occurs:

1. Report is saved to `SharedPreferences` (max 100 reports, FIFO)
2. On next app launch → automatically flushed
3. Or call manually: `ErrorTracker.flushOfflineQueue()`
4. Reports are sent oldest-first
5. If server returns 5xx → stops flushing, tries again next time

---

## Headers Sent

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `Accept` | `application/json` |
| `X-Api-Key` | Your configured API key |
| `X-Error-Tracker-Version` | `2.0.0` |
| Any custom headers from `apiConfig.headers` | |

---

## ErrorType Values

| Value | Trigger |
|-------|---------|
| `FlutterError` | Widget build, layout, rendering errors |
| `AsyncError` | Unhandled Future, async/await, Stream |
| `PlatformError` | Native/platform errors (always fatal) |
| `ApiError` | From `ErrorTracker.logApiError()` |
| `ManualLog` | From `ErrorTracker.log()` |

## ErrorLevel Values

`INFO` · `WARNING` · `ERROR` · `CRITICAL`
