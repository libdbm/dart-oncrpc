/// NFS v3 Server - Complete NFS server implementation example.
///
/// This is a fully functional NFS v3 server that demonstrates the capabilities
/// of the dart_oncrpc library. It can serve files from a local directory and
/// can be mounted by standard NFS clients including macOS.
///
/// ## Usage
///
/// ```bash
/// # Start server with default settings
/// dart run bin/nfs_server.dart --export /path/to/share
///
/// # Custom port and read-only mode
/// dart run bin/nfs_server.dart --export /path/to/share --port 2049 --read-only
///
/// # With portmapper registration
/// dart run bin/nfs_server.dart --export /path/to/share --portmap
/// ```
///
/// ## Mounting on macOS
///
/// ```bash
/// # Create mount point
/// mkdir ~/nfs_mount
///
/// # Mount the export
/// sudo mount -t nfs -o resvport,nolocks,vers=3 localhost:/ ~/nfs_mount
///
/// # Unmount when done
/// sudo umount ~/nfs_mount
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_oncrpc/dart_oncrpc.dart';

import '../lib/file_handle.dart';
import '../lib/file_system.dart';
import '../lib/mount_server.dart';
import '../lib/nfs_server.dart';

Future<void> main(final List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'export',
      abbr: 'e',
      help: 'Directory to export (required)',
      mandatory: true,
    )
    ..addOption(
      'port',
      abbr: 'p',
      help: 'NFS server port',
      defaultsTo: '2049',
    )
    ..addOption(
      'mount-port',
      abbr: 'm',
      help: 'MOUNT server port (0 for dynamic)',
      defaultsTo: '0',
    )
    ..addFlag(
      'read-only',
      abbr: 'r',
      help: 'Export as read-only',
      negatable: false,
    )
    ..addFlag(
      'portmap',
      help: 'Register with portmapper on port 111',
      negatable: false,
    )
    ..addFlag(
      'tcp',
      help: 'Use TCP transport (default)',
      defaultsTo: true,
    )
    ..addFlag(
      'udp',
      help: 'Use UDP transport',
      negatable: false,
    )
    ..addOption(
      'log-level',
      abbr: 'l',
      help: 'Logging level (error, warning, info, debug)',
      allowed: ['error', 'warning', 'info', 'debug'],
      defaultsTo: 'info',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable debug logging (shorthand for --log-level=debug)',
      negatable: false,
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      help: 'Disable all logging',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );

  try {
    final args = parser.parse(arguments);

    if (args['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }

    // Validate export directory
    final exportPath = args['export'] as String;
    final exportDir = Directory(exportPath);

    if (!exportDir.existsSync()) {
      stderr
        ..writeln('Error: Export directory does not exist: $exportPath')
        ..writeln('Please create the directory first.');
      exit(1);
    }

    final canonicalPath = exportDir.absolute.path;

    // Parse options
    final nfsPort = int.parse(args['port'] as String);
    final mountPort = int.parse(args['mount-port'] as String);
    final readOnly = args['read-only'] as bool;
    final usePortmap = args['portmap'] as bool;
    final useTcp = args['tcp'] as bool;
    final useUdp = args['udp'] as bool;
    final verbose = args['verbose'] as bool;
    final quiet = args['quiet'] as bool;
    final logLevel = args['log-level'] as String;

    // Configure logging
    if (quiet) {
      RpcLogger.enabled = false;
    } else if (verbose) {
      RpcLogger.level = LogLevel.debug;
    } else {
      // Map string to log level
      switch (logLevel) {
        case 'error':
          RpcLogger.level = LogLevel.error;
        case 'warning':
          RpcLogger.level = LogLevel.warning;
        case 'info':
          RpcLogger.level = LogLevel.info;
        case 'debug':
          RpcLogger.level = LogLevel.debug;
      }
    }

    // Print banner
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  NFS v3 Server (dart_oncrpc example)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('Export Configuration:');
    print('  Path:      $canonicalPath');
    print('  Export:    /');
    print('  Mode:      ${readOnly ? 'read-only' : 'read-write'}');
    print('');
    print('Server Configuration:');
    print('  NFS Port:        $nfsPort');
    print('  MOUNT Port:      ${mountPort == 0 ? '(dynamic)' : mountPort}');
    print(
      '  Transport:       ${useTcp ? 'TCP' : ''}${useTcp && useUdp ? ' + ' : ''}${useUdp ? 'UDP' : ''}',
    );
    print('  Portmap:         ${usePortmap ? 'enabled' : 'disabled'}');
    print(
      '  Log Level:       ${quiet ? 'disabled' : (verbose ? 'debug' : logLevel)}',
    );
    print('');

    // Initialize components
    final handles = FileHandleManager(rootPath: canonicalPath);
    final fs = NfsFileSystem(root: canonicalPath, readOnly: readOnly);

    // Create export configuration
    final exports = {
      '/': ExportConfig(
        path: canonicalPath,
        exportPath: '/',
        readOnly: readOnly,
      ),
    };

    // Create servers
    final mountServer = MountServer(handles: handles, exports: exports);
    final nfsServer = NfsServer(handles: handles, fs: fs);

    // Create RPC server with transports
    final transports = <Object>[];

    if (useTcp) {
      transports.add(TcpServerTransport(port: nfsPort));
      if (mountPort != 0) {
        transports.add(TcpServerTransport(port: mountPort));
      }
    }

    if (useUdp) {
      transports.add(UdpServerTransport(port: nfsPort));
      if (mountPort != 0) {
        transports.add(UdpServerTransport(port: mountPort));
      }
    }

    final server = RpcServer(
      transports: transports.cast(),
    );

    // Register programs
    nfsServer.register(server);
    mountServer.register(server);

    // Start server
    await server.listen();

    print('Server Status: ✓ Running');
    print('');

    // Register with portmapper if requested
    if (usePortmap) {
      print('Portmapper Registration:');
      try {
        // Register NFS
        final nfsRegistered = await PortmapRegistration.register(
          prog: 100003, // NFS_PROGRAM
          vers: 3, // NFS_V3
          port: nfsPort,
          useTcp: useTcp,
        );

        if (nfsRegistered) {
          print('  ✓ NFS program registered');
        } else {
          print('  ✗ Failed to register NFS program');
        }

        // Register MOUNT
        final actualMountPort = mountPort != 0 ? mountPort : nfsPort;
        final mountRegistered = await PortmapRegistration.register(
          prog: 100005, // MOUNT_PROGRAM
          vers: 3, // MOUNT_V3
          port: actualMountPort,
          useTcp: useTcp,
        );

        if (mountRegistered) {
          print('  ✓ MOUNT program registered');
        } else {
          print('  ✗ Failed to register MOUNT program');
        }
      } catch (e) {
        print('  ✗ Portmapper error: $e');
        print('  (Make sure portmapper/rpcbind is running)');
      }
      print('');
    }

    // Print mount instructions
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  Ready to accept NFS clients!');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
    print('To mount on macOS:');
    print('');
    print('  1. Create mount point:');
    print('     mkdir ~/nfs_mount');
    print('');
    print('  2. Mount the export:');
    print(r'     sudo mount -t nfs -o resvport,nolocks,vers=3 \');
    print('       localhost:/ ~/nfs_mount');
    print('');
    print('  3. Access files:');
    print('     ls ~/nfs_mount');
    print('     cat ~/nfs_mount/yourfile.txt');
    print('');
    print('  4. Unmount when done:');
    print('     sudo umount ~/nfs_mount');
    print('');
    print('Press Ctrl+C to stop the server');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');

    // Setup signal handlers for graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n\nShutting down...');

      // Unregister from portmapper
      if (usePortmap) {
        try {
          await PortmapRegistration.unregister(
            prog: 100003,
            vers: 3,
            useTcp: useTcp,
          );
          await PortmapRegistration.unregister(
            prog: 100005,
            vers: 3,
            useTcp: useTcp,
          );
          print('✓ Unregistered from portmapper');
        } catch (e) {
          print('✗ Portmapper unregister error: $e');
        }
      }

      // Stop server
      await server.stop();
      print('✓ Server stopped');

      // Print statistics
      print('');
      print('Session Statistics:');
      print('  NFS Operations:');
      final nfsStats = nfsServer.stats;
      for (final entry in nfsStats.entries) {
        print('    ${entry.key}: ${entry.value}');
      }

      print('  Mount Operations:');
      final mountStats = mountServer.stats;
      for (final entry in mountStats.entries) {
        print('    ${entry.key}: ${entry.value}');
      }

      print('');
      print('Goodbye!');
      exit(0);
    });

    // Keep running
    await Future<void>.delayed(const Duration(days: 365));
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln();
    _printUsage(parser);
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

void _printUsage(final ArgParser parser) {
  print('NFS v3 Server - dart_oncrpc example');
  print('');
  print('Usage: dart run bin/nfs_server.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('');
  print('  # Start server exporting current directory');
  print('  dart run bin/nfs_server.dart --export .');
  print('');
  print('  # Export as read-only on custom port');
  print(
    '  dart run bin/nfs_server.dart --export /data --port 12049 --read-only',
  );
  print('');
  print('  # With portmapper registration');
  print('  dart run bin/nfs_server.dart --export /share --portmap');
  print('');
}
