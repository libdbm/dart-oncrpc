/// File handle generation and management for NFS server.
///
/// File handles are opaque identifiers used by NFS to reference files and
/// directories. This implementation uses a secure hash-based approach to
/// generate stable, unique handles for filesystem objects.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

/// Manages file handle generation, validation, and mapping.
///
/// File handles in NFS v3 are up to 64 bytes and must be:
/// - Stable across server restarts (same file = same handle)
/// - Unique (different files = different handles)
/// - Opaque to clients (internal structure not exposed)
/// - Secure (prevent handle guessing/tampering)
class FileHandleManager {
  FileHandleManager({
    required this.rootPath,
    this.handleSize = 8,
  }) {
    // Generate and cache root handle
    _rootHandle = _generate(rootPath);
  }

  /// Root directory being exported
  final String rootPath;

  /// Size of generated file handles in bytes (XXH3 produces 8 bytes)
  final int handleSize;

  /// Cache of path → handle mappings
  final Map<String, Uint8List> _handleCache = {};

  /// Cache of handle → path mappings (for lookup)
  final Map<String, String> _pathCache = {};

  /// Special well-known handle for the export root
  late final Uint8List _rootHandle;

  /// Maximum cache size before eviction
  static const maxCacheSize = 10000;

  /// Get the root file handle for the export
  Uint8List get root => Uint8List.fromList(_rootHandle);

  /// Generate a file handle for a given path.
  ///
  /// The handle is an xxHash3 hash of:
  /// - Absolute canonical path
  /// - Export root (as salt)
  ///
  /// This ensures handles are:
  /// - Deterministic (same file always gets same handle)
  /// - Unique (hash collision extremely unlikely)
  /// - Stable (survives server restart and metadata changes)
  /// - Fast (xxHash3 is much faster than SHA-256)
  Uint8List generate(final String path) {
    // Normalize path first to ensure consistent caching
    final canonical = _canonicalize(path);

    // Check cache first
    final cached = _handleCache[canonical];
    if (cached != null) {
      return Uint8List.fromList(cached);
    }

    final handle = _generate(path);

    // Add to cache (with simple LRU eviction)
    if (_handleCache.length >= maxCacheSize) {
      // Remove oldest entry
      final first = _handleCache.keys.first;
      _handleCache.remove(first);
      _pathCache.remove(_bytesToString(_handleCache[first]!));
    }

    _handleCache[canonical] = handle;
    _pathCache[_bytesToString(handle)] = canonical;

    return Uint8List.fromList(handle);
  }

  /// Internal handle generation
  Uint8List _generate(final String path) {
    final canonical = _canonicalize(path);

    // Build handle data from canonical path and root only
    // DO NOT include timestamps or mutable metadata - handles must be stable!
    final data = StringBuffer()
      ..write(canonical)
      ..write(':')
      ..write(rootPath);

    // Generate xxHash3 (much faster than SHA-256, perfect for this use case)
    final bytes = utf8.encode(data.toString());
    final hash = const XXH3().convert(bytes);

    // Return first handleSize bytes of the hash
    return Uint8List.fromList(
      hash.bytes.sublist(0, handleSize.clamp(1, hash.bytes.length)),
    );
  }

  /// Look up the file path for a given handle.
  ///
  /// Returns null if the handle is not recognized or the file no longer exists.
  String? lookup(final Uint8List handle) {
    final key = _bytesToString(handle);
    final path = _pathCache[key];

    if (path == null) {
      // Not in cache - try to verify if it's a valid handle
      // by checking all known paths (expensive fallback)
      for (final cachedPath in _handleCache.keys) {
        if (_bytesEqual(handle, _handleCache[cachedPath]!)) {
          return cachedPath;
        }
      }
      return null;
    }

    // Verify file still exists
    if (!File(path).existsSync() && !Directory(path).existsSync()) {
      // Stale handle - remove from cache
      _handleCache.remove(path);
      _pathCache.remove(key);
      return null;
    }

    return path;
  }

  /// Validate that a file handle is well-formed.
  bool validate(final Uint8List handle) =>
      handle.isNotEmpty && handle.length <= 64;

  /// Check if a file handle refers to the export root.
  bool isRoot(final Uint8List handle) => _bytesEqual(handle, _rootHandle);

  /// Canonicalize a path (resolve symlinks, make absolute).
  String _canonicalize(final String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } catch (_) {
      try {
        return Directory(path).resolveSymbolicLinksSync();
      } catch (_) {
        // Fall back to absolute path
        return File(path).absolute.path;
      }
    }
  }

  /// Convert bytes to string key for map lookup
  String _bytesToString(final Uint8List bytes) => base64.encode(bytes);

  /// Compare two byte arrays for equality
  bool _bytesEqual(final Uint8List a, final Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Clear all cached handles (useful for testing)
  void clear() {
    _handleCache.clear();
    _pathCache.clear();
  }

  /// Get cache statistics
  Map<String, int> get stats => {
        'handle_cache_size': _handleCache.length,
        'path_cache_size': _pathCache.length,
      };
}
