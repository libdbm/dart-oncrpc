import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/rpc_secret_provider.dart';
import 'package:test/test.dart';

void main() {
  group('EnvRpcSecretProvider', () {
    test('reads AUTH_DES secrets using slugged env keys', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final env = {
        'ONCRPC_DES_SECRET_CLIENT_REALM': base64Encode(bytes),
      };
      final provider = EnvRpcSecretProvider(environment: env);
      final secret = provider.secretForDes('client@realm');
      expect(secret, equals(bytes));
    });

    test('reads AUTH_GSS secrets using principal and service slugs', () {
      final bytes = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final env = {
        'ONCRPC_GSS_SECRET_USER_REALM_NFS': base64Encode(bytes),
      };
      final provider = EnvRpcSecretProvider(environment: env);
      final secret = provider.secretForGss(
        principal: 'user@realm',
        service: 'nfs',
      );
      expect(secret, equals(bytes));
    });

    test('returns null for missing or invalid values', () {
      final env = {
        'ONCRPC_DES_SECRET_CLIENT_REALM': 'not-base64',
      };
      final provider = EnvRpcSecretProvider(environment: env);
      expect(provider.secretForDes('client@realm'), isNull);
      expect(
        provider.secretForGss(principal: 'user', service: 'svc'),
        isNull,
      );
    });
  });
}
