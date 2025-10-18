import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_logger.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server_transport.dart';
import 'package:dart_oncrpc/src/rpc/rpc_transport.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';

// ignore_for_file: constant_identifier_names
void main() async {
  RpcLogger.level = LogLevel.debug;

  const TEST_PROG = 0x30000000;
  const TEST_VERS = 1;
  const ADD_PROC = 1;

  print('Creating server...');
  final server = RpcServer(
    transports: [TcpServerTransport(port: 9999)],
  );
  final program = RpcProgram(TEST_PROG);
  final version = RpcVersion(TEST_VERS)
    ..addProcedure(ADD_PROC, (params, auth) async {
      print('Server: ADD_PROC called');
      try {
        final a = params.readInt();
        final b = params.readInt();
        print('Server: Read values a=$a, b=$b');
        final result = a + b;
        print('Server: Calculated result=$result');

        final output = XdrOutputStream()..writeInt(result);
        final bytes = Uint8List.fromList(output.bytes);
        print('Server: Returning ${bytes.length} bytes');
        return bytes;
      } catch (e, st) {
        print('Server: Error in procedure: $e');
        print('Server: Stack: $st');
        rethrow;
      }
    });

  program.addVersion(version);
  server.addProgram(program);
  await server.listen();
  print('Server listening on port 9999');

  print('Creating client...');
  final transport = TcpTransport(host: 'localhost', port: 9999);
  final client = RpcClient(transport: transport);
  await client.connect();
  print('Client connected');

  try {
    print('Client: Preparing parameters...');
    final params = XdrOutputStream()
      ..writeInt(10)
      ..writeInt(20);
    print('Client: Encoded ${params.bytes.length} bytes');

    print('Client: Making RPC call...');
    final result = await client.call(
      program: TEST_PROG,
      version: TEST_VERS,
      procedure: ADD_PROC,
      params: Uint8List.fromList(params.bytes),
    );

    print('Client: Got result: ${result?.length ?? 0} bytes');
    if (result != null) {
      final stream = XdrInputStream(result);
      final sum = stream.readInt();
      print('Client: Sum = $sum');
      if (sum == 30) {
        print('SUCCESS: Test passed!');
      } else {
        print('FAILURE: Expected 30, got $sum');
      }
    } else {
      print('FAILURE: No result received');
    }
  } catch (e, st) {
    print('Client error: $e');
    print('Stack: $st');
  } finally {
    await client.close();
    await server.stop();
    print('Cleaned up');
  }
}
