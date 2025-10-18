import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_oncrpc/dart_oncrpc.dart';

// Import the same types from the client test
import 'dart_to_c_rpc_test.dart';

void main() async {
  const port = 8888; // Dart server port

  print('Starting Dart RPC Test Server...');
  print('Program: 0x${rpcTestProg.toRadixString(16)}, Version: $rpcTestV1');
  print('Listening on TCP port $port...');

  final server = RpcServer(
    transports: [TcpServerTransport(port: port)],
  );
  final program = RpcProgram(rpcTestProg);
  final version = RpcVersion(rpcTestV1)
    // Procedure 0: NULL (ping)
    ..addProcedure(rpcNull, (params, auth) async {
      print('[Dart Server] RPC_NULL called');
      return null;
    })
    // Procedure 1: ADD
    ..addProcedure(rpcAdd, (params, auth) async {
      final a = params.readInt();
      final b = params.readInt();
      final result = a + b;

      print('[Dart Server] ADD($a, $b) = $result');

      final output = XdrOutputStream()..writeInt(result);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 2: ECHO
    ..addProcedure(rpcEcho, (params, auth) async {
      final text = params.readString();

      print('[Dart Server] ECHO("$text")');

      final output = XdrOutputStream()..writeString(text);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 3: CALCULATE
    ..addProcedure(rpcCalculate, (params, auth) async {
      final op = Operation.fromValue(params.readInt());
      final a = params.readInt();
      final b = params.readInt();

      int result;
      String message;

      switch (op) {
        case Operation.add:
          result = a + b;
          message = 'Added $a + $b';
          break;
        case Operation.subtract:
          result = a - b;
          message = 'Subtracted $a - $b';
          break;
        case Operation.multiply:
          result = a * b;
          message = 'Multiplied $a * $b';
          break;
        case Operation.divide:
          if (b != 0) {
            result = a ~/ b;
            message = 'Divided $a / $b';
          } else {
            result = 0;
            message = 'Error: Division by zero';
          }
          break;
      }

      print(
        '[Dart Server] CALCULATE(op=${op.name}, $a, $b) = $result ($message)',
      );

      final calcResult = CalcResult(result: result, message: message);
      final output = XdrOutputStream()
        ..writeInt(calcResult.result)
        ..writeString(calcResult.message);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 4: ECHO_MANY
    ..addProcedure(rpcEchoMany, (params, auth) async {
      final text = params.readString();
      final count = params.readInt();

      print('[Dart Server] ECHO_MANY("$text", $count)');

      final response = EchoResponse(echoedText: text, timesEchoed: count);
      final output = XdrOutputStream()
        ..writeString(response.echoedText)
        ..writeInt(response.timesEchoed);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 5: SUM_ARRAY
    ..addProcedure(rpcSumArray, (params, auth) async {
      final length = params.readInt();
      final numbers = <int>[];
      for (var i = 0; i < length; i++) {
        numbers.add(params.readInt());
      }

      final total = numbers.fold<int>(0, (sum, n) => sum + n);

      print('[Dart Server] SUM_ARRAY($length numbers) = $total');

      final result = SumResult(total: total, count: length);
      final output = XdrOutputStream()
        ..writeInt(result.total)
        ..writeInt(result.count);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 6: POINT_DISTANCE
    ..addProcedure(rpcPointDistance, (params, auth) async {
      final p1 = Point.decode(params);
      final p2 = Point.decode(params);

      final dx = p2.x - p1.x;
      final dy = p2.y - p1.y;
      final distance = sqrt(dx * dx + dy * dy).toInt();

      print(
        '[Dart Server] POINT_DISTANCE((${p1.x},${p1.y}), (${p2.x},${p2.y})) = $distance',
      );

      final output = XdrOutputStream()..writeInt(distance);
      return Uint8List.fromList(output.bytes);
    })
    // Procedure 7: DIVIDE_SAFE
    ..addProcedure(rpcDivideSafe, (params, auth) async {
      final a = params.readInt();
      final b = params.readInt();

      final output = XdrOutputStream();

      if (b == 0) {
        // Error case
        output
          ..writeInt(1) // status = error
          ..writeString('Cannot divide by zero');
        print('[Dart Server] DIVIDE_SAFE($a, $b) = ERROR');
      } else {
        // Success case
        final result = a ~/ b;
        output
          ..writeInt(0) // status = success
          ..writeInt(result)
          ..writeString('Division successful');
        print('[Dart Server] DIVIDE_SAFE($a, $b) = $result');
      }

      return Uint8List.fromList(output.bytes);
    })
    // Procedure 8: GET_SERVER_INFO
    ..addProcedure(rpcGetServerInfo, (params, auth) async {
      const info = 'Dart RPC Server v1.0 (dart-oncrpc)';

      print('[Dart Server] GET_SERVER_INFO() = "$info"');

      final output = XdrOutputStream()..writeString(info);
      return Uint8List.fromList(output.bytes);
    });

  program.addVersion(version);
  server.addProgram(program);

  await server.listen();

  print('Dart RPC Server ready. Waiting for requests...');
  print('Press Ctrl+C to stop.');

  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nShutting down Dart RPC Server...');
    await server.stop();
    exit(0);
  });
}
