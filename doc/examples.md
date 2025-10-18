# Examples and Tutorials

This guide provides practical examples and step-by-step tutorials for building RPC applications with dart_oncrpc.

## Table of Contents

- [Tutorial 1: Simple Echo Service](#tutorial-1-simple-echo-service)
- [Tutorial 2: User Management Service](#tutorial-2-user-management-service)
- [Tutorial 3: File Transfer Service](#tutorial-3-file-transfer-service)
- [Tutorial 4: Calculator Service with Generated Code](#tutorial-4-calculator-service-with-generated-code)
- [Tutorial 5: Multi-Language Interoperability](#tutorial-5-multi-language-interoperability)
- [Example Use Cases](#example-use-cases)

## Tutorial 1: Simple Echo Service

Build a basic echo service that demonstrates the fundamentals of RPC.

### Step 1: Define the Protocol

Create `echo.x`:

```c
/* Echo service protocol */

program ECHO_PROG {
    version ECHO_V1 {
        void NULL(void) = 0;
        string ECHO(string) = 1;
        string REVERSE(string) = 2;
    } = 1;
} = 0x20000001;
```

### Step 2: Generate Code

```bash
dart run bin/rpcgen.dart -c -s -t echo.x -o lib/echo.dart
```

### Step 3: Implement the Server

Create `bin/echo_server.dart`:

```dart
import 'dart:io';
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/echo.dart';

class EchoServiceImpl implements EchoProgServer {
  @override
  Future<void> null_() async {
    // Health check - does nothing
  }

  @override
  Future<String> echo(String message) async {
    print('Echo: $message');
    return message;
  }

  @override
  Future<String> reverse(String message) async {
    print('Reverse: $message');
    return message.split('').reversed.join();
  }
}

void main() async {
  // Create server
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  // Register service
  EchoProgServerRegistration.register(server, EchoServiceImpl());

  // Start listening
  await server.listen();
  print('Echo server running on port 8080');

  // Graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.stop();
    exit(0);
  });
}
```

### Step 4: Create the Client

Create `bin/echo_client.dart`:

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/echo.dart';

void main() async {
  // Create transport
  final transport = TcpTransport(host: 'localhost', port: 8080);

  // Create RPC client
  final rpcClient = RpcClient(transport: transport);
  await rpcClient.connect();

  // Create typed client
  final client = EchoProgClient(rpcClient);

  // Test echo
  print('Testing echo...');
  final echo = await client.echo('Hello, World!');
  print('Result: $echo');

  // Test reverse
  print('\nTesting reverse...');
  final reversed = await client.reverse('Hello, World!');
  print('Result: $reversed');

  // Clean up
  await rpcClient.close();
}
```

### Step 5: Run the Example

```bash
# Terminal 1 - Start server
dart run bin/echo_server.dart

# Terminal 2 - Run client
dart run bin/echo_client.dart
```

**Expected Output:**

Server:
```
Echo server running on port 8080
Echo: Hello, World!
Reverse: Hello, World!
```

Client:
```
Testing echo...
Result: Hello, World!

Testing reverse...
Result: !dlroW ,olleH
```

## Tutorial 2: User Management Service

Build a service that manages user data with CRUD operations.

### Step 1: Define the Protocol

Create `user_service.x`:

```c
/* User management service */

struct user {
    int id;
    string username<32>;
    string email<320>;
    bool active;
    hyper created;
};

typedef user *optional_user;

enum user_error {
    OK = 0,
    NOT_FOUND = 1,
    ALREADY_EXISTS = 2,
    INVALID_DATA = 3
};

union user_result switch (user_error status) {
    case OK:
        user data;
    default:
        void;
};

program USER_SERVICE {
    version USER_V1 {
        void NULL(void) = 0;
        user_result GET_USER(int) = 1;
        user_result CREATE_USER(user) = 2;
        user_result UPDATE_USER(user) = 3;
        user_error DELETE_USER(int) = 4;
    } = 1;
} = 0x20000002;
```

### Step 2: Generate Code

```bash
dart run bin/rpcgen.dart user_service.x -o lib/user_service.dart
```

### Step 3: Implement the Server

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/user_service.dart';

class UserDatabase {
  final Map<int, User> _users = {};
  int _nextId = 1;

  User? getUser(int id) => _users[id];

  User? createUser(User user) {
    if (_users.values.any((u) => u.username == user.username)) {
      return null; // Already exists
    }
    final newUser = User(
      id: _nextId++,
      username: user.username,
      email: user.email,
      active: user.active,
      created: BigInt.from(DateTime.now().millisecondsSinceEpoch),
    );
    _users[newUser.id] = newUser;
    return newUser;
  }

  User? updateUser(User user) {
    if (!_users.containsKey(user.id)) {
      return null; // Not found
    }
    _users[user.id] = user;
    return user;
  }

  bool deleteUser(int id) {
    return _users.remove(id) != null;
  }
}

class UserServiceImpl implements UserServiceServer {
  final UserDatabase db = UserDatabase();

  @override
  Future<void> null_() async {}

  @override
  Future<UserResult> getUser(int id) async {
    final user = db.getUser(id);
    if (user != null) {
      return UserResultOk(user);
    }
    return UserResultDefault(UserError.notFound);
  }

  @override
  Future<UserResult> createUser(User user) async {
    // Validate
    if (user.username.isEmpty || user.email.isEmpty) {
      return UserResultDefault(UserError.invalidData);
    }

    final created = db.createUser(user);
    if (created != null) {
      return UserResultOk(created);
    }
    return UserResultDefault(UserError.alreadyExists);
  }

  @override
  Future<UserResult> updateUser(User user) async {
    final updated = db.updateUser(user);
    if (updated != null) {
      return UserResultOk(updated);
    }
    return UserResultDefault(UserError.notFound);
  }

  @override
  Future<UserError> deleteUser(int id) async {
    final deleted = db.deleteUser(id);
    return deleted ? UserError.ok : UserError.notFound;
  }
}

void main() async {
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  UserServiceServerRegistration.register(server, UserServiceImpl());

  await server.listen();
  print('User service running on port 8080');
}
```

### Step 4: Create the Client

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/user_service.dart';

void main() async {
  final transport = TcpTransport(host: 'localhost', port: 8080);
  final rpcClient = RpcClient(transport: transport);
  await rpcClient.connect();

  final client = UserServiceClient(rpcClient);

  // Create user
  print('Creating user...');
  final newUser = User(
    id: 0, // Will be assigned by server
    username: 'alice',
    email: 'alice@example.com',
    active: true,
    created: BigInt.zero,
  );

  final createResult = await client.createUser(newUser);
  if (createResult is UserResultOk) {
    final created = createResult.data;
    print('Created user: ${created.id} - ${created.username}');

    // Get user
    print('\nGetting user ${created.id}...');
    final getResult = await client.getUser(created.id);
    if (getResult is UserResultOk) {
      final user = getResult.data;
      print('User: ${user.username} (${user.email})');
    }

    // Update user
    print('\nUpdating user...');
    final updated = User(
      id: created.id,
      username: created.username,
      email: 'alice.updated@example.com',
      active: false,
      created: created.created,
    );
    final updateResult = await client.updateUser(updated);
    if (updateResult is UserResultOk) {
      print('Updated: ${updateResult.data.email}');
    }

    // Delete user
    print('\nDeleting user...');
    final deleteResult = await client.deleteUser(created.id);
    print('Delete result: $deleteResult');
  }

  await rpcClient.close();
}
```

## Tutorial 3: File Transfer Service

Build a service for uploading and downloading files.

### Step 1: Define the Protocol

Create `file_service.x`:

```c
/* File transfer service */

const MAX_FILENAME = 255;
const MAX_CHUNK = 8192;

typedef string filename<MAX_FILENAME>;
typedef opaque file_chunk<MAX_CHUNK>;

enum file_status {
    OK = 0,
    NOT_FOUND = 1,
    PERMISSION_DENIED = 2,
    IO_ERROR = 3
};

struct file_info {
    filename name;
    unsigned hyper size;
    hyper modified;
};

union upload_result switch (file_status status) {
    case OK:
        void;
    default:
        string error<>;
};

union download_result switch (file_status status) {
    case OK:
        file_chunk data;
    default:
        string error<>;
};

program FILE_SERVICE {
    version FILE_V1 {
        void NULL(void) = 0;
        upload_result UPLOAD(filename, file_chunk) = 1;
        download_result DOWNLOAD(filename) = 2;
        file_info GET_INFO(filename) = 3;
        file_status DELETE(filename) = 4;
    } = 1;
} = 0x20000003;
```

### Step 2: Implement the Server

```dart
import 'dart:io';
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/file_service.dart';

class FileServiceImpl implements FileServiceServer {
  final String basePath;

  FileServiceImpl(this.basePath);

  String _getFullPath(String filename) {
    // Security: prevent directory traversal
    final sanitized = filename.replaceAll('..', '').replaceAll('/', '_');
    return '$basePath/$sanitized';
  }

  @override
  Future<void> null_() async {}

  @override
  Future<UploadResult> upload(String filename, Uint8List data) async {
    try {
      final path = _getFullPath(filename);
      await File(path).writeAsBytes(data);
      return UploadResultOk();
    } on FileSystemException catch (e) {
      return UploadResultDefault(
        FileStatus.ioError,
        error: e.message,
      );
    }
  }

  @override
  Future<DownloadResult> download(String filename) async {
    try {
      final path = _getFullPath(filename);
      final file = File(path);

      if (!await file.exists()) {
        return DownloadResultDefault(
          FileStatus.notFound,
          error: 'File not found',
        );
      }

      final data = await file.readAsBytes();
      return DownloadResultOk(data);
    } on FileSystemException catch (e) {
      return DownloadResultDefault(
        FileStatus.ioError,
        error: e.message,
      );
    }
  }

  @override
  Future<FileInfo> getInfo(String filename) async {
    final path = _getFullPath(filename);
    final file = File(path);

    if (!await file.exists()) {
      throw StateError('File not found');
    }

    final stat = await file.stat();
    return FileInfo(
      name: filename,
      size: BigInt.from(stat.size),
      modified: BigInt.from(stat.modified.millisecondsSinceEpoch),
    );
  }

  @override
  Future<FileStatus> delete(String filename) async {
    try {
      final path = _getFullPath(filename);
      await File(path).delete();
      return FileStatus.ok;
    } on FileSystemException {
      return FileStatus.ioError;
    }
  }
}

void main() async {
  // Create storage directory
  final storage = Directory('file_storage');
  if (!await storage.exists()) {
    await storage.create();
  }

  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  FileServiceServerRegistration.register(
    server,
    FileServiceImpl(storage.path),
  );

  await server.listen();
  print('File service running on port 8080');
  print('Storage: ${storage.absolute.path}');
}
```

### Step 3: Create the Client

```dart
import 'dart:io';
import 'package:dart_oncrpc/dart_oncrpc.dart';
import '../lib/file_service.dart';

void main() async {
  final transport = TcpTransport(host: 'localhost', port: 8080);
  final rpcClient = RpcClient(transport: transport);
  await rpcClient.connect();

  final client = FileServiceClient(rpcClient);

  // Upload a file
  print('Uploading file...');
  final content = 'Hello, World! This is test content.';
  final result = await client.upload(
    'test.txt',
    Uint8List.fromList(content.codeUnits),
  );

  if (result is UploadResultOk) {
    print('Upload successful');

    // Get file info
    print('\nGetting file info...');
    final info = await client.getInfo('test.txt');
    print('File: ${info.name}');
    print('Size: ${info.size} bytes');
    print('Modified: ${DateTime.fromMillisecondsSinceEpoch(info.modified.toInt())}');

    // Download the file
    print('\nDownloading file...');
    final downloadResult = await client.download('test.txt');
    if (downloadResult is DownloadResultOk) {
      final downloaded = String.fromCharCodes(downloadResult.data);
      print('Content: $downloaded');
    }

    // Delete the file
    print('\nDeleting file...');
    final deleteResult = await client.delete('test.txt');
    print('Delete status: $deleteResult');
  }

  await rpcClient.close();
}
```

## Tutorial 4: Calculator Service with Generated Code

Build a calculator service to demonstrate arithmetic operations.

### Step 1: Define the Protocol

Create `calculator.x`:

```c
/* Calculator service */

enum operation {
    ADD = 0,
    SUBTRACT = 1,
    MULTIPLY = 2,
    DIVIDE = 3
};

struct calc_request {
    operation op;
    double a;
    double b;
};

union calc_result switch (bool success) {
    case TRUE:
        double value;
    case FALSE:
        string error<>;
};

program CALCULATOR {
    version CALC_V1 {
        void NULL(void) = 0;
        calc_result CALCULATE(calc_request) = 1;
        double ADD(double, double) = 2;
        double SUBTRACT(double, double) = 3;
        double MULTIPLY(double, double) = 4;
        calc_result DIVIDE(double, double) = 5;
    } = 1;
} = 0x20000004;
```

### Step 2: Implementation

```dart
class CalculatorImpl implements CalculatorServer {
  @override
  Future<void> null_() async {}

  @override
  Future<CalcResult> calculate(CalcRequest request) async {
    try {
      final result = switch (request.op) {
        Operation.add => request.a + request.b,
        Operation.subtract => request.a - request.b,
        Operation.multiply => request.a * request.b,
        Operation.divide => request.a / request.b,
      };

      if (result.isNaN || result.isInfinite) {
        return CalcResultFalse('Invalid result');
      }

      return CalcResultTrue(result);
    } catch (e) {
      return CalcResultFalse(e.toString());
    }
  }

  @override
  Future<double> add(double a, double b) async => a + b;

  @override
  Future<double> subtract(double a, double b) async => a - b;

  @override
  Future<double> multiply(double a, double b) async => a * b;

  @override
  Future<CalcResult> divide(double a, double b) async {
    if (b == 0) {
      return CalcResultFalse('Division by zero');
    }
    return CalcResultTrue(a / b);
  }
}
```

## Tutorial 5: Multi-Language Interoperability

Demonstrate interoperability between Dart, C, and Java.

### Step 1: Define Protocol

Create `interop.x`:

```c
/* Cross-language interoperability test */

struct point {
    int x;
    int y;
};

struct message {
    string sender<32>;
    string text<>;
    hyper timestamp;
};

program INTEROP_SERVICE {
    version INTEROP_V1 {
        void NULL(void) = 0;
        int DISTANCE(point, point) = 1;
        message ECHO_MESSAGE(message) = 2;
    } = 1;
} = 0x20000005;
```

### Step 2: Generate Code for All Languages

```bash
# Dart
dart run bin/rpcgen.dart -l dart interop.x -o lib/interop.dart

# C
dart run bin/rpcgen.dart -l c interop.x -o c/

# Java
dart run bin/rpcgen.dart -l java -p com.example interop.x -o java/
```

### Step 3: Implement Dart Server

```dart
class InteropServiceImpl implements InteropServiceServer {
  @override
  Future<void> null_() async {}

  @override
  Future<int> distance(Point p1, Point p2) async {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return (dx * dx + dy * dy).round();
  }

  @override
  Future<Message> echoMessage(Message msg) async {
    return Message(
      sender: 'Dart Server',
      text: 'Echo: ${msg.text}',
      timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
    );
  }
}
```

### Step 4: C Client

```c
#include "interop.h"
#include <rpc/rpc.h>
#include <stdio.h>

int main() {
    CLIENT *client = clnt_create("localhost", INTEROP_SERVICE, INTEROP_V1, "tcp");

    if (client == NULL) {
        clnt_pcreateerror("localhost");
        return 1;
    }

    // Test distance
    struct point p1 = {0, 0};
    struct point p2 = {3, 4};

    int *result = distance_1(&p1, &p2, client);
    if (result != NULL) {
        printf("Distance: %d\n", *result);
    }

    clnt_destroy(client);
    return 0;
}
```

### Step 5: Java Client

```java
import com.example.*;
import org.dcache.oncrpc4j.*;

public class InteropClient {
    public static void main(String[] args) throws Exception {
        OncRpcClient client = new OncRpcClient(
            InetAddress.getByName("localhost"),
            INTEROP_SERVICE,
            INTEROP_V1,
            OncRpcProtocols.ONCRPC_TCP
        );

        // Test message echo
        Message msg = new Message();
        msg.setSender("Java Client");
        msg.setText("Hello from Java");
        msg.setTimestamp(System.currentTimeMillis());

        Message response = ECHO_MESSAGE(client, msg);
        System.out.println("Response: " + response.getText());

        client.close();
    }
}
```

## Example Use Cases

### 1. Microservices Communication

Use RPC for efficient microservice communication:

```dart
// Service A
class OrderService {
  final RpcClient inventoryClient;
  final RpcClient paymentClient;

  Future<Order> createOrder(Order order) async {
    // Check inventory via RPC
    final available = await checkInventory(order.items);

    if (available) {
      // Process payment via RPC
      final paid = await processPayment(order.payment);

      if (paid) {
        return await saveOrder(order);
      }
    }

    throw Exception('Order failed');
  }
}
```

### 2. Distributed Systems

Build distributed systems with RPC coordination:

```dart
// Distributed task queue
class TaskQueue {
  final List<RpcClient> workers;

  Future<void> distributeTask(Task task) async {
    // Round-robin distribution
    final worker = workers[nextWorker];
    await worker.call(
      program: WORKER_PROG,
      version: 1,
      procedure: PROCESS_TASK,
      params: task.encode(),
    );
  }
}
```

### 3. Legacy System Integration

Integrate with legacy RPC systems:

```dart
// Connect to legacy NFS server
class NfsClient {
  final RpcClient mountClient;
  final RpcClient nfsClient;

  Future<void> mount(String path) async {
    final result = await mountClient.call(
      program: 100005,  // MOUNT
      version: 3,
      procedure: 1,     // MNT
      params: encodePath(path),
    );

    processMount(result);
  }
}
```

### 4. Cross-Language APIs

Expose services to multiple languages:

```dart
// Dart server, accessible from C, Java, Python clients
final server = RpcServer(
  transports: [TcpServerTransport(port: 2049)],
);

DataServiceServerRegistration.register(server, DataServiceImpl());

await server.listen();

// Now accessible from any language with RPC support
```

## Running the Examples

All examples are in the `example/` directory:

```bash
# Echo service
dart run example/echo_server.dart
dart run example/echo_client.dart

# With generated code
dart run bin/rpcgen.dart example/echo.x -o lib/generated/echo.dart
dart run example/echo_server_generated.dart
```

## See Also

- [Code Generator Guide](generator_guide.md)
- [RPC Client Guide](client_guide.md)
- [RPC Server Guide](server_guide.md)
- [XDR Serialization Guide](xdr_guide.md)
