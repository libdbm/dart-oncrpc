import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_message.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

Uint8List _key(int length) => Uint8List.fromList(
      List<int>.generate(length, (index) => (index * 31) & 0xff),
    );

void main() {
  group('AuthNone', () {
    test('produces no-op credentials and validates', () {
      final auth = AuthNone();
      final credential = auth.credential();
      final verifier = auth.verifier();

      expect(credential.flavor, AuthFlavor.none);
      expect(verifier.flavor, AuthFlavor.none);
      expect(auth.validate(credential, verifier), isTrue);
    });
  });

  group('AuthUnix', () {
    test('encodes and decodes unix credentials', () {
      final auth = AuthUnix(
        stamp: 1234,
        hostname: 'builder',
        uid: 1000,
        gid: 100,
        gids: [100, 101],
      );

      final credential = auth.credential();
      final decoded = AuthUnix.decode(credential.body);

      expect(decoded.uid, 1000);
      expect(decoded.gid, 100);
      expect(decoded.gids, [100, 101]);
      expect(decoded.hostname, 'builder');

      final verifier = auth.verifier();
      expect(auth.validate(credential, verifier), isTrue);
    });
  });

  group('AuthDes', () {
    test('validates request and detects tampering', () {
      final key = _key(32);
      final auth = AuthDes(hostname: 'client', secretKey: key, window: 600);
      final credential = auth.credential();
      final verifier = auth.verifier();
      final server = AuthDes(hostname: 'client', secretKey: key, window: 600);

      final stream = XdrInputStream(credential.body);
      final hostname = stream.readString();
      final timestamp = stream.readInt();
      final window = stream.readInt();
      final mac = stream.readOpaque();
      final payload = XdrOutputStream()
        ..writeString(hostname)
        ..writeInt(timestamp)
        ..writeInt(window);
      final expected = Hmac(sha256, key).convert(payload.bytes).bytes;
      expect(mac, equals(expected));

      final verifierStream = XdrInputStream(verifier.body);
      final verifierTimestamp = verifierStream.readInt();
      expect(verifierTimestamp, timestamp);
      final verifierMac = verifierStream.readOpaque();
      final verifierPayload = XdrOutputStream()..writeInt(verifierTimestamp);
      final expectedVerifierMac =
          Hmac(sha256, key).convert(verifierPayload.bytes).bytes;
      expect(verifierMac, equals(expectedVerifierMac));
      expect(server.validate(credential, verifier), isTrue);

      final tamperedBytes = Uint8List.fromList(credential.body);
      tamperedBytes[tamperedBytes.length - 1] ^= 0x01;
      final tamperedCredential = OpaqueAuth(
        flavor: AuthFlavor.des,
        body: tamperedBytes,
      );
      expect(server.validate(tamperedCredential, verifier), isFalse);

      final tamperedVerifierBytes = Uint8List.fromList(verifier.body);
      tamperedVerifierBytes[tamperedVerifierBytes.length - 1] ^= 0x02;
      final tamperedVerifier = OpaqueAuth(
        flavor: AuthFlavor.des,
        body: tamperedVerifierBytes,
      );
      expect(server.validate(credential, tamperedVerifier), isFalse);

      final response = server.responseVerifier(credential);
      expect(auth.verify(response), isTrue);

      final tamperedResponseBytes = Uint8List.fromList(response.body);
      tamperedResponseBytes[tamperedResponseBytes.length - 1] ^= 0x04;
      final tamperedResponse = OpaqueAuth(
        flavor: AuthFlavor.des,
        body: tamperedResponseBytes,
      );
      expect(auth.verify(tamperedResponse), isFalse);
    });
  });

  group('AuthGss', () {
    test('performs credential handshake and response verification', () {
      final key = _key(32);
      final client = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: key,
      );

      final credential = client.credential();
      final verifier = client.verifier();

      expect(credential.flavor, AuthFlavor.gss);
      expect(verifier.flavor, AuthFlavor.gss);

      final server = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: key,
      );

      expect(server.validate(credential, verifier), isTrue);

      final response = server.responseVerifier(credential);
      expect(response.flavor, AuthFlavor.gss);
      expect(client.verify(response), isTrue);
    });

    test('detects tamperedBytes credentials and responses', () {
      final key = _key(32);
      final client = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: key,
      );
      final credential = client.credential();
      final verifier = client.verifier();

      final server = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: key,
      );

      final tamperedCredentialBytes = Uint8List.fromList(credential.body);
      tamperedCredentialBytes[tamperedCredentialBytes.length - 1] ^= 0x80;
      final tamperedCredential = OpaqueAuth(
        flavor: AuthFlavor.gss,
        body: tamperedCredentialBytes,
      );
      expect(server.validate(tamperedCredential, verifier), isFalse);

      expect(server.validate(credential, verifier), isTrue);
      final response = server.responseVerifier(credential);

      final tamperedResponseBytes = Uint8List.fromList(response.body);
      tamperedResponseBytes[tamperedResponseBytes.length - 1] ^= 0x80;
      final tamperedResponse = OpaqueAuth(
        flavor: AuthFlavor.gss,
        body: tamperedResponseBytes,
      );

      final freshClient = AuthGss(
        principal: 'user@REALM',
        service: 'nfs',
        sessionKey: key,
      );
      expect(freshClient.verify(tamperedResponse), isFalse);
    });
  });
}
