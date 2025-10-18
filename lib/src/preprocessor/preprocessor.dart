import 'dart:io';

import 'package:path/path.dart' as path;

/// Error thrown during preprocessing
class PreprocessorError implements Exception {
  PreprocessorError(this.message, [this.file, this.line]);

  final String message;
  final String? file;
  final int? line;

  @override
  String toString() {
    final location = file != null
        ? line != null
            ? ' at $file:$line'
            : ' in $file'
        : '';
    return 'PreprocessorError: $message$location';
  }
}

/// Preprocessor for XDR/RPC specification files
///
/// Handles:
/// - #include directives for file inclusion
/// - #define directives for macro definitions
/// - #ifdef/#ifndef/#endif for conditional compilation
class Preprocessor {
  /// Creates a new preprocessor.
  ///
  /// If [paths] is omitted or empty, platform-aware defaults are used. Extra
  /// include directories can also be provided via the environment variable
  /// `ONCRPC_INCLUDE_PATHS` (use `;` on Windows or `:` on POSIX systems to
  /// separate entries).
  Preprocessor({
    List<String>? paths,
    Map<String, String>? definitions,
  })  : paths = _initializeSearchPaths(paths),
        definitions = Map.from(definitions ?? {});

  /// Search paths for include files
  final List<String> paths;

  /// Defined macros
  final Map<String, String> definitions;

  /// Files being processed (for circular dependency detection)
  final Set<String> _processing = {};

  /// Already processed files (with include guards)
  final Set<String> _processed = {};

  /// Track source locations for error reporting
  final List<SourceLocation> _sources = [];

  /// Preprocess a file, expanding includes and processing directives
  String preprocess(final String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw PreprocessorError('File not found: $path');
    }

    _processing.clear();
    _sources.clear();

    return _processFile(file.absolute.path, null);
  }

  /// Process a single file
  String _processFile(final String path, final String? includer) {
    // Check for circular dependencies
    if (_processing.contains(path)) {
      throw PreprocessorError(
        'Circular include detected: $path',
        includer,
      );
    }

    _processing.add(path);

    try {
      final content = File(path).readAsStringSync();
      final processed = _processContent(content, path);

      _processing.remove(path);
      return processed;
    } catch (e) {
      _processing.remove(path);
      if (e is PreprocessorError) {
        rethrow;
      }
      throw PreprocessorError(
        'Failed to process file: $e',
        path,
      );
    }
  }

  /// Process content line by line
  String _processContent(final String content, final String filePath) {
    final lines = content.split('\n');
    final output = StringBuffer();
    final conditions = <ConditionalState>[];
    String? guard;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // Skip lines if we're in a false conditional block
      if (conditions.isNotEmpty && !conditions.last.isActive) {
        // Still need to track nested conditionals
        if (_isDirective(line)) {
          final directive = _parseDirective(line);
          if (directive != null) {
            switch (directive.type) {
              case DirectiveType.ifdef:
              case DirectiveType.ifndef:
                conditions.add(ConditionalState(isActive: false));
                break;
              case DirectiveType.endif:
                if (conditions.isNotEmpty) {
                  conditions.removeLast();
                }
                break;
              case DirectiveType.elseDirective:
                if (conditions.isNotEmpty) {
                  // Toggle the current state if parent is active
                  final parent = conditions.length > 1 &&
                      conditions[conditions.length - 2].isActive;
                  if (parent) {
                    conditions.last.isActive = !conditions.last.wasActive;
                  }
                }
                break;
              default:
                // Skip other directives in false blocks
                break;
            }
          }
        }
        continue;
      }

      // Check if this is a preprocessor directive
      if (_isDirective(line)) {
        final directive = _parseDirective(line);
        if (directive != null) {
          try {
            switch (directive.type) {
              case DirectiveType.include:
                final path = directive.args;
                final isSystemInclude = line.contains('<');
                final resolved = _resolveInclude(
                  path,
                  filePath,
                  isSystemInclude,
                );

                if (resolved != null) {
                  output
                    ..writeln('/* BEGIN include: $path */')
                    ..write(_processFile(resolved, filePath))
                    ..writeln('/* END include: $path */');
                } else {
                  throw PreprocessorError(
                    'Cannot find include file: $path',
                    filePath,
                    lineNum,
                  );
                }
                break;

              case DirectiveType.define:
                final spaceIndex = directive.args.indexOf(' ');
                final name = spaceIndex >= 0
                    ? directive.args.substring(0, spaceIndex).trim()
                    : directive.args.trim();
                final value = spaceIndex >= 0
                    ? directive.args.substring(spaceIndex + 1).trim()
                    : '';
                definitions[name] = value;

                // Check for include guard pattern
                if (guard == null && i > 0) {
                  final previous = lines[i - 1].trim();
                  if (previous.startsWith('#ifndef') &&
                      previous.split(RegExp(r'\s+')).last == name) {
                    guard = name;
                    if (_processed.contains(name)) {
                      // Skip this entire file - already processed with this guard
                      return '/* Skipped (include guard $name) */\n';
                    }
                    _processed.add(name);
                  }
                }
                output.writeln('/* define: $name = $value */');
                break;

              case DirectiveType.ifdef:
                final symbol = directive.args;
                final isDefined = definitions.containsKey(symbol);
                conditions.add(ConditionalState(isActive: isDefined));
                output.writeln('/* ifdef $symbol: $isDefined */');
                break;

              case DirectiveType.ifndef:
                final symbol = directive.args;
                final isNotDefined = !definitions.containsKey(symbol);
                conditions.add(ConditionalState(isActive: isNotDefined));
                output.writeln('/* ifndef $symbol: $isNotDefined */');
                break;

              case DirectiveType.endif:
                if (conditions.isEmpty) {
                  throw PreprocessorError(
                    'Unmatched #endif',
                    filePath,
                    lineNum,
                  );
                }
                conditions.removeLast();
                output.writeln('/* endif */');
                break;

              case DirectiveType.elseDirective:
                if (conditions.isEmpty) {
                  throw PreprocessorError(
                    'Unmatched #else',
                    filePath,
                    lineNum,
                  );
                }
                // Toggle the current conditional state
                conditions.last.isActive = !conditions.last.wasActive;
                output.writeln('/* else */');
                break;

              case DirectiveType.unknown:
                // Pass through unknown directives as comments
                output.writeln('/* unknown directive: $line */');
                break;
            }
          } catch (e) {
            if (e is PreprocessorError) {
              rethrow;
            }
            throw PreprocessorError(
              'Error processing directive: $e',
              filePath,
              lineNum,
            );
          }
        }
      } else {
        // Regular line - apply macro substitutions
        output.writeln(_applyMacros(line));

        // Track source location
        _sources.add(SourceLocation(filePath, lineNum));
      }
    }

    // Check for unclosed conditionals
    if (conditions.isNotEmpty) {
      throw PreprocessorError(
        'Unclosed conditional block (missing #endif)',
        filePath,
        lines.length,
      );
    }

    return output.toString();
  }

  /// Check if a line contains a preprocessor directive
  bool _isDirective(final String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('#') || trimmed.startsWith('%');
  }

  /// Parse a preprocessor directive
  Directive? _parseDirective(final String line) {
    final trimmed = line.trim();

    // Handle both # and % prefixes
    if (!trimmed.startsWith('#') && !trimmed.startsWith('%')) {
      return null;
    }

    // Remove the prefix and parse
    final base = trimmed.substring(1).trimLeft();

    if (base.startsWith('include')) {
      // Extract filename from #include <file> or #include "file"
      final match = RegExp(r'include\s+[<"]([^>"]+)[>"]').firstMatch(trimmed);
      if (match != null) {
        return Directive(DirectiveType.include, match.group(1)!);
      }
    } else if (base.startsWith('define')) {
      // Extract macro definition
      final match = RegExp(r'define\s+(.+)').firstMatch(trimmed);
      if (match != null) {
        return Directive(DirectiveType.define, match.group(1)!.trim());
      }
    } else if (base.startsWith('ifdef')) {
      final match = RegExp(r'ifdef\s+(\w+)').firstMatch(trimmed);
      if (match != null) {
        return Directive(DirectiveType.ifdef, match.group(1)!);
      }
    } else if (base.startsWith('ifndef')) {
      final match = RegExp(r'ifndef\s+(\w+)').firstMatch(trimmed);
      if (match != null) {
        return Directive(DirectiveType.ifndef, match.group(1)!);
      }
    } else if (base.startsWith('endif')) {
      return Directive(DirectiveType.endif, '');
    } else if (base.startsWith('else')) {
      return Directive(DirectiveType.elseDirective, '');
    }

    return Directive(DirectiveType.unknown, trimmed);
  }

  /// Apply macro substitutions to a line
  String _applyMacros(final String line) {
    var result = line;

    // Apply each defined macro
    for (final entry in definitions.entries) {
      final name = entry.key;
      final value = entry.value;

      // Use word boundary to avoid partial replacements
      final pattern = RegExp('\\b$name\\b');
      result = result.replaceAll(pattern, value);
    }

    return result;
  }

  /// Resolve an include file path
  String? _resolveInclude(
    final String filename,
    final String current,
    final bool isSystemInclude,
  ) {
    final candidates = <String>[];

    if (!isSystemInclude) {
      // For "file", check relative to current file first
      final currentDir = File(current).parent.path;
      candidates.add(path.join(currentDir, filename));
    }

    // Check search paths
    for (final p in paths) {
      candidates.add(path.join(p, filename));
    }

    // Also check absolute path
    candidates.add(filename);

    // Find first existing file
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return File(candidate).absolute.path;
      }
    }

    return null;
  }
}

const _userIncludeEnvVariable = 'ONCRPC_INCLUDE_PATHS';

List<String> _initializeSearchPaths(final List<String>? provided) {
  final searchPaths = <String>[];

  if (provided != null && provided.isNotEmpty) {
    for (final entry in provided) {
      _addSearchPath(searchPaths, entry);
    }
  } else {
    for (final entry in _defaultSearchPaths()) {
      _addSearchPath(searchPaths, entry);
    }
  }

  for (final entry in _pathsFromEnv(_userIncludeEnvVariable)) {
    _addSearchPath(searchPaths, entry);
  }

  return searchPaths;
}

List<String> _defaultSearchPaths() {
  final defaults = <String>[];

  _addSearchPath(defaults, '.');

  if (Platform.isWindows) {
    for (final entry in _pathsFromEnv('INCLUDE')) {
      _addSearchPath(defaults, entry, requireExists: true);
    }
  } else {
    for (final candidate in [
      '/usr/include/rpcsvc',
      '/usr/local/include/rpcsvc',
    ]) {
      _addSearchPath(defaults, candidate, requireExists: true);
    }
    for (final envVar in ['CPATH', 'C_INCLUDE_PATH']) {
      for (final entry in _pathsFromEnv(envVar)) {
        _addSearchPath(defaults, entry, requireExists: true);
      }
    }
  }

  return defaults;
}

Iterable<String> _pathsFromEnv(final String variable) {
  final raw = Platform.environment[variable];
  if (raw == null || raw.trim().isEmpty) {
    return const Iterable<String>.empty();
  }

  final separator = Platform.isWindows ? ';' : ':';
  return raw.split(separator).map((final segment) => segment.trim()).where(
        (final segment) => segment.isNotEmpty,
      );
}

void _addSearchPath(
  final List<String> target,
  final String candidate, {
  final bool requireExists = false,
}) {
  final trimmed = candidate.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final normalized = path.normalize(trimmed);
  if (target.contains(normalized)) {
    return;
  }

  if (requireExists && !Directory(normalized).existsSync()) {
    return;
  }

  target.add(normalized);
}

/// Represents a preprocessor directive
class Directive {
  Directive(this.type, this.args);

  final DirectiveType type;
  final String args;
}

/// Types of preprocessor directives
enum DirectiveType {
  include,
  define,
  ifdef,
  ifndef,
  endif,
  elseDirective,
  unknown,
}

/// State for conditional compilation
class ConditionalState {
  ConditionalState({required this.isActive}) : wasActive = isActive;
  bool isActive;
  final bool wasActive;
}

/// Source location for error reporting
class SourceLocation {
  SourceLocation(this.file, this.line);

  final String file;
  final int line;

  @override
  String toString() => '$file:$line';
}
