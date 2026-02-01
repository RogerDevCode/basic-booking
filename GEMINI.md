# AutoAgenda - Intelligent Single-Tenant Booking System

**AutoAgenda** is a streamlined, professional scheduling platform built on **n8n**, **PostgreSQL**, and **Telegram**. It features a "Paranoid" security architecture, atomic transactions, and a context-aware deep linking system.

## 🏗️ System Architecture

### Workflows (The Core)
The system is orchestrated by specialized n8n workflows (Microservices pattern), all standardized under the **V3** naming convention:

*   **BB_00_Global_Error_Handler:** Centralized error logging (HTML Telegram alerts + DB logs).
*   **BB_01_Telegram_Gateway:** Main entry point. Handles user context and routing via Telegram.
*   **BB_02_Security_Firewall:** Rate limiting and blacklist enforcement.
*   **BB_03_Availability_Engine:** Calculates free slots based on global resource schedules. **Path:** `/availability-v3`
*   **BB_04_Booking_Transaction:** ACID-compliant engine. Uses **Saga Pattern** to ensure consistency between GCal and Postgres. **Path:** `/book-v3`
*   **BB_05_Notification_Engine:** Batch processor for reminders (24h/2h).
*   **BB_06_Admin_Dashboard:** Full-stack SPA serving the Admin UI and API. **Path:** `/admin-v3`
*   **BB_07_Notification_Retry_Worker:** Retries failed notifications with exponential backoff.
*   **BB_08_JWT_Auth_Helper:** Secure token generation (signed in n8n Node.js).
*   **BB_09_Deep_Link_Redirect:** Web-to-Telegram bridge. Converts URLs like `/agendar/:slug` to bot deep links.

### Database (The Source of Truth)
PostgreSQL (Neon) architecture has been simplified to **Single-Tenant**:
*   **`providers`:** Central entity for resources (formerly professionals). Features unique `slug` for deep linking.
*   **`app_config`:** Global key-value store for system behavior (e.g., `TELEGRAM_BOT_USERNAME`, `SCHEDULE_START_HOUR`).
*   **`users`:** Stores client data and maintains context via `last_selected_provider_id`.
*   **`audit_logs`:** Standardized logs with `event_type`, `event_data`, and `created_at`.
*   **`bookings`:** Transactional records linked to providers and users.

### Security (Paranoid Mode)
*   **Zero Secret Leakage:** JWT secrets live only in N8N/Docker env vars. Database functions for signing have been removed.
*   **Input Validation:** Every workflow starts with a **Paranoid Guard** node (Regex + Type strictness).
*   **Atomic Rollbacks:** Saga pattern in BB_04 prevents "zombie" bookings.

---

## 🚀 Usage & Operations

### Deep Linking
To share a specific provider's schedule:
`https://n8n.stax.ink/webhook/agendar-v3/{slug}`

### Administration
Access the secure dashboard at:
`https://n8n.stax.ink/webhook/admin-v3` (Requires JWT Login)

---

## 📝 Development Conventions
*   **Neutral Naming:** Use `provider` instead of `professional/doctor`.
*   **Fail Fast:** Webhooks return styled HTML (400/404) on validation failure.
*   **SQL Safety:** Use direct interpolation `{{ }}` for parameters in current n8n version to ensure compatibility.