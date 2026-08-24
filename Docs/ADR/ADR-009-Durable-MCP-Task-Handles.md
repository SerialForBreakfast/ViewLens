# ADR-009: Durable MCP Task Handles

- **Status:** Accepted
- **Date:** 2026-08-23
- **Deciders:** Joseph McCraw, ViewLens Architecture Team
- **Tags:** `mcp`, `tasks`, `persistence`, `cancellation`, `recovery`, `security`

## Context

ViewLens audits can outlive one stdio request or client connection. Ephemeral progress notifications and request cancellation cannot provide a reconnect-safe result, a pollable terminal cancellation state, or a durable input-required workflow. Persisting arbitrary request data would also create an unacceptable credential and filesystem-exposure boundary.

## Decision

ViewLens implements the experimental MCP Tasks extension under the exact identifier `io.modelcontextprotocol/tasks`. Modern discovery advertises it, and clients must opt in through their per-request client capabilities. Task augmentation is limited to `tools/call` for screenshot, matrix, accessibility, and design-diff audits; environment diagnosis remains synchronous.

The server returns an opaque UUID task handle before execution and supports `tasks/get`, `tasks/update`, and `tasks/cancel`. Records move through `working`, `input_required`, `completed`, `failed`, or `cancelled`. Terminal records are immutable. Tool results with `isError: true` are completed results; `failed` is reserved for protocol execution or persistence failures. Task progress is exposed through `statusMessage`, not progress notifications.

The local actor-backed store persists the tool name, bounded arguments, execution state, timestamps, outstanding input requests, and terminal result. A new server instance can reload and claim a persisted working task when it is polled. Input-response values are not persisted. There is no task-list operation.

## Persistence and security boundary

- Records live in the user Application Support `ViewLens/MCPTasks` directory with `0700` directory and `0600` file permissions. A symlinked store directory is rejected.
- Task IDs are high-entropy local handles. The stdio transport has one implicit local caller; remote identity and authorization are deferred to M18 and must not reuse this assumption.
- The default TTL is one hour from creation, the suggested polling interval is 250 ms, storage is capped at 100 task records, and each encoded record is capped at 5 MB. Expired and oldest-over-limit records are removed.
- Arguments containing credential-like keys—including authorization, password, secret, API key, credential, and access or refresh token forms—are rejected before a record is created. Credentials and personal data are prohibited in task arguments, task messages, resources, and elicitation.
- Malformed, oversized, or non-UUID record files are ignored during recovery. Unknown and expired handles use JSON-RPC `-32602` with stable machine-readable ViewLens error codes.

## Consequences

Long-running audits can be polled, cancelled, and recovered after a local server reconnect without changing legacy or non-task modern behavior. Durable task calls intentionally do not emit ephemeral progress notifications. Completed results are durable JSON, although resource links may still depend on the separately bounded resource catalog until resource persistence is implemented.

Form-mode input state and partial updates are supported, but MCP-14.16 must add the user-facing elicitation producer and approval policies. Bounded task subscriptions and task logs remain separate roadmap work. Multi-process claiming, tenant isolation, encryption, remote authorization, and retention controls are required before exposing task handles over a remote transport.
