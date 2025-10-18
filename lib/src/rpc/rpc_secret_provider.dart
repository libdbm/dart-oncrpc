import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Uint8List _cloneBytes(final Uint8List value) =>
    Uint8List.fromList(List<int>.from(value));

/// Provides shared secrets for server-side authentication handlers.
///
/// Implementations can source keys from configuration files, secure stores, or
/// any other mechanism appropriate for the deployment environment.
abstract class RpcSecretProvider {
  const RpcSecretProvider();

  /// Returns the shared secret for an AUTH_DES credential associated with [netname].
  ///
  /// When null is returned the server will reject the request with
  /// [AuthStatus.tooweak].
  Uint8List? secretForDes(final String netname);

  /// Returns the session key for an AUTH_GSS credential.
  ///
  /// The combination of [principal] and [service] uniquely identifies the
  /// session. Returning null causes the request to be rejected with
  /// [AuthStatus.tooweak].
  Uint8List? secretForGss({
    required final String principal,
    required final String service,
  });
}

/// No-op secret provider that always returns null.
class NullRpcSecretProvider extends RpcSecretProvider {
  const NullRpcSecretProvider();

  @override
  Uint8List? secretForDes(final String netname) => null;

  @override
  Uint8List? secretForGss({
    required final String principal,
    required final String service,
  }) =>
      null;
}

/// In-memory secret provider for testing and simple deployments.
class StaticRpcSecretProvider extends RpcSecretProvider {
  StaticRpcSecretProvider({
    Map<String, Uint8List>? desKeys,
    Map<String, Map<String, Uint8List>>? gssSessionKeys,
  })  : _desKeys = desKeys != null
            ? desKeys.map(
                (key, value) => MapEntry(key, _cloneBytes(value)),
              )
            : const {},
        _gssSessionKeys = gssSessionKeys != null
            ? gssSessionKeys.map(
                (principal, services) => MapEntry(
                  principal,
                  services.map(
                    (service, value) => MapEntry(service, _cloneBytes(value)),
                  ),
                ),
              )
            : const {};

  final Map<String, Uint8List> _desKeys;
  final Map<String, Map<String, Uint8List>> _gssSessionKeys;

  @override
  Uint8List? secretForDes(final String netname) {
    final key = _desKeys[netname];
    return key != null ? _cloneBytes(key) : null;
  }

  @override
  Uint8List? secretForGss({
    required final String principal,
    required final String service,
  }) {
    final principalMap = _gssSessionKeys[principal];
    if (principalMap == null) return null;
    final key = principalMap[service];
    return key != null ? _cloneBytes(key) : null;
  }
}

/// Secret provider that reads base64-encoded secrets from environment variables.
///
/// Variable naming conventions:
/// - `ONCRPC_DES_SECRET_<NETNAME>` for AUTH_DES keys
/// - `ONCRPC_GSS_SECRET_<PRINCIPAL>_<SERVICE>` for AUTH_GSS session keys
///
/// All non-alphanumeric characters in identifiers are replaced with `_` and
/// names are uppercased before lookup. Values must be base64 strings.
class EnvRpcSecretProvider extends RpcSecretProvider {
  EnvRpcSecretProvider({Map<String, String>? environment})
      : _env = environment ?? Platform.environment;

  final Map<String, String> _env;

  @override
  Uint8List? secretForDes(final String netname) =>
      _decode(_env[_desKey(_slug(netname))]);

  @override
  Uint8List? secretForGss({
    required final String principal,
    required final String service,
  }) =>
      _decode(
        _env[_gssKey(_slug(principal), _slug(service))],
      );

  static String _slug(final String input) =>
      input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '_');

  static String _desKey(final String netnameSlug) =>
      'ONCRPC_DES_SECRET_$netnameSlug';

  static String _gssKey(final String principalSlug, final String serviceSlug) =>
      'ONCRPC_GSS_SECRET_${principalSlug}_$serviceSlug';

  static Uint8List? _decode(final String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(value));
    } catch (_) {
      return null;
    }
  }
}
