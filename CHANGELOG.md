## 1.0.0

Initial release of dart_oncrpc - A complete ONC-RPC implementation for Dart.

- RPC Protocol (RFC 5531)
- XDR Serialization (RFC 4506)
- Parser and code generator for .x specification files (XDR/RPC definitions)
- Multi-language code generation: Dart, C, Java
- Port mapper v2 client implementation (program 100000)
- RPCBIND v3/v4 data structures (RFC 1833)
- Echo server example with multiple procedures
- NFS server example

## 1.0.1

General cleanup following the initial checkin.

## 1.0.2

Bug fixes in the RPC subsystem:
  - harden auth/transport handling and correct protocol edge cases
  - reject unknown auth flavors instead of downgrading to AUTH_NONE
  - fix AUTH_DES and AUTH_GSS identity validation shadowing bugs
  - correct portmap CALLIT XDR encoding (remove duplicate length prefixes)
  - fix client retry semantics so maxRetries=0 still performs one attempt
  - validate maxRetries >= 0 at client construction
  - harden UDP client by accepting replies only from configured endpoint
  - map decode/format argument failures to GARBAGE_ARGS instead of always SYSTEM_ERR
  - add record-marking fragment/message size caps to reduce memory-DoS risk
  - handle record-marking decode failures safely in TCP transports
  - fix server metrics interceptor procedure-key propagation
  - add regression tests for auth flavor handling, auth identity checks, retry semantics, UDP spoof filtering, garbage-args mapping, record-marking limits, and portmap CALLIT encoding

## 1.0.3

Cleaning up dependencies.

