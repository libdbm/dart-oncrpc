/// Base class for all RPC-related errors and exceptions.
///
/// All errors thrown by the dart_oncrpc library extend this sealed base class,
/// allowing for exhaustive pattern matching and unified error handling:
///
/// ```dart
/// try {
///   await client.call(...);
/// } on RpcError catch (e) {
///   // Exhaustive pattern matching with sealed classes
///   switch (e) {
///     case RpcTransportError():
///       print('Network error: ${e.message}');
///     case RpcProtocolError():
///       print('Protocol error: ${e.message}');
///     case RpcServerError():
///       print('Server error: ${e.type}');
///     case RpcAuthError():
///       print('Auth error: ${e.type}');
///     case RpcTimeoutError():
///       print('Timeout after ${e.timeout}');
///     case RpcConnectionError():
///       print('Connection error: ${e.message}');
///     case ParseError():
///       print('Parse error: ${e.message}');
///     case CodeGenerationError():
///       print('Code generation error: ${e.message}');
///     case TlsError():
///       print('TLS error: ${e.message}');
///   }
/// }
/// ```
///
/// ## Error Hierarchy
///
/// - [RpcTransportError]: Network/transport layer errors
/// - [RpcProtocolError]: RPC protocol violations
/// - [RpcServerError]: Server-side errors (program/procedure unavailable, etc.)
/// - [RpcAuthError]: Authentication failures
/// - [RpcTimeoutError]: Request timeout errors
/// - [RpcConnectionError]: Connection state errors
/// - [ParseError]: .x file parsing errors
/// - [CodeGenerationError]: Code generation errors
/// - [TlsError]: TLS/SSL errors
sealed class RpcError implements Exception {
  /// Creates an RPC error with the specified message.
  RpcError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() {
    // Use switch to get readable class names instead of runtimeType
    final className = switch (this) {
      RpcTransportError() => 'RpcTransportError',
      RpcProtocolError() => 'RpcProtocolError',
      RpcServerError() => 'RpcServerError',
      RpcAuthError() => 'RpcAuthError',
      RpcTimeoutError() => 'RpcTimeoutError',
      RpcConnectionError() => 'RpcConnectionError',
      ParseError() => 'ParseError',
      CodeGenerationError() => 'CodeGenerationError',
      TlsError() => 'TlsError',
    };
    return '$className: $message';
  }
}

/// Error that occurs during network transport operations.
///
/// Thrown when there are network-level issues such as:
/// - Connection failures
/// - Socket errors
/// - Network timeouts
/// - DNS resolution failures
///
/// Example:
/// ```dart
/// try {
///   await client.connect();
/// } on RpcTransportError catch (e) {
///   print('Failed to connect: ${e.message}');
///   if (e.cause != null) {
///     print('Underlying cause: ${e.cause}');
///   }
/// }
/// ```
class RpcTransportError extends RpcError {
  /// Creates a transport error with optional underlying cause.
  RpcTransportError(super.message, {this.cause});

  /// The underlying exception that caused this transport error (if available).
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'RpcTransportError: $message (caused by: $cause)';
    }
    return 'RpcTransportError: $message';
  }
}

/// Error that occurs during RPC protocol processing
class RpcProtocolError extends RpcError {
  RpcProtocolError(super.message, {this.xid});
  final int? xid;

  @override
  String toString() {
    if (xid != null) {
      return 'RpcProtocolError: $message (XID: $xid)';
    }
    return 'RpcProtocolError: $message';
  }
}

/// Error returned by the RPC server indicating a rejected call.
///
/// The server can reject RPC calls for various reasons as defined in RFC 5531:
///
/// - **PROG_UNAVAIL**: The requested program is not registered
/// - **PROG_MISMATCH**: Program exists but version is not supported
/// - **PROC_UNAVAIL**: Procedure is not available in this version
/// - **GARBAGE_ARGS**: Arguments could not be decoded
/// - **SYSTEM_ERR**: Server encountered an internal error
/// - **RPC_MISMATCH**: RPC protocol version is not supported (expects version 2)
///
/// Example handling:
/// ```dart
/// try {
///   await client.call(
///     program: 100005,
///     version: 3,
///     procedure: 1,
///   );
/// } on RpcServerError catch (e) {
///   switch (e.type) {
///     case RpcServerErrorType.progUnavail:
///       print('Server does not support this program');
///       break;
///     case RpcServerErrorType.progMismatch:
///       print('Server supports versions ${e.low}-${e.high}');
///       break;
///     case RpcServerErrorType.procUnavail:
///       print('This procedure is not available');
///       break;
///     default:
///       print('Server error: ${e.message}');
///   }
/// }
/// ```
class RpcServerError extends RpcError {
  /// Creates an RPC server error with the specified type and optional version bounds.
  RpcServerError(this.type, {String message = '', this.low, this.high})
      : super(message);

  /// Creates a PROG_UNAVAIL error (program not registered on server).
  factory RpcServerError.progUnavail() => RpcServerError(
        RpcServerErrorType.progUnavail,
        message: 'Program unavailable',
      );

  /// Creates a PROG_MISMATCH error (version not supported).
  ///
  /// [low] is the minimum supported version, [high] is the maximum.
  factory RpcServerError.progMismatch(final int low, final int high) =>
      RpcServerError(
        RpcServerErrorType.progMismatch,
        message: 'Program version mismatch. Supported: $low-$high',
        low: low,
        high: high,
      );

  /// Creates a PROC_UNAVAIL error (procedure not available in this version).
  factory RpcServerError.procUnavail() => RpcServerError(
        RpcServerErrorType.procUnavail,
        message: 'Procedure unavailable',
      );

  /// Creates a GARBAGE_ARGS error (arguments could not be decoded).
  factory RpcServerError.garbageArgs() => RpcServerError(
        RpcServerErrorType.garbageArgs,
        message: 'Garbage arguments',
      );

  /// Creates a SYSTEM_ERR error (internal server error).
  factory RpcServerError.systemErr() =>
      RpcServerError(RpcServerErrorType.systemErr, message: 'System error');

  /// Creates an RPC_MISMATCH error (RPC protocol version not supported).
  factory RpcServerError.rpcMismatch(final int low, final int high) =>
      RpcServerError(
        RpcServerErrorType.rpcMismatch,
        message: 'RPC version mismatch. Supported: $low-$high',
        low: low,
        high: high,
      );

  /// The type of server error that occurred.
  final RpcServerErrorType type;

  /// Minimum supported version (for PROG_MISMATCH and RPC_MISMATCH errors).
  final int? low;

  /// Maximum supported version (for PROG_MISMATCH and RPC_MISMATCH errors).
  final int? high;
}

/// Types of RPC server errors
enum RpcServerErrorType {
  progUnavail,
  progMismatch,
  procUnavail,
  garbageArgs,
  systemErr,
  rpcMismatch,
}

/// Authentication-related errors.
///
/// Thrown when the server rejects a request due to authentication failures.
/// These correspond to the AUTH_ERROR reject status in RFC 5531.
///
/// ## Error Types
///
/// - **AUTH_BADCRED**: Credential is malformed or invalid
/// - **AUTH_REJECTEDCRED**: Credential is well-formed but rejected (e.g., expired)
/// - **AUTH_BADVERF**: Verifier is malformed or invalid
/// - **AUTH_REJECTEDVERF**: Verifier is well-formed but rejected
/// - **AUTH_TOOWEAK**: Authentication is too weak for this service
/// - **AUTH_INVALIDRESP**: Response verifier from server is invalid
/// - **AUTH_FAILED**: Generic authentication failure
///
/// Example:
/// ```dart
/// try {
///   final client = RpcClient(
///     transport: transport,
///     auth: AuthUnix(uid: 1000, gid: 1000),
///   );
///   await client.call(...);
/// } on RpcAuthError catch (e) {
///   if (e.type == RpcAuthErrorType.tooweak) {
///     print('Server requires stronger authentication');
///     // Try with AUTH_DES or AUTH_GSS
///   } else {
///     print('Authentication failed: ${e.message}');
///   }
/// }
/// ```
class RpcAuthError extends RpcError {
  /// Creates an authentication error with the specified type.
  RpcAuthError(this.type, {final String message = ''}) : super(message);

  /// Creates an AUTH_BADCRED error (malformed credentials).
  factory RpcAuthError.badcred() =>
      RpcAuthError(RpcAuthErrorType.badcred, message: 'Bad credentials');

  /// Creates an AUTH_REJECTEDCRED error (credentials rejected).
  factory RpcAuthError.rejectedcred() => RpcAuthError(
        RpcAuthErrorType.rejectedcred,
        message: 'Rejected credentials',
      );

  /// Creates an AUTH_BADVERF error (malformed verifier).
  factory RpcAuthError.badverf() =>
      RpcAuthError(RpcAuthErrorType.badverf, message: 'Bad verifier');

  /// Creates an AUTH_REJECTEDVERF error (verifier rejected).
  factory RpcAuthError.rejectedverf() =>
      RpcAuthError(RpcAuthErrorType.rejectedverf, message: 'Rejected verifier');

  /// Creates an AUTH_TOOWEAK error (authentication too weak).
  factory RpcAuthError.tooweak() => RpcAuthError(
        RpcAuthErrorType.tooweak,
        message: 'Authentication too weak',
      );

  /// Creates an AUTH_INVALIDRESP error (invalid response verifier).
  factory RpcAuthError.invalidresp() =>
      RpcAuthError(RpcAuthErrorType.invalidresp, message: 'Invalid response');

  /// Creates an AUTH_FAILED error (generic failure).
  factory RpcAuthError.failed() =>
      RpcAuthError(RpcAuthErrorType.failed, message: 'Authentication failed');

  /// The specific type of authentication error.
  final RpcAuthErrorType type;
}

/// Types of authentication errors
enum RpcAuthErrorType {
  badcred,
  rejectedcred,
  badverf,
  rejectedverf,
  tooweak,
  invalidresp,
  failed,
}

/// Timeout error for RPC operations
class RpcTimeoutError extends RpcError {
  RpcTimeoutError(this.timeout, {this.retries = 0})
      : super('RPC call timed out after ${timeout.inSeconds}s'
            '${retries > 0 ? ' ($retries retries)' : ''}');
  final Duration timeout;
  final int retries;
}

/// Error when client is closed or not connected
class RpcConnectionError extends RpcError {
  RpcConnectionError(super.message);

  factory RpcConnectionError.notConnected() =>
      RpcConnectionError('Client not connected');

  factory RpcConnectionError.closed() => RpcConnectionError('Client closed');

  factory RpcConnectionError.alreadyConnected() =>
      RpcConnectionError('Already connected');
}

/// Error during parsing of .x specification files
class ParseError extends RpcError {
  ParseError(
    super.message, {
    this.line,
    this.column,
    this.source,
  });

  factory ParseError.syntaxError(
    final String details, {
    final int? line,
    final int? column,
  }) =>
      ParseError(
        'Syntax error: $details',
        line: line,
        column: column,
      );

  factory ParseError.undefinedConstant(final String name) =>
      ParseError('Undefined constant: $name');

  factory ParseError.duplicateDefinition(final String name) =>
      ParseError('Duplicate definition: $name');
  final int? line;
  final int? column;
  final String? source;

  @override
  String toString() {
    final buffer = StringBuffer('ParseError: $message');
    if (line != null && column != null) {
      buffer.write(' at line $line, column $column');
    }
    if (source != null) {
      buffer.write(' in $source');
    }
    return buffer.toString();
  }
}

/// Error during code generation
class CodeGenerationError extends RpcError {
  CodeGenerationError(
    super.message, {
    this.fileName,
    this.cause,
  });

  factory CodeGenerationError.unsupportedType(final String typeName) =>
      CodeGenerationError('Unsupported type: $typeName');

  factory CodeGenerationError.writeError(
    final String fileName,
    final Object cause,
  ) =>
      CodeGenerationError(
        'Failed to write generated code',
        fileName: fileName,
        cause: cause,
      );
  final String? fileName;
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('CodeGenerationError: $message');
    if (fileName != null) {
      buffer.write(' in file $fileName');
    }
    if (cause != null) {
      buffer.write(' (caused by: $cause)');
    }
    return buffer.toString();
  }
}

/// Error during TLS/SSL operations
class TlsError extends RpcError {
  TlsError(super.message, {this.cause});

  factory TlsError.handshakeFailed([final Object? cause]) =>
      TlsError('TLS handshake failed', cause: cause);

  factory TlsError.certificateError(final String details) =>
      TlsError('Certificate error: $details');

  factory TlsError.invalidContext() =>
      TlsError('Invalid or missing SecurityContext');
  final Object? cause;
}
