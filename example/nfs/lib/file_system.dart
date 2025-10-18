/// Filesystem abstraction layer for NFS operations.
///
/// Provides a clean interface between NFS protocol operations and
/// the underlying Dart filesystem APIs (dart:io).
library;

import 'dart:io';
import 'dart:typed_data';

/// NFS file system abstraction.
///
/// Handles:
/// - File attribute retrieval and mapping
/// - Read/write operations
/// - Directory listing
/// - Permission checks
/// - Error mapping from IOException to NFS status codes
class NfsFileSystem {
  NfsFileSystem({
    required String root,
    this.readOnly = false,
  }) : root = Directory(root).resolveSymbolicLinksSync();

  /// Root directory of the NFS export (canonicalized absolute path with symlinks resolved)
  final String root;

  /// Whether the export is read-only
  final bool readOnly;

  /// File attributes structure matching NFS fattr3
  FileAttributes? attributes(final String path) {
    try {
      final entity = _entity(path);
      final stat = entity.statSync();

      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }

      return FileAttributes(
        type: _mapType(stat.type),
        mode: stat.mode,
        nlink: 1, // Dart doesn't expose link count
        uid: 0, // Placeholder - Dart doesn't expose UID
        gid: 0, // Placeholder - Dart doesn't expose GID
        size: stat.size,
        used: stat.size, // Approximation
        rdev: 0,
        fsid: 0,
        fileid: _generateFileId(path, stat),
        atime: stat.accessed,
        mtime: stat.modified,
        ctime: stat.changed,
      );
    } catch (e) {
      return null;
    }
  }

  /// Read data from a file.
  ReadResult? read(final String path, final int offset, final int count) {
    try {
      if (!_isWithinExport(path)) {
        return const ReadResult.error(NfsError.access);
      }

      final file = File(path);
      if (!file.existsSync()) {
        return const ReadResult.error(NfsError.noent);
      }

      final stat = file.statSync();
      if (stat.type == FileSystemEntityType.directory) {
        return const ReadResult.error(NfsError.isdir);
      }

      final length = file.lengthSync();
      if (offset >= length) {
        // EOF - return empty data
        return ReadResult.success(
          data: Uint8List(0),
          eof: true,
          attributes: attributes(path),
        );
      }

      final bytes = file.openSync();
      try {
        bytes.setPositionSync(offset);
        final remaining = length - offset;
        final toRead = count < remaining ? count : remaining;
        final data = bytes.readSync(toRead);

        return ReadResult.success(
          data: Uint8List.fromList(data),
          eof: offset + toRead >= length,
          attributes: attributes(path),
        );
      } finally {
        bytes.closeSync();
      }
    } on FileSystemException catch (e) {
      return ReadResult.error(_mapException(e));
    } catch (e) {
      return const ReadResult.error(NfsError.io);
    }
  }

  /// Write data to a file.
  WriteResult? write(
    final String path,
    final int offset,
    final Uint8List data,
  ) {
    if (readOnly) {
      return const WriteResult.error(NfsError.rofs);
    }

    try {
      if (!_isWithinExport(path)) {
        return const WriteResult.error(NfsError.access);
      }

      final file = File(path);
      if (!file.existsSync()) {
        return const WriteResult.error(NfsError.noent);
      }

      final handle = file.openSync(mode: FileMode.writeOnlyAppend);
      try {
        handle
          ..setPositionSync(offset)
          ..writeFromSync(data)
          ..flushSync();

        return WriteResult.success(
          count: data.length,
          attributes: attributes(path),
        );
      } finally {
        handle.closeSync();
      }
    } on FileSystemException catch (e) {
      return WriteResult.error(_mapException(e));
    } catch (e) {
      return const WriteResult.error(NfsError.io);
    }
  }

  /// List directory entries.
  List<DirectoryEntry>? readdir(final String path) {
    try {
      if (!_isWithinExport(path)) {
        return null;
      }

      final dir = Directory(path);
      if (!dir.existsSync()) {
        return null;
      }

      final entries = <DirectoryEntry>[];

      // Add . and .. entries
      final parent = dir.parent.path;
      entries
        ..add(
          DirectoryEntry(
            name: '.',
            fileid: _generateFileId(path, dir.statSync()),
            attributes: attributes(path),
          ),
        )
        ..add(
          DirectoryEntry(
            name: '..',
            fileid: _generateFileId(parent, dir.parent.statSync()),
            attributes: attributes(parent),
          ),
        );

      // Add actual entries
      final list = dir.listSync();
      for (final entity in list) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final stat = entity.statSync();

        entries.add(
          DirectoryEntry(
            name: name,
            fileid: _generateFileId(entity.path, stat),
            attributes: attributes(entity.path),
          ),
        );
      }

      return entries;
    } catch (e) {
      return null;
    }
  }

  /// Create a new file.
  FileAttributes? create(final String path, final int mode) {
    if (readOnly) return null;

    try {
      if (!_isWithinExport(path)) return null;

      final file = File(path);
      if (file.existsSync()) return null; // Already exists

      file.createSync();
      // Dart doesn't support chmod directly, so mode is ignored

      return attributes(path);
    } catch (e) {
      return null;
    }
  }

  /// Create a directory.
  FileAttributes? mkdir(final String path, final int mode) {
    if (readOnly) return null;

    try {
      if (!_isWithinExport(path)) return null;

      final dir = Directory(path);
      if (dir.existsSync()) return null;

      dir.createSync();
      return attributes(path);
    } catch (e) {
      return null;
    }
  }

  /// Remove a file.
  bool remove(final String path) {
    if (readOnly) return false;

    try {
      if (!_isWithinExport(path)) return false;

      final file = File(path);
      if (!file.existsSync()) return false;

      file.deleteSync();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a directory.
  bool rmdir(final String path) {
    if (readOnly) return false;

    try {
      if (!_isWithinExport(path)) return false;

      final dir = Directory(path);
      if (!dir.existsSync()) return false;

      dir.deleteSync();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rename a file or directory.
  bool rename(final String from, final String to) {
    if (readOnly) return false;

    try {
      if (!_isWithinExport(from) || !_isWithinExport(to)) return false;

      final entity = _entity(from);
      if (entity is File) {
        entity.renameSync(to);
      } else if (entity is Directory) {
        entity.renameSync(to);
      } else {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if path is within the export root (security check).
  bool _isWithinExport(final String path) {
    try {
      final canonical = File(path).absolute.path;
      final rootCanonical = Directory(root).absolute.path;
      return canonical.startsWith(rootCanonical);
    } catch (_) {
      return false;
    }
  }

  /// Get FileSystemEntity for a path.
  FileSystemEntity _entity(final String path) {
    if (FileSystemEntity.isDirectorySync(path)) {
      return Directory(path);
    } else if (FileSystemEntity.isFileSync(path)) {
      return File(path);
    } else if (FileSystemEntity.isLinkSync(path)) {
      return Link(path);
    } else {
      return File(path); // Default
    }
  }

  /// Map Dart FileSystemEntityType to NFS file type.
  int _mapType(final FileSystemEntityType type) {
    switch (type) {
      case FileSystemEntityType.file:
        return 1; // NF3REG
      case FileSystemEntityType.directory:
        return 2; // NF3DIR
      case FileSystemEntityType.link:
        return 5; // NF3LNK
      default:
        return 1; // Default to regular file
    }
  }

  /// Map FileSystemException to NFS error code.
  NfsError _mapException(final FileSystemException e) {
    final message = e.message.toLowerCase();

    if (message.contains('permission') || message.contains('access')) {
      return NfsError.access;
    } else if (message.contains('not found') || message.contains('no such')) {
      return NfsError.noent;
    } else if (message.contains('exists')) {
      return NfsError.exist;
    } else if (message.contains('not a directory')) {
      return NfsError.notdir;
    } else if (message.contains('is a directory')) {
      return NfsError.isdir;
    } else if (message.contains('read-only')) {
      return NfsError.rofs;
    } else if (message.contains('no space')) {
      return NfsError.nospc;
    }

    return NfsError.io;
  }

  /// Generate a file ID from path and stat.
  /// Uses hash of path as file ID since Dart doesn't expose inode.
  int _generateFileId(final String path, final FileStat stat) =>
      path.hashCode.abs();
}

/// File attributes matching NFS fattr3 structure.
class FileAttributes {
  const FileAttributes({
    required this.type,
    required this.mode,
    required this.nlink,
    required this.uid,
    required this.gid,
    required this.size,
    required this.used,
    required this.rdev,
    required this.fsid,
    required this.fileid,
    required this.atime,
    required this.mtime,
    required this.ctime,
  });

  final int type;
  final int mode;
  final int nlink;
  final int uid;
  final int gid;
  final int size;
  final int used;
  final int rdev;
  final int fsid;
  final int fileid;
  final DateTime atime;
  final DateTime mtime;
  final DateTime ctime;
}

/// Result of a read operation.
class ReadResult {
  const ReadResult.success({
    required this.data,
    required this.eof,
    required this.attributes,
  }) : error = null;

  const ReadResult.error(this.error)
      : data = null,
        eof = false,
        attributes = null;

  final Uint8List? data;
  final bool eof;
  final FileAttributes? attributes;
  final NfsError? error;

  bool get isSuccess => error == null;
}

/// Result of a write operation.
class WriteResult {
  const WriteResult.success({
    required this.count,
    required this.attributes,
  }) : error = null;

  const WriteResult.error(this.error)
      : count = 0,
        attributes = null;

  final int count;
  final FileAttributes? attributes;
  final NfsError? error;

  bool get isSuccess => error == null;
}

/// Directory entry with attributes.
class DirectoryEntry {
  const DirectoryEntry({
    required this.name,
    required this.fileid,
    this.attributes,
  });

  final String name;
  final int fileid;
  final FileAttributes? attributes;
}

/// NFS error codes (matching nfsstat3).
enum NfsError {
  ok(0),
  perm(1),
  noent(2),
  io(5),
  nxio(6),
  access(13),
  exist(17),
  xdev(18),
  nodev(19),
  notdir(20),
  isdir(21),
  inval(22),
  fbig(27),
  nospc(28),
  rofs(30),
  mlink(31),
  nametoolong(63),
  notempty(66),
  dquot(69),
  stale(70),
  remote(71),
  badhandle(10001),
  notSync(10002),
  badCookie(10003),
  notsupp(10004),
  toosmall(10005),
  serverfault(10006),
  badtype(10007),
  jukebox(10008);

  const NfsError(this.code);

  final int code;
}
