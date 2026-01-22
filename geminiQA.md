# 🧐 GeminiQA: Critical Audit & remediation Plan

**Date:** 2026-01-22
**Auditor:** Gemini CLI (Architect)
**Target:** AutoAgenda SaaS Architecture
**Status:** ⚠️ PARTIAL COMPLIANCE (Remediation Required)

---

## 1. 🔍 CRITICAL DISCREPANCY ANALYSIS

I have reviewed your `reportQA.md` and `qa_execution_report.md` against the actual file system state. While many artifacts exist, there are significant gaps between the **claimed status** ("✅ COMPLETE") and the **actual operational reality**.

| Component | Claimed Status | Actual Reality | Risk |
| :--- | :--- | :--- | :--- |
| **BB_04 (Saga)** | "COMPLETE" | `BB_04_Booking_Transaction_FIXED.json` exists but relies on logic that may conflict with the `trg_check_overlap` DB trigger we recently perfected. The "Saga" rollback must be coordinated with the DB constraint to avoid zombie transactions. | HIGH |
| **BB_06 (Auth)** | "COMPLETE" | `BB_06_Admin_Dashboard_AUTHENTICATED.json` exists, but the *active* workflow is likely the unauthenticated `BB_06_Admin_Dashboard.json` we just polished. **The dashboard is currently public.** | CRITICAL |
| **Infra (Nginx)** | "COMPLETE" | `nginx.conf` and `docker-compose.production.yml` exist but are not running in the current CLI context. We are running naked against n8n port. | HIGH |
| **I18n** | "COMPLETE" | `migration_v6_i18n_support.sql` exists, but has not been applied to the `neondb`. Messages are currently hardcoded in workflows. | MEDIUM |
| **Testing** | "COMPLETE" | `tests/run_all_tests.sh` exists, but the environment variables (JWT_SECRET) are likely missing, causing auth tests to fail. | HIGH |

---

## 2. 🛠️ ACTION PLAN: CONVERGENCE & REMEDIATION

We must merge the **Robust Logic** we built (Doomsday-proof) with the **Advanced Features** of the QA report (Auth, Saga, I18n).

### PHASE 1: DATABASE HARDENING (The Missing Migrations)
*Goal: Apply the infrastructure SQL that supports the new features.*

**Steps:**
1.  Apply `migration_v2_distributed_locks.sql` (Advisory locks are better for distributed systems than just triggers).
2.  Apply `migration_v3_notification_queue.sql` (Async retry logic).
3.  Apply `migration_v4_jwt_auth.sql` (Admin sessions).
4.  Apply `migration_v5_request_id_correlation.sql` (Observability).
5.  Apply `migration_v6_i18n_support.sql` (Translations).

### PHASE 2: WORKFLOW CONVERGENCE (The "Golden Master")
*Goal: Create the definitive versions of workflows that include ALL features.*

*   **BB_06 (Ultimate):** Merge the **Visual Polish** of our V24 dashboard with the **JWT Auth** of `BB_06_..._AUTHENTICATED.json`.
    *   *Action:* Inject the JWT Guard logic into the V24 Dashboard.
*   **BB_04 (Saga):** Merge the **DB Trigger** safety with the **GCal Compensation** logic.
    *   *Action:* Ensure BB_04 performs `GCal Reserve` -> `DB Insert`. If DB Insert fails (Overlap), `GCal Cancel`.

### PHASE 3: TESTING PYRAMID (Execution)
*Goal: Run the provided test suite, fixing failures immediately.*

---

## 3. 📝 EXECUTION LOG (Step-by-Step)

### STEP 1: Apply Missing Database Migrations
*Executing strictly critical migrations to support Auth and Resilience.*

```bash
# 1. Locks
psql "$DB_URL" -f database/migration_v2_distributed_locks.sql

# 2. Notification Queue (Replaces current simple update)
psql "$DB_URL" -f database/migration_v3_notification_queue.sql

# 3. Auth (CRITICAL for Dashboard)
psql "$DB_URL" -f database/migration_v4_jwt_auth.sql

# 4. Tracing & I18n
psql "$DB_URL" -f database/migration_v5_request_id_correlation.sql
psql "$DB_URL" -f database/migration_v6_i18n_support.sql
```

### STEP 2: Authenticate the Dashboard (BB_06)
*The current dashboard is wide open. We must lock it down.*

**Plan:**
1.  Read `BB_06_Admin_Dashboard_AUTHENTICATED.json` to extract the JWT Guard nodes.
2.  Read `workflows/BB_06_Admin_Dashboard.json` (our polished V24).
3.  **FUSE THEM:** Inject the JWT Auth check *before* the HTML serve and API endpoints.

### STEP 3: Validate with `run_all_tests.sh`
*This script exists but likely needs configuration.*

**Plan:**
1.  Inspect `tests/run_all_tests.sh`.
2.  Set up necessary ENV vars (mock JWT secret).
3.  Run and fix.

---

## 4. ✅ ACCEPTANCE CRITERIA (The Definition of Done)

1.  **Dashboard:** Accessible ONLY with valid JWT token (via Header or Cookie).
2.  **Transactions:** ACID compliance + GCal Consistency.
3.  **Logs:** Traceable via `request_id`.
4.  **Tests:** `run_all_tests.sh` returns Exit Code 0.

---

*Ready to execute Phase 1 (Migrations)?*
