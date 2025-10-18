# RPC Server Guide

This guide covers how to build ONC-RPC servers using the dart_oncrpc library.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Concepts](#basic-concepts)
- [Building a Server](#building-a-server)
- [RpcServer API](#rpcserver-api)
- [Programs and Versions](#programs-and-versions)
- [Procedure Handlers](#procedure-handlers)
- [Transports](#transports)
- [Authentication](#authentication)
- [Interceptors and Middleware](#interceptors-and-middleware)
- [Error Handling](#error-handling)
- [Portmapper Integration](#portmapper-integration)
- [Advanced Topics](#advanced-topics)
- [Best Practices](#best-practices)

## Quick Start

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';

void main() async {
  // Create server with TCP transport
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  // Create program and version
  final program = RpcProgram(100000);
  final version = RpcVersion(1);

  // Add NULL procedure (required)
  version.addProcedure(0, (params, auth) async => null);

  // Add echo procedure
  version.addProcedure(1, (params, auth) async {
    final message = params.readString();
    final output = XdrOutputStream();
    output.writeString('Echo: $message');
    return output.toBytes();
  });

  // Register program
  program.addVersion(version);
  server.addProgram(program);

  // Start listening
  await server.listen();
  print('Server running on port 8080');
}
```

## Basic Concepts

### RPC Programs

An RPC program is identified by a unique program number and contains one or more versions. Each version implements a set of procedures that clients can invoke.

```
Program 100000
├── Version 1
│   ├── Procedure 0: NULL
│   ├── Procedure 1: ECHO
│   └── Procedure 2: REVERSE
└── Version 2
    ├── Procedure 0: NULL
    ├── Procedure 1: ECHO
    ├── Procedure 2: REVERSE
    └── Procedure 3: UPPERCASE (new in v2)
```

### Program Numbers

- **0-99**: Reserved
- **100000-199999**: Well-known programs (NFS, MOUNT, etc.)
- **200000-299999**: Applications
- **0x20000000-0x3fffffff**: User-defined (recommended)
- **0x40000000-0x5fffffff**: Transient

### Procedure Numbers

By convention:
- **0**: NULL procedure (required for health checks)
- **1+**: Your procedures

## Building a Server

### Step 1: Create the Server

```dart
final server = RpcServer(
  transports: [
    TcpServerTransport(port: 8080),
    UdpServerTransport(port: 8080),  // Optional: also listen on UDP
  ],
);
```

### Step 2: Define Programs and Versions

```dart
final program = RpcProgram(0x20000001);  // User-defined program number
final version = RpcVersion(1);
```

### Step 3: Implement Procedures

```dart
// NULL procedure (required)
version.addProcedure(0, (params, auth) async {
  return null;  // void procedure
});

// Echo procedure
version.addProcedure(1, (params, auth) async {
  final message = params.readString();

  final output = XdrOutputStream();
  output.writeString(message);
  return output.toBytes();
});

// Add with authentication check
version.addProcedure(2, (params, auth) async {
  // Check authentication
  if (auth.auth is AuthNone) {
    throw Exception('Authentication required');
  }

  final userId = (auth.auth as AuthUnix).uid;
  print('Request from user: $userId');

  // Process request...
  final output = XdrOutputStream();
  output.writeInt(42);
  return output.toBytes();
});
```

### Step 4: Register and Start

```dart
program.addVersion(version);
server.addProgram(program);

await server.listen();
print('Server is running');
```

### Step 5: Graceful Shutdown

```dart
ProcessSignal.sigint.watch().listen((_) async {
  print('Shutting down...');
  await server.stop();
  exit(0);
});
```

## RpcServer API

### Constructor

```dart
RpcServer({
  required List<ServerTransport> transports,
  RpcSecretProvider? secretProvider,
})
```

**Parameters:**
- `transports` - List of transports to listen on (TCP, UDP, or both)
- `secretProvider` - Supplies shared secrets for AUTH_DES/AUTH_GSS

### Methods

#### addProgram()

Registers an RPC program with the server.

```dart
server.addProgram(program);
```

#### program()

Gets a registered program by number.

```dart
final program = server.program(100000);
```

#### listen()

Starts the server and begins accepting requests.

```dart
await server.listen();
```

#### stop()

Stops the server and releases resources.

```dart
await server.stop();
```

### Secret Providers

Configure a secret provider when you rely on AUTH_DES or AUTH_GSS:

```dart
// import 'dart:typed_data';
final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
  secretProvider: StaticRpcSecretProvider(
    desKeys: {
      'client@realm': Uint8List.fromList([...]),
    },
  ),
);
```

Custom providers can fetch keys from secure storage by implementing
`RpcSecretProvider`.

#### addInterceptor()

Adds a request/response interceptor.

```dart
server.addInterceptor(MyInterceptor());
```

#### addMiddleware()

Adds middleware for request processing.

```dart
server.addMiddleware(AuthMiddleware());
```

### Properties

#### isRunning

Returns true if server is currently running.

```dart
if (server.isRunning) {
  print('Server is active');
}
```

## Programs and Versions

### RpcProgram

```dart
final program = RpcProgram(programNumber);

// Add versions
program.addVersion(version1);
program.addVersion(version2);

// Get version
final v = program.version(1);

// Get supported versions
final versions = program.versions();
```

### RpcVersion

```dart
final version = RpcVersion(versionNumber);

// Add procedures
version.addProcedure(0, nullHandler);
version.addProcedure(1, echoHandler);

// Get procedure
final handler = version.procedure(1);
```

### Multiple Versions Example

Support multiple versions for backward compatibility:

```dart
final program = RpcProgram(USER_PROG);

// Version 1
final v1 = RpcVersion(1);
v1.addProcedure(0, nullProc);
v1.addProcedure(1, getUser);
program.addVersion(v1);

// Version 2 - adds new features
final v2 = RpcVersion(2);
v2.addProcedure(0, nullProc);
v2.addProcedure(1, getUser);
v2.addProcedure(2, updateUser);  // New in v2
v2.addProcedure(3, deleteUser);  // New in v2
program.addVersion(v2);

server.addProgram(program);
```

Clients can call either version based on their needs.

## Procedure Handlers

### Handler Signature

```dart
typedef RpcProcedureHandler = Future<Uint8List?> Function(
  XdrInputStream params,
  AuthContext auth,
);
```

### Reading Parameters

```dart
Future<Uint8List?> myProcedure(XdrInputStream params, AuthContext auth) async {
  // Read parameters
  final id = params.readInt();
  final name = params.readString();
  final active = params.readBoolean();

  // Process...

  // Return result
  final output = XdrOutputStream();
  output.writeInt(status);
  return output.toBytes();
}
```

### Void Procedures

Return null for procedures with no result:

```dart
Future<Uint8List?> setProcedure(XdrInputStream params, AuthContext auth) async {
  final id = params.readInt();
  final value = params.readString();

  // Update database...

  return null;  // void procedure
}
```

### Complex Types

```dart
Future<Uint8List?> getUserProc(XdrInputStream params, AuthContext auth) async {
  final id = params.readInt();

  // Get user from database
  final user = await database.getUser(id);

  // Encode result
  final output = XdrOutputStream();
  output.writeInt(user.id);
  output.writeString(user.name);
  output.writeBoolean(user.active);
  output.writeHyper(BigInt.from(user.created));

  return output.toBytes();
}
```

### Using Generated Types

With generated code from rpcgen:

```dart
Future<Uint8List?> getUserProc(XdrInputStream params, AuthContext auth) async {
  final id = params.readInt();

  // Get user
  final user = await database.getUser(id);

  // Use generated encode method
  final output = XdrOutputStream();
  user.encode(output);
  return output.toBytes();
}
```

### Error Handling

Throw exceptions to return error responses:

```dart
Future<Uint8List?> getFileProc(XdrInputStream params, AuthContext auth) async {
  final path = params.readString();

  final file = File(path);
  if (!file.existsSync()) {
    // Server will return SYSTEM_ERR
    throw FileSystemException('File not found', path);
  }

  final content = await file.readAsBytes();
  final output = XdrOutputStream();
  output.writeOpaque(content);
  return output.toBytes();
}
```

## Transports

### TCP Server Transport

```dart
final transport = TcpServerTransport(
  port: 8080,
  address: InternetAddress.anyIPv4,  // Listen on all interfaces
);
```

**Features:**
- Reliable, ordered delivery
- Multiple concurrent connections
- Record marking protocol
- Suitable for production use

### UDP Server Transport

```dart
final transport = UdpServerTransport(
  port: 8080,
  address: InternetAddress.anyIPv4,
);
```

**Features:**
- Connectionless
- Low overhead
- Limited message size (~8KB)
- Suitable for simple request/response

### Multiple Transports

Listen on both TCP and UDP simultaneously:

```dart
final server = RpcServer(
  transports: [
    TcpServerTransport(port: 8080),
    UdpServerTransport(port: 8080),
  ],
);
```

### Binding to Specific Interface

```dart
// IPv4 localhost only
final transport = TcpServerTransport(
  port: 8080,
  address: InternetAddress.loopbackIPv4,
);

// IPv6
final transport = TcpServerTransport(
  port: 8080,
  address: InternetAddress.anyIPv6,
);
```

## Authentication

### Accessing Authentication Info

```dart
Future<Uint8List?> myProc(XdrInputStream params, AuthContext auth) async {
  // Check auth type
  if (auth.auth is AuthNone) {
    print('Anonymous access');
  } else if (auth.auth is AuthUnix) {
    final unix = auth.auth as AuthUnix;
    print('User: ${unix.uid}:${unix.gid}');
    print('Machine: ${unix.machineName}');
  }

  // Check attributes
  final uid = auth.attributes['uid'] as int?;
  final gids = auth.attributes['gids'] as List<int>?;

  // Process...
}
```

### Authorization Example

```dart
Future<Uint8List?> adminProc(XdrInputStream params, AuthContext auth) async {
  // Require AUTH_UNIX
  if (auth.auth is! AuthUnix) {
    throw Exception('Unix authentication required');
  }

  final unix = auth.auth as AuthUnix;

  // Require root or specific user
  if (unix.uid != 0 && unix.uid != 1000) {
    throw Exception('Permission denied');
  }

  // Process admin operation...
}
```

### Custom Authentication

The server automatically handles AUTH_NONE and AUTH_UNIX. For custom authentication:

```dart
class MyAuthMiddleware implements RpcMiddleware {
  @override
  Future<RpcResponseContext> handle(
    RpcRequestContext context,
    Future<RpcResponseContext> Function(RpcRequestContext) next,
  ) async {
    // Validate custom auth
    final customToken = context.auth.attributes['token'] as String?;
    if (customToken == null || !validateToken(customToken)) {
      throw Exception('Invalid token');
    }

    // Continue processing
    return next(context);
  }
}

server.addMiddleware(MyAuthMiddleware());
```

## Interceptors and Middleware

### Interceptors

Interceptors observe requests and responses but don't control flow.

#### Request Interceptor

```dart
class LoggingInterceptor implements RpcRequestInterceptor {
  @override
  Future<RpcRequestContext> onRequest(RpcRequestContext context) async {
    print('Request: ${context.program}:${context.version}:${context.procedure}');
    print('From: ${context.auth.principal ?? 'anonymous'}');
    return context;
  }
}

server.addInterceptor(LoggingInterceptor());
```

#### Response Interceptor

```dart
class MetricsInterceptor implements RpcResponseInterceptor {
  final Map<String, int> counts = {};

  @override
  Future<RpcResponseContext> onResponse(RpcResponseContext context) async {
    final key = 'proc_${context.xid}';
    counts[key] = (counts[key] ?? 0) + 1;
    return context;
  }
}

server.addInterceptor(MetricsInterceptor());
```

#### Combined Interceptor

```dart
class TimingInterceptor
    implements RpcRequestInterceptor, RpcResponseInterceptor {

  @override
  Future<RpcRequestContext> onRequest(RpcRequestContext context) async {
    context.attributes['start_time'] = DateTime.now();
    return context;
  }

  @override
  Future<RpcResponseContext> onResponse(RpcResponseContext context) async {
    final start = context.attributes['start_time'] as DateTime?;
    if (start != null) {
      final duration = DateTime.now().difference(start);
      print('Request took ${duration.inMilliseconds}ms');
    }
    return context;
  }
}
```

### Middleware

Middleware controls the request processing flow.

```dart
class AuthorizationMiddleware implements RpcMiddleware {
  @override
  Future<RpcResponseContext> handle(
    RpcRequestContext context,
    Future<RpcResponseContext> Function(RpcRequestContext) next,
  ) async {
    // Check authorization
    if (!isAuthorized(context.auth)) {
      // Return error without calling next()
      throw Exception('Not authorized');
    }

    // Continue to next middleware or handler
    return next(context);
  }
}

server.addMiddleware(AuthorizationMiddleware());
```

### Middleware Chain

Middleware executes in order added:

```dart
server.addMiddleware(LoggingMiddleware());      // 1. Log request
server.addMiddleware(AuthenticationMiddleware()); // 2. Authenticate
server.addMiddleware(AuthorizationMiddleware());  // 3. Authorize
server.addMiddleware(RateLimitMiddleware());      // 4. Rate limit
// Finally: procedure handler executes
```

### Example: Rate Limiting Middleware

```dart
class RateLimitMiddleware implements RpcMiddleware {
  final Map<String, List<DateTime>> _requests = {};
  final int maxPerMinute;

  RateLimitMiddleware({this.maxPerMinute = 60});

  @override
  Future<RpcResponseContext> handle(
    RpcRequestContext context,
    Future<RpcResponseContext> Function(RpcRequestContext) next,
  ) async {
    final client = context.auth.principal ?? 'anonymous';
    final now = DateTime.now();

    // Clean old entries
    _requests[client]?.removeWhere(
      (t) => now.difference(t).inMinutes >= 1,
    );

    // Check rate
    final requests = _requests[client] ?? [];
    if (requests.length >= maxPerMinute) {
      throw Exception('Rate limit exceeded');
    }

    // Record request
    requests.add(now);
    _requests[client] = requests;

    return next(context);
  }
}
```

## Error Handling

### Automatic Error Responses

The server automatically returns appropriate error responses:

| Error | RPC Status |
|-------|------------|
| Program not registered | PROG_UNAVAIL |
| Version not supported | PROG_MISMATCH |
| Procedure not found | PROC_UNAVAIL |
| Invalid parameters | GARBAGE_ARGS |
| Handler throws exception | SYSTEM_ERR |

### Custom Error Responses

Throw exceptions in handlers:

```dart
Future<Uint8List?> getUser(XdrInputStream params, AuthContext auth) async {
  final id = params.readInt();

  if (id < 0) {
    // Client will receive SYSTEM_ERR
    throw ArgumentError('Invalid user ID');
  }

  final user = await db.getUser(id);
  if (user == null) {
    throw StateError('User not found');
  }

  return user.toXdr();
}
```

### Application-Level Errors

Return error status in the response:

```dart
Future<Uint8List?> readFile(XdrInputStream params, AuthContext auth) async {
  final path = params.readString();

  final output = XdrOutputStream();

  try {
    final content = await File(path).readAsBytes();
    output.writeInt(0);  // Status: OK
    output.writeOpaque(content);
  } catch (e) {
    output.writeInt(1);  // Status: ERROR
    output.writeString(e.toString());
  }

  return output.toBytes();
}
```

### Logging Errors

Use interceptors for centralized error logging:

```dart
class ErrorLoggingInterceptor implements RpcResponseInterceptor {
  @override
  Future<RpcResponseContext> onResponse(RpcResponseContext context) async {
    if (context.error != null) {
      print('Error in XID ${context.xid}: ${context.error}');
      // Log to file, send to monitoring system, etc.
    }
    return context;
  }
}
```

## Portmapper Integration

### Registering with Portmapper

```dart
import 'package:dart_oncrpc/src/rpc/portmap.dart';

final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
);

// ... register programs ...

await server.listen();

// Register with portmapper
final registered = await PortmapRegistration.register(
  prog: MY_PROG,
  vers: MY_VERS,
  port: 8080,
  useTcp: true,
);

if (registered) {
  print('Registered with portmapper');
} else {
  print('Portmapper registration failed');
}
```

### Unregistering on Shutdown

```dart
ProcessSignal.sigint.watch().listen((_) async {
  print('Shutting down...');

  // Unregister from portmapper
  await PortmapRegistration.unregister(
    prog: MY_PROG,
    vers: MY_VERS,
    useTcp: true,
  );

  await server.stop();
  exit(0);
});
```

### Complete Example with Portmapper

```dart
const ECHO_PROG = 0x20000001;
const ECHO_VERS = 1;

void main() async {
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  final program = RpcProgram(ECHO_PROG);
  final version = RpcVersion(ECHO_VERS);

  version.addProcedure(0, (params, auth) async => null);
  version.addProcedure(1, echoHandler);

  program.addVersion(version);
  server.addProgram(program);

  await server.listen();
  print('Server listening on port 8080');

  // Register with portmapper
  try {
    final registered = await PortmapRegistration.register(
      prog: ECHO_PROG,
      vers: ECHO_VERS,
      port: 8080,
      useTcp: true,
    );

    if (registered) {
      print('Registered with portmapper');
    }
  } catch (e) {
    print('Portmapper unavailable: $e');
  }

  // Handle shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down...');
    await PortmapRegistration.unregister(
      prog: ECHO_PROG,
      vers: ECHO_VERS,
      useTcp: true,
    );
    await server.stop();
    exit(0);
  });
}
```

## Advanced Topics

### Using Generated Server Code

Generate server skeleton from .x file:

```bash
dart run bin/rpcgen.dart -s myservice.x -o lib/myservice.dart
```

Implement the generated interface:

```dart
class MyServiceImpl implements MyServiceServer {
  @override
  Future<User> getUser(int id) async {
    // Implementation
    return User(id: id, name: 'User $id', active: true);
  }

  @override
  Future<void> setActive(int id, bool active) async {
    // Implementation
  }
}

// Register with server
final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
);

MyServiceServerRegistration.register(
  server,
  MyServiceImpl(),
);

await server.listen();
```

### State Management

#### Per-Connection State

Use middleware to track connection state:

```dart
class ConnectionStateMiddleware implements RpcMiddleware {
  final Map<String, Map<String, dynamic>> _state = {};

  @override
  Future<RpcResponseContext> handle(
    RpcRequestContext context,
    Future<RpcResponseContext> Function(RpcRequestContext) next,
  ) async {
    final clientId = context.auth.principal ?? 'anonymous';

    // Initialize state if needed
    _state[clientId] ??= {};

    // Add state to context
    context.attributes['client_state'] = _state[clientId];

    return next(context);
  }
}
```

#### Shared State

Use a database or cache for shared state across instances:

```dart
class UserService {
  final Database db;

  UserService(this.db);

  Future<Uint8List?> getUser(XdrInputStream params, AuthContext auth) async {
    final id = params.readInt();
    final user = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    // ...
  }
}

// Create service with shared database
final service = UserService(database);
version.addProcedure(1, service.getUser);
```

### Health Checks

Implement health check endpoint:

```dart
// Health check on procedure 0 (NULL)
version.addProcedure(0, (params, auth) async {
  // Check system health
  if (await database.isHealthy() && await cache.isHealthy()) {
    return null;  // Healthy
  } else {
    throw Exception('Unhealthy');  // Will return SYSTEM_ERR
  }
});
```

### Metrics and Monitoring

```dart
class MetricsCollector
    implements RpcRequestInterceptor, RpcResponseInterceptor {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  final Map<int, int> procedureCounts = {};

  @override
  Future<RpcRequestContext> onRequest(RpcRequestContext context) async {
    totalRequests++;
    procedureCounts[context.procedure] =
        (procedureCounts[context.procedure] ?? 0) + 1;
    return context;
  }

  @override
  Future<RpcResponseContext> onResponse(RpcResponseContext context) async {
    if (context.error != null) {
      failedRequests++;
    } else {
      successfulRequests++;
    }
    return context;
  }

  Map<String, dynamic> getMetrics() => {
    'total': totalRequests,
    'successful': successfulRequests,
    'failed': failedRequests,
    'procedure_counts': procedureCounts,
  };
}

final metrics = MetricsCollector();
server.addInterceptor(metrics);

// Expose metrics via separate HTTP server or logging
Timer.periodic(Duration(minutes: 1), (_) {
  print('Metrics: ${metrics.getMetrics()}');
});
```

## Best Practices

### 1. Always Implement NULL Procedure

```dart
version.addProcedure(0, (params, auth) async => null);
```

Clients use procedure 0 to check server availability.

### 2. Use Descriptive Program Numbers

```dart
// Good - descriptive
const USER_MANAGEMENT_SERVICE = 0x20000001;

// Avoid - unclear
const PROG1 = 0x20000001;
```

### 3. Version Your APIs

Support multiple versions for backward compatibility:

```dart
program.addVersion(v1);  // Original version
program.addVersion(v2);  // New features, maintains v1 compatibility
```

### 4. Validate Input

Always validate parameters:

```dart
Future<Uint8List?> getUser(XdrInputStream params, AuthContext auth) async {
  final id = params.readInt();

  if (id < 0) {
    throw ArgumentError('Invalid ID');
  }

  // Process...
}
```

### 5. Handle Errors Gracefully

Don't let exceptions crash the server:

```dart
version.addProcedure(1, (params, auth) async {
  try {
    // Process request
    return result;
  } catch (e) {
    RpcLogger.error('Error in procedure 1', e);
    throw;  // Server converts to SYSTEM_ERR
  }
});
```

### 6. Log Important Events

```dart
server.addInterceptor(LoggingInterceptor());
```

### 7. Use Appropriate Concurrency

```dart
// For CPU-intensive work
final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
);
// Offload work manually if you need asynchronous fan-out.
```

Configure secrets for AUTH_DES / AUTH_GSS:

```dart
// import 'dart:typed_data';
final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
  secretProvider: StaticRpcSecretProvider(
    desKeys: {
      'client@realm': Uint8List.fromList([...]),
    },
  ),
);
```

Environment-based secrets use base64-encoded variables:

```bash
export ONCRPC_DES_SECRET_CLIENT_REALM=$(base64 <<<"mydeskeybytes")
export ONCRPC_GSS_SECRET_USER_REALM_NFS=$(base64 <<<"sessionkeybytes")
```

```dart
final server = RpcServer(
  transports: [TcpServerTransport(port: 8080)],
  secretProvider: EnvRpcSecretProvider(),
);
```

### 8. Clean Shutdown

```dart
ProcessSignal.sigint.watch().listen((_) async {
  await portmap.unregister();
  await server.stop();
  await database.close();
  exit(0);
});
```

### 9. Use Generated Code

Generate server skeletons from .x files for type safety:

```bash
dart run bin/rpcgen.dart -s myservice.x
```

### 10. Monitor Performance

Track metrics and set up alerts:

```dart
final metrics = MetricsCollector();
server.addInterceptor(metrics);

Timer.periodic(Duration(minutes: 5), (_) {
  final m = metrics.getMetrics();
  if (m['failed'] > m['total'] * 0.01) {  // >1% error rate
    sendAlert('High error rate: ${m['failed']}/${m['total']}');
  }
});
```

## Examples

### Echo Service

See `example/echo_server.dart` for a complete example.

### File Service

```dart
class FileService {
  Future<Uint8List?> readFile(XdrInputStream params, AuthContext auth) async {
    final path = params.readString();

    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File not found');
    }

    final content = await file.readAsBytes();
    final output = XdrOutputStream();
    output.writeOpaque(content);
    return output.toBytes();
  }

  Future<Uint8List?> writeFile(XdrInputStream params, AuthContext auth) async {
    final path = params.readString();
    final content = params.readOpaque();

    await File(path).writeAsBytes(content);
    return null;  // void
  }
}
```

### Database Service

```dart
class UserDatabaseService {
  final Database db;

  UserDatabaseService(this.db);

  Future<Uint8List?> getUser(XdrInputStream params, AuthContext auth) async {
    final id = params.readInt();

    final rows = await db.query(
      'SELECT id, name, email FROM users WHERE id = ?',
      [id],
    );

    if (rows.isEmpty) {
      throw StateError('User not found');
    }

    final row = rows.first;
    final output = XdrOutputStream();
    output.writeInt(row['id'] as int);
    output.writeString(row['name'] as String);
    output.writeString(row['email'] as String);

    return output.toBytes();
  }
}
```

## See Also

- [RPC Client Guide](client_guide.md)
- [Code Generator Guide](generator_guide.md)
- [XDR Serialization Guide](xdr_guide.md)
- [Examples and Tutorials](examples.md)
