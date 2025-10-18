# dart_oncrpc

[![pub package](https://img.shields.io/pub/v/dart_oncrpc.svg)](https://pub.dev/packages/dart_oncrpc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Dart 3 implementation of ONC-RPC (Open Network Computing Remote Procedure Call) with XDR serialization and code
generation. Parse XDR/RPC specifications, generate code in multiple languages, and build RPC services with full type
safety and advanced error handling.

## Features

**Dart 3 Implementation**

- **Enhanced enums** with pattern matching and helper methods
- **Records** for cleaner data structures
- **Custom exception hierarchy** for precise error handling
- Leverages Dart 3 language features for better type safety and performance

**RPC Protocol Implementation (RFC 5531)**

- RPC message format with call/reply handling
- Transaction ID management
- Timeout support with custom `RpcTimeoutError`
- Exception handling (connection, authentication, protocol errors)
- Server and client interceptors for logging, metrics, authentication validation

**XDR Serialization (RFC 4506)**

- Primitive types: int, unsigned int, hyper, unsigned hyper, float, double, bool
- Strings with length validation
- Opaque data (fixed and variable-length)
- Fixed and variable-length arrays
- Optional data (pointers)
- Discriminated unions
- Structs, enums, and typedefs
- Byte-for-byte compatible with C rpcgen (verified via compatibility tests)

**Authentication**

- AUTH_NONE (no authentication)
- AUTH_UNIX (Unix-style authentication with uid/gid/groups)
- Response verifiers
- Extensible authentication framework (AUTH_DES/AUTH_GSS mostly implemented)

**Network Transport**

- TCP with record marking protocol (RFC 5531)
- UDP datagram support
- Connection management
- Concurrent connection handling

**Code Generation (rpcgen)**

- Dart builder for XDR types
- Parse .x specification files (XDR/RPC definitions)
- Generate type definitions, client stubs, and server skeletons
- Target languages: Dart, C, Java
- **C generator**: rpcgen-compatible output (headers and XDR functions)
    - **C-style type support**: Built-in recognition of `int32_t`, `uint32_t`, `int64_t`, `uint64_t`
        - Automatically mapped to XDR equivalents (int, unsigned int, hyper, unsigned hyper)
        - Alternative: Use traditional include files (like `rpc/types.h`) with `-I` flag for more flexibility
- **Java generator**: oncrpc4j and Remote Tea compatible
- **Dart generator**:
    - Enhanced enums with `allValues` and `isValid()` methods
    - Pattern matching in switch expressions
    - Clean, idiomatic Dart 3 code
- Preprocessor support (#include, #define, include paths)

**Port Mapper & RPCBIND**

- Port mapper v2 client (program 100000)
- RPCBIND v3/v4 data structures (RFC 1833)
- Service registration and lookup
- Universal address format support

**Cross-Language Compatibility**

- **C compatibility**: Generator produces rpcgen-compatible C code
- **Java compatibility**: Generator produces oncrpc4j/Remote Tea compatible Java code
- **XDR compatibility**: Byte-for-byte XDR serialization compatibility with C
- **RPC compatibility**: Dart ↔ C bidirectional RPC calls tested
- Compatibility test suite in `test/compatibility/`

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_oncrpc: ^1.0.0
```

Or install from the command line:

```bash
dart pub add dart_oncrpc
```

## Quick Start

### 1. Generate Code from .x Files

```bash
# Generate Dart code (types, client, server)
dart run bin/rpcgen.dart -t -c -s test/fixtures/definitions/ping.x

# Generate C code (rpcgen-compatible)
dart run bin/rpcgen.dart -l c -o generated/types.h test/fixtures/definitions/nfs.x

# Generate Java code (oncrpc4j/Remote Tea compatible)
dart run bin/rpcgen.dart -l java -p com.example.rpc -o generated/Types.java test/fixtures/definitions/nfs.x

# With preprocessor support
dart run bin/rpcgen.dart -I include/path -D DEBUG=1 -t -c -s myspec.x
```

### 2. Implement a Simple RPC Server

```dart
import 'dart:typed_data';
import 'package:dart_oncrpc/dart_oncrpc.dart';

void main() async {
  // Create server with TCP transport
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  // Define your RPC program
  final program = RpcProgram(200000); // Program number
  final version = RpcVersion(1); // Version number

  // Add procedure handlers
  version.addProcedure(1, (params, auth) async {
    // Procedure 1: Echo
    final input = params.readString();
    print('Received: $input from ${auth.principal ?? 'anonymous'}');

    final output = XdrOutputStream()
      ..writeString('Echo: $input');
    return Uint8List.fromList(output.bytes);
  });

  program.addVersion(version);
  server.addProgram(program);

  // Start listening
  await server.listen();
  print('Server listening on port 8080');
}
```

### 3. Create an RPC Client

```dart
import 'dart:typed_data';
import 'package:dart_oncrpc/dart_oncrpc.dart';

void main() async {
  // Connect to server
  final transport = TcpTransport(host: 'localhost', port: 8080);
  final client = RpcClient(transport: transport, auth: AuthNone());
  await client.connect();

  try {
    // Prepare parameters
    final params = XdrOutputStream()
      ..writeString('Hello, RPC!');

    // Make RPC call
    final result = await client.call(
      program: 200000,
      version: 1,
      procedure: 1,
      params: Uint8List.fromList(params.bytes),
    );

    if (result != null) {
      final response = XdrInputStream(result);
      print(response.readString()); // "Echo: Hello, RPC!"
    }
  } on RpcTimeoutError catch (e) {
    print('Call timed out: ${e.message}');
  } on RpcAuthError catch (e) {
    print('Authentication failed: ${e.message}');
  } on RpcServerError catch (e) {
    print('RPC error: ${e.message}');
  } finally {
    await client.close();
  }
}
```

### 4. Error Handling

The library provides a comprehensive exception hierarchy for precise error handling:

```dart
try {
final result = await client.call(...);
} on RpcTimeoutError catch (e) {
// Handle timeout (includes retry count)
print('Timeout after ${e.retries} retries');
} on RpcAuthError catch (e) {
// Handle authentication failures
print('Auth failed: ${e.message}');
} on RpcServerError catch (e) {
// Handle server-side errors (e.g., program unavailable, version mismatch)
print('Server error: ${e.message}');
} on RpcTransportError catch (e) {
// Handle network/transport errors
print('Connection error: ${e.message}');
} on RpcError catch (e) {
// Catch-all for any other RPC error
print('Error: ${e.message}');
}
```

All exceptions extend `RpcError`.

## RPC Features

- RPC version 2 (RFC 5531)
- Multiple program/version support
- Asynchronous procedure calls
- Timeout handling
- Concurrent connection handling
- Request/response interceptors

## XDR Type Mapping

| XDR Type       | Dart Type      |
|----------------|----------------|
| int            | int            |
| unsigned int   | int            |
| hyper          | BigInt         |
| unsigned hyper | BigInt         |
| float          | double         |
| double         | double         |
| bool           | bool           |
| string         | String         |
| opaque         | Uint8List      |
| array          | List<T>        |
| optional       | T?             |
| struct         | Class          |
| union          | Abstract class |
| enum           | Enum           |

## Testing

```bash
# Run all tests
dart test

# Run specific test categories
dart test test/parsing/                   # Parser tests
dart test test/generator/                 # Code generator tests
dart test test/xdr/                       # XDR serialization tests
dart test test/rpc/                       # RPC protocol tests
dart test test/compatibility/xdr/         # XDR compatibility tests (requires rpcgen)
dart test test/compatibility/rpc/         # RPC compatibility tests (requires rpcgen + C compiler)

# Run specific test file
dart test test/xdr/rfc_4506_compliance_test.dart

# Run compatibility test suites
cd test/compatibility/xdr && ./run_compatibility_tests.sh
cd test/compatibility/rpc && ./run_rpc_matrix.sh
```

Test structure:

- `test/parsing/` - Parser tests for XDR/RPC constructs
- `test/generator/` - Code generator tests (Dart, C, Java)
- `test/xdr/` - XDR serialization and RFC 4506 compliance tests
- `test/rpc/` - RPC protocol and transport tests
- `test/compatibility/xdr/` - XDR cross-language compatibility tests
- `test/compatibility/rpc/` - RPC cross-language compatibility tests
- `test/data/` - Sample .x specification files

### Compatibility Tests

The compatibility tests verify cross-language interoperability:

**XDR Compatibility** (`test/compatibility/xdr/`):

- Tests byte-for-byte XDR serialization compatibility with C rpcgen
- Automatically generates C code using rpcgen, compiles test programs
- Verifies bidirectional serialization (Dart → C and C → Dart)
- Requires: `rpcgen` and a C compiler (gcc/clang)

**RPC Compatibility** (`test/compatibility/rpc/`):

- Tests bidirectional RPC calls between Dart and C implementations
- Dart client → C server and C client → Dart server
- Automatically generates and compiles C RPC code
- Requires: `rpcgen` and a C compiler (gcc/clang)

Both test suites automatically clean up generated files after running.

## Cross-Language Compatibility

### C Compatibility

The C code generator produces output compatible with standard `rpcgen`:

- **Header files (.h)**:
    - Guard format: `_FILENAME_H_RPCGEN`
    - Modern C types: `int64_t`/`u_int64_t` for hyper
    - Proper struct/enum/union typedefs
    - XDR function declarations: `extern bool_t xdr_Type(XDR *, Type *);`

- **Implementation files (.c)**:
    - Standard `#include "filename.h"` format
    - XDR functions compatible with system RPC libraries
    - Optional pointers use `xdr_pointer()`
    - Variable-length arrays generate structs with `_len` and `_val` fields

- **Compatibility testing**:
    - Byte-for-byte XDR serialization compatibility verified
    - Bidirectional RPC calls tested (Dart ↔ C)
    - See `test/compatibility/xdr/` and `test/compatibility/rpc/` for full test suites

### Java Compatibility

The Java code generator produces output compatible with **oncrpc4j** and **Remote Tea**:

- **Class structure**:
    - All types implement `XdrAble` interface
    - Constants wrapped in `Constants` interface
    - Enums are Java enums with integer values
    - Structs are classes with private fields and getters/setters

- **XDR methods**:
    - `xdrEncode(XdrEncodingStream xdr)` for serialization
    - `static Type xdrDecode(XdrDecodingStream xdr)` for deserialization
    - Uses `org.dcache.oncrpc4j.xdr.*` packages

- **Type mappings**:
    - `hyper` → `long`
    - Optional types → nullable objects with boolean presence flag
    - Arrays → Java arrays with proper length encoding

See `test/generator/c_generator_tests.dart` and `test/generator/java_generator_tests.dart` for generator validation.

## Limitations

### Authentication

- Only AUTH_NONE and AUTH_UNIX are implemented
- AUTH_DES is partially implemented
- AUTH_GSS/RPCSEC_GSS is partially implemented

### XDR Types

- Quadruple-precision floats (128-bit) not supported (Dart limitation)
- Legacy struct pointers (deprecated XDR syntax) not supported in strict mode

### Transport

- No built-in TLS support (wrap transport layer with secure socket if needed)
- UDP has message size limitations (typically 8KB-64KB depending on network)

### RPC Features

- Batched calls not explicitly supported
- Broadcast RPC (RPCBINDPROC_BCAST) data structures defined but not fully implemented
- No automatic retry mechanism (implement in client code if needed)

## Examples

See the `example/` directory for working examples:

### Echo Service (Basic RPC)

- `echo_server.dart` - Complete RPC server with multiple procedures
- `echo_client.dart` - Interactive RPC client example

### NFS v3 Server (Advanced Example)

- `nfs/` - **Full NFS v3 server implementation**
    - Complete MOUNT and NFS protocol implementation
    - File handle management and filesystem abstraction
    - macOS client compatible
    - Read and write operations
    - Demonstrates all major library features
    - See `example/nfs/README.md` for full documentation

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass (`dart test`)
2. Code follows Dart conventions (`dart analyze`)
3. New features include tests
4. Update CLAUDE.md if architecture changes

## License

See LICENSE file for details.

## References

- [RFC 5531 - RPC: Remote Procedure Call Protocol Specification Version 2](https://tools.ietf.org/html/rfc5531)
- [RFC 4506 - XDR: External Data Representation Standard](https://tools.ietf.org/html/rfc4506)
- [RFC 1833 - Binding Protocols for ONC RPC Version 2](https://tools.ietf.org/html/rfc1833)
- [RFC 1813 - NFS Version 3 Protocol Specification](https://tools.ietf.org/html/rfc1813)