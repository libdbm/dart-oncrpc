import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../xdr/xdr_io.dart';
import 'rpc_message.dart';

Uint8List _cloneBytes(final Uint8List input) =>
    Uint8List.fromList(List<int>.from(input));

Uint8List _hmacSha256(final Uint8List key, final List<int> data) =>
    Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

bool _constantTimeEquals(final List<int> a, final List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Base class for RPC authentication methods.
///
/// ONC-RPC supports multiple authentication flavors as defined in RFC 5531.
/// Each flavor provides different levels of security and identity verification.
///
/// ## Available Authentication Flavors
///
/// - [AuthNone]: No authentication (flavor 0)
/// - [AuthUnix]: Unix-style authentication with UID/GID (flavor 1)
/// - [AuthDes]: DES-based secure authentication (flavor 3)
/// - [AuthGss]: RPCSEC_GSS Kerberos authentication (flavor 6)
///
/// ## Client-Side Usage
///
/// ```dart
/// // Use AUTH_UNIX with current user credentials
/// final client = RpcClient(
///   transport: transport,
///   auth: AuthUnix(uid: 1000, gid: 1000),
/// );
/// ```
///
/// ## Server-Side Usage
///
/// The server automatically validates credentials and provides an [AuthContext]
/// to procedure handlers:
///
/// ```dart
/// version.addProcedure(1, (params, auth) async {
///   // Check authentication
///   if (!auth.isAuthenticated) {
///     throw Exception('Authentication required');
///   }
///
///   // Access user identity
///   final uid = auth.attributes['uid'] as int;
///   // ... perform authorized operation ...
/// });
/// ```
abstract class RpcAuthentication {
  /// Gets the credential to send with each request.
  ///
  /// The credential contains the client's identity and authentication data.
  OpaqueAuth credential();

  /// Gets the verifier to send with each request.
  ///
  /// The verifier proves the client has access to secrets associated with
  /// the credential (e.g., encrypted timestamp).
  OpaqueAuth verifier();

  /// Generates a response verifier based on the request credential.
  ///
  /// Server-side method to create a verifier that proves the server validated
  /// the client's credential. The client can verify this to ensure it's talking
  /// to a legitimate server.
  OpaqueAuth responseVerifier(final OpaqueAuth credential);

  /// Validates a credential and verifier pair.
  ///
  /// Server-side method to check if the provided credential and verifier are
  /// valid. Returns true if authentication succeeds, false otherwise.
  bool validate(final OpaqueAuth credential, final OpaqueAuth verifier);

  /// Verifies a server response verifier on the client side.
  ///
  /// Defaults to accepting all responses. Secure authentication flavors should
  /// override this to validate the server's response MAC/signature.
  bool verify(final OpaqueAuth verifier) => true;

  /// Refreshes time-sensitive authentication data.
  ///
  /// Called periodically to update timestamps or renew tickets for
  /// time-based authentication schemes like AUTH_DES and AUTH_GSS.
  void refresh();
}

/// AUTH_NONE - No authentication (flavor 0).
///
/// This is the default authentication method that provides no identity
/// verification or security. Use this for public services that don't require
/// authentication or for testing.
///
/// Example:
/// ```dart
/// final client = RpcClient(
///   transport: transport,
///   auth: AuthNone(), // or omit auth parameter (defaults to AuthNone)
/// );
/// ```
class AuthNone extends RpcAuthentication {
  @override
  OpaqueAuth credential() => OpaqueAuth.none();

  @override
  OpaqueAuth verifier() => OpaqueAuth.none();

  @override
  OpaqueAuth responseVerifier(final OpaqueAuth credential) => OpaqueAuth.none();

  @override
  bool validate(final OpaqueAuth credential, final OpaqueAuth verifier) =>
      credential.flavor == AuthFlavor.none;

  @override
  void refresh() {}
}

/// AUTH_UNIX - Unix-style authentication (flavor 1).
///
/// This authentication method sends the client's Unix user ID (UID), group ID
/// (GID), machine name, and supplemental group IDs. It provides basic identity
/// information but NO security - credentials are sent in plaintext and can be
/// easily spoofed.
///
/// Use AUTH_UNIX for:
/// - Trusted networks where all machines and users are known
/// - Services that need simple identity tracking without security
/// - NFS and other Unix-oriented RPC services
///
/// Example:
/// ```dart
/// // Authenticate as user 1000, group 1000
/// final client = RpcClient(
///   transport: transport,
///   auth: AuthUnix(
///     uid: 1000,
///     gid: 1000,
///     machineName: 'workstation',
///     gids: [1000, 27, 44], // supplemental groups (cdrom, video, etc.)
///   ),
/// );
/// ```
///
/// See also:
/// - RFC 5531 section 9.2 for AUTH_UNIX specification
/// - [AuthDes] for secure authentication
class AuthUnix extends RpcAuthentication {
  /// Creates Unix-style authentication with the specified credentials.
  ///
  /// Parameters:
  /// - [stamp]: Timestamp for credential generation (defaults to current time)
  /// - [hostname]: Name of the client machine (defaults to 'localhost')
  /// - [uid]: User ID of the calling user (defaults to 0)
  /// - [gid]: Primary group ID of the user (defaults to 0)
  /// - [gids]: Supplemental group IDs (defaults to empty list)
  AuthUnix({
    int? stamp,
    String? hostname,
    int? uid,
    int? gid,
    List<int>? gids,
  })  : stamp = stamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        hostname = hostname ?? 'localhost',
        uid = uid ?? 0,
        gid = gid ?? 0,
        gids = gids ?? [];

  /// Timestamp when this credential was created (Unix epoch seconds).
  final int stamp;

  /// Name of the client machine.
  final String hostname;

  /// User ID of the calling user.
  final int uid;

  /// Primary group ID of the user.
  final int gid;

  /// Supplemental group IDs (e.g., for file access control).
  final List<int> gids;

  @override
  OpaqueAuth credential() {
    final stream = XdrOutputStream()
      ..writeInt(stamp)
      ..writeString(hostname)
      ..writeInt(uid)
      ..writeInt(gid)
      ..writeInt(gids.length);
    gids.forEach(stream.writeInt);

    return OpaqueAuth(
      flavor: AuthFlavor.unix,
      body: Uint8List.fromList(stream.toBytes()),
    );
  }

  @override
  OpaqueAuth verifier() => OpaqueAuth.none();

  @override
  OpaqueAuth responseVerifier(final OpaqueAuth credential) =>
      // AUTH_UNIX uses AUTH_NONE as response verifier
      OpaqueAuth.none();

  @override
  bool validate(final OpaqueAuth credential, final OpaqueAuth verifier) {
    if (credential.flavor != AuthFlavor.unix) {
      return false;
    }

    try {
      final stream = XdrInputStream(credential.body)
        ..readInt() // stamp
        ..readString() // machineName
        ..readInt() // uid
        ..readInt(); // gid
      final gidsLen = stream.readInt();
      final gids = <int>[];
      for (int i = 0; i < gidsLen; i++) {
        gids.add(stream.readInt());
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void refresh() {}

  /// Decodes AUTH_UNIX credentials from XDR-encoded bytes.
  ///
  /// Used by the server to extract Unix credentials from incoming requests.
  ///
  /// Returns an [AuthUnix] instance with the decoded credentials.
  // ignore: prefer_constructors_over_static_methods
  static AuthUnix decode(final Uint8List body) {
    final stream = XdrInputStream(body);
    final stamp = stream.readInt();
    final hostname = stream.readString();
    final uid = stream.readInt();
    final gid = stream.readInt();
    final gidsLen = stream.readInt();
    final gids = <int>[];
    for (int i = 0; i < gidsLen; i++) {
      gids.add(stream.readInt());
    }

    return AuthUnix(
      stamp: stamp,
      hostname: hostname,
      uid: uid,
      gid: gid,
      gids: gids,
    );
  }
}

/// Authentication context provided to RPC procedure handlers.
///
/// [AuthContext] encapsulates the authentication information for an RPC request,
/// including the authentication method used, the client's identity (principal),
/// and additional attributes extracted from the credentials.
///
/// ## Usage in Procedure Handlers
///
/// ```dart
/// version.addProcedure(1, (params, auth) async {
///   // Check if authenticated
///   if (!auth.isAuthenticated) {
///     throw Exception('Authentication required');
///   }
///
///   // Get user identity
///   final uid = auth.attributes['uid'] as int;
///   final gid = auth.attributes['gid'] as int;
///
///   // Check authorization
///   if (uid != 0 && uid != 1000) {
///     throw Exception('Insufficient permissions');
///   }
///
///   // ... perform operation ...
/// });
/// ```
///
/// ## Attributes by Auth Flavor
///
/// ### AUTH_NONE
/// - No attributes available
///
/// ### AUTH_UNIX
/// - `uid`: User ID (int)
/// - `gid`: Primary group ID (int)
/// - `gids`: Supplemental group IDs (`List<int>`)
/// - `machineName`: Client machine name (String)
///
/// ### AUTH_DES / AUTH_GSS
/// - Implementation-specific attributes
class AuthContext {
  /// Creates an authentication context.
  ///
  /// - [auth]: The authentication method used
  /// - [principal]: Optional principal name (e.g., "user@realm")
  /// - [attributes]: Additional authentication attributes
  AuthContext({
    required this.auth,
    this.principal,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};

  /// The authentication method used for this request.
  final RpcAuthentication auth;

  /// The client's principal name (if available).
  ///
  /// For AUTH_UNIX, this is typically "uid:gid".
  /// For AUTH_GSS, this would be the Kerberos principal.
  final String? principal;

  /// Additional authentication attributes extracted from credentials.
  ///
  /// The contents depend on the authentication flavor used.
  /// See class documentation for details on available attributes.
  final Map<String, dynamic> attributes;

  /// Returns true if the client is authenticated (not using AUTH_NONE).
  bool get isAuthenticated => auth is! AuthNone;
}

/// AUTH_DES (DES-based secure RPC authentication)
///
/// Simplified implementation using HMAC-SHA256 instead of DES encryption
/// for demonstration purposes. In production, use proper DES/3DES encryption.
class AuthDes extends RpcAuthentication {
  AuthDes({
    required this.hostname,
    required Uint8List secretKey,
    this.window = 300, // 5 minutes
  })  : secretKey = _cloneBytes(secretKey),
        _timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final String hostname;
  final Uint8List secretKey;
  final int window;
  int _timestamp;

  int get timestamp => _timestamp;

  @override
  OpaqueAuth credential() {
    _timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final payload = XdrOutputStream()
      ..writeString(hostname)
      ..writeInt(_timestamp)
      ..writeInt(window);

    payload.writeOpaque(_hmacSha256(secretKey, payload.bytes));

    return OpaqueAuth(
      flavor: AuthFlavor.des,
      body: Uint8List.fromList(payload.toBytes()),
    );
  }

  @override
  OpaqueAuth verifier() {
    final credentials = XdrOutputStream()..writeInt(_timestamp);
    final mac = _hmacSha256(secretKey, credentials.bytes);
    final payload = XdrOutputStream()
      ..writeInt(_timestamp)
      ..writeOpaque(mac);

    return OpaqueAuth(
      flavor: AuthFlavor.des,
      body: Uint8List.fromList(payload.toBytes()),
    );
  }

  @override
  OpaqueAuth responseVerifier(final OpaqueAuth credential) {
    try {
      final stream = XdrInputStream(credential.body);
      // Extract the timestamp used in the original credential
      final timestamp = () {
        stream.readString(); // netname
        final value = stream.readInt(); // timestamp
        stream
          ..readInt() // window
          ..readOpaque(); // MAC
        return value;
      }();

      final signature = XdrOutputStream()..writeInt(timestamp);
      final mac = _hmacSha256(secretKey, signature.bytes);
      final response = XdrOutputStream()
        ..writeInt(timestamp)
        ..writeOpaque(mac);
      return OpaqueAuth(
        flavor: AuthFlavor.des,
        body: Uint8List.fromList(response.toBytes()),
      );
    } catch (_) {
      return OpaqueAuth.none();
    }
  }

  @override
  bool validate(final OpaqueAuth credential, final OpaqueAuth verifier) {
    if (credential.flavor != AuthFlavor.des ||
        verifier.flavor != AuthFlavor.des) {
      return false;
    }

    try {
      final stream = XdrInputStream(credential.body);
      final hostname = stream.readString();
      final timestamp = stream.readInt();
      final window = stream.readInt();
      final mac = stream.readOpaque();

      final payload = XdrOutputStream()
        ..writeString(hostname)
        ..writeInt(timestamp)
        ..writeInt(window);
      final expected = _hmacSha256(secretKey, payload.bytes);

      if (!_constantTimeEquals(mac, expected)) {
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if ((now - timestamp).abs() > window) {
        return false;
      }

      final verifierStream = XdrInputStream(verifier.body);
      final verifierTimestamp = verifierStream.readInt();
      if (verifierTimestamp != timestamp) {
        return false;
      }
      final verifierMac = verifierStream.readOpaque();
      final verifierPayload = XdrOutputStream()..writeInt(verifierTimestamp);
      final expectedVerifierMac = _hmacSha256(secretKey, verifierPayload.bytes);

      if (!_constantTimeEquals(verifierMac, expectedVerifierMac)) {
        return false;
      }

      _timestamp = timestamp;
      return hostname == hostname;
    } catch (_) {
      return false;
    }
  }

  @override
  bool verify(final OpaqueAuth verifier) {
    if (verifier.flavor != AuthFlavor.des) {
      return false;
    }

    try {
      final stream = XdrInputStream(verifier.body);
      final timestamp = stream.readInt();
      final mac = stream.readOpaque();

      if (timestamp != _timestamp) {
        return false;
      }

      final payload = XdrOutputStream()..writeInt(timestamp);
      final expectedMac = _hmacSha256(secretKey, payload.bytes);
      return _constantTimeEquals(mac, expectedMac);
    } catch (_) {
      return false;
    }
  }

  @override
  void refresh() {
    _timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  // ignore: prefer_constructors_over_static_methods
  static AuthDes decode(final Uint8List body, final Uint8List secretKey) {
    final stream = XdrInputStream(body);
    final hostname = stream.readString();
    final timestamp = stream.readInt();
    final window = stream.readInt();

    return AuthDes(
      hostname: hostname,
      secretKey: secretKey,
      window: window,
    ).._timestamp = timestamp;
  }
}

/// AUTH_GSS (RPCSEC_GSS - Kerberos-based authentication)
///
/// Simplified implementation that models the RPCSEC_GSS credential/verifier
/// exchange using HMAC-SHA256 over the RPCSEC fields. While this is not a full
/// Kerberos stack, it mirrors the wire contract closely enough for integration
/// testing and interoperability development.
class AuthGss extends RpcAuthentication {
  AuthGss({
    required this.principal,
    required this.service,
    required Uint8List sessionKey,
    int sequenceNumber = 0,
  })  : sessionKey = _cloneBytes(sessionKey),
        _sequenceNumber = sequenceNumber;

  static const int _rpcsecVersion = 1;

  final String principal;
  final String service;
  final Uint8List sessionKey;
  int _sequenceNumber;

  int get sequenceNumber => _sequenceNumber;

  @override
  OpaqueAuth credential() {
    final payload = XdrOutputStream()
      ..writeInt(_rpcsecVersion)
      ..writeInt(_sequenceNumber)
      ..writeString(service)
      ..writeString(principal)
      ..writeOpaque(
        _signCredential(_rpcsecVersion, _sequenceNumber, service, principal),
      );

    return OpaqueAuth(
      flavor: AuthFlavor.gss,
      body: Uint8List.fromList(payload.toBytes()),
    );
  }

  @override
  OpaqueAuth verifier() {
    final payload = XdrOutputStream()
      ..writeInt(_rpcsecVersion)
      ..writeInt(_sequenceNumber)
      ..writeOpaque(_signVerifier(_rpcsecVersion, _sequenceNumber));

    return OpaqueAuth(
      flavor: AuthFlavor.gss,
      body: Uint8List.fromList(payload.toBytes()),
    );
  }

  @override
  OpaqueAuth responseVerifier(final OpaqueAuth credential) {
    try {
      final stream = XdrInputStream(credential.body);
      final version = stream.readInt();
      final sequence = stream.readInt();
      stream
        ..readString()
        ..readString()
        ..readOpaque();

      final responseSequence = sequence + 1;
      final payload = XdrOutputStream()
        ..writeInt(version)
        ..writeInt(responseSequence)
        ..writeOpaque(_signVerifier(version, responseSequence));
      return OpaqueAuth(
        flavor: AuthFlavor.gss,
        body: Uint8List.fromList(payload.toBytes()),
      );
    } catch (_) {
      return OpaqueAuth.none();
    }
  }

  @override
  bool validate(final OpaqueAuth credential, final OpaqueAuth verifier) {
    if (credential.flavor != AuthFlavor.gss ||
        verifier.flavor != AuthFlavor.gss) {
      return false;
    }

    try {
      final stream = XdrInputStream(credential.body);
      final version = stream.readInt();
      if (version != _rpcsecVersion) {
        return false;
      }

      final sequence = stream.readInt();
      final service = stream.readString();
      final principal = stream.readString();
      final mac = stream.readOpaque();

      final expected = _signCredential(
        version,
        sequence,
        service,
        principal,
      );

      if (!_constantTimeEquals(mac, expected)) {
        return false;
      }

      if (service != service || principal != principal) {
        return false;
      }

      final verifierStream = XdrInputStream(verifier.body);
      final verifierVersion = verifierStream.readInt();
      if (verifierVersion != version) {
        return false;
      }

      final verifierSequence = verifierStream.readInt();
      if (verifierSequence != sequence) {
        return false;
      }
      final verifierMac = verifierStream.readOpaque();
      final expectedVerifierMac =
          _signVerifier(verifierVersion, verifierSequence);

      if (!_constantTimeEquals(verifierMac, expectedVerifierMac)) {
        return false;
      }

      _sequenceNumber = sequence;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies a server response verifier (client-side usage).
  ///
  /// Returns true if the response MAC matches and sequence numbers advance.
  @override
  bool verify(final OpaqueAuth verifier) {
    if (verifier.flavor != AuthFlavor.gss) {
      return false;
    }

    try {
      final stream = XdrInputStream(verifier.body);
      final version = stream.readInt();
      if (version != _rpcsecVersion) {
        return false;
      }

      final sequence = stream.readInt();
      final mac = stream.readOpaque();
      final expected = _signVerifier(version, _sequenceNumber + 1);

      if (!_constantTimeEquals(mac, expected)) {
        return false;
      }

      _sequenceNumber = sequence + 1;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void refresh() {
    // Would refresh Kerberos ticket in full implementation.
  }

  /// Decode an incoming credential into an [AuthGss] instance using a shared key.
  // ignore: prefer_constructors_over_static_methods
  static AuthGss decode(final Uint8List body, final Uint8List sessionKey) {
    final stream = XdrInputStream(body);
    final version = stream.readInt();
    final sequence = stream.readInt();
    final service = stream.readString();
    final principal = stream.readString();
    final mac = stream.readOpaque();

    if (version != _rpcsecVersion) {
      throw FormatException('Unsupported AUTH_GSS version: $version');
    }

    final auth = AuthGss(
      principal: principal,
      service: service,
      sessionKey: sessionKey,
      sequenceNumber: sequence,
    );

    final expectedMac =
        auth._signCredential(version, sequence, service, principal);
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw const FormatException('Invalid AUTH_GSS credential signature');
    }

    return auth;
  }

  Uint8List _signCredential(
    final int version,
    final int sequence,
    final String service,
    final String principal,
  ) {
    final stream = XdrOutputStream()
      ..writeInt(version)
      ..writeInt(sequence)
      ..writeString(service)
      ..writeString(principal);
    return _hmacSha256(sessionKey, stream.bytes);
  }

  Uint8List _signVerifier(final int version, final int sequence) {
    final stream = XdrOutputStream()
      ..writeInt(version)
      ..writeInt(sequence);
    return _hmacSha256(sessionKey, stream.bytes);
  }
}
