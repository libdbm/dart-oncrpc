import 'dart:io';

import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:path/path.dart' as path;

import 'array_handler.dart';
import 'naming_strategy.dart';
import 'type_inspector.dart';
import 'type_registry.dart';

/// Represents a generated code artifact (file)
class GeneratedArtifact {
  const GeneratedArtifact({
    required this.filename,
    required this.content,
    this.description,
  });

  /// The filename (without directory path)
  final String filename;

  /// The generated content
  final String content;

  /// Optional description of this artifact
  final String? description;
}

/// Result of code generation
class GenerationResult {
  const GenerationResult({
    required this.artifacts,
    this.summary,
  });

  /// List of generated artifacts
  final List<GeneratedArtifact> artifacts;

  /// Optional summary message
  final String? summary;
}

/// Base class for code generators that convert .x specifications to source code.
///
/// [Generator] provides a framework for generating code from parsed RPC/XDR
/// specifications. It implements the visitor pattern to traverse the AST and
/// emit code in different target languages.
///
/// ## Available Generators
///
/// - [DartGenerator]: Generates Dart client/server code
/// - [CGenerator]: Generates C code compatible with standard rpcgen
/// - [JavaGenerator]: Generates Java code compatible with oncrpc4j
///
/// ## Usage
///
/// ```dart
/// // Parse .x specification
/// final parser = RpcParser();
/// final spec = parser.parse(xdrSource);
///
/// // Generate Dart code
/// final generator = DartGenerator(
///   spec,
///   {
///     'outputDir': 'lib/generated',
///     'inputFilename': 'protocol.x',
///   },
/// );
///
/// final result = generator.generate();
/// print(result.summary); // "Generated 2 files: protocol.dart, protocol_client.dart"
/// ```
///
/// ## Implementing Custom Generators
///
/// ```dart
/// class MyGenerator extends Generator {
///   MyGenerator(Specification spec, Map<String, dynamic> config)
///       : super(spec, config);
///
///   @override
///   void onConstant(Map<String, dynamic> config, Constant<Value> constant) {
///     // Emit constant definition in your target language
///   }
///
///   @override
///   void onTypeDefinition(Map<String, dynamic> config, Definition typedef) {
///     // Emit type definition in your target language
///   }
///
///   @override
///   List<GeneratedArtifact> buildArtifacts() {
///     // Return list of generated files
///     return [GeneratedArtifact(...)];
///   }
///
///   // Implement other abstract methods...
/// }
/// ```
abstract class Generator {
  /// Creates a generator with the parsed specification and configuration.
  ///
  /// Parameters:
  /// - [specification]: The parsed .x specification
  /// - [config]: Configuration options (outputDir, inputFilename, etc.)
  Generator(this.specification, this.config) {
    registry.registerAll(specification.types);
  }

  /// Configuration options for code generation.
  final Map<String, dynamic> config;

  /// The parsed RPC/XDR specification to generate code from.
  final Specification specification;

  /// Shared utilities available to all generators
  final TypeRegistry registry = TypeRegistry();
  final TypeInspector inspector = const TypeInspector();
  late final ArrayDimensionHandler arrays = ArrayDimensionHandler(inspector);

  /// Naming strategy (override in subclass)
  NamingStrategy get naming;

  /// Generate code and optionally write to files
  /// Returns list of generated artifacts and metadata
  GenerationResult generate() {
    onStartSpecification(config, inputFilename);

    for (final e in specification.constants) {
      onConstant(config, e);
    }
    for (final e in specification.types) {
      onTypeDefinition(config, e);
    }
    for (final e in specification.programs) {
      onProgram(config, e);
    }

    onEndSpecification(config, inputFilename);

    final artifacts = buildArtifacts();

    // Write files if output directory is configured
    if (config['outputDir'] != null) {
      writeArtifacts(artifacts);
    }

    return GenerationResult(
      artifacts: artifacts,
      summary: buildSummary(artifacts),
    );
  }

  /// Build the list of artifacts to be generated
  List<GeneratedArtifact> buildArtifacts();

  /// Write artifacts to the output directory
  void writeArtifacts(final List<GeneratedArtifact> artifacts) {
    final outputDir = config['outputDir'] as String;
    final directory = Directory(outputDir);

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    for (final artifact in artifacts) {
      File(path.join(outputDir, artifact.filename))
          .writeAsStringSync(artifact.content);
    }
  }

  /// Build a summary message describing what was generated
  String buildSummary(final List<GeneratedArtifact> artifacts) {
    final count = artifacts.length;
    final files = artifacts.map((final a) => a.filename).join(', ');
    return 'Generated $count file(s): $files';
  }

  /// Get the input filename from config
  String get inputFilename => config['inputFilename'] as String? ?? 'spec';

  /// Get base name without extension for generating output filenames
  String get basename {
    final name = inputFilename;
    final index = name.lastIndexOf('.');
    return index > 0 ? name.substring(0, index) : name;
  }

  void onStartSpecification(
    final Map<String, dynamic> config,
    final String name,
  );

  void onEndSpecification(
    final Map<String, dynamic> config,
    final String name,
  );

  void onConstant(
    final Map<String, dynamic> config,
    final Constant<Value> constant,
  );

  void onTypeDefinition(
    final Map<String, dynamic> config,
    final TypeDefinition definition,
  );

  void onProgram(
    final Map<String, dynamic> config,
    final Program program,
  );
}
