import 'package:dart_oncrpc/src/generator/code_builder.dart';
import 'package:dart_oncrpc/src/generator/dart_code_generators.dart';
import 'package:dart_oncrpc/src/generator/generator.dart';
import 'package:dart_oncrpc/src/generator/naming_strategy.dart';
import 'package:dart_oncrpc/src/generator/type_mappers.dart';
import 'package:dart_oncrpc/src/generator/type_visitor.dart';
import 'package:dart_oncrpc/src/parser/ast.dart';

/// Dart code generator supporting all ONC-RPC types
class DartGenerator extends Generator {
  DartGenerator(super.specification, super.config) {
    _encoder = EncoderStrategy(registry);
    _decoder = DecoderStrategy(registry);
  }

  final CodeBuilder _typesBuilder = CodeBuilder();
  final CodeBuilder _clientBuilder = CodeBuilder();
  final CodeBuilder _serverBuilder = CodeBuilder();
  late final EncoderStrategy _encoder;
  late final DecoderStrategy _decoder;

  bool get _emitTypes => config['generateTypes'] as bool? ?? true;
  bool get _emitClient => config['generateClient'] as bool? ?? true;
  bool get _emitServer => config['generateServer'] as bool? ?? true;

  @override
  NamingStrategy get naming => DartNamingStrategy(
        useDartConventions: config['dartConventions'] == true,
      );

  @override
  List<GeneratedArtifact> buildArtifacts() {
    final sections = <String>[];

    final typesContent = _typesBuilder.toString().trim();
    if (typesContent.isNotEmpty) {
      sections.add(typesContent);
    }

    final clientContent = _clientBuilder.toString().trim();
    if (clientContent.isNotEmpty) {
      sections.add(clientContent);
    }

    final serverContent = _serverBuilder.toString().trim();
    if (serverContent.isNotEmpty) {
      sections.add(serverContent);
    }

    final combined = sections.join('\n\n').trimRight();
    final finalContent = combined.isEmpty ? '\n' : '$combined\n';

    return [
      GeneratedArtifact(
        filename: '$basename.dart',
        content: finalContent,
        description: 'Dart generated code',
      ),
    ];
  }

  @override
  void onStartSpecification(
    final Map<String, dynamic> config,
    final String name,
  ) {
    if (_emitTypes || _emitClient || _emitServer) {
      _writeImports();
    }
  }

  void _writeImports() {
    _typesBuilder
      ..comment(' Generated ONC-RPC code')
      ..comment(' DO NOT EDIT - Generated from .x file')
      ..comment(
        ' ignore_for_file: constant_identifier_names, non_constant_identifier_names, unreachable_switch_default, cascade_invocations, unused_import, prefer_constructors_over_static_methods, sort_constructors_first, avoid_positional_boolean_parameters, no_leading_underscores_for_local_identifiers',
      )
      ..writeln()
      ..addImport("import 'dart:typed_data';")
      ..addImport("import 'package:dart_oncrpc/src/xdr/xdr_io.dart';")
      ..addImport("import 'package:dart_oncrpc/src/rpc/rpc_client.dart';")
      ..addImport("import 'package:dart_oncrpc/src/rpc/rpc_server.dart';")
      ..addImport(
        "import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';",
      )
      ..writeImports()
      ..comment(' Standard XDR boolean constants')
      ..writeln('const TRUE = 1;')
      ..writeln('const FALSE = 0;')
      ..writeln();
  }

  @override
  void onEndSpecification(
    final Map<String, dynamic> config,
    final String name,
  ) {
    // Generation complete - artifacts will be built by buildArtifacts()
  }

  @override
  void onConstant(
    final Map<String, dynamic> config,
    final Constant<Value> constant,
  ) {
    final name = naming.formatConstant(constant.name);
    final value = constant.value;

    // Handle integer constants - Dart int is 64-bit, same as RPC hyper
    // BigInt would only be needed for values > 2^63-1, which are rare in RPC specs
    _typesBuilder.writeln('const $name = $value;');
  }

  @override
  void onProgram(final Map<String, dynamic> config, final Program program) {
    if (!(_emitTypes || _emitClient || _emitServer)) {
      return;
    }

    _generateProgramConstants(program);
    if (_emitClient) {
      _generateClient(program);
    }
    if (_emitServer) {
      _generateServerInterface(program);
      _generateServerRegistration(program);
    }
  }

  void _generateProgramConstants(final Program program) {
    if (!(_emitTypes || _emitClient || _emitServer)) {
      return;
    }

    _typesBuilder
      ..writeln()
      ..comment(' Program constants')
      ..writeln(
        'const ${naming.formatConstant(program.name)} = ${program.constant};',
      );
    for (final version in program.versions) {
      _typesBuilder.writeln(
        'const ${naming.formatConstant(version.name)} = ${version.constant};',
      );
      for (final proc in version.procedures) {
        _typesBuilder.writeln(
          'const ${naming.formatConstant(proc.name)} = ${proc.constant};',
        );
      }
    }
    _typesBuilder.writeln();
  }

  void _generateClient(final Program program) {
    final className = '${naming.toPascalCase(program.name)}Client';
    _clientBuilder
      ..writeln('\n// Client implementation for ${program.name}')
      ..writeln('class $className {')
      ..writeln('  final RpcClient _client;')
      ..writeln()
      ..writeln('  $className(this._client);')
      ..writeln();

    for (final version in program.versions) {
      _clientBuilder.writeln('  // Version ${version.name}');
      for (final procedure in version.procedures) {
        _generateClientMethod(program, version, procedure);
      }
    }

    _clientBuilder
      ..writeln('}')
      ..writeln();
  }

  void _generateClientMethod(
    final Program program,
    final Version version,
    final Procedure procedure,
  ) {
    final methodName = naming.toCamelCase(procedure.name);
    final returnType = _getFullDartType(procedure.type);
    final params = _generateMethodParams(procedure.arguments);

    _clientBuilder
        .writeln('  Future<$returnType> $methodName($params) async {');

    if (procedure.arguments.isNotEmpty &&
        !inspector.isVoid(procedure.arguments.first)) {
      _clientBuilder.writeln('    final stream = XdrOutputStream();');
      for (var i = 0; i < procedure.arguments.length; i++) {
        _generateFullEncoder(
          _clientBuilder,
          'arg$i',
          procedure.arguments[i],
          '    ',
        );
      }
      _clientBuilder.writeln('    final params = stream.toBytes();');
    } else {
      _clientBuilder.writeln('    final Uint8List? params = null;');
    }

    _clientBuilder
      ..writeln('    final result = await _client.call(')
      ..writeln('      program: ${program.name},')
      ..writeln('      version: ${version.name},')
      ..writeln('      procedure: ${procedure.name},')
      ..writeln('      params: params,')
      ..writeln('    );');

    if (!inspector.isVoid(procedure.type)) {
      _clientBuilder
        ..writeln('    if (result != null) {')
        ..writeln('      final resultStream = XdrInputStream(result);');
      _generateFullDecoder(
        _clientBuilder,
        'return',
        procedure.type,
        '      ',
        null,
        'resultStream',
      );
      _clientBuilder.writeln('    }');
      if (returnType.endsWith('?')) {
        _clientBuilder.writeln('    return null;');
      } else {
        _clientBuilder.writeln(
          '    throw RpcProtocolError("No result received from procedure ${procedure.name}");',
        );
      }
    }

    _clientBuilder
      ..writeln('  }')
      ..writeln();
  }

  void _generateServerInterface(final Program program) {
    final className = '${naming.toPascalCase(program.name)}Server';
    _serverBuilder
      ..writeln('\n// Server interface for ${program.name}')
      ..writeln('abstract class $className {');

    for (final version in program.versions) {
      version.procedures.forEach(_generateServerMethod);
    }

    _serverBuilder
      ..writeln('}')
      ..writeln();
  }

  void _generateServerMethod(final Procedure procedure) {
    final methodName = naming.toCamelCase(procedure.name);
    final returnType = _getFullDartType(procedure.type);
    final params = _generateMethodParams(procedure.arguments);

    _serverBuilder.writeln('  Future<$returnType> $methodName($params);');
  }

  void _generateServerRegistration(final Program program) {
    final className = '${naming.toPascalCase(program.name)}ServerRegistration';
    _serverBuilder
      ..writeln('class $className {')
      ..writeln(
        '  static void register(RpcServer server, ${naming.toPascalCase(program.name)}Server implementation) {',
      )
      ..writeln('    final program = RpcProgram(${program.name});');

    for (final version in program.versions) {
      _serverBuilder.writeln(
        '    final version${version.constant} = RpcVersion(${version.name});',
      );

      for (final procedure in version.procedures) {
        _generateServerHandler(version, procedure);
      }

      _serverBuilder
          .writeln('    program.addVersion(version${version.constant});');
    }

    _serverBuilder
      ..writeln('    server.addProgram(program);')
      ..writeln('  }')
      ..writeln('}')
      ..writeln();
  }

  void _generateServerHandler(
    final Version version,
    final Procedure procedure,
  ) {
    final methodName = naming.toCamelCase(procedure.name);

    _serverBuilder.writeln(
      '    version${version.constant}.addProcedure(${procedure.name}, (params, auth) async {',
    );

    if (procedure.arguments.isNotEmpty &&
        !inspector.isVoid(procedure.arguments.first)) {
      for (var i = 0; i < procedure.arguments.length; i++) {
        _generateFullDecoder(
          _serverBuilder,
          'final arg$i',
          procedure.arguments[i],
          '      ',
          null,
          'params',
        );
      }

      final args =
          List.generate(procedure.arguments.length, (final i) => 'arg$i')
              .join(', ');
      _serverBuilder.writeln(
        '      final result = await implementation.$methodName($args);',
      );
    } else {
      _serverBuilder
          .writeln('      final result = await implementation.$methodName();');
    }

    if (!inspector.isVoid(procedure.type)) {
      _serverBuilder.writeln('      final resultStream = XdrOutputStream();');
      _generateFullEncoder(
        _serverBuilder,
        'result',
        procedure.type,
        '      ',
        null,
        'resultStream',
      );
      _serverBuilder.writeln('      return resultStream.toBytes();');
    } else {
      _serverBuilder.writeln('      return null;');
    }

    _serverBuilder.writeln('    });');
  }

  @override
  void onTypeDefinition(
    final Map<String, dynamic> config,
    final TypeDefinition definition,
  ) {
    if (!_emitTypes) {
      return;
    }

    if (registry.isDefined(definition.name)) {
      return;
    }
    registry.markDefined(definition.name);

    if (definition is EnumTypeDefinition) {
      _generateEnum(definition);
    } else if (definition is StructTypeDefinition) {
      _generateStruct(definition);
    } else if (definition is UnionTypeDefinition) {
      _generateUnion(definition);
    } else if (definition is PointerTypeDefinition) {
      // Optional types are handled inline
      return;
    } else {
      _generateTypedef(definition);
    }
  }

  void _generateEnum(final EnumTypeDefinition definition) {
    final enumSpec = definition.type as EnumTypeSpecifier;
    final className = definition.name;

    // Generate enum type
    _typesBuilder
      ..writeln()
      ..comment(' Enum: $className')
      ..writeln('enum $className {');
    for (final value in enumSpec.values) {
      _typesBuilder.writeln(
        '  ${naming.sanitize(value.name.toLowerCase())}(${value.value}),',
      );
    }
    _typesBuilder
      ..writeln('  ;')
      ..writeln()
      ..writeln('  final int value;')
      ..writeln('  const $className(this.value);')
      ..writeln()
      ..comment('   Create from XDR integer value')
      ..writeln(
        '  factory $className.fromValue(final int value) => switch (value) {',
      );
    for (final value in enumSpec.values) {
      _typesBuilder.writeln(
        '      ${value.value} => ${naming.sanitize(value.name.toLowerCase())},',
      );
    }
    _typesBuilder
      ..writeln(
        "      _ => throw ArgumentError('Unknown $className value: \$value'),",
      )
      ..writeln('    };')
      ..writeln()
      ..comment('   Get all possible values')
      ..writeln('  static List<$className> get allValues => values;')
      ..writeln()
      ..comment('   Check if value is valid')
      ..writeln('  static bool isValid(final int value) => switch (value) {');
    for (final value in enumSpec.values) {
      _typesBuilder.writeln('      ${value.value} => true,');
    }
    _typesBuilder
      ..writeln('      _ => false,')
      ..writeln('    };')
      ..writeln('}')
      ..writeln();
  }

  void _generateStruct(final StructTypeDefinition definition) {
    final structSpec = definition.type as StructTypeSpecifier;
    final className = definition.name;

    _typesBuilder
      ..writeln('\n// Struct: $className')
      ..writeln('class $className {');

    // Generate fields
    for (final field in structSpec.fields) {
      final fieldType = _getFullDartType(
        field.type,
        field.dimensions,
        field is PointerTypeDefinition,
      );
      final fieldName = naming.sanitize(field.name);
      _typesBuilder.writeln('  final $fieldType $fieldName;');
    }

    // Generate constructor
    _typesBuilder
      ..writeln()
      ..writeln('  $className({');
    for (final field in structSpec.fields) {
      final fieldName = naming.sanitize(field.name);
      final isOptional = field is PointerTypeDefinition;
      if (isOptional) {
        _typesBuilder.writeln('    this.$fieldName,');
      } else {
        _typesBuilder.writeln('    required this.$fieldName,');
      }
    }
    _typesBuilder
      ..writeln('  });')
      ..writeln()
      ..writeln('  void encode(XdrOutputStream stream) {');
    for (final field in structSpec.fields) {
      final fieldName = naming.sanitize(field.name);
      if (field is PointerTypeDefinition) {
        _generateOptionalEncoder(
          _typesBuilder,
          fieldName,
          field.type,
          '    ',
          field.dimensions.isNotEmpty ? field.dimensions.first : null,
        );
      } else {
        _generateMultiDimEncoder(
          _typesBuilder,
          fieldName,
          field.type,
          '    ',
          field.dimensions,
        );
      }
    }
    _typesBuilder
      ..writeln('  }')
      ..writeln()
      ..writeln('  static $className decode(XdrInputStream stream) {');
    for (final field in structSpec.fields) {
      final fieldName = naming.sanitize(field.name);
      if (field is PointerTypeDefinition) {
        _generateOptionalDecoder(
          _typesBuilder,
          fieldName, // Just the name for optional fields
          field.type,
          '    ',
          field.dimensions.isNotEmpty ? field.dimensions.first : null,
        );
      } else {
        _generateMultiDimDecoder(
          _typesBuilder,
          'final $fieldName',
          field.type,
          '    ',
          field.dimensions,
        );
      }
    }
    _typesBuilder.writeln('    return $className (');
    for (final field in structSpec.fields) {
      final fieldName = naming.sanitize(field.name);
      _typesBuilder.writeln('      $fieldName: $fieldName,');
    }
    _typesBuilder
      ..writeln('    );')
      ..writeln('  }')
      ..writeln('}')
      ..writeln();
  }

  void _generateUnion(final UnionTypeDefinition definition) {
    final unionSpec = definition.type as UnionTypeSpecifier;
    final className = definition.name;
    final discriminantType = _getFullDartType(unionSpec.variable.type);

    _typesBuilder
      ..writeln('\n// Union: $className')
      ..writeln('abstract class $className {')
      ..writeln('  final $discriminantType discriminant;')
      ..writeln('  $className(this.discriminant);')
      ..writeln()
      ..writeln('  void encode(XdrOutputStream stream) {');

    // Generate discriminant encoding based on type
    _generateFullEncoder(
      _typesBuilder,
      'discriminant',
      unionSpec.variable.type,
      '    ',
    );

    _typesBuilder
      ..writeln('    encodeArm(stream);')
      ..writeln('  }')
      ..writeln()
      ..writeln('  void encodeArm(XdrOutputStream stream);')
      ..writeln()
      ..writeln('  static $className decode(XdrInputStream stream) {');

    // Generate discriminant decoding
    _generateFullDecoder(
      _typesBuilder,
      'final discriminant',
      unionSpec.variable.type,
      '    ',
    );

    _typesBuilder.writeln('    switch (discriminant) {');

    for (final caseSpec in unionSpec.arms) {
      for (final label in caseSpec.labels) {
        final caseLabel = _formatCaseLabel(label, unionSpec.variable.type);
        _typesBuilder.writeln('      case $caseLabel:');
      }
      final caseClassName =
          '$className${naming.toPascalCase((caseSpec.labels.first.asInt ?? caseSpec.labels.first.asReference).toString())}';
      if (!inspector.isVoid(caseSpec.type.type)) {
        _generateFullDecoder(
          _typesBuilder,
          'final value',
          caseSpec.type.type,
          '        ',
          caseSpec.type.dimensions.isNotEmpty
              ? caseSpec.type.dimensions.first
              : null,
        );
        _typesBuilder.writeln('        return $caseClassName(value);');
      } else {
        _typesBuilder.writeln('        return $caseClassName();');
      }
    }

    if (unionSpec.otherwise != null) {
      _typesBuilder.writeln('      default:');
      final defaultClassName = '${className}Default';
      if (!inspector.isVoid(unionSpec.otherwise!.type)) {
        _generateFullDecoder(
          _typesBuilder,
          'final value',
          unionSpec.otherwise!.type,
          '        ',
          unionSpec.otherwise!.dimensions.isNotEmpty
              ? unionSpec.otherwise!.dimensions.first
              : null,
        );
        _typesBuilder
            .writeln('        return $defaultClassName(discriminant, value);');
      } else {
        _typesBuilder
            .writeln('        return $defaultClassName(discriminant);');
      }
    } else {
      _typesBuilder
        ..writeln('      default:')
        ..writeln(
          r"        throw ArgumentError('Unknown discriminant: $discriminant');",
        );
    }

    _typesBuilder
      ..writeln('    }')
      ..writeln('  }')
      ..writeln('}')
      ..writeln();

    // Generate case classes
    for (final caseSpec in unionSpec.arms) {
      final caseClassName =
          '$className${naming.toPascalCase((caseSpec.labels.first.asInt ?? caseSpec.labels.first.asReference).toString())}';
      final discriminantValue =
          _formatCaseLabel(caseSpec.labels.first, unionSpec.variable.type);

      if (!inspector.isVoid(caseSpec.type.type)) {
        final valueType =
            _getFullDartType(caseSpec.type.type, caseSpec.type.dimensions);

        _typesBuilder
          ..writeln('class $caseClassName extends $className {')
          ..writeln('  final $valueType value;')
          ..writeln(
            '  $caseClassName(this.value) : super($discriminantValue);',
          )
          ..writeln('  ')
          ..writeln('  @override')
          ..writeln('  void encodeArm(XdrOutputStream stream) {');
        _generateFullEncoder(
          _typesBuilder,
          'value',
          caseSpec.type.type,
          '    ',
          caseSpec.type.dimensions.isNotEmpty
              ? caseSpec.type.dimensions.first
              : null,
        );
        _typesBuilder
          ..writeln('  }')
          ..writeln('}');
      } else {
        _typesBuilder
          ..writeln('class $caseClassName extends $className {')
          ..writeln(
            '  $caseClassName() : super($discriminantValue);',
          )
          ..writeln('  ')
          ..writeln('  @override')
          ..writeln('  void encodeArm(XdrOutputStream stream) {}')
          ..writeln('}');
      }
      _typesBuilder.writeln();
    }

    if (unionSpec.otherwise != null) {
      final defaultClassName = '${className}Default';

      if (!inspector.isVoid(unionSpec.otherwise!.type)) {
        final valueType = _getFullDartType(
          unionSpec.otherwise!.type,
          unionSpec.otherwise!.dimensions,
        );

        _typesBuilder
          ..writeln('class $defaultClassName extends $className {')
          ..writeln('  final $valueType value;')
          ..writeln(
            '  $defaultClassName(super.discriminant, this.value);',
          )
          ..writeln('  ')
          ..writeln('  @override')
          ..writeln('  void encodeArm(XdrOutputStream stream) {');
        _generateFullEncoder(
          _typesBuilder,
          'value',
          unionSpec.otherwise!.type,
          '    ',
          unionSpec.otherwise!.dimensions.isNotEmpty
              ? unionSpec.otherwise!.dimensions.first
              : null,
        );
        _typesBuilder
          ..writeln('  }')
          ..writeln('}');
      } else {
        _typesBuilder
          ..writeln('class $defaultClassName extends $className {')
          ..writeln(
            '  $defaultClassName(super.discriminant);',
          )
          ..writeln('  ')
          ..writeln('  @override')
          ..writeln('  void encodeArm(XdrOutputStream stream) {}')
          ..writeln('}');
      }
      _typesBuilder.writeln();
    }
  }

  void _generateTypedef(final TypeDefinition definition) {
    // For simple typedefs, create a type alias
    final dartType = _getFullDartType(definition.type, definition.dimensions);
    _typesBuilder
      ..writeln('\n// Typedef: ${definition.name}')
      ..writeln('typedef ${definition.name} = $dartType;')
      ..writeln();
  }

  /// Converts an XDR type specifier to its Dart type representation.
  ///
  /// Handles arrays, optionals, and special cases like strings and opaque data.
  /// - [type]: The XDR type to convert
  /// - [dimensions]: ArraySpecifier or List&lt;ArraySpecifier&gt; for array types
  /// - [isOptional]: Whether the type is nullable (adds '?' suffix)
  ///
  /// Examples:
  /// - `int` → `int`
  /// - `int&lt;&gt;` → `List&lt;int&gt;`
  /// - `string&lt;&gt;` → `String` (string handles its own max length)
  /// - `int*` (optional) → `int?`
  String _getFullDartType(
    final TypeSpecifier type, [
    final dynamic dimensions,
    final bool isOptional = false,
  ]) {
    // Use visitor pattern for type mapping
    String baseType = type.accept(const DartTypeMapper());

    // Handle arrays - support both single ArraySpecifier and List<ArraySpecifier>
    if (dimensions != null) {
      if (dimensions is ArraySpecifier) {
        // Don't wrap strings or opaque in List - they handle their own sizing
        if (!inspector.isString(type) && !inspector.isOpaque(type)) {
          baseType = 'List<$baseType>';
        }
      } else if (dimensions is List<ArraySpecifier>) {
        if (inspector.isString(type) && dimensions.length == 1) {
          // Single dimension on string = max length, not array
        } else if (inspector.isOpaque(type) && dimensions.length == 1) {
          // Single dimension on opaque = fixed-size array, stay as Uint8List
        } else {
          for (int i = dimensions.length - 1; i >= 0; i--) {
            baseType = 'List<$baseType>';
          }
        }
      }
    }

    // Handle optionals
    if (isOptional && baseType != 'void') {
      baseType = '$baseType?';
    }

    return baseType;
  }

  /// Generates Dart method parameter list from XDR argument types.
  ///
  /// Returns empty string for void or no parameters.
  /// Otherwise returns comma-separated "Type argN" format.
  ///
  /// Example: `[int, string]` → `"int arg0, String arg1"`
  String _generateMethodParams(final List<TypeSpecifier> arguments) {
    if (arguments.isEmpty || inspector.isVoid(arguments.first)) {
      return '';
    }

    final params = <String>[];
    for (var i = 0; i < arguments.length; i++) {
      params.add('${_getFullDartType(arguments[i])} arg$i');
    }
    return params.join(', ');
  }

  void _generateMultiDimEncoder(
    final CodeBuilder buffer,
    final String varName,
    final TypeSpecifier type,
    final String indent,
    final List<ArraySpecifier> dimensions, [
    final String streamVar = 'stream',
  ]) {
    if (dimensions.isEmpty) {
      _generateFullEncoder(buffer, varName, type, indent, null, streamVar);
    } else if (dimensions.length == 1) {
      _generateFullEncoder(
        buffer,
        varName,
        type,
        indent,
        dimensions.first,
        streamVar,
      );
    } else {
      _generateNestedArrayEncoder(
        buffer,
        varName,
        type,
        indent,
        dimensions,
        0,
        streamVar,
      );
    }
  }

  void _generateMultiDimDecoder(
    final CodeBuilder buffer,
    final String varDecl,
    final TypeSpecifier type,
    final String indent,
    final List<ArraySpecifier> dimensions, [
    final String streamVar = 'stream',
  ]) {
    if (dimensions.isEmpty) {
      _generateFullDecoder(buffer, varDecl, type, indent, null, streamVar);
    } else if (dimensions.length == 1) {
      _generateFullDecoder(
        buffer,
        varDecl,
        type,
        indent,
        dimensions.first,
        streamVar,
      );
    } else {
      _generateNestedArrayDecoder(
        buffer,
        varDecl,
        type,
        indent,
        dimensions,
        0,
        streamVar,
      );
    }
  }

  void _generateNestedArrayEncoder(
    final CodeBuilder buffer,
    final String varName,
    final TypeSpecifier type,
    final String indent,
    final List<ArraySpecifier> dimensions,
    final int level, [
    final String streamVar = 'stream',
  ]) {
    if (level >= dimensions.length) {
      _generateFullEncoder(buffer, varName, type, indent, null, streamVar);
      return;
    }

    final dim = dimensions[level];
    final sizeInt = dim.size.asInt;
    final sizeValue = sizeInt ?? dim.size.asReference ?? 0;
    final itemVar = level == 0 ? varName : 'item$level';
    final nextItemVar = 'item${level + 1}';

    if (dim.isFixedLength) {
      if (level == 0) {
        buffer
          ..writeln('$indent'
              '// Fixed array dimension ${level + 1} of ${dimensions.length}: $sizeValue elements')
          ..writeln('$indent' 'if ($itemVar.length != $sizeValue) {')
          ..writeln('$indent'
              "  throw ArgumentError('Fixed array dimension ${level + 1} must have exactly $sizeValue elements');")
          ..writeln('$indent' '}');
      }
      buffer.writeln('$indent' 'for (final $nextItemVar in $itemVar) {');
      _generateNestedArrayEncoder(
        buffer,
        nextItemVar,
        type,
        '$indent  ',
        dimensions,
        level + 1,
        streamVar,
      );
      buffer.writeln('$indent' '}');
    } else {
      if (level == 0) {
        buffer.writeln('$indent'
            '// Variable array dimension ${level + 1} of ${dimensions.length}');
        if (sizeInt != null && sizeInt > 0) {
          buffer
            ..writeln('$indent' 'if ($itemVar.length > $sizeValue) {')
            ..writeln('$indent'
                "  throw ArgumentError('Array dimension ${level + 1} exceeds maximum length of $sizeValue');")
            ..writeln('$indent' '}');
        }
      }
      buffer
        ..writeln('$indent' '$streamVar.writeInt($itemVar.length);')
        ..writeln('$indent' 'for (final $nextItemVar in $itemVar) {');
      _generateNestedArrayEncoder(
        buffer,
        nextItemVar,
        type,
        '$indent  ',
        dimensions,
        level + 1,
        streamVar,
      );
      buffer.writeln('$indent' '}');
    }
  }

  void _generateNestedArrayDecoder(
    final CodeBuilder buffer,
    final String varDecl,
    final TypeSpecifier type,
    final String indent,
    final List<ArraySpecifier> dimensions,
    final int level, [
    final String streamVar = 'stream',
  ]) {
    if (level >= dimensions.length) {
      _generateFullDecoder(buffer, '$varDecl =', type, indent, null, streamVar);
      return;
    }

    final dim = dimensions[level];
    final sizeInt = dim.size.asInt;
    final sizeValue = sizeInt ?? dim.size.asReference ?? 0;

    String levelType = _getFullDartType(type);
    for (var i = dimensions.length - 1; i > level; i--) {
      levelType = 'List<$levelType>';
    }

    final tempVar =
        '_array${level}_${varDecl.replaceAll(RegExp('[^a-zA-Z0-9]'), '')}';

    if (dim.isFixedLength) {
      buffer
        ..writeln('$indent'
            '// Fixed array dimension ${level + 1} of ${dimensions.length}: $sizeValue elements')
        ..writeln('$indent' 'final $tempVar = <$levelType>[];')
        ..writeln(
          '$indent' 'for (int i$level = 0; i$level < $sizeValue; i$level++) {',
        );
      _generateNestedArrayDecoder(
        buffer,
        'final item${level + 1}',
        type,
        '$indent  ',
        dimensions,
        level + 1,
        streamVar,
      );
      buffer
        ..writeln('$indent' '  $tempVar.add(item${level + 1});')
        ..writeln('$indent' '}')
        ..writeln('$indent' '$varDecl = $tempVar;');
    } else {
      buffer
        ..writeln('$indent'
            '// Variable array dimension ${level + 1} of ${dimensions.length}')
        ..writeln('$indent' 'final ${tempVar}Length = $streamVar.readInt();');
      if (sizeInt != null && sizeInt > 0) {
        buffer
          ..writeln('$indent' 'if (${tempVar}Length > $sizeValue) {')
          ..writeln('$indent'
              "  throw ArgumentError('Array dimension ${level + 1} length exceeds maximum of $sizeValue');")
          ..writeln('$indent' '}');
      }
      buffer
        ..writeln('$indent' 'final $tempVar = <$levelType>[];')
        ..writeln('$indent'
            'for (int i$level = 0; i$level < ${tempVar}Length; i$level++) {');
      _generateNestedArrayDecoder(
        buffer,
        'final item${level + 1}',
        type,
        '$indent  ',
        dimensions,
        level + 1,
        streamVar,
      );
      buffer
        ..writeln('$indent' '  $tempVar.add(item${level + 1});')
        ..writeln('$indent' '}')
        ..writeln('$indent' '$varDecl = $tempVar;');
    }
  }

  void _generateFullEncoder(
    final CodeBuilder buffer,
    final String varName,
    final TypeSpecifier type,
    final String indent, [
    final ArraySpecifier? length,
    final String streamVar = 'stream',
  ]) {
    buffer.write(_encoder.generate(varName, type, indent, length, streamVar));
  }

  void _generateFullDecoder(
    final CodeBuilder buffer,
    final String varDecl,
    final TypeSpecifier type,
    final String indent, [
    final ArraySpecifier? length,
    final String streamVar = 'stream',
  ]) {
    buffer.write(_decoder.generate(varDecl, type, indent, length, streamVar));
  }

  void _generateOptionalEncoder(
    final CodeBuilder buffer,
    final String varName,
    final TypeSpecifier type,
    final String indent, [
    final ArraySpecifier? length,
    final String streamVar = 'stream',
  ]) {
    buffer
      ..writeln('$indent' 'if ($varName != null) {')
      ..writeln('$indent' '  $streamVar.writeInt(1); // Present');
    // Use null assertion since we know it's not null inside the if block
    _generateFullEncoder(
      buffer,
      '$varName!',
      type,
      '$indent  ',
      length,
      streamVar,
    );
    buffer
      ..writeln('$indent' '} else {')
      ..writeln('$indent' '  $streamVar.writeInt(0); // Not present')
      ..writeln('$indent' '}');
  }

  void _generateOptionalDecoder(
    final CodeBuilder buffer,
    final String varDecl,
    final TypeSpecifier type,
    final String indent, [
    final ArraySpecifier? length,
    final String streamVar = 'stream',
  ]) {
    buffer.writeln('$indent' 'final ${varDecl}Present = $streamVar.readInt();');
    final dartType = _getFullDartType(type, length);
    buffer
      ..writeln('$indent' '$dartType? $varDecl;')
      ..writeln('$indent' 'if (${varDecl}Present != 0) {');
    _generateFullDecoder(
      buffer,
      '$varDecl =',
      type,
      '$indent  ',
      length,
      streamVar,
    );
    buffer.writeln('$indent' '}');
  }

  /// Formats a union case label for Dart switch statement.
  ///
  /// Converts XDR discriminant values to appropriate Dart representations:
  /// - Boolean: `TRUE`/`1` → `true`, `FALSE`/`0` → `false`
  /// - Enum: Uses qualified enum value (e.g., `MyEnum.value`)
  /// - Integer: Uses literal value
  String _formatCaseLabel(
    final Value label,
    final TypeSpecifier discriminantType,
  ) {
    final labelStr = label.asReference ?? label.asInt.toString();

    // For boolean discriminants, use true/false
    if (discriminantType is BooleanTypeSpecifier) {
      if (labelStr == 'TRUE' || labelStr == '1') return 'true';
      if (labelStr == 'FALSE' || labelStr == '0') return 'false';
      return labelStr;
    }

    // For enum discriminants, use EnumType.enumValue
    if (discriminantType is UserDefinedTypeSpecifier) {
      final typeDef = registry.lookup(discriminantType.name);
      if (typeDef is EnumTypeDefinition) {
        // Find the enum value that matches this label
        final enumSpec = typeDef.type as EnumTypeSpecifier;
        for (final enumValue in enumSpec.values) {
          if (enumValue.name == labelStr ||
              enumValue.value.toString() == labelStr) {
            return '${discriminantType.name}.${naming.sanitize(enumValue.name.toLowerCase())}';
          }
        }
      }
    }

    // For int or other types, return as-is
    return labelStr;
  }
}
