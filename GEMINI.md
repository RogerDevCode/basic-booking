# AutoAgenda - Intelligent Single-Tenant Booking System

**AutoAgenda** is a professional scheduling platform built on **n8n v2.4.6**, **PostgreSQL (Neon)**, and **Telegram**. It features a "Paranoid" security architecture, ACID transactions (Saga Pattern), and a modular microservices design.

## 🏗️ System Architecture

### Workflows (Microservices Pattern)
Workflows are standardized under the **V3** naming convention, with high modularity:

*   **BB_00_Global_Error_Handler:** Centralized logging, PII redaction (40+ patterns), rate limiting, and HTML Telegram alerts.
*   **BB_01_Telegram_Gateway:** Single entry point and router for bot messages.
*   **BB_02_Security_Firewall:** Identity validation, real-time access control, and behavioral blocking.
*   **BB_03_Availability_Engine (Modular):** Orchestrates 7 sub-workflows (`BB_03_00` to `BB_03_06`) for validation, schedule fetching, slot calculation, and range protection (`MAX_SLOTS`).
*   **BB_04_Booking_Transaction:** ACID-compliant engine using **Saga Pattern** for GCal/Postgres atomicity.
*   **BB_05_Notification_Engine:** Reminders (24h/2h) batch processor.
*   **BB_06_Admin_Dashboard:** Full-stack SPA backend and Admin API.
*   **BB_07_Notification_Retry_Worker:** Exponential backoff retry system.
*   **BB_08_JWT_Auth_Helper:** Secure administrative token generation.
*   **BB_09_Deep_Link_Redirect:** Web-to-Bot bridge (`/agendar-v3/:slug`).

### Database (The Source of Truth)
PostgreSQL (Neon) Single-Tenant Schema with 15+ tables:
*   **`users`:** Clients with roles, RUT, and context.
*   **`providers`:** Entities with unique slugs and specific slot configs.
*   **`bookings`:** Transactional records with `gcal_event_id`.
*   **`app_config`:** Global K-V store (Timezone, limits, branding).
*   **`security_firewall` / `audit_logs`:** Strike tracking and detailed event trail.
*   **`notification_queue` / `configs`:** Asynchronous notification management.
*   **`system_errors` / `error_metrics` / `circuit_breaker_state`:** Observability and stability.

### Security (Paranoid Mode)
*   **Zero Leakage:** Secrets stored in environment variables; PII redacted in logs.
*   **Strict Guard Nodes:** Every workflow starts with a **Paranoid Guard** (Code v2) for regex/type validation.
*   **Atomic Rollbacks:** Saga Pattern in BB_04 prevents "zombie" entries in GCal or DB.
*   **Circuit Breaker:** State-based protection for unstable external APIs.

---

## 📝 Development Conventions (SOT-N8N-2.4.6)

### n8n Node Versions
| Node | Version | Requirement |
| :--- | :---: | :--- |
| **Postgres** | **v2.4** | Mandatory SQL parameterization ($1, $2). No string concatenation. |
| **Switch** | **v3** | Must include fallback output. Strict type checking. |
| **Code** | **v2** | Mandatory `try-catch`. Use for sanitization and complex logic. |
| **Webhook** | **v1** | Stable response mode. |

### Code & SQL Patterns
*   **Structured Returns:** Always return `{success, error_code, error_message, data}`.
*   **Audit First:** Log BEFORE critical decisions.
*   **SQL Safety:** Convert arrays to PG format `{{ "{" + arr.join(",") + "}" }}`. Use `$1` for params.
*   **Timezone:** All calculations in UTC; `TIMEZONE` from `app_config` for local derivation.

---

