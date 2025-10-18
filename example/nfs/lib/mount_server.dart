/// MOUNT protocol server implementation (RFC 1813).
///
/// The MOUNT protocol is used by NFS clients to:
/// - Obtain the initial file handle for an exported filesystem
/// - Query available exports
/// - Track mounted filesystems
/// - Unmount when done
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/dart_oncrpc.dart';

import 'constants.dart';
import 'file_handle.dart';

/// MOUNT v3 protocol server.
///
/// Implements the MOUNT protocol for NFS client initialization.
/// Clients use MOUNT to get the root file handle before making NFS calls.
class MountServer {
  MountServer({
    required this.handles,
    required this.exports,
  });

  /// File handle manager
  final FileHandleManager handles;

  /// Map of export path → Export configuration
  final Map<String, ExportConfig> exports;

  /// Currently mounted clients (hostname → mount list)
  final Map<String, List<MountEntry>> _mounts = {};

  /// Register MOUNT program with RPC server.
  void register(final RpcServer server) {
    final program = RpcProgram(MOUNT_PROGRAM)
      ..addVersion(
        RpcVersion(MOUNT_V3)
          ..addProcedure(0, _null)
          ..addProcedure(1, _mnt)
          ..addProcedure(2, _dump)
          ..addProcedure(3, _umnt)
          ..addProcedure(4, _umntall)
          ..addProcedure(5, _export),
      );

    server.addProgram(program);
  }

  /// MOUNT3_NULL - Null procedure (ping/health check).
  Future<Uint8List?> _null(
    final XdrInputStream params,
    final AuthContext auth,
  ) async =>
      null; // No-op - just return success

  /// MOUNT3_MNT - Mount an export and return root file handle.
  Future<Uint8List?> _mnt(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    // Decode dirpath (export path requested by client)
    final path = params.readString();

    // Find matching export
    final export = _findExport(path);
    if (export == null) {
      return _mountError(MNT3ERR_NOENT);
    }

    // Verify directory exists
    final dir = Directory(export.path);
    if (!dir.existsSync()) {
      return _mountError(MNT3ERR_NOENT);
    }

    // Check permissions (basic host-based access control)
    if (!_checkAccess(auth, export)) {
      return _mountError(MNT3ERR_ACCES);
    }

    // Generate root file handle for this export
    final fhandle = handles.generate(export.path);

    // Track this mount
    final hostname = auth.principal ?? 'unknown';
    _mounts.putIfAbsent(hostname, () => []).add(
          MountEntry(
            hostname: hostname,
            directory: path,
            time: DateTime.now(),
          ),
        );

    // Return success with file handle and auth flavors
    final out = XdrOutputStream()
      // mountstat3 status = MNT3_OK
      ..writeInt(MNT3_OK)
      // mountres3_ok
      // fhandle3 - variable length opaque data (writeBytes includes length)
      ..writeBytes(fhandle)
      // int auth_flavors<> - support AUTH_NONE and AUTH_UNIX
      ..writeInt(2) // Array length
      ..writeInt(0) // AUTH_NONE
      ..writeInt(1); // AUTH_UNIX

    return Uint8List.fromList(out.bytes);
  }

  /// MOUNT3_DUMP - Return list of current mounts.
  Future<Uint8List?> _dump(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    final out = XdrOutputStream();

    // Build mount list (linked list structure)
    final allMounts = <MountEntry>[];
    _mounts.values.forEach(allMounts.addAll);

    if (allMounts.isEmpty) {
      // Empty list - write null pointer
      out.writeInt(0);
    } else {
      // Write each mount entry
      for (var i = 0; i < allMounts.length; i++) {
        final mount = allMounts[i];

        // Pointer present
        out
          ..writeInt(1)
          // ml_hostname
          ..writeString(mount.hostname)
          // ml_directory
          ..writeString(mount.directory);

        // ml_next pointer (1 if more, 0 if last)
        if (i < allMounts.length - 1) {
          // More entries follow
        } else {
          // Last entry - null next pointer
          out.writeInt(0);
        }
      }
    }

    return Uint8List.fromList(out.bytes);
  }

  /// MOUNT3_UMNT - Unmount an export.
  Future<Uint8List?> _umnt(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    final path = params.readString();
    final hostname = auth.principal ?? 'unknown';

    // Remove this mount from the list
    final mounts = _mounts[hostname];
    if (mounts != null) {
      mounts.removeWhere((m) => m.directory == path);
      if (mounts.isEmpty) {
        _mounts.remove(hostname);
      }
    }

    // Void return
    return null;
  }

  /// MOUNT3_UMNTALL - Unmount all exports for this client.
  Future<Uint8List?> _umntall(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    final hostname = auth.principal ?? 'unknown';

    // Remove all mounts for this client
    _mounts.remove(hostname);

    // Void return
    return null;
  }

  /// MOUNT3_EXPORT - Return list of available exports.
  Future<Uint8List?> _export(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    final out = XdrOutputStream();

    if (exports.isEmpty) {
      // Empty list
      out.writeInt(0);
    } else {
      final exportList = exports.values.toList();

      for (var i = 0; i < exportList.length; i++) {
        final export = exportList[i];

        // Pointer present
        out
          ..writeInt(1)
          // ex_dir (directory path)
          ..writeString(export.exportPath);

        // ex_groups (list of allowed groups/hosts)
        if (export.hosts.isEmpty) {
          // No restrictions - null list
          out.writeInt(0);
        } else {
          // Write group list
          for (var j = 0; j < export.hosts.length; j++) {
            out
              ..writeInt(1) // Pointer present
              ..writeString(export.hosts[j]); // gr_name

            // gr_next
            if (j < export.hosts.length - 1) {
              // More groups
            } else {
              out.writeInt(0); // Null next
            }
          }
        }

        // ex_next pointer
        if (i < exportList.length - 1) {
          // More exports
        } else {
          out.writeInt(0); // Last entry
        }
      }
    }

    return Uint8List.fromList(out.bytes);
  }

  /// Find an export configuration by path.
  ExportConfig? _findExport(final String path) {
    // Try exact match first
    if (exports.containsKey(path)) {
      return exports[path];
    }

    // Try matching by actual filesystem path
    for (final export in exports.values) {
      if (export.exportPath == path) {
        return export;
      }
    }

    return null;
  }

  /// Check if client has access to an export.
  bool _checkAccess(final AuthContext auth, final ExportConfig export) {
    // If no host restrictions, allow all
    if (export.hosts.isEmpty) {
      return true;
    }

    // Check if client hostname matches allowed hosts
    final hostname = auth.principal ?? 'unknown';

    for (final allowed in export.hosts) {
      if (allowed == '*' || allowed == hostname) {
        return true;
      }

      // Support simple wildcards like "*.example.com"
      if (allowed.startsWith('*.')) {
        final domain = allowed.substring(2);
        if (hostname.endsWith(domain)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Create error response for mount operation.
  Uint8List _mountError(final int status) {
    final out = XdrOutputStream()..writeInt(status);
    return Uint8List.fromList(out.bytes);
  }

  /// Get current mount statistics.
  Map<String, dynamic> get stats => {
        'total_mounts':
            _mounts.values.fold<int>(0, (sum, list) => sum + list.length),
        'unique_clients': _mounts.length,
        'exports': exports.length,
      };
}

/// Export configuration.
class ExportConfig {
  const ExportConfig({
    required this.path,
    required this.exportPath,
    this.hosts = const [],
    this.readOnly = false,
    this.options = const {},
  });

  /// Actual filesystem path to export
  final String path;

  /// Export path as seen by clients (usually just "/" or "/export")
  final String exportPath;

  /// List of allowed hostnames (* for all)
  final List<String> hosts;

  /// Whether export is read-only
  final bool readOnly;

  /// Additional export options
  final Map<String, dynamic> options;
}

/// Mount entry tracking.
class MountEntry {
  const MountEntry({
    required this.hostname,
    required this.directory,
    required this.time,
  });

  final String hostname;
  final String directory;
  final DateTime time;
}
