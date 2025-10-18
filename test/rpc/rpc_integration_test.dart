import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_errors.dart';
import 'package:dart_oncrpc/src/rpc/rpc_secret_provider.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server_transport.dart';
import 'package:dart_oncrpc/src/rpc/rpc_transport.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

// ignore_for_file: constant_identifier_names
void main() {
  group('RPC Integration Tests', () {
    const TEST_PROG = 0x30000000;
    const TEST_VERS = 1;
    const ADD_PROC = 1;
    const CONCAT_PROC = 2;
    const ECHO_STRUCT_PROC = 3;
    const VOID_PROC = 4;

    test('TCP client-server communication with integer parameters', () async {
      final transport = TcpServerTransport(port: 9999);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ADD_PROC, (params, auth) async {
          final a = params.readInt();
          final b = params.readInt();
          final result = a + b;
          final output = XdrOutputStream()..writeInt(result);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9999);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeInt(10)
          ..writeInt(20);
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: ADD_PROC,
          params: params.toBytes(),
        );
        expect(result, isNotNull);
        final stream = XdrInputStream(result!);
        final sum = stream.readInt();
        expect(sum, equals(30));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('TCP client-server communication with string parameters', () async {
      final transport = TcpServerTransport(port: 9998);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(CONCAT_PROC, (params, auth) async {
          final s1 = params.readString();
          final s2 = params.readString();
          final result = s1 + s2;
          final output = XdrOutputStream()..writeString(result);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9998);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeString('Hello, ')
          ..writeString('World!');
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: CONCAT_PROC,
          params: params.toBytes(),
        );
        expect(result, isNotNull);
        final resultStream = XdrInputStream(result!);
        final concatenated = resultStream.readString();
        expect(concatenated, equals('Hello, World!'));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('TCP client-server communication with struct parameters', () async {
      final transport = TcpServerTransport(port: 9997);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ECHO_STRUCT_PROC, (params, auth) async {
          final id = params.readInt();
          final name = params.readString();
          final value = params.readFloat();
          final output = XdrOutputStream()
            ..writeInt(id)
            ..writeString(name)
            ..writeFloat(value);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9997);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeInt(42)
          ..writeString('Test Item')
          ..writeFloat(3.14);
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: ECHO_STRUCT_PROC,
          params: params.toBytes(),
        );
        expect(result, isNotNull);
        final resultStream = XdrInputStream(result!);
        expect(resultStream.readInt(), equals(42));
        expect(resultStream.readString(), equals('Test Item'));
        expect(resultStream.readFloat(), closeTo(3.14, 0.001));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('Void procedure returns null', () async {
      final transport = TcpServerTransport(port: 9996);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(VOID_PROC, (params, auth) async => null);

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9996);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: VOID_PROC,
        );
        expect(result == null || result.isEmpty, isTrue);
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('AUTH_DES authentication succeeds with secret provider', () async {
      final secret = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final transport = TcpServerTransport(port: 9989);
      final server = RpcServer(
        transports: [transport],
        secretProvider: StaticRpcSecretProvider(
          desKeys: {'client@realm': secret},
        ),
      );

      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ADD_PROC, (params, auth) async {
          expect(auth.isAuthenticated, isTrue);
          expect(auth.principal, equals('client@realm'));
          expect(auth.attributes['netname'], equals('client@realm'));

          final a = params.readInt();
          final b = params.readInt();
          return (XdrOutputStream()..writeInt(a + b)).toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9989);
      final client = RpcClient(
        transport: clientTransport,
        auth: AuthDes(hostname: 'client@realm', secretKey: secret),
      );
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeInt(2)
          ..writeInt(3);

        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: ADD_PROC,
          params: params.toBytes(),
        );

        expect(result, isNotNull);
        final stream = XdrInputStream(result!);
        expect(stream.readInt(), equals(5));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('AUTH_GSS authentication succeeds with secret provider', () async {
      final sessionKey =
          Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      final transport = TcpServerTransport(port: 9988);
      final server = RpcServer(
        transports: [transport],
        secretProvider: StaticRpcSecretProvider(
          gssSessionKeys: {
            'user@REALM': {'nfs': sessionKey},
          },
        ),
      );

      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(CONCAT_PROC, (params, auth) async {
          expect(auth.isAuthenticated, isTrue);
          expect(auth.principal, equals('user@REALM'));
          final service = auth.attributes['service'];
          expect(service, equals('nfs'));

          final s1 = params.readString();
          final s2 = params.readString();
          return (XdrOutputStream()..writeString('$s1$s2')).toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9988);
      final client = RpcClient(
        transport: clientTransport,
        auth: AuthGss(
          principal: 'user@REALM',
          service: 'nfs',
          sessionKey: sessionKey,
        ),
      );
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeString('foo')
          ..writeString('bar');
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: CONCAT_PROC,
          params: params.toBytes(),
        );

        expect(result, isNotNull);
        final stream = XdrInputStream(result!);
        expect(stream.readString(), equals('foobar'));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('Authentication with AUTH_UNIX', () async {
      final transport = TcpServerTransport(port: 9995);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ADD_PROC, (params, auth) async {
          expect(auth.isAuthenticated, isTrue);
          expect(auth.attributes['uid'], equals(1000));
          expect(auth.attributes['gid'], equals(1000));

          final a = params.readInt();
          final b = params.readInt();
          final result = a + b;
          final output = XdrOutputStream()..writeInt(result);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9995);
      final client = RpcClient(
        transport: clientTransport,
        auth: AuthUnix(uid: 1000, gid: 1000),
      );
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeInt(5)
          ..writeInt(7);
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: ADD_PROC,
          params: params.toBytes(),
        );
        expect(result, isNotNull);
        final resultStream = XdrInputStream(result!);
        expect(resultStream.readInt(), equals(12));
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('Program not available error', () async {
      final transport = TcpServerTransport(port: 9994);
      final server = RpcServer(transports: [transport]);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9994);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        await expectLater(
          client.call(
            program: 0x99999999,
            version: 1,
            procedure: 1,
          ),
          throwsA(
            isA<RpcServerError>().having(
              (e) => e.message,
              'message',
              'Program unavailable',
            ),
          ),
        );
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('Version mismatch error', () async {
      final transport = TcpServerTransport(port: 9993);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(1)
        ..addProcedure(ADD_PROC, (params, auth) async {
          final output = XdrOutputStream()..writeInt(0);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9993);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        await expectLater(
          client.call(
            program: TEST_PROG,
            version: 2, // Wrong version
            procedure: ADD_PROC,
          ),
          throwsA(
            isA<RpcServerError>().having(
              (e) => e.message,
              'message',
              contains('version mismatch'),
            ),
          ),
        );
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('Procedure not available error', () async {
      final transport = TcpServerTransport(port: 9992);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ADD_PROC, (params, auth) async {
          final output = XdrOutputStream()..writeInt(0);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = TcpTransport(host: 'localhost', port: 9992);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        await expectLater(
          client.call(
            program: TEST_PROG,
            version: TEST_VERS,
            procedure: 999, // Non-existent procedure
          ),
          throwsA(
            isA<RpcServerError>().having(
              (e) => e.message,
              'message',
              'Procedure unavailable',
            ),
          ),
        );
      } finally {
        await client.close();
        await server.stop();
      }
    });

    test('UDP client-server communication', () async {
      final transport = UdpServerTransport(address: '127.0.0.1', port: 9991);
      final server = RpcServer(transports: [transport]);
      final program = RpcProgram(TEST_PROG);
      final version = RpcVersion(TEST_VERS)
        ..addProcedure(ADD_PROC, (params, auth) async {
          final a = params.readInt();
          final b = params.readInt();
          final result = a + b;
          final output = XdrOutputStream()..writeInt(result);
          return output.toBytes();
        });

      program.addVersion(version);
      server.addProgram(program);
      await server.listen();

      final clientTransport = UdpTransport(host: '127.0.0.1', port: 9991);
      final client = RpcClient(transport: clientTransport);
      await client.connect();

      try {
        final params = XdrOutputStream()
          ..writeInt(15)
          ..writeInt(25);
        final result = await client.call(
          program: TEST_PROG,
          version: TEST_VERS,
          procedure: ADD_PROC,
          params: params.toBytes(),
        );
        expect(result, isNotNull);
        final resultStream = XdrInputStream(result!);
        final sum = resultStream.readInt();
        expect(sum, equals(40));
      } finally {
        await client.close();
        await server.stop();
      }
    });
  });
}
