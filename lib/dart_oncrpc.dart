/// ONC-RPC (Open Network Computing Remote Procedure Call) implementation for Dart.
///
/// This library provides a complete ONC-RPC implementation with:
///
/// **XDR Serialization (RFC 4506)**
/// - All primitive types (int, hyper, float, double, bool, string, opaque)
/// - Complex types (structs, unions, enums, arrays, optionals)
/// - Byte-for-byte compatible with C rpcgen
///
/// **RPC Protocol (RFC 5531)**
/// - Full message format with call/reply handling
/// - TCP and UDP transports
/// - AUTH_NONE and AUTH_UNIX authentication
/// - Timeout and retry support
///
/// **Code Generation**
/// - Generate client and server stubs from .x specification files
/// - Support for C, Java, and Dart targets
/// - Preprocessor support (#include, #define)
///
/// **C Compatibility**
/// - Comprehensive compatibility testing with standard C RPC
/// - Bidirectional interoperability (Dart <-> C)
/// - Production-ready for NFS servers and RPC services
///
/// ## Quick Start
///
/// ```dart
/// import 'package:dart_oncrpc/dart_oncrpc.dart';
///
/// // Create RPC client
/// final transport = TcpTransport(host: 'localhost', port: 8080);
/// final client = RpcClient(transport: transport, auth: AuthNone());
/// await client.connect();
///
/// // Make RPC call
/// final result = await client.call(
///   program: 100000,
///   version: 1,
///   procedure: 1,
/// );
/// ```
///
/// See README.md for comprehensive documentation and examples.
library;

export 'src/generator/c_generator.dart';
export 'src/generator/dart_generator.dart';
export 'src/generator/generator.dart';
export 'src/generator/java_generator.dart';
export 'src/parser/ast.dart';
export 'src/parser/parser.dart';
export 'src/rpc/portmap.dart';
export 'src/rpc/rpc_authentication.dart';
export 'src/rpc/rpc_client.dart';
export 'src/rpc/rpc_errors.dart';
export 'src/rpc/rpc_interceptor.dart';
export 'src/rpc/rpc_logger.dart';
export 'src/rpc/rpc_message.dart';
export 'src/rpc/rpc_secret_provider.dart';
export 'src/rpc/rpc_server.dart';
export 'src/rpc/rpc_server_transport.dart';
export 'src/rpc/rpc_transport.dart';
export 'src/rpc/testing/mock_transport.dart';
export 'src/xdr/xdr_exceptions.dart';
export 'src/xdr/xdr_io.dart';
