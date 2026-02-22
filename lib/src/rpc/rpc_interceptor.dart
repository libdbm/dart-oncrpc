/// RPC request/response interceptor framework.
///
/// Interceptors provide a powerful mechanism for adding cross-cutting concerns
/// to RPC clients and servers without modifying procedure handlers. They enable:
/// - Logging and debugging
/// - Metrics collection and monitoring
/// - Authentication and authorization validation
/// - Request/response transformation
/// - Caching and rate limiting
/// - Custom error handling
///
/// ## Client-Side Interceptors
///
/// Client interceptors can intercept outgoing calls and incoming responses:
///
/// ```dart
/// class LoggingInterceptor implements ClientCallInterceptor, ClientResponseInterceptor {
///   @override
///   Future<void> onCall(RpcCallContext context) async {
///     print('Calling ${context.program}.${context.procedure}');
///   }
///
///   @override
///   Future<void> onResponse(RpcResponseContext context) async {
///     if (context.error != null) {
///       print('Error: ${context.error}');
///     } else {
///       print('Success: ${context.result?.length ?? 0} bytes');
///     }
///   }
/// }
///
/// client.addInterceptor(LoggingInterceptor());
/// ```
///
/// ## Server-Side Interceptors
///
/// Server interceptors can validate requests and transform responses:
///
/// ```dart
/// class AuthInterceptor implements ServerRequestInterceptor {
///   @override
///   Future<void> onRequest(RpcRequestContext context) async {
///     // Validate authentication
///     if (!context.auth.isAuthenticated) {
///       throw Exception('Authentication required');
///     }
///
///     // Check authorization
///     if (!hasPermission(context.auth, context.procedure)) {
///       throw Exception('Permission denied');
///     }
///   }
/// }
///
/// server.addInterceptor(AuthInterceptor());
/// ```
///
/// ## Metrics Collection
///
/// ```dart
/// class MetricsInterceptor implements ServerRequestInterceptor, ServerResponseInterceptor {
///   final callCounts = <int, int>{};
///   final responseTimes = <int, List<Duration>>{};
///
///   @override
///   Future<void> onRequest(RpcRequestContext context) async {
///     context.attributes['startTime'] = DateTime.now();
///     callCounts[context.procedure] = (callCounts[context.procedure] ?? 0) + 1;
///   }
///
///   @override
///   Future<void> onResponse(RpcResponseContext context) async {
///     final start = context.attributes['startTime'] as DateTime;
///     final duration = DateTime.now().difference(start);
///     // Record metrics...
///   }
/// }
/// ```
library;

import 'dart:async';
import 'dart:typed_data';

import '../xdr/xdr_io.dart';
import 'rpc_authentication.dart';
import 'rpc_errors.dart';

/// Context passed through the interceptor chain for RPC requests
class RpcRequestContext {
  RpcRequestContext({
    required this.xid,
    required this.program,
    required this.version,
    required this.procedure,
    required this.auth,
    required this.params,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};
  final int xid;
  final int program;
  final int version;
  final int procedure;
  final AuthContext auth;
  final XdrInputStream params;
  final Map<String, dynamic> attributes;

  /// Creates a copy with optional overrides
  RpcRequestContext copyWith({
    final int? xid,
    final int? program,
    final int? version,
    final int? procedure,
    final AuthContext? auth,
    final XdrInputStream? params,
    final Map<String, dynamic>? attributes,
  }) =>
      RpcRequestContext(
        xid: xid ?? this.xid,
        program: program ?? this.program,
        version: version ?? this.version,
        procedure: procedure ?? this.procedure,
        auth: auth ?? this.auth,
        params: params ?? this.params,
        attributes: attributes ?? Map.from(this.attributes),
      );
}

/// Context passed through the interceptor chain for RPC responses
class RpcResponseContext {
  RpcResponseContext({
    required this.xid,
    this.result,
    this.error,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};
  final int xid;
  final Uint8List? result;
  final Object? error;
  final Map<String, dynamic> attributes;

  /// Creates a copy with optional overrides
  RpcResponseContext copyWith({
    final int? xid,
    final Uint8List? result,
    final Object? error,
    final Map<String, dynamic>? attributes,
  }) =>
      RpcResponseContext(
        xid: xid ?? this.xid,
        result: result ?? this.result,
        error: error ?? this.error,
        attributes: attributes ?? Map.from(this.attributes),
      );
}

/// Interceptor for RPC request processing
///
/// Interceptors can:
/// - Log requests/responses
/// - Modify request parameters
/// - Add authentication checks
/// - Collect metrics
/// - Short-circuit request processing
abstract class RpcRequestInterceptor {
  /// Process the request before it reaches the handler.
  ///
  /// Return a modified context to continue processing,
  /// or throw an error to abort the request.
  Future<RpcRequestContext> onRequest(final RpcRequestContext context);
}

/// Interceptor for RPC response processing
abstract class RpcResponseInterceptor {
  /// Process the response before it's sent to the client.
  ///
  /// Return a modified context to continue processing.
  Future<RpcResponseContext> onResponse(final RpcResponseContext context);
}

/// Combined interceptor for both requests and responses
abstract class RpcInterceptor
    implements RpcRequestInterceptor, RpcResponseInterceptor {}

/// Middleware-style handler signature
typedef MiddlewareHandler = Future<RpcResponseContext> Function(
  RpcRequestContext context,
);

/// Server-side middleware that can intercept and modify request/response flow
///
/// Middleware differs from interceptors by having access to the next handler
/// in the chain, allowing for more sophisticated control flow patterns.
abstract class RpcMiddleware {
  /// Process the request with access to the next handler in chain.
  ///
  /// Call `next(context)` to continue to the next middleware or handler,
  /// or return a response directly to short-circuit the chain.
  Future<RpcResponseContext> handle(
    final RpcRequestContext context,
    final MiddlewareHandler next,
  );
}

/// Adapts an interceptor to work as middleware
class InterceptorMiddleware implements RpcMiddleware {
  InterceptorMiddleware({
    RpcRequestInterceptor? request,
    RpcResponseInterceptor? response,
  })  : _requestInterceptor = request,
        _responseInterceptor = response;

  factory InterceptorMiddleware.fromInterceptor(
    final RpcInterceptor interceptor,
  ) =>
      InterceptorMiddleware(
        request: interceptor,
        response: interceptor,
      );
  final RpcRequestInterceptor? _requestInterceptor;
  final RpcResponseInterceptor? _responseInterceptor;

  @override
  Future<RpcResponseContext> handle(
    final RpcRequestContext context,
    final MiddlewareHandler next,
  ) async {
    var requestContext = context;

    // Run request interceptor if present
    if (_requestInterceptor != null) {
      requestContext = await _requestInterceptor!.onRequest(context);
    }

    // Call next handler
    var responseContext = await next(requestContext);

    // Run response interceptor if present
    if (_responseInterceptor != null) {
      responseContext = await _responseInterceptor!.onResponse(responseContext);
    }

    return responseContext;
  }
}

/// Middleware for rate limiting
class RateLimitMiddleware implements RpcMiddleware {
  RateLimitMiddleware({required this.maxCallsPerSecond});

  final int maxCallsPerSecond;
  final Map<String, List<int>> _callTimestamps = {};

  @override
  Future<RpcResponseContext> handle(
    final RpcRequestContext context,
    final MiddlewareHandler next,
  ) async {
    final key = context.auth.principal ?? 'anonymous';
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneSecondAgo = now - 1000;

    // Clean old timestamps
    final timestamps = (_callTimestamps[key] ?? [])
      ..removeWhere((ts) => ts < oneSecondAgo);

    // Check rate limit
    if (timestamps.length >= maxCallsPerSecond) {
      throw RpcServerError(
        RpcServerErrorType.systemErr,
        message: 'Rate limit exceeded: $maxCallsPerSecond calls/sec',
      );
    }

    // Record this call
    timestamps.add(now);
    _callTimestamps[key] = timestamps;

    return next(context);
  }
}

/// Logging interceptor for debugging
class LoggingInterceptor implements RpcInterceptor {
  LoggingInterceptor({void Function(String)? log})
      : _log = log ?? ((msg) => print('[RPC] $msg'));
  final void Function(String) _log;

  @override
  Future<RpcRequestContext> onRequest(final RpcRequestContext context) async {
    _log('Request: ${context.program}:${context.version}.${context.procedure} '
        '(XID: ${context.xid}, Auth: ${context.auth.principal ?? "none"})');
    return context;
  }

  @override
  Future<RpcResponseContext> onResponse(
    final RpcResponseContext context,
  ) async {
    if (context.error != null) {
      _log('Response: XID ${context.xid} - Error: ${context.error}');
    } else {
      _log(
        'Response: XID ${context.xid} - ${context.result?.length ?? 0} bytes',
      );
    }
    return context;
  }
}

/// Metrics collection interceptor
class MetricsInterceptor implements RpcInterceptor {
  final Map<String, int> _callCounts = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, List<int>> _responseTimes = {};

  @override
  Future<RpcRequestContext> onRequest(final RpcRequestContext context) async {
    final key = '${context.program}:${context.version}.${context.procedure}';
    _callCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    context.attributes['_startTime'] = DateTime.now().millisecondsSinceEpoch;
    context.attributes['_procedureKey'] = key;
    return context;
  }

  @override
  Future<RpcResponseContext> onResponse(
    final RpcResponseContext context,
  ) async {
    final startTime = context.attributes['_startTime'] as int?;
    if (startTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      final key = context.attributes['_procedureKey'] as String? ?? 'unknown';
      _responseTimes.update(
        key,
        (v) => v..add(elapsed),
        ifAbsent: () => [elapsed],
      );
    }

    if (context.error != null) {
      final key = context.attributes['_procedureKey'] as String? ?? 'unknown';
      _errorCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    return context;
  }

  Map<String, int> get callCounts => Map.unmodifiable(_callCounts);

  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);

  Map<String, double> get averageResponseTimes =>
      _responseTimes.map((key, times) {
        final avg = times.reduce((a, b) => a + b) / times.length;
        return MapEntry(key, avg);
      });

  void reset() {
    _callCounts.clear();
    _errorCounts.clear();
    _responseTimes.clear();
  }
}

/// Auth validation interceptor
class AuthValidationInterceptor implements RpcRequestInterceptor {
  AuthValidationInterceptor(this._validator);

  final bool Function(AuthContext) _validator;

  @override
  Future<RpcRequestContext> onRequest(final RpcRequestContext context) async {
    if (!_validator(context.auth)) {
      throw RpcAuthError.failed();
    }
    return context;
  }
}

// ============================================================================
// Client-side interceptor contexts and interfaces
// ============================================================================

/// Context for client-side RPC call interceptors
class ClientCallContext {
  ClientCallContext({
    required this.program,
    required this.version,
    required this.procedure,
    this.params,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};
  final int program;
  final int version;
  final int procedure;
  final Uint8List? params;
  final Map<String, dynamic> attributes;

  /// Creates a copy with optional overrides
  ClientCallContext copyWith({
    final int? program,
    final int? version,
    final int? procedure,
    final Uint8List? params,
    final Map<String, dynamic>? attributes,
  }) =>
      ClientCallContext(
        program: program ?? this.program,
        version: version ?? this.version,
        procedure: procedure ?? this.procedure,
        params: params ?? this.params,
        attributes: attributes ?? Map.from(this.attributes),
      );
}

/// Context for client-side RPC response interceptors
class ClientResponseContext {
  ClientResponseContext({
    required this.program,
    required this.version,
    required this.procedure,
    this.result,
    this.error,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};
  final int program;
  final int version;
  final int procedure;
  final Uint8List? result;
  final Object? error;
  final Map<String, dynamic> attributes;

  /// Creates a copy with optional overrides
  ClientResponseContext copyWith({
    final int? program,
    final int? version,
    final int? procedure,
    final Uint8List? result,
    final Object? error,
    final Map<String, dynamic>? attributes,
  }) =>
      ClientResponseContext(
        program: program ?? this.program,
        version: version ?? this.version,
        procedure: procedure ?? this.procedure,
        result: result ?? this.result,
        error: error ?? this.error,
        attributes: attributes ?? Map.from(this.attributes),
      );
}

/// Client-side call interceptor
///
/// Interceptors can:
/// - Modify call parameters
/// - Add retry logic
/// - Log calls
/// - Collect metrics
/// - Short-circuit calls
abstract class ClientCallInterceptor {
  /// Intercept outgoing RPC call before it's sent.
  ///
  /// Return a modified context to continue processing,
  /// or throw an error to abort the call.
  Future<ClientCallContext> onCall(final ClientCallContext context);
}

/// Client-side response interceptor
abstract class ClientResponseInterceptor {
  /// Intercept RPC response before it's returned to caller.
  ///
  /// Return a modified context to continue processing.
  Future<ClientResponseContext> onResponse(final ClientResponseContext context);
}

/// Combined client-side interceptor
abstract class ClientInterceptor
    implements ClientCallInterceptor, ClientResponseInterceptor {}

/// Client-side logging interceptor
class ClientLoggingInterceptor implements ClientInterceptor {
  ClientLoggingInterceptor({void Function(String)? log})
      : _log = log ?? ((msg) => print('[RPC Client] $msg'));
  final void Function(String) _log;

  @override
  Future<ClientCallContext> onCall(final ClientCallContext context) async {
    _log('Call: ${context.program}:${context.version}.${context.procedure} '
        '(${context.params?.length ?? 0} bytes)');
    return context;
  }

  @override
  Future<ClientResponseContext> onResponse(
    final ClientResponseContext context,
  ) async {
    if (context.error != null) {
      _log(
          'Response: ${context.program}:${context.version}.${context.procedure} '
          '- Error: ${context.error}');
    } else {
      _log(
          'Response: ${context.program}:${context.version}.${context.procedure} '
          '- ${context.result?.length ?? 0} bytes');
    }
    return context;
  }
}

/// Client-side metrics interceptor
class ClientMetricsInterceptor implements ClientInterceptor {
  final Map<String, int> _callCounts = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, List<int>> _responseTimes = {};

  @override
  Future<ClientCallContext> onCall(final ClientCallContext context) async {
    final key = '${context.program}:${context.version}.${context.procedure}';
    _callCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    context.attributes['_startTime'] = DateTime.now().millisecondsSinceEpoch;
    context.attributes['_procedureKey'] = key;
    return context;
  }

  @override
  Future<ClientResponseContext> onResponse(
    final ClientResponseContext context,
  ) async {
    final startTime = context.attributes['_startTime'] as int?;
    if (startTime != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      final key = context.attributes['_procedureKey'] as String? ?? 'unknown';
      _responseTimes.update(
        key,
        (v) => v..add(elapsed),
        ifAbsent: () => [elapsed],
      );
    }

    if (context.error != null) {
      final key = context.attributes['_procedureKey'] as String? ?? 'unknown';
      _errorCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    return context;
  }

  Map<String, int> get callCounts => Map.unmodifiable(_callCounts);

  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);

  Map<String, double> get averageResponseTimes =>
      _responseTimes.map((key, times) {
        final avg = times.reduce((a, b) => a + b) / times.length;
        return MapEntry(key, avg);
      });

  void reset() {
    _callCounts.clear();
    _errorCounts.clear();
    _responseTimes.clear();
  }
}
