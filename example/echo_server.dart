/// Example RPC server implementing a multi-procedure echo service.
///
/// This example demonstrates:
/// - Creating an RPC server with multiple procedures
/// - TCP and UDP transport options
/// - Portmapper registration for service discovery
/// - Statistics tracking across procedure calls
/// - Authentication context handling
/// - Graceful shutdown with cleanup
///
/// ## Features
///
/// The echo service implements 5 procedures:
/// 1. **ECHO** (proc 1): Returns input string unchanged
/// 2. **REVERSE** (proc 2): Returns reversed string
/// 3. **UPPERCASE** (proc 3): Returns uppercase string
/// 4. **GET_STATS** (proc 4): Returns call statistics
/// 5. **RESET_STATS** (proc 5): Resets statistics counters
///
/// ## Usage
///
/// ```bash
/// # Start server on default port 8080 with TCP
/// dart run example/echo_server.dart
///
/// # Start on custom port
/// dart run example/echo_server.dart 9000
///
/// # Use UDP instead of TCP
/// dart run example/echo_server.dart 8080 --udp
///
/// # Disable portmapper registration
/// dart run example/echo_server.dart 8080 --no-portmap
/// ```
///
/// ## Testing
///
/// Use the companion echo_client.dart to test:
/// ```bash
/// # In terminal 1
/// dart run example/echo_server.dart
///
/// # In terminal 2
/// dart run example/echo_client.dart
/// echo> echo Hello, World!
/// Response: Hello, World!
/// ```
///
/// Or test with standard RPC tools:
/// ```bash
/// # Check service availability
/// rpcinfo -p localhost | grep ECHO
///
/// # Call NULL procedure (procedure 0)
/// rpcinfo -T tcp localhost 0x20000001 1
/// ```
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/portmap.dart';
import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server_transport.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';

// Echo service constants
// ignore_for_file: constant_identifier_names
const ECHO_PROG = 0x20000001;
const ECHO_VERS = 1;
const ECHO_PROC = 1;
const REVERSE_PROC = 2;
const UPPERCASE_PROC = 3;
const GET_STATS_PROC = 4;
const RESET_STATS_PROC = 5;

class EchoService {
  int echoCount = 0;
  int reverseCount = 0;
  int uppercaseCount = 0;
  int totalCalls = 0;

  /// Echo procedure - returns the input string
  Future<Uint8List?> echo(XdrInputStream params, AuthContext auth) async {
    totalCalls++;
    echoCount++;

    final input = params.readString();
    print('[ECHO] Received: "$input" from ${auth.principal ?? 'anonymous'}');

    final output = XdrOutputStream()..writeString(input);
    return Uint8List.fromList(output.bytes);
  }

  /// Reverse procedure - returns the reversed string
  Future<Uint8List?> reverse(XdrInputStream params, AuthContext auth) async {
    totalCalls++;
    reverseCount++;

    final input = params.readString();
    final reversed = input.split('').reversed.join();
    print('[REVERSE] Input: "$input" -> Output: "$reversed"');

    final output = XdrOutputStream()..writeString(reversed);
    return Uint8List.fromList(output.bytes);
  }

  /// Uppercase procedure - returns the string in uppercase
  Future<Uint8List?> uppercase(XdrInputStream params, AuthContext auth) async {
    totalCalls++;
    uppercaseCount++;

    final input = params.readString();
    final upper = input.toUpperCase();
    print('[UPPERCASE] Input: "$input" -> Output: "$upper"');

    final output = XdrOutputStream()..writeString(upper);
    return Uint8List.fromList(output.bytes);
  }

  /// Get stats procedure - returns server statistics
  Future<Uint8List?> getStats(XdrInputStream params, AuthContext auth) async {
    totalCalls++;

    print('[GET_STATS] Returning statistics');

    final output = XdrOutputStream()
      ..writeInt(echoCount)
      ..writeInt(reverseCount)
      ..writeInt(uppercaseCount)
      ..writeInt(totalCalls);
    return Uint8List.fromList(output.bytes);
  }

  /// Reset stats procedure - resets server statistics
  Future<Uint8List?> resetStats(XdrInputStream params, AuthContext auth) async {
    totalCalls++;

    print('[RESET_STATS] Resetting statistics');
    echoCount = 0;
    reverseCount = 0;
    uppercaseCount = 0;
    totalCalls = 0;

    return null; // void procedure
  }
}

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8080 : 8080;
  final tcp = !args.contains('--udp');
  final portmap = !args.contains('--no-portmap');

  print('Starting Echo RPC Server...');
  print('  Port: $port');
  print('  Protocol: ${tcp ? 'TCP' : 'UDP'}');
  print(
    '  Portmap registration: ${portmap ? 'enabled' : 'disabled'}',
  );

  final service = EchoService();
  final server = RpcServer(
    transports: tcp
        ? [TcpServerTransport(port: port)]
        : [UdpServerTransport(port: port)],
  );

  // Create the ECHO program
  final program = RpcProgram(ECHO_PROG)
    ..addVersion(
      RpcVersion(ECHO_VERS)
        ..addProcedure(ECHO_PROC, service.echo)
        ..addProcedure(REVERSE_PROC, service.reverse)
        ..addProcedure(UPPERCASE_PROC, service.uppercase)
        ..addProcedure(GET_STATS_PROC, service.getStats)
        ..addProcedure(RESET_STATS_PROC, service.resetStats),
    );

  // Register program with server
  server.addProgram(program);

  // Start listening
  await server.listen();

  // Register with portmapper if requested
  if (portmap) {
    try {
      final registered = await PortmapRegistration.register(
        prog: ECHO_PROG,
        vers: ECHO_VERS,
        port: port,
        useTcp: tcp,
      );

      if (registered) {
        print('Successfully registered with portmapper');
      } else {
        print('Warning: Failed to register with portmapper');
      }
    } catch (e) {
      print('Warning: Could not connect to portmapper: $e');
    }
  }

  print('Echo server is running. Press Ctrl+C to stop.');

  // Handle shutdown gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');

    // Unregister from portmapper if we registered
    if (portmap) {
      try {
        await PortmapRegistration.unregister(
          prog: ECHO_PROG,
          vers: ECHO_VERS,
          useTcp: tcp,
        );
        print('Unregistered from portmapper');
      } catch (e) {
        print('Warning: Could not unregister from portmapper: $e');
      }
    }

    await server.stop();
    print('Server stopped');
    exit(0);
  });
}
