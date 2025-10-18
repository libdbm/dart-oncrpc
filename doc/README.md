# dart_oncrpc Documentation

Complete documentation for the dart_oncrpc ONC-RPC library for Dart.

## Overview

dart_oncrpc is a production-ready implementation of ONC-RPC (Open Network Computing Remote Procedure Call) for Dart. It provides:

- Complete RPC protocol implementation (RFC 5531)
- XDR serialization (RFC 4506)
- Code generation from `.x` specification files
- Multi-language support (Dart, C, Java)
- TCP and UDP transports
- Authentication (AUTH_NONE, AUTH_UNIX)
- Portmapper/RPCBIND integration

## Quick Links

### Getting Started

- **[Installation](#installation)** - Add dart_oncrpc to your project
- **[Quick Start](#quick-start)** - Build your first RPC service in 5 minutes
- **[Examples and Tutorials](examples.md)** - Step-by-step tutorials

### Core Guides

- **[Code Generator Guide](generator_guide.md)** - Generate client/server code from `.x` files
- **[RPC Client Guide](client_guide.md)** - Make RPC calls to servers
- **[RPC Server Guide](server_guide.md)** - Build RPC servers
- **[XDR Serialization Guide](xdr_guide.md)** - Encode/decode data with XDR

### Additional Resources

- **[API Reference](https://pub.dev/documentation/dart_oncrpc/latest/)** - Complete API documentation
- **[GitHub Repository](https://github.com/yourusername/dart_oncrpc)** - Source code
- **[Examples](../example/)** - Working examples

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_oncrpc: ^1.0.0
```

Or install from command line:

```bash
dart pub add dart_oncrpc
```

## Quick Start

### 1. Define Your Protocol

Create `myservice.x`:

```c
program MY_SERVICE {
    version V1 {
        void NULL(void) = 0;
        string ECHO(string) = 1;
    } = 1;
} = 0x20000001;
```

### 2. Generate Code

```bash
dart run bin/rpcgen.dart myservice.x -o lib/myservice.dart
```

### 3. Implement Server

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'lib/myservice.dart';

class MyServiceImpl implements MyServiceServer {
  @override
  Future<void> null_() async {}

  @override
  Future<String> echo(String message) async {
    return message;
  }
}

void main() async {
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  MyServiceServerRegistration.register(server, MyServiceImpl());
  await server.listen();

  print('Server running on port 8080');
}
```

### 4. Create Client

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'lib/myservice.dart';

void main() async {
  final transport = TcpTransport(host: 'localhost', port: 8080);
  final rpcClient = RpcClient(transport: transport);
  await rpcClient.connect();

  final client = MyServiceClient(rpcClient);
  final result = await client.echo('Hello!');

  print('Result: $result');
  await rpcClient.close();
}
```

## Documentation Structure

### By Role

**For Application Developers:**
1. Start with [Examples and Tutorials](examples.md)
2. Read [RPC Client Guide](client_guide.md)
3. Understand [XDR Serialization](xdr_guide.md)

**For Service Developers:**
1. Start with [RPC Server Guide](server_guide.md)
2. Learn [Code Generation](generator_guide.md)
3. Review [Examples](examples.md)

**For Protocol Designers:**
1. Read [Code Generator Guide](generator_guide.md)
2. Understand [XDR Serialization](xdr_guide.md)
3. Study example protocols in `test/data/`

### By Feature

**Code Generation:**
- [Generator Guide](generator_guide.md) - Complete rpcgen documentation
- Supported languages: Dart, C, Java
- XDR type definitions
- Client/server stub generation

**RPC Communication:**
- [Client Guide](client_guide.md) - Making RPC calls
- [Server Guide](server_guide.md) - Handling RPC requests
- TCP and UDP transports
- Authentication and authorization
- Error handling

**Data Serialization:**
- [XDR Guide](xdr_guide.md) - External Data Representation
- Primitive types (int, hyper, float, double, bool)
- Complex types (structs, unions, enums, arrays)
- Optional types (pointers)
- Custom type definitions

**Advanced Topics:**
- Interceptors and middleware
- Synchronous server processing model
- Secret management for AUTH_DES/AUTH_GSS
- Portmapper integration
- Cross-language interoperability
- Performance optimization

## Common Tasks

### Generate Client Code

```bash
dart run bin/rpcgen.dart -c --no-server myservice.x -o lib/client.dart
```

### Generate Server Code

```bash
dart run bin/rpcgen.dart -s --no-client myservice.x -o lib/server.dart
```

### Generate C Code (rpcgen-compatible)

```bash
dart run bin/rpcgen.dart -l c myservice.x -o c_generated/
```

### Generate Java Code (oncrpc4j-compatible)

```bash
dart run bin/rpcgen.dart -l java -p com.example myservice.x -o java/
```

### Add Authentication

```dart
final client = RpcClient(
  transport: transport,
  auth: AuthUnix.currentUser(),
);
```

### Use UDP Transport

```dart
final server = RpcServer(
  transports: [UdpServerTransport(port: 8080)],
);
```

### Register with Portmapper

```dart
await PortmapRegistration.register(
  prog: MY_PROG,
  vers: MY_VERS,
  port: 8080,
  useTcp: true,
);
```

## Features by Guide

### Code Generator Guide

- Command line options
- Input file format (.x files)
- Output languages (Dart, C, Java)
- Type mappings
- Preprocessing (#include, #define)
- Generated code structure
- Best practices

### RPC Client Guide

- Creating clients
- Making RPC calls
- Transports (TCP, UDP)
- Authentication (AUTH_NONE, AUTH_UNIX)
- Error handling
- Interceptors
- TypedRpcClient wrapper
- Connection pooling
- Portmapper integration

### RPC Server Guide

- Building servers
- Program and version registration
- Procedure handlers
- Multiple transports
- Authentication and authorization
- Interceptors and middleware
- Synchronous execution model
- Error responses
- Portmapper integration
- Metrics and monitoring

### XDR Serialization Guide

- XdrOutputStream (encoding)
- XdrInputStream (decoding)
- Primitive types
- Strings and opaque data
- Arrays (fixed and variable)
- Structs
- Unions
- Enums
- Optional types
- Custom types
- Error handling
- Performance tips

## Example Applications

### Echo Service
Simple request/response service demonstrating basics.

**Files:**
- `example/echo_server.dart`
- `example/echo_client.dart`
- `example/echo.x` (protocol definition)

**Features:**
- Basic RPC calls
- String handling
- TCP transport

### User Management Service
CRUD operations with structured data.

**Features:**
- Complex data structures
- Error handling with unions
- Database integration
- Authentication

### File Transfer Service
Upload and download files over RPC.

**Features:**
- Binary data transfer
- Large payloads
- Error handling
- File system integration

### Calculator Service
Arithmetic operations with type-safe enums.

**Features:**
- Enumerations
- Union types for results
- Multiple procedure signatures

### Multi-Language Interop
Demonstrates Dart, C, and Java interoperability.

**Features:**
- Cross-language compatibility
- C client with Dart server
- Java client with Dart server
- Standard protocol

## Tutorials

### Tutorial 1: Simple Echo Service
Build your first RPC service in 10 minutes.

**Learn:**
- Protocol definition
- Code generation
- Server implementation
- Client usage

### Tutorial 2: User Management Service
Build a complete CRUD service.

**Learn:**
- Complex data types
- Error handling
- Union types
- Database integration

### Tutorial 3: File Transfer Service
Upload and download files.

**Learn:**
- Binary data
- Large payloads
- File system operations
- Security considerations

### Tutorial 4: Calculator with Generated Code
Use generated code for type safety.

**Learn:**
- Enumerations
- Multiple procedures
- Type-safe clients
- Error unions

### Tutorial 5: Multi-Language Interoperability
Connect Dart, C, and Java.

**Learn:**
- Cross-language RPC
- C code generation
- Java code generation
- Protocol compatibility

## Testing

Run the complete test suite:

```bash
dart test
```

Run specific tests:

```bash
# Parsing tests
dart test test/parsing/

# Generator tests
dart test test/generator/

# Compatibility tests
dart test test/compatibility/
```

## Performance

### Benchmarks

Typical performance on modern hardware:

| Operation | Throughput |
|-----------|------------|
| Simple call (TCP) | ~50,000 ops/sec |
| Simple call (UDP) | ~80,000 ops/sec |
| 1KB payload | ~40,000 ops/sec |
| 10KB payload | ~20,000 ops/sec |

### Optimization Tips

1. **Reuse connections** - Don't create new clients for each call
2. **Use appropriate transport** - UDP for small requests, TCP for large
3. **Batch operations** - Combine multiple calls when possible
4. **Offload heavy work** - Delegate CPU-bound tasks to separate services
5. **Pool connections** - Maintain connection pool for high throughput

See [Performance Tips](client_guide.md#performance-tips) for details.

## Compatibility

### Cross-Language Compatibility

**C (rpcgen):**
- ✅ Generated C code is rpcgen-compatible
- ✅ Byte-for-byte XDR compatibility
- ✅ Bidirectional RPC calls tested
- ✅ Works with system RPC libraries

**Java (oncrpc4j/Remote Tea):**
- ✅ Generated Java code is oncrpc4j-compatible
- ✅ Also compatible with Remote Tea
- ✅ XdrAble interface implementation
- ✅ Type-safe Java classes

**Protocol Compatibility:**
- ✅ RFC 5531 (RPC protocol)
- ✅ RFC 4506 (XDR serialization)
- ✅ RFC 1833 (Portmapper)
- ✅ NFS protocols (tested with NFSv3)

### Dart Compatibility

- Dart SDK: >=2.17.0 <4.0.0
- Platforms: All (VM, Web not supported)
- Null safety: Full support

## Troubleshooting

### Common Issues

**"Parse error" when generating code:**
- Check `.x` file syntax
- Ensure semicolons at end of statements
- Verify all types are defined before use

**"Connection refused" errors:**
- Check server is running
- Verify correct host and port
- Check firewall settings

**"Program unavailable" errors:**
- Ensure program is registered with server
- Verify program number and version match
- Check portmapper registration if used

**XDR encoding errors:**
- Validate data before encoding
- Check size limits on strings/arrays
- Ensure BigInt for hyper types

See individual guides for detailed troubleshooting.

## Contributing

Contributions are welcome! Areas for improvement:

- Additional authentication methods
- WebSocket transport
- HTTP/JSON-RPC bridge
- Performance optimizations
- More examples

Please see CONTRIBUTING.md in the repository.

## License

MIT License - see LICENSE file for details.

## References

### RFCs

- [RFC 5531 - RPC: Remote Procedure Call Protocol Specification Version 2](https://tools.ietf.org/html/rfc5531)
- [RFC 4506 - XDR: External Data Representation Standard](https://tools.ietf.org/html/rfc4506)
- [RFC 1833 - Binding Protocols for ONC RPC Version 2](https://tools.ietf.org/html/rfc1833)
- [RFC 1813 - NFS Version 3 Protocol Specification](https://tools.ietf.org/html/rfc1813)

### External Resources

- [ONC RPC Programming Guide](http://docs.oracle.com/cd/E19683-01/816-1435/)
- [rpcgen Programming Guide](https://docs.oracle.com/cd/E19683-01/816-1435/rpcgenpguide-21470/index.html)
- [oncrpc4j Documentation](https://github.com/dcache/oncrpc4j)

## Support

- GitHub Issues: Report bugs and request features
- Stack Overflow: Tag questions with `dart-oncrpc`
- Email: support@example.com

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for version history.

## Acknowledgments

Built on the ONC-RPC standard developed by Sun Microsystems and maintained by the IETF.

Compatible with standard rpcgen and oncrpc4j implementations.

---

**Quick Navigation:**

- [Code Generator Guide](generator_guide.md) | [Client Guide](client_guide.md) | [Server Guide](server_guide.md) | [XDR Guide](xdr_guide.md) | [Examples](examples.md)
