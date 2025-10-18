import '../parser/ast.dart';
import 'generator.dart';
import 'naming_strategy.dart';
import 'type_mappers.dart';
import 'type_visitor.dart';

/// Minimum value for formatting integers as hexadecimal in generated code.
/// Values >= 0x10000000 (268,435,456) are formatted as hex for readability,
/// as they typically represent RPC program numbers, which by convention use
/// the ranges 0x20000000-0x3fffffff (transient) or 0x00000000-0x1fffffff (registered).
const int _hexFormatThreshold = 0x10000000;

/// Java code generator for ONC-RPC specifications
///
/// Generates Java code using OncRpc4J library conventions
class JavaGenerator extends Generator {
  JavaGenerator(super.specification, super.config);

  final StringBuffer _buffer = StringBuffer();
  final List<GeneratedArtifact> _artifacts = [];
  String _packageName = 'org.example.rpc';
  String _currentClassName = '';
  StringBuffer _currentClassBuffer = StringBuffer();

  @override
  NamingStrategy get naming => const JavaNamingStrategy();

  @override
  List<GeneratedArtifact> buildArtifacts() => _artifacts;

  @override
  void onStartSpecification(
    final Map<String, dynamic> config,
    final String name,
  ) {
    if (config.containsKey('javaPackage')) {
      _packageName = config['javaPackage'] as String;
    } else if (config.containsKey('package')) {
      _packageName = config['package'] as String;
    }
  }

  @override
  void onEndSpecification(
    final Map<String, dynamic> config,
    final String name,
  ) {
    // Save the last class if any
    if (_currentClassName.isNotEmpty) {
      _artifacts.add(
        GeneratedArtifact(
          filename: '$_currentClassName.java',
          content: _currentClassBuffer.toString(),
          description: 'Java class $_currentClassName',
        ),
      );
      _currentClassName = '';
      _currentClassBuffer = StringBuffer();
    }

    // Save constants file if we have any constants
    if (_buffer.isNotEmpty) {
      _buffer.writeln('}'); // Close Constants interface
      _artifacts.add(
        GeneratedArtifact(
          filename: 'Constants.java',
          content: _buffer.toString(),
          description: 'Java constants interface',
        ),
      );
    }
  }

  @override
  void onConstant(
    final Map<String, dynamic> config,
    final Constant<Value> constant,
  ) {
    // Generate package declaration and Constants class if this is the first content
    if (_buffer.isEmpty) {
      _buffer
        ..writeln('package $_packageName;')
        ..writeln()
        ..writeln('/**')
        ..writeln(' * Constants defined in the RPC specification.')
        ..writeln(' */')
        ..writeln('public interface Constants {');
    }

    // Format the value
    final value = constant.value;
    final intValue = value.asInt;
    final String formattedValue;
    if (intValue != null && intValue >= _hexFormatThreshold) {
      formattedValue = '0x${intValue.toRadixString(16).toUpperCase()}';
    } else if (value.asReference != null) {
      formattedValue = value.asReference!;
    } else {
      formattedValue = value.toString();
    }

    _buffer.writeln(
      '    public static final int ${constant.name} = $formattedValue;',
    );
  }

  @override
  void onTypeDefinition(
    final Map<String, dynamic> config,
    final TypeDefinition definition,
  ) {
    // Start a new file for each type
    _startNewClass(definition.name);

    if (definition is EnumTypeDefinition) {
      _generateEnum(definition);
    } else if (definition is StructTypeDefinition) {
      _generateStruct(definition);
    } else if (definition is UnionTypeDefinition) {
      _generateUnion(definition);
    } else {
      _generateTypedef(definition);
    }
  }

  void _startNewClass(final String className) {
    // Save previous class if any
    if (_currentClassName.isNotEmpty) {
      _artifacts.add(
        GeneratedArtifact(
          filename: '$_currentClassName.java',
          content: _currentClassBuffer.toString(),
          description: 'Java class $_currentClassName',
        ),
      );
    }

    // Start new class
    _currentClassName = className;
    _currentClassBuffer = StringBuffer();

    _currentClassBuffer
      ..writeln('package $_packageName;')
      ..writeln()
      ..writeln('import org.dcache.oncrpc4j.rpc.*;')
      ..writeln('import org.dcache.oncrpc4j.xdr.*;')
      ..writeln('import java.io.IOException;')
      ..writeln('import java.nio.charset.StandardCharsets;')
      ..writeln('import java.util.*;')
      ..writeln();
  }

  void _generateEnum(final EnumTypeDefinition enumDef) {
    final enumType = enumDef.type as EnumTypeSpecifier;

    _currentClassBuffer
        .writeln('public enum ${enumDef.name} implements XdrAble {');

    // Generate enum constants
    for (var i = 0; i < enumType.values.length; i++) {
      final member = enumType.values[i];
      final comma = i < enumType.values.length - 1 ? ',' : ';';
      _currentClassBuffer.writeln('    ${member.name}(${member.value})$comma');
    }

    _currentClassBuffer
      ..writeln()
      ..writeln('    private final int value;')
      ..writeln()
      ..writeln('    ${enumDef.name}(int value) {')
      ..writeln('        this.value = value;')
      ..writeln('    }')
      ..writeln()
      ..writeln('    public int getValue() {')
      ..writeln('        return value;')
      ..writeln('    }')
      ..writeln()
      ..writeln('    public static ${enumDef.name} valueOf(int value) {')
      ..writeln('        for (${enumDef.name} e : values()) {')
      ..writeln('            if (e.value == value) return e;')
      ..writeln('        }')
      ..writeln(
        '        throw new IllegalArgumentException("Invalid ${enumDef.name} value: " + value);',
      )
      ..writeln('    }')
      ..writeln();

    // Generate XDR methods
    _generateXdrMethods(enumDef.name, 'enum');

    _currentClassBuffer.writeln('}');
  }

  void _generateStruct(final StructTypeDefinition structDef) {
    final structType = structDef.type as StructTypeSpecifier;

    _currentClassBuffer
        .writeln('public class ${structDef.name} implements XdrAble {');

    // Generate fields
    for (final field in structType.fields) {
      _currentClassBuffer.writeln(
        '    private ${_getJavaType(field.type, field.dimensions)} ${field.name};',
      );
    }

    _currentClassBuffer
      ..writeln()
      ..writeln('    public ${structDef.name}() {')
      ..writeln('    }')
      ..writeln();

    // Generate parameterized constructor
    if (structType.fields.isNotEmpty) {
      _currentClassBuffer.write('    public ${structDef.name}(');
      for (var i = 0; i < structType.fields.length; i++) {
        final field = structType.fields[i];
        if (i > 0) _currentClassBuffer.write(', ');
        _currentClassBuffer.write(
          '${_getJavaType(field.type, field.dimensions)} ${field.name}',
        );
      }
      _currentClassBuffer.writeln(') {');
      for (final field in structType.fields) {
        _currentClassBuffer
            .writeln('        this.${field.name} = ${field.name};');
      }
      _currentClassBuffer
        ..writeln('    }')
        ..writeln();
    }

    // Generate getters and setters
    for (final field in structType.fields) {
      final javaType = _getJavaType(field.type, field.dimensions);
      final capitalizedName = _capitalize(field.name);

      // Getter and Setter
      _currentClassBuffer
        ..writeln('    public $javaType get$capitalizedName() {')
        ..writeln('        return ${field.name};')
        ..writeln('    }')
        ..writeln()
        ..writeln(
          '    public void set$capitalizedName($javaType ${field.name}) {',
        )
        ..writeln('        this.${field.name} = ${field.name};')
        ..writeln('    }')
        ..writeln();
    }

    // Generate XDR methods
    _generateXdrMethods(structDef.name, 'struct', structType);

    _currentClassBuffer.writeln('}');
  }

  void _generateUnion(final UnionTypeDefinition unionDef) {
    final unionType = unionDef.type as UnionTypeSpecifier;

    // Generate getters/setters for discriminant
    final discriminantType = _getJavaType(unionType.variable.type, []);

    _currentClassBuffer
      ..writeln('public class ${unionDef.name} implements XdrAble {')
      ..writeln()
      ..writeln(
        '    private ${_getJavaType(unionType.variable.type, [])} ${unionType.variable.name};',
      )
      ..writeln()
      ..writeln('    private Object value;')
      ..writeln()
      ..writeln('    public ${unionDef.name}() {')
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public ${unionDef.name}(${_getJavaType(unionType.variable.type, [])} ${unionType.variable.name}) {',
      )
      ..writeln(
        '        this.${unionType.variable.name} = ${unionType.variable.name};',
      )
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public $discriminantType get${_capitalize(unionType.variable.name)}() {',
      )
      ..writeln('        return ${unionType.variable.name};')
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public void set${_capitalize(unionType.variable.name)}($discriminantType ${unionType.variable.name}) {',
      )
      ..writeln(
        '        this.${unionType.variable.name} = ${unionType.variable.name};',
      )
      ..writeln('    }')
      ..writeln();

    // Generate typed getters/setters for each arm
    for (final caseSpec in unionType.arms) {
      if (!inspector.isVoid(caseSpec.type.type)) {
        final armType =
            _getJavaType(caseSpec.type.type, caseSpec.type.dimensions);
        final armName =
            caseSpec.type.name.isNotEmpty ? caseSpec.type.name : 'value';
        final capitalizedName = _capitalize(armName);

        _currentClassBuffer
          ..writeln('    public $armType get$capitalizedName() {')
          ..writeln('        return ($armType) value;')
          ..writeln('    }')
          ..writeln()
          ..writeln(
            '    public void set$capitalizedName($armType $armName) {',
          )
          ..writeln('        this.value = $armName;');
        if (caseSpec.labels.isNotEmpty) {
          final labelValue =
              caseSpec.labels.first.asInt ?? caseSpec.labels.first.asReference;
          _currentClassBuffer.writeln(
            '        this.${unionType.variable.name} = $labelValue;',
          );
        }
        _currentClassBuffer
          ..writeln('    }')
          ..writeln();
      }
    }

    // Generate XDR methods
    _generateXdrMethods(unionDef.name, 'union', unionType);

    _currentClassBuffer.writeln('}');
  }

  void _generateTypedef(final TypeDefinition typeDef) {
    // In Java, we'll create a wrapper class for typedefs
    _currentClassBuffer
      ..writeln('public class ${typeDef.name} implements XdrAble {')
      ..writeln(
        '    private ${_getJavaType(typeDef.type, typeDef.dimensions)} value;',
      )
      ..writeln()
      ..writeln('    public ${typeDef.name}() {')
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public ${typeDef.name}(${_getJavaType(typeDef.type, typeDef.dimensions)} value) {',
      )
      ..writeln('        this.value = value;')
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public ${_getJavaType(typeDef.type, typeDef.dimensions)} getValue() {',
      )
      ..writeln('        return value;')
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public void setValue(${_getJavaType(typeDef.type, typeDef.dimensions)} value) {',
      )
      ..writeln('        this.value = value;')
      ..writeln('    }')
      ..writeln();

    // Generate XDR methods
    _generateXdrMethods(typeDef.name, 'typedef', typeDef);

    _currentClassBuffer.writeln('}');
  }

  void _generateXdrMethods(
    final String className,
    final String typeKind, [
    final dynamic typeSpec,
  ]) {
    // xdrEncode method
    _currentClassBuffer
      ..writeln('    @Override')
      ..writeln(
        '    public void xdrEncode(XdrEncodingStream xdr) throws IOException {',
      );

    if (typeKind == 'enum') {
      _currentClassBuffer.writeln('        xdr.xdrEncodeInt(value);');
    } else if (typeKind == 'struct' && typeSpec != null) {
      _generateStructEncoder(typeSpec as StructTypeSpecifier);
    } else if (typeKind == 'union' && typeSpec != null) {
      _generateUnionEncoder(typeSpec as UnionTypeSpecifier);
    } else if (typeKind == 'typedef' && typeSpec != null) {
      _generateTypedefEncoder(typeSpec as TypeDefinition);
    }

    _currentClassBuffer
      ..writeln('    }')
      ..writeln()
      ..writeln(
        '    public static $className xdrDecode(XdrDecodingStream xdr) throws IOException {',
      )
      ..writeln('        $className result = new $className();');

    if (typeKind == 'enum') {
      _currentClassBuffer
        ..writeln('        int value = xdr.xdrDecodeInt();')
        ..writeln('        result = $className.valueOf(value);');
    } else if (typeKind == 'struct' && typeSpec != null) {
      _generateStructDecoder(typeSpec as StructTypeSpecifier);
    } else if (typeKind == 'union' && typeSpec != null) {
      _generateUnionDecoder(typeSpec as UnionTypeSpecifier);
    } else if (typeKind == 'typedef' && typeSpec != null) {
      _generateTypedefDecoder(typeSpec as TypeDefinition);
    }

    _currentClassBuffer
      ..writeln('        return result;')
      ..writeln('    }');
  }

  void _generateStructEncoder(final StructTypeSpecifier structType) {
    for (final field in structType.fields) {
      _currentClassBuffer.write('        ');
      _generateFieldEncoder(field.name, field.type, field.dimensions);
    }
  }

  void _generateStructDecoder(final StructTypeSpecifier structType) {
    for (final field in structType.fields) {
      _currentClassBuffer.write('        ');
      _generateFieldDecoder(field.name, field.type, field.dimensions);
    }
  }

  void _generateUnionEncoder(final UnionTypeSpecifier unionType) {
    // Encode discriminant
    _generateFieldEncoder(unionType.variable.name, unionType.variable.type, []);

    // Encode appropriate arm based on discriminant
    _currentClassBuffer
        .writeln('        switch (${unionType.variable.name}) {');

    for (final caseSpec in unionType.arms) {
      for (final label in caseSpec.labels) {
        final labelValue = label.asInt ?? label.asReference;
        _currentClassBuffer.writeln('        case $labelValue:');
      }
      if (!inspector.isVoid(caseSpec.type.type)) {
        // Cast value to the correct type before encoding
        final armType =
            _getJavaType(caseSpec.type.type, caseSpec.type.dimensions);
        final armName =
            caseSpec.type.name.isNotEmpty ? caseSpec.type.name : 'value';
        _currentClassBuffer
          ..writeln(
            '            final $armType ${armName}Typed = ($armType) value;',
          )
          ..write('            ');
        _generateFieldEncoder(
          '${armName}Typed',
          caseSpec.type.type,
          caseSpec.type.dimensions,
        );
      }
      _currentClassBuffer.writeln('            break;');
    }

    if (unionType.otherwise != null) {
      _currentClassBuffer.writeln('        default:');
      if (!inspector.isVoid(unionType.otherwise!.type)) {
        // Cast value to the correct type before encoding
        final armType = _getJavaType(
          unionType.otherwise!.type,
          unionType.otherwise!.dimensions,
        );
        _currentClassBuffer
          ..writeln(
            '            final $armType defaultTyped = ($armType) value;',
          )
          ..write('            ');
        _generateFieldEncoder(
          'defaultTyped',
          unionType.otherwise!.type,
          unionType.otherwise!.dimensions,
        );
      }
      _currentClassBuffer.writeln('            break;');
    }

    _currentClassBuffer.writeln('        }');
  }

  void _generateUnionDecoder(final UnionTypeSpecifier unionType) {
    // Decode discriminant
    _generateFieldDecoder('status', unionType.variable.type, []);

    // Decode appropriate arm based on discriminant
    _currentClassBuffer
        .writeln('        switch (result.${unionType.variable.name}) {');

    for (final caseSpec in unionType.arms) {
      for (final label in caseSpec.labels) {
        final labelValue = label.asInt ?? label.asReference;
        _currentClassBuffer.writeln('        case $labelValue:');
      }
      if (!inspector.isVoid(caseSpec.type.type)) {
        _currentClassBuffer.write('            result.');
        _generateFieldDecoder(
          'value',
          caseSpec.type.type,
          caseSpec.type.dimensions,
          false,
        );
      }
      _currentClassBuffer.writeln('            break;');
    }

    if (unionType.otherwise != null) {
      _currentClassBuffer.writeln('        default:');
      if (!inspector.isVoid(unionType.otherwise!.type)) {
        _currentClassBuffer.write('            result.');
        _generateFieldDecoder(
          'value',
          unionType.otherwise!.type,
          unionType.otherwise!.dimensions,
          false,
        );
      }
      _currentClassBuffer.writeln('            break;');
    }

    _currentClassBuffer.writeln('        }');
  }

  void _generateTypedefEncoder(final TypeDefinition typeDef) {
    _generateFieldEncoder('value', typeDef.type, typeDef.dimensions);
  }

  void _generateTypedefDecoder(final TypeDefinition typeDef) {
    _generateFieldDecoder('value', typeDef.type, typeDef.dimensions);
  }

  void _generateFieldEncoder(
    final String fieldName,
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions, [
    final bool addNewline = true,
  ]) {
    final String output;

    // Handle pointer types - encode boolean for presence, then value if present
    if (type is PointerTypeSpecifier) {
      _currentClassBuffer
        ..writeln('if ($fieldName == null) {')
        ..writeln('    xdr.xdrEncodeBoolean(false);')
        ..writeln('} else {')
        ..writeln('    xdr.xdrEncodeBoolean(true);')
        ..write('    ');
      _generateFieldEncoder(fieldName, type.type, dimensions, addNewline);
      _currentClassBuffer.writeln('}');
      return;
    }

    // Strings with max length are not arrays
    if (type is StringTypeSpecifier && dimensions.isNotEmpty) {
      output = 'xdr.xdrEncodeString($fieldName);';
    } else if (dimensions.isNotEmpty && type is! StringTypeSpecifier) {
      _generateArrayEncoder(fieldName, type, dimensions);
      return;
    } else if (type is IntTypeSpecifier) {
      output = 'xdr.xdrEncodeInt($fieldName);';
    } else if (type is HyperTypeSpecifier) {
      output = 'xdr.xdrEncodeLong($fieldName);';
    } else if (type is FloatTypeSpecifier) {
      output = 'xdr.xdrEncodeFloat($fieldName);';
    } else if (type is DoubleTypeSpecifier) {
      output = 'xdr.xdrEncodeDouble($fieldName);';
    } else if (type is BooleanTypeSpecifier) {
      output = 'xdr.xdrEncodeBoolean($fieldName);';
    } else if (type is StringTypeSpecifier) {
      output = 'xdr.xdrEncodeString($fieldName);';
    } else if (type is OpaqueTypeSpecifier) {
      output = 'xdr.xdrEncodeOpaque($fieldName);';
    } else if (type is VoidTypeSpecifier) {
      // Void encodes to nothing
      return;
    } else if (type is UserDefinedTypeSpecifier) {
      output = '$fieldName.xdrEncode(xdr);';
    } else if (type is EnumTypeSpecifier) {
      output = 'xdr.xdrEncodeInt($fieldName.getValue());';
    } else {
      return;
    }

    if (addNewline) {
      _currentClassBuffer.writeln(output);
    } else {
      _currentClassBuffer.write(output);
    }
  }

  void _generateFieldDecoder(
    final String fieldName,
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions, [
    final bool addResultPrefix = true,
  ]) {
    // Add result. prefix if we're decoding into result object
    final prefix = addResultPrefix ? 'result.' : '';

    // Handle pointer types - decode boolean for presence, then value if present
    if (type is PointerTypeSpecifier) {
      _currentClassBuffer
        ..writeln('if (xdr.xdrDecodeBoolean()) {')
        ..write('    ');
      _generateFieldDecoder(fieldName, type.type, dimensions, addResultPrefix);
      _currentClassBuffer
        ..writeln('} else {')
        ..writeln('    $prefix$fieldName = null;')
        ..writeln('}');
      return;
    }

    // Strings with max length are not arrays
    if (type is StringTypeSpecifier && dimensions.isNotEmpty) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeString();');
      return;
    }

    if (dimensions.isNotEmpty && type is! StringTypeSpecifier) {
      _generateArrayDecoder(fieldName, type, dimensions);
    } else if (type is IntTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeInt();');
    } else if (type is HyperTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeLong();');
    } else if (type is FloatTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeFloat();');
    } else if (type is DoubleTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeDouble();');
    } else if (type is BooleanTypeSpecifier) {
      _currentClassBuffer
          .writeln('$prefix$fieldName = xdr.xdrDecodeBoolean();');
    } else if (type is StringTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeString();');
    } else if (type is OpaqueTypeSpecifier) {
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeOpaque();');
    } else if (type is VoidTypeSpecifier) {
      // Void decodes to nothing
    } else if (type is UserDefinedTypeSpecifier) {
      _currentClassBuffer
          .writeln('$prefix$fieldName = ${type.name}.xdrDecode(xdr);');
    } else if (type is EnumTypeSpecifier) {
      // Enum type - decode as int (type name not available here)
      _currentClassBuffer.writeln('$prefix$fieldName = xdr.xdrDecodeInt();');
    }
  }

  void _generateArrayEncoder(
    final String fieldName,
    final TypeSpecifier elementType,
    final List<ArraySpecifier> dimensions, [
    final int depth = 0,
  ]) {
    final dim = dimensions.first;

    // Fixed-size opaque becomes byte[]
    if (elementType is OpaqueTypeSpecifier && dim.isFixedLength) {
      _currentClassBuffer.writeln('xdr.xdrEncodeOpaque($fieldName);');
      return;
    }

    if (!dim.isFixedLength) {
      // Variable-length array - encode length first
      _currentClassBuffer.writeln('xdr.xdrEncodeInt($fieldName.length);');
    }

    // Use correct element type for this dimension
    final loopVarType = dimensions.length > 1
        ? _getJavaType(
            elementType,
            dimensions.sublist(1),
          ) // For multi-dim: use sub-array type
        : _getJavaType(elementType, []); // For 1D: use base type

    final loopVar = depth > 0 ? 'element$depth' : 'element';

    _currentClassBuffer
      ..writeln('for ($loopVarType $loopVar : $fieldName) {')
      ..write('    ');
    if (dimensions.length > 1) {
      _generateArrayEncoder(
        loopVar,
        elementType,
        dimensions.sublist(1),
        depth + 1,
      );
    } else {
      _generateFieldEncoder(loopVar, elementType, []);
    }
    _currentClassBuffer.writeln('}');
  }

  void _generateArrayDecoder(
    final String fieldName,
    final TypeSpecifier elementType,
    final List<ArraySpecifier> dimensions, [
    final int depth = 0,
  ]) {
    final dim = dimensions.first;
    int arraySize;

    // Fixed-size opaque becomes byte[]
    if (elementType is OpaqueTypeSpecifier && dim.isFixedLength) {
      _currentClassBuffer.writeln(
        'result.$fieldName = xdr.xdrDecodeOpaque(${dim.size.asInt});',
      );
      return;
    }

    if (!dim.isFixedLength) {
      // Variable-length array - decode length first
      _currentClassBuffer
          .writeln('int ${fieldName}_length = xdr.xdrDecodeInt();');
      arraySize = 0; // Will use variable
    } else {
      arraySize = dim.size.asInt ?? 0;
    }

    final elementJavaType = dimensions.length > 1
        ? _getJavaType(elementType, dimensions.sublist(1))
        : _getJavaType(elementType, []);

    final loopVar = depth > 0 ? 'i$depth' : 'i';

    if (dim.isFixedLength) {
      // For multi-dimensional arrays, declare with first dimension size, rest empty
      if (dimensions.length > 1) {
        final baseType = _getJavaType(elementType, []);
        final innerDims = '[]' * (dimensions.length - 1);
        _currentClassBuffer.writeln(
          'result.$fieldName = new $baseType[$arraySize]$innerDims;',
        );
      } else {
        _currentClassBuffer
            .writeln('result.$fieldName = new $elementJavaType[$arraySize];');
      }
      _currentClassBuffer.writeln(
        'for (int $loopVar = 0; $loopVar < $arraySize; $loopVar++) {',
      );
    } else {
      // Variable-length arrays
      if (dimensions.length > 1) {
        final baseType = _getJavaType(elementType, []);
        final innerDims = '[]' * (dimensions.length - 1);
        _currentClassBuffer.writeln(
          'result.$fieldName = new $baseType[${fieldName}_length]$innerDims;',
        );
      } else {
        _currentClassBuffer.writeln(
          'result.$fieldName = new $elementJavaType[${fieldName}_length];',
        );
      }
      _currentClassBuffer.writeln(
        'for (int $loopVar = 0; $loopVar < ${fieldName}_length; $loopVar++) {',
      );
    }

    if (dimensions.length > 1) {
      _generateArrayDecoder(
        '$fieldName[$loopVar]',
        elementType,
        dimensions.sublist(1),
        depth + 1,
      );
    } else {
      _generateFieldDecoder('$fieldName[$loopVar]', elementType, []);
    }
    _currentClassBuffer.writeln('}');
  }

  String _getJavaType(
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions,
  ) {
    // Use visitor pattern for type mapping
    String baseType = type.accept(const JavaTypeMapper());

    // Special handling for strings with max length
    if (inspector.isString(type) && dimensions.isNotEmpty) {
      return 'String'; // String with max length is still just String, not String[]
    }

    // Special handling for opaque
    if (inspector.isOpaque(type)) {
      // Fixed-size opaque is byte[], variable is byte[][]
      if (dimensions.isNotEmpty && dimensions.first.isFixedLength) {
        return 'byte[]';
      }
    }

    // Add array brackets for each dimension (except for strings with max length)
    if (!inspector.isString(type)) {
      final buffer = StringBuffer(baseType);
      for (var i = 0; i < dimensions.length; i++) {
        buffer.write('[]');
      }
      baseType = buffer.toString();
    }

    return baseType;
  }

  String _capitalize(final String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  void onProgram(final Map<String, dynamic> config, final Program program) {
    _startNewClass(program.name);

    _currentClassBuffer.writeln('public class ${program.name} {');

    // Format hex constants properly
    final progValue = program.constant;
    final progHex = progValue < 0
        ? progValue
        : '0x${progValue.toRadixString(16).toUpperCase()}';
    _currentClassBuffer
        .writeln('    public static final int PROGRAM = $progHex;');

    for (final version in program.versions) {
      _currentClassBuffer.writeln(
        '    public static final int ${version.name} = ${version.constant};',
      );

      for (final procedure in version.procedures) {
        _currentClassBuffer.writeln(
          '    public static final int ${procedure.name} = ${procedure.constant};',
        );
      }

      _currentClassBuffer
        ..writeln()
        ..writeln(
          '    public interface ${version.name}_Client extends OncRpcClient {',
        );
      for (final procedure in version.procedures) {
        final returnType = _getJavaType(procedure.type, []);
        String paramTypes = '';
        if (procedure.arguments.isNotEmpty) {
          paramTypes = procedure.arguments
              .map((arg) => '${_getJavaType(arg, [])} arg')
              .join(', ');
        } else {
          paramTypes = 'void arg';
        }

        _currentClassBuffer.writeln(
          '        $returnType ${procedure.name.toLowerCase()}($paramTypes) throws IOException, OncRpcException;',
        );
      }
      _currentClassBuffer
        ..writeln('    }')
        ..writeln()
        ..writeln('    public interface ${version.name}_Server {');
      for (final procedure in version.procedures) {
        final returnType = _getJavaType(procedure.type, []);
        String paramTypes = '';
        if (procedure.arguments.isNotEmpty) {
          paramTypes = procedure.arguments
              .map((arg) => '${_getJavaType(arg, [])} arg')
              .join(', ');
        } else {
          paramTypes = 'void arg';
        }

        _currentClassBuffer.writeln(
          '        $returnType ${procedure.name.toLowerCase()}($paramTypes, OncRpcCallContext context);',
        );
      }
      _currentClassBuffer.writeln('    }');
    }

    _currentClassBuffer.writeln('}');
  }
}
