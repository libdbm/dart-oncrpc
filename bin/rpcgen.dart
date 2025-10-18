/// RPC/XDR code generator for Dart, C, and Java.
///
/// This program parses ONC-RPC/XDR specification files (.x files) and generates
/// type definitions, client stubs, and server skeletons in multiple target languages.
///
/// ## Supported Output Languages
///
/// - **Dart**: Full type definitions with serialization, client and server stubs
/// - **C**: rpcgen-compatible header and XDR function files
/// - **Java**: oncrpc4j/Remote Tea compatible classes
///
/// ## Usage
///
/// ```bash
/// # Generate Dart code with all components
/// dart run bin/rpcgen.dart -t -c -s protocol.x
///
/// # Generate C code (rpcgen-compatible)
/// dart run bin/rpcgen.dart -l c -o generated/types.h protocol.x
///
/// # Generate Java code
/// dart run bin/rpcgen.dart -l java -p com.example.rpc -o Types.java protocol.x
///
/// # Use preprocessor with includes and defines
/// dart run bin/rpcgen.dart -I /usr/include/rpc -D DEBUG=1 -t protocol.x
/// ```
///
/// ## Options
///
/// - `-c, --client`: Generate client stubs
/// - `-s, --server`: Generate server skeletons
/// - `-t, --types`: Generate type definitions
/// - `-l, --language`: Target language (dart, c, java)
/// - `-o, --output`: Output file path
/// - `-p, --package`: Package name for Java output
/// - `-I, --include-path`: Add directory to include search path
/// - `-D, --define`: Define preprocessor macro
/// - `--no-preprocess`: Skip preprocessing
/// - `--save-preprocessed`: Save preprocessed .x file
/// - `--dart-conventions`: Convert UPPERCASE names to lowerCamelCase (Dart only, off by default)
///
/// ## Preprocessor Support
///
/// The preprocessor handles:
/// - `#include "file.x"` - Include other .x files
/// - `#include <file.x>` - Include from system paths
/// - `#define NAME value` - Define constants
/// - Use `-I` to add include search paths
/// - Use `-D` to define macros from command line
///
/// ## Cross-Language Compatibility
///
/// **C Output**: 100% compatible with system `rpcgen`
/// - Same header guard format
/// - Same XDR function signatures
/// - Interoperable with C RPC libraries
///
/// **Java Output**: Compatible with oncrpc4j and Remote Tea
/// - Implements XdrAble interface
/// - Uses org.dcache.oncrpc4j.xdr packages
/// - Standard Java bean patterns
///
/// See README.md for detailed examples and architecture documentation.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:dart_oncrpc/src/preprocessor/preprocessor.dart';
import 'package:path/path.dart' as p;
import 'package:petitparser/petitparser.dart';

Future<void> main(final List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addFlag('client', abbr: 'c', help: 'Generate client stubs')
    ..addFlag('server', abbr: 's', help: 'Generate server stubs')
    ..addFlag('types', abbr: 't', help: 'Generate type definitions')
    ..addOption('output', abbr: 'o', help: 'Output file (default: stdout)')
    ..addOption(
      'language',
      abbr: 'l',
      defaultsTo: 'dart',
      allowed: ['dart', 'c', 'java'],
      help: 'Target language (dart, c, java)',
    )
    ..addOption('package', abbr: 'p', help: 'Package name (for Java)')
    ..addMultiOption(
      'include-path',
      abbr: 'I',
      help: 'Add directory to include search path',
    )
    ..addMultiOption(
      'define',
      abbr: 'D',
      help: 'Define a macro (format: NAME or NAME=VALUE)',
    )
    ..addFlag(
      'no-preprocess',
      help: 'Skip preprocessing (no include expansion)',
    )
    ..addFlag(
      'save-preprocessed',
      help: 'Save preprocessed output to .pp file',
    )
    ..addFlag(
      'dart-conventions',
      help: 'Convert UPPERCASE names to lowerCamelCase (Dart only)',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool || results.rest.isEmpty) {
      stdout
        ..writeln('Usage: rpcgen [options] <input.x>')
        ..writeln('\nOptions:')
        ..writeln(parser.usage);
      exit(0);
    }

    final input = File(results.rest.first);
    if (!input.existsSync()) {
      stderr.writeln('Error: Input file "${results.rest.first}" not found');
      exit(1);
    }

    String content;

    final hasOutput = results.wasParsed('client') ||
        results.wasParsed('server') ||
        results.wasParsed('types');

    final generateClient = !hasOutput || (results['client'] as bool);
    final generateServer = !hasOutput || (results['server'] as bool);
    final generateTypes = !hasOutput || (results['types'] as bool);

    if (!generateClient && !generateServer && !generateTypes) {
      stderr.writeln(
        'Error: No output selected. Enable --types, --client, or --server.',
      );
      exit(1);
    }

    // Handle preprocessing unless disabled
    if (results['no-preprocess'] as bool? ?? false) {
      content = input.readAsStringSync();
    } else {
      try {
        final paths = results['include-path'] as List<String>? ?? [];
        final substitutions = <String, String>{};
        final definitions = results['define'] as List<String>? ?? [];
        for (final definition in definitions) {
          final parts = definition.split('=');
          final name = parts[0];
          final value = parts.length > 1 ? parts.sublist(1).join('=') : '';
          substitutions[name] = value;
        }

        final preprocessor = Preprocessor(
          paths: paths,
          definitions: substitutions,
        );
        content = preprocessor.preprocess(input.path);
        if (results['save-preprocessed'] as bool? ?? false) {
          final output = '${input.path}.pp';
          File(output).writeAsStringSync(content);
          stdout.writeln('Preprocessed output saved to: $output');
        }
      } catch (e) {
        if (e is PreprocessorError) {
          stderr.writeln('Preprocessor error: $e');
        } else {
          stderr.writeln('Preprocessing failed: $e');
        }
        exit(1);
      }
    }

    final result = RPCParser.parse(content);
    if (result is Failure) {
      stderr
        ..writeln('Parse error: ${result.message}')
        ..writeln('At position: ${result.position}');

      // Show context around the error
      final pos = result.position;
      final start = pos > 50 ? pos - 50 : 0;
      final end = pos + 50 < content.length ? pos + 50 : content.length;

      stderr
        ..writeln('\nContext:')
        ..writeln('Before: "${content.substring(start, pos)}"')
        ..writeln('At error: "${content.substring(pos, end)}"');

      exit(1);
    }

    final specification = result.value;
    final language = results['language'] as String;
    final inputFile = input.path.split('/').last;

    final config = {
      'generateClient': generateClient,
      'generateServer': generateServer,
      'generateTypes': generateTypes,
      'dartConventions': results['dart-conventions'] as bool? ?? false,
      'inputFilename': inputFile,
      if (results['package'] != null) 'package': results['package'],
    };

    // Create appropriate generator based on language
    Generator generator;
    switch (language) {
      case 'c':
        generator = CGenerator(specification, config);
        break;
      case 'java':
        generator = JavaGenerator(specification, config);
        break;
      case 'dart':
      default:
        generator = DartGenerator(specification, config);
        break;
    }

    // Generate code and get artifacts
    final status = generator.generate();
    if (results['output'] != null) {
      final path = results['output'] as String;
      final artifacts = status.artifacts;
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      final treatAsDirectory =
          _shouldTreatAsDirectory(path, artifacts.length, type);

      if (treatAsDirectory && type == FileSystemEntityType.file) {
        stderr.writeln(
          'Error: Output path "$path" is a file but multiple artifacts were generated.',
        );
        exit(1);
      }

      if (treatAsDirectory) {
        final directory = Directory(path)..createSync(recursive: true);
        for (final artifact in artifacts) {
          final filePath = p.join(directory.path, artifact.filename);
          File(filePath).writeAsStringSync(artifact.content);
          stdout.writeln('Generated: $filePath');
        }
      } else {
        if (artifacts.length > 1) {
          stderr.writeln(
            'Error: Output path "$path" must be a directory when multiple artifacts are generated.',
          );
          exit(1);
        }
        final file = File(path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(artifacts.single.content);
        stdout.writeln('Generated: ${file.path}');
      }

      if (status.summary != null) {
        stdout.writeln(status.summary);
      }
    } else {
      for (final artifact in status.artifacts) {
        if (status.artifacts.length > 1) {
          stdout
            ..writeln('// File: ${artifact.filename}')
            ..writeln();
        }
        stdout.write(artifact.content);
        if (status.artifacts.length > 1) {
          stdout.writeln();
        }
      }
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

bool _shouldTreatAsDirectory(
  final String path,
  final int count,
  final FileSystemEntityType type,
) {
  if (type == FileSystemEntityType.directory) {
    return true;
  }

  if (count > 1) {
    return true;
  }

  // Handle paths that clearly denote a directory even if it does not exist yet.
  if (path.endsWith('/') || path.endsWith(r'\')) {
    return true;
  }

  return false;
}
