# Qwen Code Memory for AutoAgenda Project

## Project Context
- **Project Name:** AutoAgenda (Multi-tenant SaaS Booking System)
- **Stack:** n8n (Self-Hosted, Docker), Neon (Postgres 17 + Pooling), Telegram Bot API
- **User Role:** Electrical Engineer (Expert in automation/networks)
- **Operating System:** Xubuntu 25.04+ (Noble/Plucky)
- **Location:** Concepción, Chile (Timezone: America/Santiago)

## Architectural Principles
- **Defensive Programming:** Never trust input, assume `input.data` is `null`, `undefined`, `NaN`, or garbage until validated
- **Zero Trust Methodology:** All inputs must be validated before processing
- **Fail Fast:** If data is invalid, throw an error immediately, do not propagate nulls
- **SQL Safety:** Always use parameterized queries

## Defensive Programming Patterns for N8N Code Nodes

### Pattern A: String & Empty Check
```javascript
const rawName = items[0].json.name;
if (rawName == null) throw new Error("Validation: 'name' is missing.");
const cleanName = String(rawName).trim();
if (cleanName.length === 0) throw new Error("Validation: 'name' is empty.");
```

### Pattern B: Number & NaN Check
```javascript
const rawPrice = items[0].json.price;
if (rawPrice === "") throw new Error("Validation: 'price' is empty string.");
const price = Number(rawPrice);
if (isNaN(price)) throw new Error(`Validation: 'price' is NaN. Got: ${rawPrice}`);
```

### Pattern C: Array & Length Check
```javascript
const tags = items[0].json.tags;
if (!Array.isArray(tags)) throw new Error("Validation: 'tags' must be an Array.");
if (tags.length === 0) console.log("Warning: 'tags' array is empty.");
```

### Pattern D: Safe Object Navigation (No 'undefined' crashes)
```javascript
const data = items[0].json || {};
const user = data.user || {};
const city = (user.address && user.address.city) ? user.address.city : null;
if (!city) throw new Error("Validation: User City is missing deep in object.");
```

## Current Project Status
- **Phase:** I - Foundational Architecture
- **Completed:** DB Schema (Tenants/Users/RLS) & Connection Pooling
- **Current Goal:** Global Error Handler Workflow (Chapter 3: The Watchtower)

## Key Files and Locations
- **Database migrations:** `/database/`
- **Workflows:** `/workflows/`
- **Documentation:** `/docs/`
- **Tests:** `/tests/`
- **Credentials:** `/credentials/`

## Global Error Handler Implementation (Chapter 3 Completed)
- **Status:** ✅ IMPLEMENTED
- **Database table:** `system_errors` with tenant isolation via RLS
- **Workflow:** BB_00_Global_Error_Handler.json activated
- **Integration:** Error Triggers added to BB_01, BB_02, BB_03, BB_04
- **Testing:** 100% pass rate (4/4 tests)
- **Documentation:** docs/ERROR_HANDLING.md

## Defensive Patterns Applied
- ✅ PATTERN A: String validation (workflow_name, error_message, error_type, severity)
- ✅ PATTERN D: Safe object navigation (optional fields)
- ✅ Fail Fast: Invalid data rejected immediately
- ✅ SQL Safety: Parameterized queries

## Advanced Validation Techniques
- **Ultra-paranoic validation:** Multiple layers of validation for all input fields
- **String validation:** Length limits, character checks, null/empty detection
- **Object validation:** Depth limits, circular reference detection, type checking
- **Array validation:** Size limits, element type validation
- **Response codes:** Proper HTTP status codes (400 for validation errors, 200 for success)

## Critical Implementation Notes
- **Response handling:** Use `$response` property in code nodes for explicit HTTP status codes
- **Error routing:** Proper error handling chains with validation before processing
- **Security:** Protection against injection attacks, null byte exploits, and malformed data
- **Performance:** Efficient validation that fails fast without unnecessary processing

## Next Chapter
- **Chapter 4:** Rate Limiting & DDoS Protection