import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_errors.dart';
import 'package:dart_oncrpc/src/rpc/rpc_message.dart';
import 'package:dart_oncrpc/src/rpc/rpc_transport.dart';
import 'package:dart_oncrpc/src/rpc/testing/mock_transport.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

Uint8List _sessionKey() => Uint8List.fromList(List<int>.generate(16, (i) => i));

void main() {
  group('RpcClient', () {
    test('rejects replies with invalid response verifier', () async {
      final clientAuth = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: _sessionKey(),
      );

      final serverAuth = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: _sessionKey(),
      );

      final transport = MockTransport(
        replyGenerator: (call) {
          final body = call.body as CallBody;

          // Server validates incoming credential/verifier pair.
          expect(serverAuth.validate(body.cred, body.verf), isTrue);

          final response = serverAuth.responseVerifier(body.cred);
          final tampered = Uint8List.fromList(response.body);
          tampered[0] ^= 0xFF;
          final tamperedVerifier = OpaqueAuth(
            flavor: response.flavor,
            body: tampered,
          );

          return RpcMessage(
            xid: call.xid,
            messageType: MessageType.reply,
            body: ReplyBody(
              replyStatus: ReplyStatus.accepted,
              data: AcceptedReply(
                verf: tamperedVerifier,
                acceptStatus: AcceptStatus.success,
                data: SuccessData(Uint8List(0)),
              ),
            ),
          );
        },
      );

      final client = RpcClient(transport: transport, auth: clientAuth);
      await client.connect();

      await expectLater(
        client.call(
          program: 1,
          version: 1,
          procedure: 1,
        ),
        throwsA(
          isA<RpcAuthError>().having(
            (error) => error.type,
            'type',
            RpcAuthErrorType.invalidresp,
          ),
        ),
      );

      await client.close();
    });

    test('allocates distinct XIDs for concurrent calls', () async {
      final transport = MockTransport();
      final client = RpcClient(transport: transport);
      await client.connect();

      final first = client.call(
        program: 42,
        version: 1,
        procedure: 1,
      );

      // Allow first call to be sent.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(transport.sentMessages, isNotEmpty);
      final xid1 = transport.sentMessages.first.xid;

      final second = client.call(
        program: 42,
        version: 1,
        procedure: 2,
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(transport.sentMessages, hasLength(2));
      final xid2 = transport.sentMessages[1].xid;

      expect(xid1, isNot(equals(xid2)));

      // Respond to both calls with empty success payloads.
      transport
        ..injectReply(
          RpcMessage(
            xid: xid1,
            messageType: MessageType.reply,
            body: ReplyBody(
              replyStatus: ReplyStatus.accepted,
              data: AcceptedReply(
                verf: OpaqueAuth.none(),
                acceptStatus: AcceptStatus.success,
                data: SuccessData(null),
              ),
            ),
          ),
        )
        ..injectReply(
          RpcMessage(
            xid: xid2,
            messageType: MessageType.reply,
            body: ReplyBody(
              replyStatus: ReplyStatus.accepted,
              data: AcceptedReply(
                verf: OpaqueAuth.none(),
                acceptStatus: AcceptStatus.success,
                data: SuccessData(null),
              ),
            ),
          ),
        );

      await expectLater(first, completion(isNull));
      await expectLater(second, completion(isNull));

      await client.close();
    });

    test('maxRetries = 0 still performs one attempt', () async {
      final transport = MockTransport();
      final client = RpcClient(
        transport: transport,
        timeout: const Duration(milliseconds: 30),
        maxRetries: 0,
      );
      await client.connect();

      await expectLater(
        client.call(program: 1, version: 1, procedure: 1),
        throwsA(isA<RpcTimeoutError>()),
      );
      expect(transport.sentCount, equals(1));

      await client.close();
    });

    test('rejects negative maxRetries', () {
      expect(
        () => RpcClient(transport: MockTransport(), maxRetries: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('UDP client ignores replies from unexpected source endpoint',
        () async {
      final server =
          await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final attacker =
          await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);

      final client = RpcClient(
        transport: UdpTransport(host: '127.0.0.1', port: server.port),
        timeout: const Duration(milliseconds: 60),
        maxRetries: 0,
      );
      await client.connect();

      final firstRequest = Completer<Datagram>();
      final serverSub = server.listen((event) {
        if (event != RawSocketEvent.read || firstRequest.isCompleted) {
          return;
        }
        final datagram = server.receive();
        if (datagram != null) {
          firstRequest.complete(datagram);
        }
      });

      try {
        final callFuture = client.call(program: 1, version: 1, procedure: 1);
        final request = await firstRequest.future.timeout(
          const Duration(seconds: 1),
        );
        final xid = XdrInputStream(request.data).readInt();

        final forgedReply = RpcMessage(
          xid: xid,
          messageType: MessageType.reply,
          body: ReplyBody(
            replyStatus: ReplyStatus.accepted,
            data: AcceptedReply(
              verf: OpaqueAuth.none(),
              acceptStatus: AcceptStatus.success,
              data: SuccessData(Uint8List(0)),
            ),
          ),
        );
        final stream = XdrOutputStream();
        forgedReply.encode(stream);
        attacker.send(stream.toBytes(), request.address, request.port);

        await expectLater(callFuture, throwsA(isA<RpcTimeoutError>()));
      } finally {
        await serverSub.cancel();
        await client.close();
        attacker.close();
        server.close();
      }
    });
  });
}
