/// NFS v3 protocol server implementation (RFC 1813).
///
/// Implements the core NFS v3 procedures for file access over the network.
// ignore_for_file: cascade_invocations
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/dart_oncrpc.dart';

import 'constants.dart';
import 'file_handle.dart';
import 'file_system.dart';

/// NFS v3 protocol server.
///
/// Implements essential NFS procedures for file and directory operations.
class NfsServer {
  NfsServer({
    required this.handles,
    required this.fs,
  });

  /// File handle manager
  final FileHandleManager handles;

  /// File system operations
  final NfsFileSystem fs;

  /// Write verifier (used to detect server reboots)
  final Uint8List _writeVerifier = Uint8List(8);

  /// Operation counters for statistics
  final Map<String, int> _stats = {};

  /// Register NFS program with RPC server.
  void register(final RpcServer server) {
    final program = RpcProgram(NFS_PROGRAM)
      ..addVersion(
        RpcVersion(NFS_V3)
          ..addProcedure(0, _null)
          ..addProcedure(1, _getattr)
          ..addProcedure(2, _setattr)
          ..addProcedure(3, _lookup)
          ..addProcedure(4, _access)
          ..addProcedure(5, _readlink)
          ..addProcedure(6, _read)
          ..addProcedure(7, _write)
          ..addProcedure(8, _create)
          ..addProcedure(9, _mkdir)
          ..addProcedure(10, _symlink)
          ..addProcedure(11, _mknod)
          ..addProcedure(12, _remove)
          ..addProcedure(13, _rmdir)
          ..addProcedure(14, _rename)
          ..addProcedure(15, _link)
          ..addProcedure(16, _readdir)
          ..addProcedure(17, _readdirplus)
          ..addProcedure(18, _fsstat)
          ..addProcedure(19, _fsinfo)
          ..addProcedure(20, _pathconf)
          ..addProcedure(21, _commit),
      );

    server.addProgram(program);
  }

  /// NFS3_NULL - Null procedure (ping).
  Future<Uint8List?> _null(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('null');
    return null;
  }

  /// NFS3_SETATTR - Set file attributes.
  Future<Uint8List?> _setattr(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('setattr');

    try {
      final fhandle = params.readBytes(); // Variable-length opaque
      // Decode sattr3 (6 discriminated unions)
      // set_mode3
      final modeSet = params.readInt();
      if (modeSet == 1) {
        params.readInt(); // mode
      }

      // set_uid3
      final uidSet = params.readInt();
      if (uidSet == 1) params.readInt(); // uid

      // set_gid3
      final gidSet = params.readInt();
      if (gidSet == 1) params.readInt(); // gid

      // set_size3
      final sizeSet = params.readInt();
      if (sizeSet == 1) params.readHyper(); // size (hyper)

      // set_atime
      final atimeHow = params.readInt();
      if (atimeHow == 2) {
        // SET_TO_CLIENT_TIME
        params.readInt(); // seconds
        params.readInt(); // nseconds
      }

      // set_mtime
      final mtimeHow = params.readInt();
      if (mtimeHow == 2) {
        // SET_TO_CLIENT_TIME
        params.readInt(); // seconds
        params.readInt(); // nseconds
      }

      // Decode sattrguard3 (discriminated union)
      final guardCheck = params.readInt();
      if (guardCheck == 1) {
        // TRUE - skip obj_ctime (nfstime3)
        params.readInt(); // seconds
        params.readInt(); // nseconds
      }

      final path = handles.lookup(fhandle);
      if (path == null) {
        // Return SETATTR3resfail with wcc_data
        final out = XdrOutputStream()
          ..writeInt(NFS3ERR_STALE)
          ..writeInt(0) // wcc_data.before (pre_op_attr)
          ..writeInt(0); // wcc_data.after (post_op_attr)
        return Uint8List.fromList(out.bytes);
      }

      // Get current attributes for response
      final attrs = fs.attributes(path);

      // Return success with wcc_data
      final out = XdrOutputStream()
        ..writeInt(NFS3_OK)
        // wcc_data
        ..writeInt(0); // before (pre_op_attr - not available)

      // after (post_op_attr)
      if (attrs != null) {
        out.writeInt(1); // attributes_follow = TRUE
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0); // attributes_follow = FALSE
      }

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      // Return SETATTR3resfail with wcc_data
      final out = XdrOutputStream()
        ..writeInt(NFS3ERR_IO)
        ..writeInt(0) // wcc_data.before
        ..writeInt(0); // wcc_data.after
      return Uint8List.fromList(out.bytes);
    }
  }

  /// NFS3_GETATTR - Get file attributes.
  Future<Uint8List?> _getattr(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('getattr');

    try {
      // Decode file handle (variable-length opaque)
      final fhandle = params.readBytes();

      // Look up file path
      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      // Get attributes
      final attrs = fs.attributes(path);
      if (attrs == null) {
        return _error(NFS3ERR_NOENT);
      }

      // Return success with attributes
      final out = XdrOutputStream()..writeInt(NFS3_OK); // status
      _writeFileAttributes(out, attrs);

      final result = Uint8List.fromList(out.bytes);
      return result;
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_LOOKUP - Look up a filename in a directory.
  Future<Uint8List?> _lookup(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('lookup');

    try {
      // Decode diropargs3
      final dirFh = params.readBytes(); // Variable-length opaque
      final filename = params.readString();

      // Look up directory
      final dirPath = handles.lookup(dirFh);
      if (dirPath == null) {
        // Return proper LOOKUP3resfail structure (can't get dir attrs for stale handle)
        final out = XdrOutputStream()
          ..writeInt(NFS3ERR_STALE) // status
          ..writeInt(0); // dir_attributes: attributes_follow = FALSE
        return Uint8List.fromList(out.bytes);
      }

      // Build target path
      final targetPath = '$dirPath${Platform.pathSeparator}$filename';

      // Check if file exists
      final attrs = fs.attributes(targetPath);
      if (attrs == null) {
        // Return proper LOOKUP3resfail structure
        final out = XdrOutputStream()..writeInt(NFS3ERR_NOENT); // status

        // dir_attributes (post_op_attr)
        final dirAttrs = fs.attributes(dirPath);
        if (dirAttrs != null) {
          out.writeInt(1); // attributes_follow = TRUE
          _writeFileAttributes(out, dirAttrs);
        } else {
          out.writeInt(0); // attributes_follow = FALSE
        }

        return Uint8List.fromList(out.bytes);
      }

      // Generate file handle for target
      final targetFh = handles.generate(targetPath);

      // Return success
      final out = XdrOutputStream()
        ..writeInt(NFS3_OK) // status
        // LOOKUP3resok
        // object (nfs_fh3) - writeBytes includes length
        ..writeBytes(targetFh)
        // obj_attributes (post_op_attr)
        ..writeInt(1); // attributes_follow = TRUE
      _writeFileAttributes(out, attrs);

      // dir_attributes (post_op_attr)
      final dirAttrs = fs.attributes(dirPath);
      if (dirAttrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, dirAttrs);
      } else {
        out.writeInt(0);
      }

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      // Return proper LOOKUP3resfail structure
      final out = XdrOutputStream()
        ..writeInt(NFS3ERR_IO) // status
        ..writeInt(
          0,
        ); // dir_attributes: attributes_follow = FALSE (can't safely get)
      return Uint8List.fromList(out.bytes);
    }
  }

  /// NFS3_READLINK - Read symbolic link.
  Future<Uint8List?> _readlink(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('readlink');
    return _error(NFS3ERR_NOTSUPP);
  }

  /// NFS3_ACCESS - Check access permissions.
  Future<Uint8List?> _access(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('access');

    try {
      // Decode ACCESS3args
      final fhandle = params.readBytes(); // Variable-length opaque
      final requested = params.readInt();

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final attrs = fs.attributes(path);
      if (attrs == null) {
        return _error(NFS3ERR_NOENT);
      }

      // Grant all requested access (simplified - no real permission check)
      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // ACCESS3resok
      // obj_attributes
      out.writeInt(1);
      _writeFileAttributes(out, attrs);

      // access (granted permissions)
      out.writeInt(requested); // Grant all requested

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_READ - Read from a file.
  Future<Uint8List?> _read(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('read');

    try {
      // Decode READ3args
      final fhandle = params.readBytes(); // Variable-length opaque
      final offsetBig = params.readHyper();
      final offset = offsetBig.toInt();
      final count = params.readInt();

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      // Perform read
      final result = fs.read(path, offset, count);
      if (result == null || !result.isSuccess) {
        return _error(result?.error?.code ?? NFS3ERR_IO);
      }

      // Return success
      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // READ3resok
      // file_attributes
      if (result.attributes != null) {
        out.writeInt(1);
        _writeFileAttributes(out, result.attributes!);
      } else {
        out.writeInt(0);
      }

      // count
      out.writeInt(result.data!.length);

      // eof
      out.writeBoolean(result.eof);

      // data (variable-length opaque - writeBytes includes length)
      out.writeBytes(result.data!);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_WRITE - Write to a file.
  Future<Uint8List?> _write(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('write');

    try {
      // Decode WRITE3args
      final fhandle = params.readBytes(); // Variable-length opaque
      final offsetBig = params.readHyper();
      final offset = offsetBig.toInt();
      params.readInt(); // count parameter
      params.readInt(); // stable_how
      final data = params.readBytes(); // Variable-length opaque
      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      // Perform write
      final result = fs.write(path, offset, data);
      if (result == null || !result.isSuccess) {
        return _error(result?.error?.code ?? NFS3ERR_IO);
      }

      // Return success
      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // WRITE3resok
      // file_wcc (wcc_data - simplified, no pre/post attrs)
      out.writeInt(0); // before (pre_op_attr)
      if (result.attributes != null) {
        out.writeInt(1); // after (post_op_attr)
        _writeFileAttributes(out, result.attributes!);
      } else {
        out.writeInt(0);
      }

      // count
      out.writeInt(result.count);

      // committed (stable_how)
      out.writeInt(FILE_SYNC); // FILE_SYNC = 2

      // verf (writeverf3 - fixed 8 bytes)
      out.writeBytes(_writeVerifier, fixed: true);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_CREATE - Create a file.
  Future<Uint8List?> _create(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('create');

    try {
      // Decode CREATE3args
      final dirFh = params.readBytes(); // Variable-length opaque
      final filename = params.readString();

      // Decode createhow3 (discriminated union)
      final createMode = params.readInt(); // createmode3
      // Skip the sattr3 or createverf3 depending on mode
      if (createMode == 2) {
        // EXCLUSIVE mode - skip createverf3 (8 bytes fixed)
        params.readBytes(8);
      } else {
        // UNCHECKED or GUARDED - skip sattr3
        // sattr3 has 6 union fields: mode, uid, gid, size, atime, mtime

        // set_mode3
        if (params.readInt() == 1) params.readInt(); // mode

        // set_uid3
        if (params.readInt() == 1) params.readInt(); // uid

        // set_gid3
        if (params.readInt() == 1) params.readInt(); // gid

        // set_size3
        if (params.readInt() == 1) params.readHyper(); // size (hyper)

        // set_atime
        final atimeHow = params.readInt();
        if (atimeHow == 2) {
          // SET_TO_CLIENT_TIME - skip nfstime3
          params.readInt(); // seconds
          params.readInt(); // nseconds
        }

        // set_mtime
        final mtimeHow = params.readInt();
        if (mtimeHow == 2) {
          // SET_TO_CLIENT_TIME - skip nfstime3
          params.readInt(); // seconds
          params.readInt(); // nseconds
        }
      }

      final dirPath = handles.lookup(dirFh);
      if (dirPath == null) {
        return _error(NFS3ERR_STALE);
      }

      final targetPath = '$dirPath${Platform.pathSeparator}$filename';

      // Create file with default mode
      final attrs = fs.create(targetPath, 0);
      if (attrs == null) {
        return _error(NFS3ERR_IO);
      }

      // Generate handle
      final targetFh = handles.generate(targetPath);

      // Return success
      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // CREATE3resok
      // obj (post_op_fh3)
      out.writeInt(1); // handle_follows
      out.writeBytes(targetFh); // writeBytes includes length

      // obj_attributes
      out.writeInt(1);
      _writeFileAttributes(out, attrs);

      // dir_wcc - include parent directory attributes
      out.writeInt(0); // before (pre_op_attr - not available)

      // after (post_op_attr) - include parent directory attributes
      final dirAttrs = fs.attributes(dirPath);
      if (dirAttrs != null) {
        out.writeInt(1); // attributes_follow = TRUE
        _writeFileAttributes(out, dirAttrs);
      } else {
        out.writeInt(0); // attributes_follow = FALSE
      }

      final result = Uint8List.fromList(out.bytes);
      return result;
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_SYMLINK - Create symbolic link.
  Future<Uint8List?> _symlink(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('symlink');
    return _error(NFS3ERR_NOTSUPP);
  }

  /// NFS3_MKNOD - Create special file.
  Future<Uint8List?> _mknod(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('mknod');
    return _error(NFS3ERR_NOTSUPP);
  }

  /// NFS3_MKDIR - Create a directory.
  Future<Uint8List?> _mkdir(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('mkdir');

    try {
      // Similar to CREATE but for directories
      final dirFh = params.readBytes(); // Variable-length opaque
      final dirname = params.readString();
      final mode = params.readInt();

      final dirPath = handles.lookup(dirFh);
      if (dirPath == null) {
        return _error(NFS3ERR_STALE);
      }

      final targetPath = '$dirPath${Platform.pathSeparator}$dirname';

      final attrs = fs.mkdir(targetPath, mode);
      if (attrs == null) {
        return _error(NFS3ERR_IO);
      }

      final targetFh = handles.generate(targetPath);

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // MKDIR3resok (same structure as CREATE3resok)
      out
        ..writeInt(1) // handle_follows
        ..writeBytes(targetFh); // writeBytes includes length

      out.writeInt(1);
      _writeFileAttributes(out, attrs);

      // dir_wcc - include parent directory attributes
      out.writeInt(0); // before (pre_op_attr - not available)

      // after (post_op_attr) - include parent directory attributes
      final dirAttrs = fs.attributes(dirPath);
      if (dirAttrs != null) {
        out.writeInt(1); // attributes_follow = TRUE
        _writeFileAttributes(out, dirAttrs);
      } else {
        out.writeInt(0); // attributes_follow = FALSE
      }

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_REMOVE - Remove a file.
  Future<Uint8List?> _remove(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('remove');

    try {
      final dirFh = params.readBytes(); // Variable-length opaque
      final filename = params.readString();

      final dirPath = handles.lookup(dirFh);
      if (dirPath == null) {
        return _error(NFS3ERR_STALE);
      }

      final targetPath = '$dirPath${Platform.pathSeparator}$filename';

      if (!fs.remove(targetPath)) {
        return _error(NFS3ERR_NOENT);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // REMOVE3resok
      // dir_wcc - include parent directory attributes
      out.writeInt(0); // before (pre_op_attr - not available)

      // after (post_op_attr) - include parent directory attributes
      final dirAttrs = fs.attributes(dirPath);
      if (dirAttrs != null) {
        out.writeInt(1); // attributes_follow = TRUE
        _writeFileAttributes(out, dirAttrs);
      } else {
        out.writeInt(0); // attributes_follow = FALSE
      }

      final result = Uint8List.fromList(out.bytes);
      return result;
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_RMDIR - Remove a directory.
  Future<Uint8List?> _rmdir(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('rmdir');

    try {
      final dirFh = params.readBytes(); // Variable-length opaque
      final dirname = params.readString();

      final dirPath = handles.lookup(dirFh);
      if (dirPath == null) {
        return _error(NFS3ERR_STALE);
      }

      final targetPath = '$dirPath${Platform.pathSeparator}$dirname';

      if (!fs.rmdir(targetPath)) {
        return _error(NFS3ERR_NOENT);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // RMDIR3resok
      // dir_wcc - include parent directory attributes
      out.writeInt(0); // before (pre_op_attr - not available)

      // after (post_op_attr) - include parent directory attributes
      final dirAttrs = fs.attributes(dirPath);
      if (dirAttrs != null) {
        out.writeInt(1); // attributes_follow = TRUE
        _writeFileAttributes(out, dirAttrs);
      } else {
        out.writeInt(0); // attributes_follow = FALSE
      }

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_LINK - Create hard link.
  Future<Uint8List?> _link(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('link');
    return _error(NFS3ERR_NOTSUPP);
  }

  /// NFS3_RENAME - Rename a file or directory.
  Future<Uint8List?> _rename(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('rename');

    try {
      final fromDirFh = params.readBytes(); // Variable-length opaque
      final fromName = params.readString();

      final toDirFh = params.readBytes(); // Variable-length opaque
      final toName = params.readString();

      final fromDirPath = handles.lookup(fromDirFh);
      final toDirPath = handles.lookup(toDirFh);

      if (fromDirPath == null || toDirPath == null) {
        return _error(NFS3ERR_STALE);
      }

      final fromPath = '$fromDirPath${Platform.pathSeparator}$fromName';
      final toPath = '$toDirPath${Platform.pathSeparator}$toName';

      if (!fs.rename(fromPath, toPath)) {
        return _error(NFS3ERR_IO);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // RENAME3resok
      // fromdir_wcc
      out.writeInt(0); // before (pre_op_attr - not available)
      final fromDirAttrs = fs.attributes(fromDirPath);
      if (fromDirAttrs != null) {
        out.writeInt(1); // after: attributes_follow = TRUE
        _writeFileAttributes(out, fromDirAttrs);
      } else {
        out.writeInt(0); // after: attributes_follow = FALSE
      }

      // todir_wcc
      out.writeInt(0); // before (pre_op_attr - not available)
      final toDirAttrs = fs.attributes(toDirPath);
      if (toDirAttrs != null) {
        out.writeInt(1); // after: attributes_follow = TRUE
        _writeFileAttributes(out, toDirAttrs);
      } else {
        out.writeInt(0); // after: attributes_follow = FALSE
      }

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_READDIR - Read directory entries.
  Future<Uint8List?> _readdir(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('readdir');

    try {
      // Decode READDIR3args
      final fhandle = params.readBytes(); // Variable-length opaque
      params.readHyper(); // cookie (ignored - return all entries)
      params.readBytes(); // cookieverf (ignored)
      params.readInt(); // count (ignored - return all entries)

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final entries = fs.readdir(path);
      if (entries == null) {
        return _error(NFS3ERR_NOTDIR);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // READDIR3resok
      // dir_attributes
      final attrs = fs.attributes(path);
      if (attrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0);
      }

      // cookieverf (fixed-length 8 bytes)
      out.writeBytes(Uint8List(8), fixed: true);

      // dirlist3
      if (entries.isEmpty) {
        out.writeInt(0); // no entries
      } else {
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];

          out.writeInt(1); // entry present

          // fileid
          out.writeHyper(BigInt.from(entry.fileid));

          // name
          out.writeString(entry.name);

          // cookie
          out.writeHyper(BigInt.from(i + 1));

          // nextentry (0 if last)
          if (i < entries.length - 1) {
            // More entries
          } else {
            out.writeInt(0);
          }
        }
      }

      // eof
      out.writeBoolean(true);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_READDIRPLUS - Read directory with attributes.
  Future<Uint8List?> _readdirplus(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('readdirplus');

    try {
      // Decode READDIRPLUS3args
      final fhandle = params.readBytes(); // Variable-length opaque
      params.readHyper(); // cookie (ignored - return all entries)
      params.readBytes(); // cookieverf (ignored)
      params.readInt(); // dircount (ignored - return all entries)
      params.readInt(); // maxcount (ignored - return all entries)

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final entries = fs.readdir(path);
      if (entries == null) {
        return _error(NFS3ERR_NOTDIR);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // READDIRPLUS3resok
      // dir_attributes
      final attrs = fs.attributes(path);
      if (attrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0);
      }

      // cookieverf (fixed-length 8 bytes)
      out.writeBytes(Uint8List(8), fixed: true);

      // dirlistplus3
      if (entries.isEmpty) {
        out.writeInt(0); // no entries
      } else {
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];

          out.writeInt(1); // entry present

          // fileid
          out.writeHyper(BigInt.from(entry.fileid));

          // name
          out.writeString(entry.name);

          // cookie
          out.writeHyper(BigInt.from(i + 1));

          // name_attributes (post_op_attr)
          final entryPath = '$path${Platform.pathSeparator}${entry.name}';
          final entryAttrs = fs.attributes(entryPath);
          if (entryAttrs != null) {
            out.writeInt(1);
            _writeFileAttributes(out, entryAttrs);
          } else {
            out.writeInt(0);
          }

          // name_handle (post_op_fh3)
          if (entryAttrs != null) {
            out.writeInt(1); // handle_follows
            final entryFh = handles.generate(entryPath);
            out.writeBytes(entryFh); // writeBytes includes length
          } else {
            out.writeInt(0); // no handle
          }

          // nextentry (0 if last)
          if (i < entries.length - 1) {
            // More entries
          } else {
            out.writeInt(0);
          }
        }
      }

      // eof
      out.writeBoolean(true);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_FSSTAT - Get filesystem statistics.
  Future<Uint8List?> _fsstat(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('fsstat');

    try {
      final fhandle = params.readBytes(); // Variable-length opaque

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // FSSTAT3resok
      // obj_attributes
      final attrs = fs.attributes(path);
      if (attrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0);
      }

      // tbytes (total size in bytes)
      out.writeHyper(BigInt.from(1024 * 1024 * 1024 * 100)); // 100 GB

      // fbytes (free bytes)
      out.writeHyper(BigInt.from(1024 * 1024 * 1024 * 50)); // 50 GB

      // abytes (available bytes)
      out.writeHyper(BigInt.from(1024 * 1024 * 1024 * 50)); // 50 GB

      // tfiles (total file slots)
      out.writeHyper(BigInt.from(1000000));

      // ffiles (free file slots)
      out.writeHyper(BigInt.from(500000));

      // afiles (available file slots)
      out.writeHyper(BigInt.from(500000));

      // invarsec (server time granularity)
      out.writeInt(1);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_FSINFO - Get static filesystem info.
  Future<Uint8List?> _fsinfo(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('fsinfo');

    try {
      final fhandle = params.readBytes(); // Variable-length opaque

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // FSINFO3resok
      // obj_attributes
      final attrs = fs.attributes(path);
      if (attrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0);
      }

      // rtmax (max read size)
      out.writeInt(65536);

      // rtpref (preferred read size)
      out.writeInt(32768);

      // rtmult (suggested read multiple)
      out.writeInt(4096);

      // wtmax (max write size)
      out.writeInt(65536);

      // wtpref (preferred write size)
      out.writeInt(32768);

      // wtmult (suggested write multiple)
      out.writeInt(4096);

      // dtpref (preferred readdir size)
      out.writeInt(8192);

      // maxfilesize
      out.writeHyper(BigInt.parse('9223372036854775807')); // Max int64

      // time_delta
      out.writeInt(1); // seconds
      out.writeInt(0); // nseconds

      // properties
      out.writeInt(FSF3_HOMOGENEOUS | FSF3_CANSETTIME);

      final result = Uint8List.fromList(out.bytes);
      return result;
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_PATHCONF - Get POSIX path configuration.
  Future<Uint8List?> _pathconf(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('pathconf');

    try {
      final fhandle = params.readBytes(); // Variable-length opaque

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      final out = XdrOutputStream()..writeInt(NFS3_OK);

      // PATHCONF3resok
      // obj_attributes
      final attrs = fs.attributes(path);
      if (attrs != null) {
        out.writeInt(1);
        _writeFileAttributes(out, attrs);
      } else {
        out.writeInt(0);
      }

      // linkmax
      out.writeInt(32767);

      // name_max
      out.writeInt(255);

      // no_trunc
      out.writeBoolean(true);

      // chown_restricted
      out.writeBoolean(true);

      // case_insensitive
      out.writeBoolean(false);

      // case_preserving
      out.writeBoolean(true);

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// NFS3_COMMIT - Commit cached data.
  Future<Uint8List?> _commit(
    final XdrInputStream params,
    final AuthContext auth,
  ) async {
    _incrementStat('commit');

    try {
      final fhandle = params.readBytes(); // Variable-length opaque
      params.readHyper(); // offset (ignored)
      params.readInt(); // count (ignored)

      final path = handles.lookup(fhandle);
      if (path == null) {
        return _error(NFS3ERR_STALE);
      }

      // Return success with writeverf
      final out = XdrOutputStream()
        ..writeInt(NFS3_OK)
        ..writeInt(0) // wcc_data.before
        ..writeInt(0) // wcc_data.after
        ..writeBytes(_writeVerifier, fixed: true); // writeverf (8 bytes)

      return Uint8List.fromList(out.bytes);
    } catch (e) {
      return _error(NFS3ERR_IO);
    }
  }

  /// Write file attributes to XDR stream (fattr3 structure).
  void _writeFileAttributes(
    final XdrOutputStream out,
    final FileAttributes attrs,
  ) {
    out.writeInt(attrs.type); // ftype3
    out.writeInt(attrs.mode); // mode3
    out.writeInt(attrs.nlink); // nlink
    out.writeInt(attrs.uid); // uid3
    out.writeInt(attrs.gid); // gid3
    out.writeHyper(BigInt.from(attrs.size)); // size3
    out.writeHyper(BigInt.from(attrs.used)); // size3 (used)
    out.writeInt(0); // specdata3.specdata1
    out.writeInt(0); // specdata3.specdata2
    out.writeHyper(BigInt.from(attrs.fsid)); // fsid
    out.writeHyper(BigInt.from(attrs.fileid)); // fileid3

    // nfstime3 atime
    out.writeInt(attrs.atime.millisecondsSinceEpoch ~/ 1000);
    out.writeInt((attrs.atime.millisecondsSinceEpoch % 1000) * 1000000);

    // nfstime3 mtime
    out.writeInt(attrs.mtime.millisecondsSinceEpoch ~/ 1000);
    out.writeInt((attrs.mtime.millisecondsSinceEpoch % 1000) * 1000000);

    // nfstime3 ctime
    out.writeInt(attrs.ctime.millisecondsSinceEpoch ~/ 1000);
    out.writeInt((attrs.ctime.millisecondsSinceEpoch % 1000) * 1000000);
  }

  /// Create error response with nfsstat3 status code.
  Uint8List _error(final int status) {
    final out = XdrOutputStream()..writeInt(status);
    return Uint8List.fromList(out.bytes);
  }

  /// Increment operation counter.
  void _incrementStat(final String op) {
    _stats[op] = (_stats[op] ?? 0) + 1;
  }

  /// Get operation statistics.
  Map<String, int> get stats => Map.unmodifiable(_stats);
}
