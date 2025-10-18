# Basic RPC Server Example

This example shows how to build a minimal ONC-RPC server in Dart using dart_oncrpc.

It defines a simple program with one version and one procedure that echoes back an input string.

## Quick start

- Make sure you have Dart SDK installed (3.x)
- From the repository root, run the example below with `dart run`

## Minimal server

```dart
// file: example/basic_server.dart (inline example)
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_server.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server_transport.dart';
import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';

// Program and version identifiers (arbitrary example values)
const int PROG = 0x20000002; // pick your own unique program number
const int VERS = 1;
const int ECHO_PROC = 1; // first custom procedure id

Future<Uint8List?> echo(XdrInputStream params, AuthContext auth) async {
  // Read a string from the request parameters
  final input = params.readString();

  // Prepare the response payload
  final out = XdrOutputStream()..writeString(input);
  return Uint8List.fromList(out.bytes);
}

Future<void> main(List<String> args) async {
  final server = RpcServer(
    transports: [TcpServerTransport(port: 8080)],
  );

  // Define program -> version -> procedures
  final program = RpcProgram(PROG)
    ..addVersion(
      RpcVersion(VERS)
        ..addProcedure(ECHO_PROC, echo),
    );

  // Register program and start listening
  server.addProgram(program);
  await server.listen();

  print('Basic RPC server listening on TCP port 8080');
}
```

### Run it

From the project root:

```bash
dart run example/echo_server.dart
# or run the inline example by placing it into example/basic_server.dart first
```

### Test it quickly

Use the provided echo client:

```bash
# Terminal 1
dart run example/echo_server.dart

# Terminal 2
dart run example/echo_client.dart
```

Or use rpcinfo to check that the server responds to NULL calls (procedure 0) if you register via portmapper in a more advanced setup.

## See also

- Full featured server with multiple procedures: example/echo_server.dart
- Client example: example/echo_client.dart
- Documentation: doc/server_guide.md, doc/examples.md
