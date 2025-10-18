import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:test/test.dart';

// Constants from rpc_test.x
const rpcTestProg = 0x20000100;
const rpcTestV1 = 1;
const maxNameLen = 100;
const maxItems = 50;

// Procedure numbers
const rpcNull = 0;
const rpcAdd = 1;
const rpcEcho = 2;
const rpcCalculate = 3;
const rpcEchoMany = 4;
const rpcSumArray = 5;
const rpcPointDistance = 6;
const rpcDivideSafe = 7;
const rpcGetServerInfo = 8;

// Enums
enum Operation {
  add(0),
  subtract(1),
  multiply(2),
  divide(3);

  final int value;
  // ignore: sort_constructors_first
  const Operation(this.value);

  static Operation fromValue(final int value) =>
      Operation.values.firstWhere((e) => e.value == value);
}

// Structs
class Point {
  Point({required this.x, required this.y});
  final int x;
  final int y;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(x)
      ..writeInt(y);
  }

  // ignore: prefer_constructors_over_static_methods
  static Point decode(final XdrInputStream stream) => Point(
        x: stream.readInt(),
        y: stream.readInt(),
      );
}

class CalcRequest {
  CalcRequest({required this.op, required this.a, required this.b});
  final Operation op;
  final int a;
  final int b;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(op.value)
      ..writeInt(a)
      ..writeInt(b);
  }
}

class CalcResult {
  CalcResult({required this.result, required this.message});
  final int result;
  final String message;

  // ignore: prefer_constructors_over_static_methods
  static CalcResult decode(final XdrInputStream stream) => CalcResult(
        result: stream.readInt(),
        message: stream.readString(),
      );
}

class EchoRequest {
  EchoRequest({required this.text, required this.count});
  final String text;
  final int count;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeString(text)
      ..writeInt(count);
  }
}

class EchoResponse {
  EchoResponse({required this.echoedText, required this.timesEchoed});
  final String echoedText;
  final int timesEchoed;

  // ignore: prefer_constructors_over_static_methods
  static EchoResponse decode(final XdrInputStream stream) => EchoResponse(
        echoedText: stream.readString(),
        timesEchoed: stream.readInt(),
      );
}

class SumRequest {
  SumRequest({required this.numbers});
  final List<int> numbers;

  void encode(final XdrOutputStream stream) {
    stream.writeInt(numbers.length);
    numbers.forEach(stream.writeInt);
  }
}

class SumResult {
  SumResult({required this.total, required this.count});
  final int total;
  final int count;

  // ignore: prefer_constructors_over_static_methods
  static SumResult decode(final XdrInputStream stream) => SumResult(
        total: stream.readInt(),
        count: stream.readInt(),
      );
}

class AddRequest {
  AddRequest({required this.a, required this.b});
  final int a;
  final int b;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(a)
      ..writeInt(b);
  }
}

class PointPair {
  PointPair({required this.p1, required this.p2});
  final Point p1;
  final Point p2;

  void encode(final XdrOutputStream stream) {
    p1.encode(stream);
    p2.encode(stream);
  }
}

class DivideRequest {
  DivideRequest({required this.dividend, required this.divisor});
  final int dividend;
  final int divisor;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(dividend)
      ..writeInt(divisor);
  }
}

// Union
abstract class TestResult {
  TestResult(this.status);
  final int status;

  static TestResult decode(final XdrInputStream stream) {
    final status = stream.readInt();
    switch (status) {
      case 0:
        return TestResultSuccess(CalcResult.decode(stream));
      case 1:
        return TestResultError(stream.readString());
      default:
        return TestResultVoid();
    }
  }
}

class TestResultSuccess extends TestResult {
  TestResultSuccess(this.success) : super(0);
  final CalcResult success;
}

class TestResultError extends TestResult {
  TestResultError(this.error) : super(1);
  final String error;
}

class TestResultVoid extends TestResult {
  TestResultVoid() : super(2);
}

void main() {
  group('Dart Client → C Server RPC Tests', tags: ['integration', 'c-interop'],
      () {
    String? skipReason;
    RpcClient? client;
    Process? serverProcess;
    const serverHost = 'localhost';
    const serverPort = 7777;

    setUpAll(() async {
      // Note: setUpAll runs even when tests are skipped with @Skip.
      // We handle this gracefully by catching errors.
      try {
        // Check if rpcgen is available
        final rpcgenCheck = await Process.run('which', ['rpcgen']);
        if (rpcgenCheck.exitCode != 0) {
          throw Exception(
            'rpcgen not found. Please install rpcgen to run RPC compatibility tests.',
          );
        }

        // Clean up any existing generated files
        final workDir = Directory('test/compatibility/rpc');
        const artifacts = [
          'rpc_test_xdr.c',
          'rpc_test_clnt.c',
          'rpc_test.h',
          'c_rpc_server',
          'c_rpc_client',
          'c_server.log',
        ];
        for (final fileName in artifacts) {
          final file = File('${workDir.path}/$fileName');
          if (await file.exists()) {
            await file.delete();
          }
        }

        // Generate XDR and client code with rpcgen
        await Process.run(
          'rpcgen',
          ['-h', 'rpc_test.x', '-o', 'rpc_test.h'],
          workingDirectory: workDir.path,
        );
        await Process.run(
          'rpcgen',
          ['-c', 'rpc_test.x', '-o', 'rpc_test_xdr.c'],
          workingDirectory: workDir.path,
        );
        await Process.run(
          'rpcgen',
          ['-l', 'rpc_test.x', '-o', 'rpc_test_clnt.c'],
          workingDirectory: workDir.path,
        );

        // Compile C server and client
        await Process.run(
          'cc',
          [
            '-o',
            'c_rpc_server',
            'c_rpc_server.c',
            'rpc_test_xdr.c',
            '-Wno-unused-variable',
            '-Wno-deprecated-non-prototype',
          ],
          workingDirectory: workDir.path,
        );
        await Process.run(
          'cc',
          [
            '-o',
            'c_rpc_client',
            'c_rpc_client.c',
            'rpc_test_clnt.c',
            'rpc_test_xdr.c',
            '-Wno-unused-variable',
            '-Wno-deprecated-non-prototype',
            '-Wno-incompatible-function-pointer-types',
            '-Wno-implicit-function-declaration',
          ],
          workingDirectory: workDir.path,
        );

        // First, try to connect to an already-running server
        // (e.g., when run by run_rpc_matrix.sh)
        stdout.writeln('Attempting to connect to C RPC server...');
        client = RpcClient(
          transport: TcpTransport(host: serverHost, port: serverPort),
        );

        try {
          await client!.connect();
          stdout.writeln('Connected to existing C RPC server!');
          return;
        } catch (e) {
          // Server not running, try to start it ourselves
          stdout.writeln('No server running, will start our own...');
        }

        // Check if C server executable exists
        const serverPath = 'test/compatibility/rpc/c_rpc_server';
        final serverFile = File(serverPath);

        if (!serverFile.existsSync()) {
          // Tests are already skipped, so just return
          client = null;
          return;
        }

        // Start the C server
        stdout.writeln('Starting C RPC server at $serverHost:$serverPort...');
        serverProcess = await Process.start(
          serverPath,
          [],
          workingDirectory: 'test/compatibility/rpc',
        );

        // Give the server time to start
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Connect client
        stdout.writeln('Connecting to C RPC server...');
        await client!.connect();
        stdout.writeln('Connected successfully!');
        skipReason = null;
      } catch (e) {
        // If setUp fails and tests are already skipped, silently ignore
        // This is expected when @Skip annotation is active
        client = null;
        skipReason ??=
            'C RPC server not available - requires rpcgen and build prerequisites ($e)';
      }
    });

    tearDownAll(() async {
      // Close client first (if initialized)
      try {
        await client?.close();
      } catch (e) {
        // Client may not be initialized if tests were skipped
      }

      // Stop the C server
      if (serverProcess != null) {
        stdout.writeln('Stopping C RPC server...');
        serverProcess!.kill();
        await serverProcess!.exitCode;
      }

      // Clean up generated files
      final workDir = Directory('test/compatibility/rpc');
      const artifacts = [
        'rpc_test_xdr.c',
        'rpc_test_clnt.c',
        'rpc_test.h',
        'c_rpc_server',
        'c_rpc_client',
        'c_server.log',
      ];
      for (final fileName in artifacts) {
        final file = File('${workDir.path}/$fileName');
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    RpcClient? clientOrSkip() {
      if (client == null) {
        markTestSkipped(
          skipReason ??
              'C RPC server not available - requires rpcgen and build prerequisites',
        );
      }
      return client;
    }

    test('RPC_NULL (ping)', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcNull,
      );

      // NULL procedure returns void (null or empty)
      expect(result, anyOf(isNull, isEmpty));
    });

    test('ADD - simple addition', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = AddRequest(a: 42, b: 8);
      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcAdd,
        params: Uint8List.fromList(params.bytes),
      );

      final response = XdrInputStream(result!);
      final sum = response.readInt();

      expect(sum, equals(50));
    });

    test('ECHO - string echo', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      const testString = 'Hello from Dart!';
      final params = XdrOutputStream()..writeString(testString);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcEcho,
        params: Uint8List.fromList(params.bytes),
      );

      final response = XdrInputStream(result!);
      final echoed = response.readString();

      expect(echoed, equals(testString));
    });

    test('CALCULATE - with operation enum', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = CalcRequest(
        op: Operation.multiply,
        a: 7,
        b: 6,
      );

      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcCalculate,
        params: Uint8List.fromList(params.bytes),
      );

      final response = CalcResult.decode(XdrInputStream(result!));

      expect(response.result, equals(42));
      expect(response.message, contains('Multiplied'));
    });

    test('ECHO_MANY - struct request and response', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = EchoRequest(
        text: 'Test message',
        count: 5,
      );

      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcEchoMany,
        params: Uint8List.fromList(params.bytes),
      );

      final response = EchoResponse.decode(XdrInputStream(result!));

      expect(response.echoedText, equals('Test message'));
      expect(response.timesEchoed, equals(5));
    });

    test('SUM_ARRAY - variable-length array', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = SumRequest(
        numbers: [10, 20, 30, 40, 50],
      );

      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcSumArray,
        params: Uint8List.fromList(params.bytes),
      );

      final response = SumResult.decode(XdrInputStream(result!));

      expect(response.total, equals(150));
      expect(response.count, equals(5));
    });

    test('POINT_DISTANCE - multiple struct parameters', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = PointPair(
        p1: Point(x: 0, y: 0),
        p2: Point(x: 3, y: 4),
      );

      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcPointDistance,
        params: Uint8List.fromList(params.bytes),
      );

      final response = XdrInputStream(result!);
      final distance = response.readInt();

      expect(distance, equals(5)); // sqrt(3^2 + 4^2) = 5
    });

    test('DIVIDE_SAFE - union success case', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = DivideRequest(dividend: 20, divisor: 4);
      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcDivideSafe,
        params: Uint8List.fromList(params.bytes),
      );

      final response = TestResult.decode(XdrInputStream(result!));

      expect(response, isA<TestResultSuccess>());
      final success = response as TestResultSuccess;
      expect(success.success.result, equals(5));
    });

    test('DIVIDE_SAFE - union error case (divide by zero)', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final request = DivideRequest(dividend: 20, divisor: 0);
      final params = XdrOutputStream();
      request.encode(params);

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcDivideSafe,
        params: Uint8List.fromList(params.bytes),
      );

      final response = TestResult.decode(XdrInputStream(result!));

      expect(response, isA<TestResultError>());
      final error = response as TestResultError;
      expect(error.error, contains('zero'));
    });

    test('GET_SERVER_INFO - void parameter', () async {
      final currentClient = clientOrSkip();
      if (currentClient == null) return;

      final result = await currentClient.call(
        program: rpcTestProg,
        version: rpcTestV1,
        procedure: rpcGetServerInfo,
      );

      final response = XdrInputStream(result!);
      final info = response.readString();

      expect(info, contains('C RPC Server'));
      expect(info, contains('rpcgen'));
    });
  });
}
