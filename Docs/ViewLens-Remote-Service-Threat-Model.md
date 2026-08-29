# ViewLens Remote Service & Multi-Tenant MCP Threat Model

**Document Version:** 1.0  
**Date:** 2026-08-29  
**Status:** Approved Architecture Baseline  
**Scope:** Remote MCP Server HTTP/SSE Transport, Encrypted Multi-Tenant Storage, Agent Capabilities (MCP-18.6–18.15)

---

## 1. System Overview & Trust Boundaries

ViewLens operates as a specialized Apple UI layout auditor and accessibility engine. When deployed as a remote service, it exposes HTTP POST (`/mcp`) and Server-Sent Events (`/events`) endpoints to AI agents and development hosts.

```
┌────────────────────────────────────────────────────────┐
│ Host Agent (Claude Code / Cursor / CI Runner)          │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS + Bearer Authorization
                           ▼
┌────────────────────────────────────────────────────────┐
│ Trust Boundary: Remote Transport & Auth Validator       │
│  - Audience Validation (`aud: viewlens://...`)          │
│  - Scoped Capabilities (`read:audit`, `execute:flow`)  │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ ViewLens Core MCP Engine & In-Memory Sandboxes         │
│  - Allowlisted UI actions & Simulator control          │
│  - Deterministic Rule Evaluation & CoreML Detection    │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ Trust Boundary: Tenant-Isolated Encrypted Storage      │
│  - AES-GCM Encrypted Artifacts (CryptoKit)             │
│  - Strict TTL Pruning & Zero-Knowledge Metadata        │
└────────────────────────────────────────────────────────┘
```

---

## 2. STRIDE Threat Analysis & Mitigations

### 2.1 Spoofing Identity
* **Threat:** Malicious caller impersonates legitimate tenant or bypasses authentication.
* **Mitigation:**
  * Strict Bearer token authentication via `RemoteAuthorizationValidator`.
  * Exact audience matching (`expectedAudience`).
  * Expired tokens are rejected immediately with JSON-RPC `-32002`.
  * Per-request tenant ID propagation; requests cannot access artifacts from other tenants.

### 2.2 Tampering with Data
* **Threat:** Modification of stored review artifacts, baseline images, or test fixtures.
* **Mitigation:**
  * All persisted artifacts are encrypted at rest using AES-GCM (`EncryptedArtifactStore`).
  * Cryptographic authentication tags ensure ciphertext cannot be modified or swapped.
  * Signed artifact URLs include HMAC signatures and expiration timestamps.

### 2.3 Repudiation
* **Threat:** An agent performs UI interactions or requests modifications without accountability.
* **Mitigation:**
  * Immutable JSON-Lines audit logging (`AuditLog.swift`) recording timestamp, tenant ID, user ID, tool name, and resolved targets.
  * Structural impossibility of logging user password fields or sensitive form inputs.

### 2.4 Information Disclosure
* **Threat:** Exposure of developer source code, application secrets, or user credentials in telemetry/errors.
* **Mitigation:**
  * Strict automatic parameter redaction in `TelemetryEngine` and task stores.
  * Screenshot-only and nonvisual models redact secure text fields and fixture passwords.
  * Tool error envelopes return sanitized messages with stable error codes rather than raw stack traces.

### 2.5 Denial of Service (Compute / Storage Exhaustion)
* **Threat:** Malicious payload floods server with unbounded crawl requests or huge images.
* **Mitigation:**
  * Request payload size capped at 10 MB for binary artifacts and 5 MB for task payloads.
  * `StateCrawler` enforces strict limits: `maxStates` (default 25), `maxActions` (default 50), and bounded timeout.
  * Automated background TTL cleanup purges stale records and evicts cache entries beyond capacity limits.

### 2.6 Elevation of Privilege
* **Threat:** Host agent uses MCP tool to execute arbitrary shell commands or access out-of-scope files.
* **Mitigation:**
  * **Absolute Invariant:** ViewLens does NOT expose shell execution tools over MCP.
  * All Xcode / simulator actions use allowlisted parameters in `ProcessLauncher` with explicit workspace boundary validation.
  * Project context resolution is strictly read-only and lexical; no compilation or script execution.

---

## 3. Data Retention & Privacy Lifecycle

| Data Category | Storage Location | Encryption | Retention / TTL |
|---|---|---|---|
| Review Artifacts (PNG, Heatmaps) | `<tenantId>/<reviewId>/` | AES-GCM (256-bit) | Configurable (Default 7 days) |
| Nonvisual JSON Models | `<tenantId>/<reviewId>/` | AES-GCM (256-bit) | Configurable (Default 7 days) |
| Task Handles & State | Application Support / MCPTasks | Private POSIX (0600) | 1 Hour |
| Telemetry Traces | Memory / OpenTelemetry exporter | In-Transit TLS | Max 24 Hours / Flushed on exit |

---

## 4. Disaster Recovery & Breach Response

1. **Compromised Token:** Immediate token revocation by rotating the pre-shared secret or invalidating the OAuth audience key.
2. **Tenant Data Purge:** Immediate execution of `EncryptedArtifactStore.purgeTenant(tenantId:)` securely removing all tenant ciphertext keys and files.
3. **Audit Inspection:** Offline review of append-only `AuditLog` JSON-Lines logs to identify affected review IDs.
