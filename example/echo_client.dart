/// Example RPC client for the echo service.
///
/// This interactive client demonstrates:
/// - Creating RPC clients with TCP or UDP transport
/// - Service discovery via portmapper
/// - Making multiple types of RPC calls
/// - Unix authentication credentials
/// - Interactive command-line interface
/// - Error handling and timeout management
///
/// ## Features
///
/// The client provides an interactive shell with commands:
/// - `echo <message>` - Echo a message back
/// - `reverse <message>` - Get reversed message
/// - `uppercase <message>` - Get uppercase message
/// - `stats` - View server statistics
/// - `reset` - Reset server statistics
/// - `quit` - Exit the client
///
/// ## Usage
///
/// ```bash
/// # Connect to default localhost:8080
/// dart run example/echo_client.dart
///
/// # Connect to specific host and port
/// dart run example/echo_client.dart --host server.example.com --port 9000
///
/// # Use UDP transport
/// dart run example/echo_client.dart --udp
///
/// # Use portmapper for service discovery
/// dart run example/echo_client.dart --portmap
///
/// # Combine options
/// dart run example/echo_client.dart --host nfs-server --portmap --udp
/// ```
///
/// ## Interactive Session
///
/// ```
/// Connecting to Echo RPC Server...
///   Host: localhost
///   Port: 8080
///   Protocol: TCP
/// Connected! Type commands or "help" for options.
///
/// echo> echo Hello, World!
/// Response: Hello, World!
///
/// echo> reverse Dart
/// Response: traD
///
/// echo> uppercase hello
/// Response: HELLO
///
/// echo> stats
/// Server Statistics:
///   Echo calls: 1
///   Reverse calls: 1
///   Uppercase calls: 1
///   Total calls: 3
///
/// echo> quit
/// Goodbye!
/// ```
///
/// ## Authentication
///
/// The client uses AUTH_UNIX authentication with the local machine name
/// and uid/gid 1000. This demonstrates how RPC authentication credentials
/// are passed with each call.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/portmap.dart';
import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_transport.dart';
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

class EchoClient {
  EchoClient(this._client);

  final RpcClient _client;

  static Future<EchoClient> connect({
    String host = 'localhost',
    int? port,
    bool tcp = true,
    bool portmap = false,
  }) async {
    // If port is not specified and usePortmap is true, lookup via portmapper
    if (port == null && portmap) {
      port = await PortmapRegistration.lookup(
        prog: ECHO_PROG,
        vers: ECHO_VERS,
        useTcp: tcp,
        portmapHost: host,
      );

      if (port == 0) {
        throw Exception('Echo service not registered with portmapper');
      }

      print('Found echo service at port $port via portmapper');
    }

    final servicePort = port ?? 8080; // Default port if not specified
    final transport = tcp
        ? TcpTransport(host: host, port: servicePort)
        : UdpTransport(host: host, port: servicePort);
    final auth = AuthUnix(
      hostname: Platform.localHostname,
      uid: 1000,
      gid: 1000,
    );

    final client = RpcClient(
      transport: transport,
      auth: auth,
    );

    await client.connect();
    return EchoClient(client);
  }

  Future<void> close() async {
    await _client.close();
  }

  Future<String> echo(String message) async {
    final params = XdrOutputStream()..writeString(message);
    final result = await _client.call(
      program: ECHO_PROG,
      version: ECHO_VERS,
      procedure: ECHO_PROC,
      params: Uint8List.fromList(params.bytes),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readString();
    }

    throw Exception('No result received');
  }

  Future<String> reverse(String message) async {
    final params = XdrOutputStream()..writeString(message);
    final result = await _client.call(
      program: ECHO_PROG,
      version: ECHO_VERS,
      procedure: REVERSE_PROC,
      params: Uint8List.fromList(params.bytes),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readString();
    }

    throw Exception('No result received');
  }

  Future<String> uppercase(String message) async {
    final params = XdrOutputStream()..writeString(message);
    final result = await _client.call(
      program: ECHO_PROG,
      version: ECHO_VERS,
      procedure: UPPERCASE_PROC,
      params: Uint8List.fromList(params.bytes),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readString();
    }

    throw Exception('No result received');
  }

  Future<Map<String, int>> getStats() async {
    final result = await _client.call(
      program: ECHO_PROG,
      version: ECHO_VERS,
      procedure: GET_STATS_PROC,
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return {
        'echo_count': stream.readInt(),
        'reverse_count': stream.readInt(),
        'uppercase_count': stream.readInt(),
        'total_calls': stream.readInt(),
      };
    }

    throw Exception('No result received');
  }

  Future<void> resetStats() async {
    await _client.call(
      program: ECHO_PROG,
      version: ECHO_VERS,
      procedure: RESET_STATS_PROC,
    );
  }
}

void main(List<String> args) async {
  String host = 'localhost';
  int? port;
  bool tcp = true;
  bool portmap = false;

  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--host':
        if (i + 1 < args.length) {
          host = args[++i];
        }
        break;
      case '--port':
        if (i + 1 < args.length) {
          port = int.tryParse(args[++i]);
        }
        break;
      case '--udp':
        tcp = false;
        break;
      case '--portmap':
        portmap = true;
        break;
      case '--help':
        printUsage();
        return;
    }
  }

  print('Connecting to Echo RPC Server...');
  print('  Host: $host');
  print('  Port: ${port ?? (portmap ? 'via portmap' : '8080')}');
  print('  Protocol: ${tcp ? 'TCP' : 'UDP'}');

  try {
    final client = await EchoClient.connect(
      host: host,
      port: port,
      tcp: tcp,
      portmap: portmap,
    );

    print('Connected! Type commands or "help" for options.\n');
    while (true) {
      stdout.write('echo> ');
      final input = stdin.readLineSync();

      if (input == null || input.isEmpty) continue;

      final parts = input.split(' ');
      final command = parts[0].toLowerCase();
      final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      try {
        switch (command) {
          case 'echo':
            if (message.isEmpty) {
              print('Usage: echo <message>');
            } else {
              final result = await client.echo(message);
              print('Response: $result');
            }
            break;

          case 'reverse':
            if (message.isEmpty) {
              print('Usage: reverse <message>');
            } else {
              final result = await client.reverse(message);
              print('Response: $result');
            }
            break;

          case 'uppercase':
          case 'upper':
            if (message.isEmpty) {
              print('Usage: uppercase <message>');
            } else {
              final result = await client.uppercase(message);
              print('Response: $result');
            }
            break;

          case 'stats':
            final stats = await client.getStats();
            print('Server Statistics:');
            print('  Echo calls: ${stats['echo_count']}');
            print('  Reverse calls: ${stats['reverse_count']}');
            print('  Uppercase calls: ${stats['uppercase_count']}');
            print('  Total calls: ${stats['total_calls']}');
            break;

          case 'reset':
            await client.resetStats();
            print('Statistics reset');
            break;

          case 'help':
            print('Available commands:');
            print('  echo <message>     - Echo the message back');
            print('  reverse <message>  - Reverse the message');
            print('  uppercase <message> - Convert message to uppercase');
            print('  stats             - Show server statistics');
            print('  reset             - Reset server statistics');
            print('  quit              - Exit the client');
            break;

          case 'quit':
          case 'exit':
            print('Goodbye!');
            await client.close();
            return;

          default:
            print('Unknown command: $command (type "help" for commands)');
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  } catch (e) {
    print('Failed to connect: $e');
    exit(1);
  }
}

void printUsage() {
  print('''
Usage: dart echo_client.dart [options]

Options:
  --host <hostname>  Server hostname (default: localhost)
  --port <port>      Server port (default: 8080 or via portmap)
  --udp              Use UDP instead of TCP
  --portmap          Look up port via portmapper
  --help             Show this help message

Interactive commands:
  echo <message>      Echo the message back
  reverse <message>   Reverse the message
  uppercase <message> Convert to uppercase
  stats              Show server statistics
  reset              Reset server statistics
  quit               Exit the client
''');
}
