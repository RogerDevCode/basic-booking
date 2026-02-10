# AutoAgenda - Intelligent Single-Tenant Booking System

**AutoAgenda** is a streamlined, professional scheduling platform built on **n8n**, **PostgreSQL**, and **Telegram**. It features a "Paranoid" security architecture, atomic transactions, and a context-aware deep linking system.

## 🏗️ System Architecture

### Workflows (The Core)
Standardized under the **V3** naming convention (Microservices pattern):

*   **BB_00_Global_Error_Handler:** Centralized error logging (HTML Telegram alerts + DB logs). PII redaction (40+ patterns) and rate limiting (10 errors/5min).
*   **BB_01_Telegram_Gateway:** Main entry point and router for Telegram messages.
*   **BB_02_Security_Firewall:** Validates access, manages bans, and handles routing based on user status (Authorized, New User, Blocked).
*   **BB_03_Availability_Engine:** Calculates free slots based on global resource schedules. **Path:** `/availability-v3`
*   **BB_04_Booking_Transaction:** ACID-compliant engine. Uses **Saga Pattern** for GCal/Postgres consistency. **Path:** `/book-v3`
*   **BB_05_Notification_Engine:** Batch processor for reminders (24h/2h).
*   **BB_06_Admin_Dashboard:** Full-stack SPA for the Admin UI and API. **Path:** `/admin-v3`
*   **BB_07_Notification_Retry_Worker:** Retries failed notifications with exponential backoff.
*   **BB_08_JWT_Auth_Helper:** Secure token generation (signed in n8n Node.js).
*   **BB_09_Deep_Link_Redirect:** Web-to-Telegram bridge. Converts `/agendar-v3/:slug` to bot deep links.

### Database (The Source of Truth)
PostgreSQL (Neon) Single-Tenant Schema:
*   **`providers`:** Central entity for resources. Features unique `slug`.
*   **`users`:** Client data and context. Linked to `security_firewall`.
*   **`security_firewall`:** Entity-based (e.g., `telegram:ID`) block/strike tracking.
*   **`app_config`:** Global key-value store (e.g., `ADMIN_TELEGRAM_CHAT_ID`, `SCHEDULE_START_HOUR`).
*   **`system_errors`:** Centralized log for BB_00 with severity and context.
*   **`audit_logs`:** Standardized logs (`SELECT|INSERT|UPDATE|DELETE`) for critical actions.
*   **`bookings`:** Transactional records linked to providers and users.

### Security (Paranoid Mode)
*   **Zero Secret Leakage:** JWT secrets live only in N8N/Docker env vars.
*   **Input Validation:** Every workflow starts with a **Paranoid Guard** node (Regex + Type strictness).
*   **Atomic Rollbacks:** Saga pattern in BB_04 prevents "zombie" bookings.

---

## 📝 Development Conventions

### n8n Nodes
*   **Trigger sub-workflow:** `executeWorkflowTrigger` v1.1 ("When Executed by Another Workflow").
*   **Execute sub-workflow:** `executeWorkflow` v1.1.
*   **Switch:** v3 with `fallbackOutput: "extra"`.
*   **Postgres:** v2.4 with `queryTimeout`, `continueOnFail`, and `alwaysOutputData`.
*   **Code:** v2 with mandatory `try-catch`.

### Code Patterns
*   **No Flow Control via Errors:** Never use `throw Error` for control flow.
*   **Structured Returns:** Always return `{success, error_code, error_message, data}`.
*   **Audit Logging:** Log BEFORE critical decisions.
*   **PII Safety:** Ensure any log data is redacted (handled centrally by BB_00).
*   **SQL Safety:** Use direct interpolation `{{ }}` for parameters in current n8n version.

---

## 🚀 Integration Patterns

### Workflow Routing
`Telegram Trigger -> BB_02_Security_Firewall -> Switch (granted/denied/error) -> Action`

### Error Handling
`Node with error -> Prepare Error Data -> BB_00_Global_Error_Handler`

---

## 📝 Workflow Review Methodology
1.  **FODA Analysis:** Strengths, Opportunities, Weaknesses, Threats.
2.  **QA Analysis:** Test cases, bugs, coverage.
3.  **Devil's Advocate:** Critical evaluation against production readiness.
4.  **Comparison:** Cross-check with independent reports.
5.  **Prioritized Improvement Plan:** (P0-P3 ranking).
