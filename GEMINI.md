# AutoAgenda - Intelligent SaaS Booking System

**AutoAgenda** is a robust, multi-tenant booking and scheduling platform built on **n8n**, **PostgreSQL**, and **Telegram**. It features a "Paranoid" security architecture, atomic transactions, and a fully dynamic Admin Dashboard.

## 🏗️ System Architecture

### Workflows (The Core)

The system is orchestrated by a series of specialized n8n workflows (Microservices pattern):

* **BB_00_Global_Error_Handler:** Centralized error logging (HTML Telegram alerts + DB logs).
* **BB_01_Telegram_Gateway:** Main entry point. Normalizes inputs, handles routing, and orchestrates sub-workflows.
* **BB_02_Security_Firewall:** Rate limiting, strike system (3 strikes = ban), and blacklist enforcement.
* **BB_03_Availability_Engine:** Calculates free slots based on Postgres schedules and existing bookings. **Path:** `/availability-v3`
* **BB_04_Booking_Transaction:** ACID-compliant booking engine. Uses **Saga Pattern** to ensure consistency between Google Calendar and Postgres. **Path:** `/book-v3`
* **BB_05_Notification_Engine:** Batch processor for reminders (24h/2h).
* **BB_06_Admin_Dashboard:** Full-stack SPA (Single Page Application) serving the Admin UI and API. **Path:** `/admin-v3`
* **BB_07_Notification_Retry_Worker:** Retries failed notifications with exponential backoff.
* **BB_08_JWT_Auth_Helper:** Utility for token generation.
* **BB_09_Deep_Link_Redirect:** Web-to-Telegram bridge. Converts HTTP deep links to bot deep links with slug validation. **Path:** `/agendar-v3/:slug`

### Database (The Source of Truth)

PostgreSQL (Neon) holds all business logic and configuration:

* **`app_config`:** Centralized key-value store for business rules (e.g., `SLOT_DURATION_MINS`, `COLOR_PRIMARY`, `TELEGRAM_BOT_USERNAME`).
* **`app_messages`:** i18n support for error messages.
* **`users`:** Identity provider with `password_hash` (pgcrypto) for Admin Login.
* **`professionals`:** Catalog of professionals with unique slugs for deep link routing (BB_09).
* **`audit_logs`:** Immutable trail of all critical actions.
* **`bookings`:** Transactional data with strict constraints.

### Security (Paranoid Mode)

* **Input Validation:** "Paranoid Guards" in every workflow reject invalid types, strict UUIDs, and logical impossibilities (e.g., end time < start time).
* **Authentication:** Custom JWT implementation. Login verifies against DB hash -> DB generates Token -> N8N verifies signature using shared secret.
* **Secrets:** Managed via `.env` (`JWT_SECRET`).
* **Infrastructure:** Rate limiting and CSP headers configured at Nginx level.

---

## 🚀 Usage & Deployment

### 1. Environment Setup

Create a `.env` file (see `.env.example`) with:

```env
JWT_SECRET=AutoAgenda_Secret_Key_2026_Secure
DB_POSTGRESDB_POOL_MIN=10
...
```

### 2. Database Migrations

Migrations are located in `database/`. Key initialization scripts:

* `schema.sql`: Base schema.
* `migration_v7_app_config.sql`: Seeds default configuration.
* `migration_jwt_setup_fix.sql`: Sets up Auth functions and default admin (`admin` / `admin123`).

### 3. Dashboard Access

* **URL:** `https://your-n8n-instance/webhook/admin-v3`
* **Default Credentials:** `admin` / `admin123`
* **Features:** View stats, manage calendar, update system config (colors, hours) dynamically.

---

## 🧪 Testing & Verification

The project includes a comprehensive test suite in `tests/`:

* **`tests/doomsday_audit.sh`:** End-to-End stress test. Simulates concurrency races and full flow orchestration.
* **`tests/paranoid_audit_v3.sh`:** Fuzzing and security test. Injects malicious payloads (SQLi, XSS, Type Confusion) to verify Guards.
* **`tests/run_all_tests.sh`:** Master runner.

**Run Verification:**

```bash
bash tests/doomsday_audit.sh
```

---

## 📂 Directory Structure

* `workflows/`: JSON definitions of n8n workflows (Version controlled).
* `database/`: SQL migration scripts.
* `scripts/`: Python/Bash utilities for building and deploying.
* `tests/`: QA scripts.
* `dashboard_*.html`: Source code for the frontend UI (injected into BB_06).

## 📝 Development Conventions

* **Zero Hardcoding:** Never put IDs or settings in nodes. Use `app_config` table.
* **Fail Fast:** Guards must throw errors immediately on invalid input.
* **Safe SQL:** Use parameterized queries or safe interpolation `{{ }}` for N8N compatibility.
* **V3 Endpoints:** All public webhooks use `-v3` suffix to avoid "zombie" caching issues.
