import 'dart:async';
import 'dart:typed_data';

import '../xdr/xdr_io.dart';
import 'rpc_authentication.dart';
import 'rpc_interceptor.dart';
import 'rpc_logger.dart';
import 'rpc_message.dart';
import 'rpc_secret_provider.dart';
import 'rpc_server_transport.dart';

/// Handler function for RPC procedures
///
/// Takes encoded parameters and authentication context,
/// returns encoded response data or null for void procedures.
typedef RpcProcedureHandler = Future<Uint8List?> Function(
  XdrInputStream params,
  AuthContext auth,
);

/// Represents an RPC program with multiple versions and procedures.
///
/// An RPC program is identified by a unique program number (typically defined
/// in RFC specifications or assigned from the user-defined range). Each program
/// can support multiple versions, allowing for backward compatibility and
/// protocol evolution.
///
/// Example:
/// ```dart
/// // Create a MOUNT program (program number 100005)
/// final mountProgram = RpcProgram(100005);
///
/// // Add version 3 of the MOUNT protocol
/// final v3 = RpcVersion(3);
/// v3.addProcedure(0, nullProcedure);  // NULL
/// v3.addProcedure(1, mntProcedure);   // MNT
/// v3.addProcedure(2, dumpProcedure);  // DUMP
/// v3.addProcedure(3, umntProcedure);  // UMNT
/// mountProgram.addVersion(v3);
/// ```
class RpcProgram {
  /// Creates an RPC program with the specified program number.
  ///
  /// [programNumber] should be a unique identifier for this program. Standard
  /// program numbers are documented in RFC 1833. User-defined programs should
  /// use numbers in the range 0x20000000-0x3fffffff.
  RpcProgram(this.programNumber);

  /// The unique program number identifying this RPC program.
  final int programNumber;

  /// Map of version number to version implementation.
  final Map<int, RpcVersion> _versions = {};

  /// Adds a version to this program.
  ///
  /// If a version with the same number already exists, it will be replaced.
  void addVersion(final RpcVersion version) {
    _versions[version.versionNumber] = version;
  }

  /// Gets a specific version of this program.
  ///
  /// Returns null if the requested version is not supported.
  RpcVersion? version(final int versionNumber) => _versions[versionNumber];

  /// Gets a sorted list of all supported version numbers.
  ///
  /// The list is sorted in ascending order, with the lowest version first.
  List<int> versions() => _versions.keys.toList()..sort();
}

/// Represents a specific version of an RPC program.
///
/// Each version contains a collection of procedures that can be invoked by
/// clients. Procedures are identified by procedure numbers and implemented
/// as asynchronous handler functions.
///
/// By convention, procedure 0 is the NULL procedure, which should be
/// implemented as a no-op that returns null. This is used for health checks
/// and server availability testing.
///
/// Example:
/// ```dart
/// final version = RpcVersion(3);
///
/// // Add NULL procedure (required by convention)
/// version.addProcedure(0, (params, auth) async => null);
///
/// // Add actual procedures
/// version.addProcedure(1, (params, auth) async {
///   final path = params.readString();
///   // ... mount logic ...
///   final output = XdrOutputStream();
///   output.writeInt(0);  // Status: OK
///   return output.toBytes();
/// });
/// ```
class RpcVersion {
  /// Creates an RPC version with the specified version number.
  RpcVersion(this.versionNumber);

  /// The version number for this version of the program.
  final int versionNumber;

  /// Map of procedure number to procedure handler.
  final Map<int, RpcProcedureHandler> _procedures = {};

  /// Adds a procedure to this version.
  ///
  /// [id] identifies the procedure (0 for NULL by convention)
  /// [handler] is the async function that implements the procedure logic
  ///
  /// If a procedure with the same number already exists, it will be replaced.
  void addProcedure(
    final int id,
    final RpcProcedureHandler handler,
  ) {
    _procedures[id] = handler;
  }

  /// Gets the handler for a specific procedure.
  ///
  /// Returns null if the procedure is not available in this version.
  RpcProcedureHandler? procedure(final int id) => _procedures[id];
}

/// ONC-RPC server for handling remote procedure calls.
///
/// [RpcServer] provides a complete server implementation that can:
/// - Listen on multiple transports (TCP, UDP) simultaneously
/// - Handle multiple RPC programs with different versions
/// - Authenticate clients using AUTH_NONE, AUTH_UNIX, etc.
/// - Apply interceptors and middleware for logging, metrics, and custom logic
/// - Return proper error responses for invalid programs, versions, or procedures
///
/// ## Basic Usage
///
/// ```dart
/// // Create server with TCP and UDP transports
/// final server = RpcServer(transports: [
///   TcpServerTransport(port: 8080),
///   UdpServerTransport(port: 8080),
/// ]);
///
/// // Register a program
/// final program = RpcProgram(100000);
/// final version = RpcVersion(1);
/// version.addProcedure(0, (params, auth) async => null); // NULL
/// version.addProcedure(1, myProcedureHandler);
/// program.addVersion(version);
/// server.addProgram(program);
///
/// // Start listening
/// await server.listen();
/// ```
///
///
/// ## Interceptors and Middleware
///
/// ```dart
/// // Add request/response interceptors
/// server.addInterceptor(ServerLoggingInterceptor());
/// server.addInterceptor(ServerMetricsInterceptor());
///
/// // Add middleware for auth checks
/// server.addMiddleware(AuthorizationMiddleware());
/// ```
class RpcServer {
  /// Creates an RPC server with the specified transports.
  ///
  /// Each incoming request is processed synchronously to match ONC-RPC's
  /// request/response semantics. If you need asynchronous fan-out, layer it
  /// above this API.
  ///
  /// Parameters:
  /// - [transports]: Network transports to listen on.
  /// - [secretProvider]: Supplies shared secrets for AUTH_DES/AUTH_GSS validation.
  RpcServer({
    required List<ServerTransport> transports,
    RpcSecretProvider? secretProvider,
  })  : _transports = transports,
        _secretProvider = secretProvider ?? const NullRpcSecretProvider();
  final List<ServerTransport> _transports;
  final RpcSecretProvider _secretProvider;
  final Map<int, RpcProgram> _programs = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<RpcRequestInterceptor> _requestInterceptors = [];
  final List<RpcResponseInterceptor> _responseInterceptors = [];
  final List<RpcMiddleware> _middlewares = [];
  bool _running = false;

  /// Adds an interceptor to the server.
  ///
  /// Interceptors are called in the order they are added.
  void addInterceptor(final dynamic interceptor) {
    if (interceptor is RpcRequestInterceptor) {
      _requestInterceptors.add(interceptor);
    }
    if (interceptor is RpcResponseInterceptor) {
      _responseInterceptors.add(interceptor);
    }
  }

  /// Removes an interceptor from the server.
  void removeInterceptor(final dynamic interceptor) {
    _requestInterceptors.remove(interceptor);
    _responseInterceptors.remove(interceptor);
  }

  /// Adds middleware to the server.
  ///
  /// Middleware is called in the order it's added.
  /// Use middleware for cross-cutting concerns that need control flow.
  void addMiddleware(final RpcMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Removes middleware from the server.
  void removeMiddleware(final RpcMiddleware middleware) {
    _middlewares.remove(middleware);
  }

  /// Registers an RPC program with the server.
  ///
  /// The program will be available for clients to call once the server is
  /// started with [listen]. If a program with the same program number already
  /// exists, it will be replaced.
  ///
  /// Example:
  /// ```dart
  /// final mountProgram = RpcProgram(100005);
  /// // ... configure versions and procedures ...
  /// server.addProgram(mountProgram);
  /// ```
  void addProgram(final RpcProgram program) {
    _programs[program.programNumber] = program;
  }

  /// Gets a registered program by its program number.
  ///
  /// Returns null if no program with the given number has been registered.
  RpcProgram? program(final int programNumber) => _programs[programNumber];

  /// Starts the server and begins accepting RPC requests.
  ///
  /// The server will continue running until [stop] is called.
  ///
  /// Example:
  /// ```dart
  /// await server.listen();
  /// print('Server is running');
  /// ```
  Future<void> listen() async {
    if (_running) return;
    _running = true;

    try {
      for (final transport in _transports) {
        _subscriptions.add(transport.requests.listen(_handleRequest));
        await transport.listen();
      }
    } catch (e) {
      // Clean up subscriptions if listen fails
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      _running = false;
      rethrow;
    }
  }

  /// Stops the server and releases all resources.
  ///
  /// This method:
  /// - Cancels all active subscriptions
  /// - Closes all transports
  ///
  /// After calling this method, the server cannot be restarted. Create a new
  /// instance if you need to start the server again.
  ///
  /// Example:
  /// ```dart
  /// // Graceful shutdown
  /// await server.stop();
  /// print('Server stopped');
  /// ```
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final transport in _transports) {
      await transport.close();
    }
  }

  /// Returns true if the server is currently running.
  bool get isRunning => _running;

  void _handleRequest(final RpcRequest request) {
    _processRequest(request);
  }

  void _processRequest(final RpcRequest request) {
    try {
      RpcLogger.debug('Processing request: ${request.data.length} bytes');
      final stream = XdrInputStream(request.data);
      RpcLogger.debug('Decoding RPC message...');
      final message = RpcMessage.decode(stream);
      RpcLogger.debug(
        'RPC message decoded: xid=${message.xid}, type=${message.messageType}',
      );

      if (message.messageType != MessageType.call) {
        return;
      }

      final call = message.body as CallBody;
      RpcLogger.debug(
        'RPC call: prog=${call.prog}, vers=${call.vers}, proc=${call.proc}',
      );

      // Validate RPC version
      if (call.rpcvers != 2) {
        final reply = _reply(
          message.xid,
          ReplyStatus.denied,
          RejectedReply(
            rejectStatus: RejectStatus.rpcMismatch,
            data: MismatchInfo(low: 2, high: 2),
          ),
        );
        request.respond(_encode(reply));
        return;
      }

      // Find program
      final program = _programs[call.prog];
      if (program == null) {
        final reply = _accepted(
          message.xid,
          AcceptStatus.progUnavail,
        );
        request.respond(_encode(reply));
        return;
      }

      // Find version
      final version = program.version(call.vers);
      if (version == null) {
        final supportedVersions = program.versions();
        final reply = _accepted(
          message.xid,
          AcceptStatus.progMismatch,
          data: MismatchInfo(
            low: supportedVersions.first,
            high: supportedVersions.last,
          ),
        );
        request.respond(_encode(reply));
        return;
      }

      // Find procedure
      final procedure = version.procedure(call.proc);
      if (procedure == null) {
        final reply = _accepted(
          message.xid,
          AcceptStatus.procUnavail,
        );
        request.respond(_encode(reply));
        return;
      }

      // Authenticate
      final authResult = _authenticate(call.cred, call.verf);

      // Check for authentication error
      if (authResult.error != null) {
        final reply = _reply(
          message.xid,
          ReplyStatus.denied,
          RejectedReply(
            rejectStatus: RejectStatus.authError,
            data: AuthError(status: authResult.error!),
          ),
        );
        request.respond(_encode(reply));
        return;
      }

      final authContext = authResult.context!;

      // Generate response verifier
      final responseVerifier = authContext.auth.responseVerifier(call.cred);

      // Execute procedure with interceptors
      XdrInputStream paramsStream;
      if (call.params != null && call.params!.isNotEmpty) {
        paramsStream = XdrInputStream(call.params!);
        RpcLogger.debug('RPC params size: ${call.params!.length} bytes');
      } else {
        paramsStream = XdrInputStream(Uint8List(0));
        RpcLogger.debug('RPC params: empty');
      }

      RpcLogger.debug(
        'Executing procedure prog=${call.prog}, vers=${call.vers}, proc=${call.proc}',
      );

      _executeWithInterceptors(
        message.xid,
        call.prog,
        call.vers,
        call.proc,
        paramsStream,
        authContext,
        procedure,
        request,
        responseVerifier,
      );
    } catch (e, st) {
      RpcLogger.error('Error processing request', e, st);
      // Cannot respond if message parsing failed, as XID is unknown.
    }
  }

  _AuthResult _authenticate(
    final OpaqueAuth credential,
    final OpaqueAuth verifier,
  ) {
    switch (credential.flavor) {
      case AuthFlavor.none:
        return _AuthResult.success(AuthContext(auth: AuthNone()));
      case AuthFlavor.unix:
        try {
          final authUnix = AuthUnix.decode(credential.body);
          return _AuthResult.success(
            AuthContext(
              auth: authUnix,
              principal: '${authUnix.uid}:${authUnix.gid}',
              attributes: {
                'uid': authUnix.uid,
                'gid': authUnix.gid,
                'gids': authUnix.gids,
                'machineName': authUnix.hostname,
              },
            ),
          );
        } catch (e) {
          RpcLogger.warning('Failed to decode AUTH_UNIX credentials: $e');
          return _AuthResult.error(AuthStatus.badcred);
        }
      case AuthFlavor.short:
        return _AuthResult.error(AuthStatus.tooweak);
      case AuthFlavor.des:
        try {
          final netname = XdrInputStream(credential.body).readString();
          final secretKey = _secretProvider.secretForDes(netname);
          if (secretKey == null) {
            RpcLogger.warning(
              'AUTH_DES secret not configured for netname "$netname"',
            );
            return _AuthResult.error(AuthStatus.tooweak);
          }
          final authDes = AuthDes.decode(credential.body, secretKey);
          if (!authDes.validate(credential, verifier)) {
            return _AuthResult.error(AuthStatus.badverf);
          }
          return _AuthResult.success(
            AuthContext(
              auth: authDes,
              principal: netname,
              attributes: {
                'netname': netname,
                'window': authDes.window,
                'timestamp': authDes.timestamp,
              },
            ),
          );
        } catch (e) {
          RpcLogger.warning('Failed to process AUTH_DES credentials: $e');
          return _AuthResult.error(AuthStatus.badcred);
        }
      case AuthFlavor.gss:
        try {
          final stream = XdrInputStream(credential.body);
          final version = stream.readInt();
          stream.readInt(); // sequence - reserved for future use
          final service = stream.readString();
          final principal = stream.readString();
          stream.readOpaque();

          final sessionKey = _secretProvider.secretForGss(
            principal: principal,
            service: service,
          );
          if (sessionKey == null) {
            RpcLogger.warning(
              'AUTH_GSS session key not configured for '
              'principal "$principal" and service "$service"',
            );
            return _AuthResult.error(AuthStatus.tooweak);
          }

          final authGss = AuthGss.decode(credential.body, sessionKey);
          if (!authGss.validate(credential, verifier)) {
            return _AuthResult.error(AuthStatus.badverf);
          }

          return _AuthResult.success(
            AuthContext(
              auth: authGss,
              principal: principal,
              attributes: {
                'principal': principal,
                'service': service,
                'sequence': authGss.sequenceNumber,
                'version': version,
              },
            ),
          );
        } catch (e) {
          RpcLogger.warning('Failed to process AUTH_GSS credentials: $e');
          return _AuthResult.error(AuthStatus.badcred);
        }
    }
  }

  RpcMessage _reply(
    final int xid,
    final ReplyStatus status,
    final ReplyData data,
  ) =>
      RpcMessage(
        xid: xid,
        messageType: MessageType.reply,
        body: ReplyBody(
          replyStatus: status,
          data: data,
        ),
      );

  RpcMessage _accepted(
    final int xid,
    final AcceptStatus status, {
    final AcceptData? data,
    final OpaqueAuth? verifier,
  }) =>
      _reply(
        xid,
        ReplyStatus.accepted,
        AcceptedReply(
          verf: verifier ?? OpaqueAuth.none(),
          acceptStatus: status,
          data: data,
        ),
      );

  Uint8List _encode(final RpcMessage message) {
    final stream = XdrOutputStream();
    message.encode(stream);
    return stream.toBytes();
  }

  Future<void> _executeWithInterceptors(
    final int xid,
    final int program,
    final int version,
    final int procedure,
    final XdrInputStream params,
    final AuthContext auth,
    final RpcProcedureHandler handler,
    final RpcRequest request,
    final OpaqueAuth verifier,
  ) async {
    try {
      // Build request context
      var context = RpcRequestContext(
        xid: xid,
        program: program,
        version: version,
        procedure: procedure,
        auth: auth,
        params: params,
      );

      // Run request interceptors
      for (final interceptor in _requestInterceptors) {
        context = await interceptor.onRequest(context);
      }

      // Build middleware chain
      final responseContext = await _executeWithMiddleware(
        context,
        handler,
      );

      RpcLogger.debug(
        'Procedure ${context.procedure} executed successfully, result: ${responseContext.result?.length ?? 0} bytes',
      );

      // Send success reply
      final reply = _accepted(
        xid,
        AcceptStatus.success,
        data: SuccessData(responseContext.result),
        verifier: verifier,
      );
      final encodedReply = _encode(reply);
      RpcLogger.debug(
        'Sending reply: ${encodedReply.length} bytes (xid=$xid, proc=${context.procedure})',
      );
      unawaited(request.respond(encodedReply));
    } catch (error, stackTrace) {
      RpcLogger.error('Error executing procedure', error, stackTrace);

      // Run response interceptors with error
      var responseContext = RpcResponseContext(
        xid: xid,
        error: error,
      );

      for (final interceptor in _responseInterceptors) {
        try {
          responseContext = await interceptor.onResponse(responseContext);
        } catch (e) {
          // Ignore interceptor errors during error handling
          RpcLogger.warning('Interceptor error during error handling: $e');
        }
      }

      final reply = _accepted(
        xid,
        AcceptStatus.systemErr,
        verifier: verifier,
      );
      unawaited(request.respond(_encode(reply)));
    }
  }

  /// Execute handler with middleware chain
  Future<RpcResponseContext> _executeWithMiddleware(
    final RpcRequestContext context,
    final RpcProcedureHandler handler,
  ) async {
    // Create the final handler that executes the procedure
    Future<RpcResponseContext> finalHandler(RpcRequestContext ctx) async {
      final result = await handler(ctx.params, ctx.auth);

      var responseContext = RpcResponseContext(
        xid: ctx.xid,
        result: result,
        attributes: ctx.attributes,
      );

      // Run response interceptors
      for (final interceptor in _responseInterceptors) {
        responseContext = await interceptor.onResponse(responseContext);
      }

      return responseContext;
    }

    // Build middleware chain from back to front
    var next = finalHandler;
    for (var i = _middlewares.length - 1; i >= 0; i--) {
      final middleware = _middlewares[i];
      final currentNext = next;
      next = (ctx) => middleware.handle(ctx, currentNext);
    }

    // Execute the chain
    return next(context);
  }
}

/// Internal helper class for authentication results
class _AuthResult {
  _AuthResult.success(this.context) : error = null;

  _AuthResult.error(this.error) : context = null;
  final AuthContext? context;
  final AuthStatus? error;
}
