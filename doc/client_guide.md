# RPC Client Guide

This guide covers how to use the ONC-RPC client library to make remote procedure calls to RPC servers.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Usage](#basic-usage)
- [RpcClient API](#rpcclient-api)
- [Transports](#transports)
- [Authentication](#authentication)
- [Error Handling](#error-handling)
- [Interceptors](#interceptors)
- [TypedRpcClient](#typedrpcclient)
- [Advanced Topics](#advanced-topics)
- [Best Practices](#best-practices)

## Quick Start

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';

void main() async {
  // Create TCP transport
  final transport = TcpTransport(host: 'localhost', port: 8080);

  // Create client with Unix auth
  final client = RpcClient(
    transport: transport,
    auth: AuthUnix.currentUser(),
    timeout: Duration(seconds: 10),
  );

  // Connect
  await client.connect();

  // Make RPC call
  final result = await client.call(
    program: 100000,
    version: 1,
    procedure: 1,
    params: encodeParams(),
  );

  // Process result
  if (result != null) {
    processResult(result);
  }

  // Clean up
  await client.close();
}
```

## Basic Usage

### Creating a Client

The `RpcClient` class provides the main interface for making RPC calls:

```dart
final client = RpcClient(
  transport: transport,        // Required: network transport
  auth: auth,                  // Optional: authentication (default: AUTH_NONE)
  timeout: Duration(seconds: 30),  // Optional: call timeout (default: 30s)
  maxRetries: 3,              // Optional: retry attempts (default: 3)
);
```

### Connection Lifecycle

```dart
// Connect to server
await client.connect();

// Check connection status
if (client.transport.isConnected) {
  print('Connected');
}

// Make calls...

// Close connection
await client.close();
```

The client automatically connects on the first call if not already connected.

### Making RPC Calls

```dart
final result = await client.call(
  program: programNumber,      // RPC program number
  version: versionNumber,      // Program version
  procedure: procedureNumber,  // Procedure to call
  params: encodedParams,       // Optional: XDR-encoded parameters
);
```

**Example with parameters:**

```dart
// Encode parameters
final params = XdrOutputStream();
params.writeString('/export/data');
params.writeInt(1234);

// Make call
final result = await client.call(
  program: 100005,  // MOUNT program
  version: 3,
  procedure: 1,     // MNT procedure
  params: params.toBytes(),
);

// Decode result
if (result != null) {
  final stream = XdrInputStream(result);
  final status = stream.readInt();
  print('Mount status: $status');
}
```

## RpcClient API

### Constructor

```dart
RpcClient({
  required RpcTransport transport,
  Auth? auth,
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = 3,
})
```

### Methods

#### connect()

Establishes connection to the RPC server.

```dart
await client.connect();
```

**Throws:**
- `RpcTransportError` - Connection failed

#### call()

Invokes a remote procedure.

```dart
Future<Uint8List?> call({
  required int program,
  required int version,
  required int procedure,
  Uint8List? params,
})
```

**Returns:**
- `Uint8List?` - XDR-encoded result, or null for void procedures

**Throws:**
- `RpcTimeoutError` - Call timed out after all retries.
- `RpcServerError` - The server returned an error (e.g., program unavailable, version mismatch, procedure unavailable, garbage arguments, or system error).
- `RpcAuthError` - Authentication failed.
- `RpcTransportError` - The connection was lost or another transport-level error occurred.

#### close()

Closes the connection and releases resources.

```dart
await client.close();
```

Fails all pending calls and closes the underlying transport.

#### addInterceptor()

Adds an interceptor for custom processing.

```dart
client.addInterceptor(MyInterceptor());
```

See [Interceptors](#interceptors) section.

#### removeInterceptor()

Removes a previously added interceptor.

```dart
client.removeInterceptor(interceptor);
```

## Transports

### TCP Transport

TCP provides reliable, ordered delivery with connection-oriented communication.

```dart
final transport = TcpTransport(
  host: 'localhost',
  port: 8080,
);
```

**Features:**
- Automatic reconnection on connection loss
- Record marking protocol (RFC 5531)
- Efficient for large payloads
- Connection multiplexing

**Use cases:**
- Long-lived connections
- Large data transfers
- Reliable delivery required

### UDP Transport

UDP provides connectionless, unreliable datagram delivery.

```dart
final transport = UdpTransport(
  host: 'localhost',
  port: 8080,
);
```

**Features:**
- No connection overhead
- Low latency
- Broadcast support
- Limited to 8KB datagrams (typical)

**Use cases:**
- Low-latency operations
- Small requests/responses
- Broadcast RPC
- Stateless services

**Limitations:**
- No automatic retransmission (client must retry)
- No guaranteed delivery
- No ordering guarantees
- Size limited by MTU (typically 1500 bytes)

### Transport Selection

| Criteria | TCP | UDP |
|----------|-----|-----|
| Reliability | High | Low |
| Latency | Medium | Low |
| Overhead | High | Low |
| Max message size | Unlimited | ~8KB |
| Connection state | Yes | No |
| Ordering | Guaranteed | Not guaranteed |

## Authentication

### AUTH_NONE

No authentication (default).

```dart
final client = RpcClient(
  transport: transport,
  auth: AuthNone(),  // or omit auth parameter
);
```

### AUTH_UNIX

Unix-style authentication with UID/GID credentials.

```dart
// Example for a user with UID 1000 and GID 1000
final client = RpcClient(
  transport: transport,
  auth: AuthUnix(
    machineName: 'workstation',
    uid: 1000,
    gid: 1000,
    gids: [1000, 100, 10],  // Supplementary groups
  ),
);
```

**Fields:**
- `machineName` - Client machine name
- `uid` - User ID
- `gid` - Primary group ID
- `gids` - Supplementary group IDs (optional)

### Custom Authentication

Implement the `Auth` interface:

```dart
class MyAuth implements Auth {
  @override
  OpaqueAuth getCredential() {
    // Return credential
    return OpaqueAuth(
      flavor: AuthFlavor.custom,
      body: encodeCredential(),
    );
  }

  @override
  OpaqueAuth getVerifier() {
    // Return verifier
    return OpaqueAuth.none();
  }

  @override
  OpaqueAuth generateResponseVerifier(OpaqueAuth credential) {
    // Generate verifier for server response
    return OpaqueAuth.none();
  }
}

final client = RpcClient(
  transport: transport,
  auth: MyAuth(),
);
```

## Error Handling

The library provides a comprehensive custom exception hierarchy for precise error handling. All exceptions extend `RpcException` and include a `message` and optional `details` map.

### Exception Hierarchy

- `RpcError` - Base class for all RPC errors.
  - `RpcTransportError`: Network/transport layer errors.
  - `RpcProtocolError`: RPC protocol violations.
  - `RpcServerError`: Server-side errors. The specific cause is indicated by the `type` property, which is an `RpcServerErrorType` enum (e.g., `progUnavail`, `progMismatch`).
  - `RpcAuthError`: Authentication failures. The specific cause is indicated by the `type` property, which is an `RpcAuthErrorType` enum (e.g., `badcred`, `tooweak`).
  - `RpcTimeoutError`: Request timeout errors.
  - `RpcConnectionError`: Connection state errors.
  - `ParseError`: Errors during `.x` file parsing.
  - `CodeGenerationError`: Errors during code generation.

### Error Types

#### RpcTimeoutError

Call timed out after all retry attempts.

```dart
try {
  await client.call(...);
} on RpcTimeoutError catch (e) {
  print('Timeout: ${e.message}');
  print('Retries: ${e.details?['retries']}');
  print('Timeout duration: ${e.details?['timeout']}');
}
```

#### RpcServerError

Server returned an error response (program/version/procedure unavailable).

```dart
try {
  await client.call(...);
} on RpcServerError catch (e) {
  print('RPC error: ${e.message}');
  // Check details for version information if available
  if (e.details?['lowVersion'] != null) {
    print('Supported versions: ${e.details?['lowVersion']}-${e.details?['highVersion']}');
  }
}
```

#### RpcAuthError

Authentication failed.

```dart
try {
  await client.call(...);
} on RpcAuthError catch (e) {
  print('Authentication failed: ${e.message}');
  print('Auth status: ${e.details?['authStatus']}');
  // Update credentials and retry
}
```

#### RpcServerError

Server could not decode the parameters.

```dart
try {
  await client.call(...);
} on RpcServerError catch (e) {
  print('Invalid parameters: ${e.message}');
  // Check parameter encoding
}
```

#### RpcServerError

Server encountered a system error.

```dart
try {
  await client.call(...);
} on RpcServerError catch (e) {
  print('Server system error: ${e.message}');
  // Server-side issue, may need to retry later
}
```

#### RpcTransportError

Connection was lost or transport failed.

```dart
try {
  await client.call(...);
} on RpcTransportError catch (e) {
  print('Connection error: ${e.message}');
  print('Details: ${e.details}');
  // Reconnect
  await client.connect();
}
```

### Comprehensive Error Handling

```dart
try {
  final result = await client.call(
    program: 100000,
    version: 1,
    procedure: 1,
  );
  processResult(result);
} on RpcTimeoutError catch (e) {
  print('Timeout: ${e.message}');
  // Maybe increase timeout or check network
} on RpcServerError catch (e) {
  print('RPC error: ${e.message}');
  if (e.details?['lowVersion'] != null) {
    print('Server supports versions ${e.details?['lowVersion']}-${e.details?['highVersion']}');
    // Try with different version
  }
} on RpcAuthError catch (e) {
  print('Authentication failed: ${e.message}');
  // Update credentials
} on RpcTransportError catch (e) {
  print('Connection lost: ${e.message}');
  // Reconnect and retry
  await client.connect();
} on RpcException catch (e) {
  // Catch-all for any RPC exception
  print('RPC error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Interceptors

Interceptors provide hooks for request/response processing.

### Creating Interceptors

Implement `ClientCallInterceptor` for request processing:

```dart
class LoggingInterceptor implements ClientCallInterceptor {
  @override
  Future<ClientCallContext> onCall(ClientCallContext context) async {
    print('Calling ${context.program}:${context.version}:${context.procedure}');
    return context;
  }
}
```

Implement `ClientResponseInterceptor` for response processing:

```dart
class ResponseLogger implements ClientResponseInterceptor {
  @override
  Future<ClientResponseContext> onResponse(ClientResponseContext context) async {
    if (context.error != null) {
      print('Error: ${context.error}');
    } else {
      print('Success: ${context.result?.length ?? 0} bytes');
    }
    return context;
  }
}
```

Implement both for full lifecycle:

```dart
class MetricsInterceptor
    implements ClientCallInterceptor, ClientResponseInterceptor {
  final Map<String, int> callCounts = {};
  final Map<String, Duration> responseTimes = {};

  @override
  Future<ClientCallContext> onCall(ClientCallContext context) async {
    final key = '${context.program}:${context.procedure}';
    callCounts[key] = (callCounts[key] ?? 0) + 1;
    context.attributes['start_time'] = DateTime.now();
    return context;
  }

  @override
  Future<ClientResponseContext> onResponse(ClientResponseContext context) async {
    final startTime = context.attributes['start_time'] as DateTime?;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      final key = '${context.program}:${context.procedure}';
      responseTimes[key] = duration;
    }
    return context;
  }
}
```

### Using Interceptors

```dart
final client = RpcClient(transport: transport);

// Add interceptors
client.addInterceptor(LoggingInterceptor());
client.addInterceptor(MetricsInterceptor());

// Make calls - interceptors run automatically
await client.call(...);

// Remove interceptors
client.removeInterceptor(interceptor);
```

### Built-in Interceptors

The library provides common interceptors:

#### Logging Interceptor

```dart
class ClientLoggingInterceptor
    implements ClientCallInterceptor, ClientResponseInterceptor {
  @override
  Future<ClientCallContext> onCall(ClientCallContext context) async {
    RpcLogger.info('RPC call: ${context.program}:${context.version}:${context.procedure}');
    return context;
  }

  @override
  Future<ClientResponseContext> onResponse(ClientResponseContext context) async {
    if (context.error != null) {
      RpcLogger.error('RPC error', context.error);
    } else {
      RpcLogger.info('RPC success: ${context.result?.length ?? 0} bytes');
    }
    return context;
  }
}

client.addInterceptor(ClientLoggingInterceptor());
```

### Modifying Requests

Interceptors can modify the request:

```dart
class CompressionInterceptor implements ClientCallInterceptor {
  @override
  Future<ClientCallContext> onCall(ClientCallContext context) async {
    if (context.params != null && context.params!.length > 1024) {
      // Compress large payloads
      context.params = compress(context.params!);
      context.attributes['compressed'] = true;
    }
    return context;
  }
}
```

## TypedRpcClient

`TypedRpcClient` provides a higher-level API with typed parameters and results.

### Basic Usage

```dart
final typedClient = TypedRpcClient(client);

final user = await typedClient.call<User>(
  program: 100000,
  version: 1,
  procedure: 1,
  encodeParams: (stream) {
    stream.writeInt(userId);
  },
  decodeResult: (stream) {
    return User.decode(stream);
  },
);

print('User: ${user.name}');
```

### With Generated Code

When using generated code from rpcgen:

```dart
// Generated client class wraps TypedRpcClient
class UserServiceClient {
  final RpcClient _client;
  UserServiceClient(this._client);

  Future<User> getUser(int id) async {
    final params = XdrOutputStream();
    params.writeInt(id);

    final result = await _client.call(
      program: USER_PROG,
      version: USER_V1,
      procedure: GET_USER,
      params: params.toBytes(),
    );

    if (result != null) {
      return User.decode(XdrInputStream(result));
    }
    throw Exception('No result received');
  }
}

// Usage
final client = RpcClient(transport: transport);
await client.connect();

final userClient = UserServiceClient(client);
final user = await userClient.getUser(123);
```

## Advanced Topics

### Connection Pooling

For high-throughput scenarios, maintain multiple connections:

```dart
class ClientPool {
  final List<RpcClient> _clients = [];
  int _current = 0;

  ClientPool(int size, String host, int port) {
    for (int i = 0; i < size; i++) {
      _clients.add(RpcClient(
        transport: TcpTransport(host: host, port: port),
      ));
    }
  }

  Future<void> connect() async {
    await Future.wait(_clients.map((c) => c.connect()));
  }

  RpcClient next() {
    final client = _clients[_current];
    _current = (_current + 1) % _clients.length;
    return client;
  }

  Future<void> closeAll() async {
    await Future.wait(_clients.map((c) => c.close()));
  }
}

// Usage
final pool = ClientPool(4, 'localhost', 8080);
await pool.connect();

final result = await pool.next().call(...);
```

### Broadcast RPC

For UDP broadcast to multiple servers:

```dart
final transport = UdpTransport(
  host: '255.255.255.255',  // Broadcast address
  port: 8080,
);

final client = RpcClient(
  transport: transport,
  timeout: Duration(seconds: 5),
);

try {
  // Send broadcast
  await client.call(...);
  // First responder wins
} on RpcTimeoutError {
  print('No servers responded');
}
```

### Custom Timeout per Call

Use interceptors to adjust timeout dynamically:

```dart
class DynamicTimeoutInterceptor implements ClientCallInterceptor {
  @override
  Future<ClientCallContext> onCall(ClientCallContext context) async {
    // Set timeout based on procedure
    if (context.procedure == EXPENSIVE_PROC) {
      context.attributes['timeout'] = Duration(minutes: 5);
    }
    return context;
  }
}
```

### Portmapper Integration

Use portmapper to discover service ports:

```dart
import 'package:dart_oncrpc/src/rpc/portmap.dart';

// Lookup port
final port = await PortmapRegistration.lookup(
  prog: 100005,      // MOUNT program
  vers: 3,
  useTcp: true,
  portmapHost: 'fileserver.local',
);

if (port == 0) {
  throw Exception('Service not registered');
}

// Connect to discovered port
final transport = TcpTransport(
  host: 'fileserver.local',
  port: port,
);
final client = RpcClient(transport: transport);
```

## Best Practices

### 1. Reuse Connections

Create one client and reuse it:

```dart
// Good
final client = RpcClient(transport: transport);
await client.connect();
for (final item in items) {
  await client.call(...);
}
await client.close();

// Bad - creates new connection each time
for (final item in items) {
  final client = RpcClient(transport: transport);
  await client.connect();
  await client.call(...);
  await client.close();
}
```

### 2. Handle Errors Gracefully

Always handle RPC errors:

```dart
Future<User?> getUser(int id) async {
  try {
    final result = await client.call(...);
    return User.decode(XdrInputStream(result!));
  } on RpcServerError catch (e) {
    if (e.message.contains('Procedure unavailable')) {
      return null;  // Procedure not found
    }
    rethrow;
  } on RpcTimeoutError {
    // Retry with exponential backoff
    await Future.delayed(Duration(seconds: 1));
    return getUser(id);
  }
}
```

### 3. Use Appropriate Transport

Choose transport based on requirements:

```dart
// For large file transfers - use TCP
final tcpClient = RpcClient(
  transport: TcpTransport(host: 'fileserver', port: 2049),
);

// For ping/health checks - use UDP
final udpClient = RpcClient(
  transport: UdpTransport(host: 'fileserver', port: 2049),
  timeout: Duration(seconds: 1),
);
```

### 4. Set Reasonable Timeouts

Adjust timeout based on operation:

```dart
// Quick operations
final pingClient = RpcClient(
  transport: transport,
  timeout: Duration(seconds: 5),
  maxRetries: 2,
);

// Long-running operations
final batchClient = RpcClient(
  transport: transport,
  timeout: Duration(minutes: 5),
  maxRetries: 1,
);
```

### 5. Clean Up Resources

Always close clients when done:

```dart
final client = RpcClient(transport: transport);
try {
  await client.connect();
  await client.call(...);
} finally {
  await client.close();
}
```

### 6. Use Generated Code

Generate client code from .x files for type safety:

```bash
dart run bin/rpcgen.dart -c myservice.x -o lib/myservice.dart
```

Then use the generated client class instead of raw RpcClient.

### 7. Monitor Performance

Use interceptors for metrics:

```dart
final metrics = MetricsInterceptor();
client.addInterceptor(metrics);

// Periodically check metrics
Timer.periodic(Duration(minutes: 1), (_) {
  print('Call counts: ${metrics.callCounts}');
  print('Avg response times: ${metrics.responseTimes}');
});
```

## Examples

### Simple Echo Client

```dart
final client = RpcClient(
  transport: TcpTransport(host: 'localhost', port: 8080),
  auth: AuthUnix.currentUser(),
);

await client.connect();

final params = XdrOutputStream();
params.writeString('Hello, World!');

final result = await client.call(
  program: 0x20000001,
  version: 1,
  procedure: 1,
  params: params.toBytes(),
);

final response = XdrInputStream(result!).readString();
print('Echo: $response');

await client.close();
```

### File Service Client

```dart
class FileClient {
  final RpcClient _client;

  FileClient(String host, int port)
    : _client = RpcClient(
        transport: TcpTransport(host: host, port: port),
        auth: AuthUnix.currentUser(),
      );

  Future<void> connect() => _client.connect();
  Future<void> close() => _client.close();

  Future<Uint8List> readFile(String path) async {
    final params = XdrOutputStream();
    params.writeString(path);

    final result = await _client.call(
      program: FILE_PROG,
      version: 1,
      procedure: READ_FILE,
      params: params.toBytes(),
    );

    return XdrInputStream(result!).readOpaque();
  }

  Future<void> writeFile(String path, Uint8List data) async {
    final params = XdrOutputStream();
    params.writeString(path);
    params.writeOpaque(data);

    await _client.call(
      program: FILE_PROG,
      version: 1,
      procedure: WRITE_FILE,
      params: params.toBytes(),
    );
  }
}
```

## See Also

- [RPC Server Guide](server_guide.md)
- [Code Generator Guide](generator_guide.md)
- [XDR Serialization Guide](xdr_guide.md)
- [Examples and Tutorials](examples.md)
