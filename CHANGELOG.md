## 0.2.0

- Remove environment configuration and environment context from SDK batches.
- Keep endpoint and public write key as application-supplied configuration.
- Document that the project is selected by the Rena public write key.

## 0.1.0

- Initial Flutter package for Rena Telemetry Kit.
- Add manual event tracking, error capture, breadcrumbs, super properties, flush, opt-out, local queue persistence, retry policy, anonymous ID, session ID, and lifecycle flush support.
- Add automatic OS version and device model context when available.
- Add `runtimePlatform` to distinguish runtime telemetry platform from Rena project `sdk_family`.
