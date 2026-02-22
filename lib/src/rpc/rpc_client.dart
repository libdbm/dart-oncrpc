import 'dart:async';
import 'dart:typed_data';

import '../xdr/xdr_io.dart';
import 'rpc_authentication.dart';
import 'rpc_errors.dart';
import 'rpc_interceptor.dart';
import 'rpc_logger.dart';
import 'rpc_message.dart';
import 'rpc_transport.dart';

/// ONC-RPC client for making remote procedure calls.
///
/// The [RpcClient] provides a high-level interface for invoking procedures on
/// remote RPC servers. It handles:
/// - Connection management and reconnection
/// - Authentication (AUTH_NONE, AUTH_UNIX, AUTH_DES, AUTH_GSS)
/// - Automatic retries on timeout
/// - Request/response correlation via XID (transaction ID)
/// - Client-side interceptors for logging, metrics, and custom processing
///
/// ## Example Usage
///
/// ```dart
/// // Create client with TCP transport
/// final transport = TcpTransport(host: 'nfs-server.local', port: 2049);
/// final client = RpcClient(
///   transport: transport,
///   auth: AuthUnix.currentUser(),
///   timeout: Duration(seconds: 10),
///   maxRetries: 3,
/// );
///
/// // Connect and make RPC call
/// await client.connect();
/// final result = await client.call(
///   program: 100005,  // MOUNT program
///   version: 3,
///   procedure: 1,     // MNT
///   params: mountParams,
/// );
///
/// // Clean up
/// await client.close();
/// ```
///
/// ## Interceptors
///
/// Add interceptors for cross-cutting concerns:
///
/// ```dart
/// // Add logging
/// client.addInterceptor(ClientLoggingInterceptor());
///
/// // Add metrics collection
/// final metrics = ClientMetricsInterceptor();
/// client.addInterceptor(metrics);
///
/// // Check metrics later
/// print('Call counts: ${metrics.callCounts}');
/// print('Average response times: ${metrics.averageResponseTimes}');
/// ```
///
/// See also:
/// - [RpcTransport] for transport options
/// - [RpcAuthentication] for authentication methods
/// - [ClientInterceptor] for custom request/response processing
class RpcClient {
  /// Creates an RPC client with the specified transport and options.
  ///
  /// [transport] - The network transport (TCP or UDP)
  /// [auth] - Authentication method (defaults to AUTH_NONE)
  /// [timeout] - Timeout for each RPC call (default: 30 seconds)
  /// [maxRetries] - Maximum number of retries on timeout (default: 3)
  RpcClient({
    required this.transport,
    RpcAuthentication? auth,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  }) : auth = auth ?? AuthNone() {
    if (maxRetries < 0) {
      throw ArgumentError.value(maxRetries, 'maxRetries', 'must be >= 0');
    }
  }

  /// The network transport used for RPC communication.
  final RpcTransport transport;

  /// Authentication method for this client.
  final RpcAuthentication auth;

  /// Timeout duration for RPC calls.
  final Duration timeout;

  /// Maximum number of retry attempts on timeout.
  final int maxRetries;

  final _pendingCalls = <int, Completer<Uint8List?>>{};
  final _callInterceptors = <ClientCallInterceptor>[];
  final _responseInterceptors = <ClientResponseInterceptor>[];
  StreamSubscription<RpcMessage>? _messageSubscription;

  /// Maximum XID (transaction ID) value: 31-bit positive integer.
  ///
  /// RFC 5531 does not explicitly reserve the sign bit, but XIDs are
  /// transmitted as signed 32-bit integers in XDR. Using 0x7FFFFFFF
  /// (max positive signed 32-bit value) ensures compatibility and
  /// avoids potential issues with negative XIDs.
  static const int _maxXidValue = 0x7fffffff;
  int _nextXid = 1;

  /// Adds an interceptor to the client.
  ///
  /// Interceptors are called in the order they are added. The [interceptor]
  /// can implement [ClientCallInterceptor], [ClientResponseInterceptor], or both.
  ///
  /// Example:
  /// ```dart
  /// client.addInterceptor(ClientLoggingInterceptor());
  /// client.addInterceptor(ClientMetricsInterceptor());
  /// ```
  void addInterceptor(final dynamic interceptor) {
    if (interceptor is ClientCallInterceptor) {
      _callInterceptors.add(interceptor);
    }
    if (interceptor is ClientResponseInterceptor) {
      _responseInterceptors.add(interceptor);
    }
  }

  /// Removes an interceptor from the client.
  ///
  /// The [interceptor] must be the same object instance that was added.
  void removeInterceptor(final dynamic interceptor) {
    _callInterceptors.remove(interceptor);
    _responseInterceptors.remove(interceptor);
  }

  /// Connects to the RPC server.
  ///
  /// Must be called before making any RPC calls. This establishes the
  /// underlying transport connection and starts listening for responses.
  ///
  /// Throws [RpcTransportError] if connection fails.
  Future<void> connect() async {
    if (transport.isConnected) {
      return;
    }

    await transport.connect();

    await _messageSubscription?.cancel();
    _messageSubscription = transport.messages.listen(
      _handleReply,
      onError: _handleError,
    );
  }

  /// Closes the RPC client and releases all resources.
  ///
  /// This method:
  /// - Cancels the message subscription
  /// - Closes the underlying transport connection
  /// - Fails all pending RPC calls with [RpcTransportError]
  ///
  /// After calling this method, the client cannot be reused. Create a new
  /// instance if you need to reconnect.
  Future<void> close() async {
    await _messageSubscription?.cancel();
    await transport.close();

    // Cancel all pending calls
    for (final completer in _pendingCalls.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          RpcTransportError('Client closed'),
        );
      }
    }
    _pendingCalls.clear();
  }

  /// Invokes a remote procedure call on the RPC server.
  ///
  /// This is the main method for making RPC calls. It handles:
  /// - Automatic connection if not already connected
  /// - Running call interceptors before sending the request
  /// - Automatic retries on timeout (up to [maxRetries] times)
  /// - Running response interceptors after receiving the reply
  /// - Proper error handling and propagation
  ///
  /// Parameters:
  /// - [program]: The RPC program number (e.g., 100005 for MOUNT)
  /// - [version]: The program version number
  /// - [procedure]: The procedure number to invoke
  /// - [params]: Optional XDR-encoded parameters for the procedure
  ///
  /// Returns the XDR-encoded result from the server, or null if the procedure
  /// returns void.
  ///
  /// Throws:
  /// - [RpcTimeoutError] if the call times out after all retries
  /// - [RpcServerError] if the server returns an error (program unavailable,
  ///   version mismatch, procedure unavailable, etc.)
  /// - [RpcAuthError] if authentication fails
  /// - [RpcTransportError] if the connection is lost
  ///
  /// Example:
  /// ```dart
  /// // Prepare parameters
  /// final params = XdrOutputStream();
  /// params.writeString('/export/data');
  ///
  /// // Make the call
  /// final result = await client.call(
  ///   program: 100005,  // MOUNT
  ///   version: 3,
  ///   procedure: 1,     // MNT
  ///   params: Uint8List.fromList(params.bytes),
  /// );
  ///
  /// // Decode the result
  /// if (result != null) {
  ///   final stream = XdrInputStream(result);
  ///   final status = stream.readInt();
  ///   // ...
  /// }
  /// ```
  Future<Uint8List?> call({
    required int program,
    required int version,
    required int procedure,
    Uint8List? params,
  }) async {
    if (!transport.isConnected) {
      await connect();
    }

    // Run call interceptors
    var callContext = ClientCallContext(
      program: program,
      version: version,
      procedure: procedure,
      params: params,
    );

    for (final interceptor in _callInterceptors) {
      callContext = await interceptor.onCall(callContext);
    }

    int timedOutAttempts = 0;

    while (true) {
      try {
        final result = await _makeCall(
          callContext.program,
          callContext.version,
          callContext.procedure,
          callContext.params,
        );

        // Run response interceptors on success
        var responseContext = ClientResponseContext(
          program: callContext.program,
          version: callContext.version,
          procedure: callContext.procedure,
          result: result,
          attributes: callContext.attributes,
        );

        for (final interceptor in _responseInterceptors) {
          responseContext = await interceptor.onResponse(responseContext);
        }

        return responseContext.result;
      } on TimeoutException {
        timedOutAttempts++;
        if (timedOutAttempts > maxRetries) {
          throw RpcTimeoutError(timeout, retries: maxRetries);
        }
      } catch (e) {
        // Run response interceptors on error
        var responseContext = ClientResponseContext(
          program: callContext.program,
          version: callContext.version,
          procedure: callContext.procedure,
          error: e,
          attributes: callContext.attributes,
        );

        for (final interceptor in _responseInterceptors) {
          try {
            responseContext = await interceptor.onResponse(responseContext);
          } catch (interceptorError) {
            RpcLogger.warning(
              'Interceptor error during error handling: $interceptorError',
            );
          }
        }

        rethrow;
      }
    }
  }

  Future<Uint8List?> _makeCall(
    final int program,
    final int version,
    final int procedure,
    final Uint8List? params,
  ) async {
    final xid = _allocateXid();

    final message = RpcMessage(
      xid: xid,
      messageType: MessageType.call,
      body: CallBody(
        prog: program,
        vers: version,
        proc: procedure,
        cred: auth.credential(),
        verf: auth.verifier(),
        params: params,
      ),
    );

    final completer = Completer<Uint8List?>();
    _pendingCalls[xid] = completer;

    await transport.send(message);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingCalls.remove(xid);
        throw TimeoutException('RPC call timed out', timeout);
      },
    );
  }

  void _handleReply(final RpcMessage message) {
    if (message.messageType != MessageType.reply) {
      return;
    }

    final completer = _pendingCalls.remove(message.xid);
    if (completer == null || completer.isCompleted) {
      // Log if a reply arrives after timeout or for unknown xid
      if (completer != null && completer.isCompleted) {
        RpcLogger.warning(
          'Received reply for xid ${message.xid} after timeout',
        );
      }
      return;
    }

    final reply = message.body as ReplyBody;

    if (reply.replyStatus == ReplyStatus.accepted) {
      final accepted = reply.data as AcceptedReply;

      if (!auth.verify(accepted.verf)) {
        completer.completeError(RpcAuthError.invalidresp());
        return;
      }

      switch (accepted.acceptStatus) {
        case AcceptStatus.success:
          // Return the result data from the message
          final successData = accepted.data! as SuccessData;
          completer.complete(successData.result);
          break;

        case AcceptStatus.progUnavail:
          completer.completeError(RpcServerError.progUnavail());
          break;

        case AcceptStatus.progMismatch:
          final mismatch = accepted.data as MismatchInfo?;
          completer.completeError(
            RpcServerError.progMismatch(
              mismatch?.low ?? 0,
              mismatch?.high ?? 0,
            ),
          );
          break;

        case AcceptStatus.procUnavail:
          completer.completeError(RpcServerError.procUnavail());
          break;

        case AcceptStatus.garbageArgs:
          completer.completeError(RpcServerError.garbageArgs());
          break;

        case AcceptStatus.systemErr:
          completer.completeError(RpcServerError.systemErr());
          break;
      }
    } else {
      final rejected = reply.data as RejectedReply;

      switch (rejected.rejectStatus) {
        case RejectStatus.rpcMismatch:
          final mismatch = rejected.data as MismatchInfo?;
          completer.completeError(
            RpcServerError.rpcMismatch(
              mismatch?.low ?? 2,
              mismatch?.high ?? 2,
            ),
          );
          break;

        case RejectStatus.authError:
          final authErr = rejected.data as AuthError?;
          final status = authErr?.status;
          completer.completeError(_mapAuthStatusToError(status));
          break;
      }
    }
  }

  void _handleError(final Object error) {
    RpcLogger.error('RPC transport error', error);

    // Notify all pending calls about the error
    final pendingCount = _pendingCalls.length;
    if (pendingCount > 0) {
      RpcLogger.info(
        'Failing $pendingCount pending RPC calls due to transport error',
      );
    }

    for (final completer in _pendingCalls.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingCalls.clear();
  }

  RpcAuthError _mapAuthStatusToError(final AuthStatus? status) {
    if (status == null) return RpcAuthError.failed();

    return switch (status) {
      AuthStatus.badcred => RpcAuthError.badcred(),
      AuthStatus.rejectedcred => RpcAuthError.rejectedcred(),
      AuthStatus.badverf => RpcAuthError.badverf(),
      AuthStatus.rejectedverf => RpcAuthError.rejectedverf(),
      AuthStatus.tooweak => RpcAuthError.tooweak(),
      AuthStatus.invalidresp => RpcAuthError.invalidresp(),
      AuthStatus.failed => RpcAuthError.failed(),
      AuthStatus.ok => RpcAuthError.failed(), // Shouldn't happen
    };
  }

  int _allocateXid() {
    for (var attempts = 0; attempts < _maxXidValue; attempts++) {
      final xid = _nextXid;
      _nextXid = _nextXid == _maxXidValue ? 1 : _nextXid + 1;
      if (!_pendingCalls.containsKey(xid)) {
        return xid;
      }
    }
    throw StateError('Unable to allocate RPC XID: exhausted space');
  }
}

/// Convenience wrapper for making RPC calls with typed parameters and results.
///
/// [TypedRpcClient] provides a higher-level API that works with strongly-typed
/// Dart objects instead of raw [Uint8List] buffers. It automatically handles
/// XDR encoding/decoding using provided encoder and decoder functions.
///
/// This is particularly useful when working with generated code from rpcgen,
/// where each type has its own encode/decode methods.
///
/// Example:
/// ```dart
/// final typed = TypedRpcClient(client);
///
/// // Make a typed call
/// final response = await typed.call<MountResponse>(
///   program: 100005,
///   version: 3,
///   procedure: 1,
///   encodeParams: (stream) {
///     stream.writeString('/export/data');
///   },
///   decodeResult: (stream) => MountResponse.decode(stream),
/// );
///
/// print('Mount status: ${response.status}');
/// ```
class TypedRpcClient {
  /// Creates a typed RPC client wrapper around an existing [RpcClient].
  TypedRpcClient(this.client);

  /// The underlying RPC client that handles the actual communication.
  final RpcClient client;

  /// Invokes a remote procedure call with typed parameters and result.
  ///
  /// This method provides type-safe RPC calls by handling XDR encoding/decoding
  /// automatically. The type parameter [T] specifies the expected return type.
  ///
  /// Parameters:
  /// - [program]: The RPC program number
  /// - [version]: The program version number
  /// - [procedure]: The procedure number to invoke
  /// - [encodeParams]: Optional function to encode parameters into XDR format
  /// - [decodeResult]: Optional function to decode the XDR result into type [T]
  ///
  /// Returns an instance of [T] decoded from the server's response, or null if
  /// the procedure returns void or [decodeResult] is not provided.
  ///
  /// Example:
  /// ```dart
  /// // Call with typed parameters and result
  /// final sum = await typed.call<int>(
  ///   program: 0x20000100,
  ///   version: 1,
  ///   procedure: 1,
  ///   encodeParams: (stream) {
  ///     stream.writeInt(10);
  ///     stream.writeInt(20);
  ///   },
  ///   decodeResult: (stream) => stream.readInt(),
  /// );
  ///
  /// print('Sum: $sum');
  /// ```
  Future<T?> call<T>({
    required final int program,
    required final int version,
    required final int procedure,
    final void Function(XdrOutputStream)? encodeParams,
    final T Function(XdrInputStream)? decodeResult,
  }) async {
    Uint8List? params;

    if (encodeParams != null) {
      final stream = XdrOutputStream();
      encodeParams(stream);
      params = Uint8List.fromList(stream.toBytes());
    }

    final result = await client.call(
      program: program,
      version: version,
      procedure: procedure,
      params: params,
    );

    if (result != null && decodeResult != null) {
      final stream = XdrInputStream(result);
      return decodeResult(stream);
    }

    return null;
  }
}
