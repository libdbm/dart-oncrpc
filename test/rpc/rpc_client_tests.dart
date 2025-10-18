import 'dart:async';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_errors.dart';
import 'package:dart_oncrpc/src/rpc/rpc_message.dart';
import 'package:dart_oncrpc/src/rpc/testing/mock_transport.dart';
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
  });
}
