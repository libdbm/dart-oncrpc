import 'package:dart_oncrpc/src/generator/dart_xdr_visitors.dart';
import 'package:dart_oncrpc/src/generator/type_registry.dart';
import 'package:dart_oncrpc/src/generator/type_visitor.dart';
import 'package:dart_oncrpc/src/parser/ast.dart';

/// Strategy for encoding different XDR types to Dart code
/// This uses a functional approach with type-specific encoder generators
class EncoderStrategy {
  EncoderStrategy(this.registry);

  final TypeRegistry registry;

  /// Generate encoding code for a specific type
  /// Returns the generated code as a string
  String generate(
    final String varName,
    final TypeSpecifier type,
    final String indent,
    final ArraySpecifier? length,
    final String streamVar,
  ) {
    final buffer = StringBuffer();

    // Handle arrays first
    if (length != null) {
      _generateArrayEncoder(buffer, varName, type, indent, length, streamVar);
      return buffer.toString();
    }

    // Use visitor pattern for type dispatch
    final context = EncoderContext(
      buffer: buffer,
      varName: varName,
      indent: indent,
      streamVar: streamVar,
      registry: registry,
    );

    type.accept(DartEncoderVisitor(context));

    return buffer.toString();
  }

  void _generateArrayEncoder(
    final StringBuffer buffer,
    final String varName,
    final TypeSpecifier type,
    final String indent,
    final ArraySpecifier length,
    final String streamVar,
  ) {
    // For opaque and string types, the array specifier represents max size, not a true array
    // These types encode their length inline, so we don't iterate
    final isOpaque = type is OpaqueTypeSpecifier;
    final isString = type is StringTypeSpecifier;

    if (isOpaque || isString) {
      final sizeValue = length.size.asInt ?? -1;
      if (sizeValue > 0) {
        buffer
          ..writeln('$indent// Max size: $sizeValue')
          ..writeln('${indent}if ($varName.length > $sizeValue) {')
          ..writeln(
            "$indent  throw ArgumentError('${isOpaque ? 'Opaque' : 'String'} exceeds maximum length of $sizeValue');",
          )
          ..writeln('$indent}');
      }
      // Just encode the value directly - it handles its own length
      buffer.write(generate(varName, type, indent, null, streamVar));
      return;
    }

    if (length.isFixedLength) {
      final sizeValue = length.size.asInt ?? length.size.asReference ?? 0;
      buffer
        ..writeln('$indent// Fixed array of $sizeValue elements')
        ..writeln('${indent}if ($varName.length != $sizeValue) {')
        ..writeln(
          "$indent  throw ArgumentError('Fixed array must have exactly $sizeValue elements');",
        )
        ..writeln('$indent}')
        ..writeln('${indent}for (final item in $varName) {')
        ..write(generate('item', type, '$indent  ', null, streamVar))
        ..writeln('$indent}');
    } else {
      final sizeValue = length.size.asInt ?? -1;
      if (sizeValue > 0) {
        buffer
          ..writeln('$indent// Variable array with max $sizeValue elements')
          ..writeln('${indent}if ($varName.length > $sizeValue) {')
          ..writeln(
            "$indent  throw ArgumentError('Array exceeds maximum length of $sizeValue');",
          )
          ..writeln('$indent}');
      } else {
        buffer.writeln('$indent// Variable array with no maximum');
      }
      buffer
        ..writeln('$indent$streamVar.writeInt($varName.length);')
        ..writeln('${indent}for (final item in $varName) {')
        ..write(generate('item', type, '$indent  ', null, streamVar))
        ..writeln('$indent}');
    }
  }
}

/// Strategy for decoding different XDR types from Dart code
class DecoderStrategy {
  DecoderStrategy(this.registry);

  final TypeRegistry registry;

  /// Generate decoding code for a specific type
  String generate(
    final String varDecl,
    final TypeSpecifier type,
    final String indent,
    final ArraySpecifier? length,
    final String streamVar,
  ) {
    final buffer = StringBuffer();

    // Handle arrays first
    if (length != null) {
      _generateArrayDecoder(buffer, varDecl, type, indent, length, streamVar);
      return buffer.toString();
    }

    // Use visitor pattern for type dispatch
    final context = DecoderContext(
      buffer: buffer,
      varDecl: varDecl,
      indent: indent,
      streamVar: streamVar,
      registry: registry,
    );

    type.accept(DartDecoderVisitor(context));

    return buffer.toString();
  }

  String _extractVarName(final String varDecl) {
    final match = RegExp(r'(\w+)\s*=?\s*$').firstMatch(varDecl);
    return match?.group(1) ?? 'var';
  }

  void _generateArrayDecoder(
    final StringBuffer buffer,
    final String varDecl,
    final TypeSpecifier type,
    final String indent,
    final ArraySpecifier length,
    final String streamVar,
  ) {
    // For opaque and string types, the array specifier represents max size, not a true array
    // These types decode their length inline, so we don't iterate
    final isOpaque = type is OpaqueTypeSpecifier;
    final isString = type is StringTypeSpecifier;

    if (isOpaque || isString) {
      // Just decode the value directly - it handles its own length
      buffer.write(generate(varDecl, type, indent, null, streamVar));
      final sizeValue = length.size.asInt ?? -1;
      if (sizeValue > 0) {
        final varName = _extractVarName(varDecl);
        buffer
          ..writeln('${indent}if ($varName.length > $sizeValue) {')
          ..writeln(
            "$indent  throw ArgumentError('${isOpaque ? 'Opaque' : 'String'} exceeds maximum length of $sizeValue');",
          )
          ..writeln('$indent}');
      }
      return;
    }

    final varName = _extractVarName(varDecl);
    final dartType = _getDartType(type);

    if (length.isFixedLength) {
      final sizeValue = length.size.asInt ?? length.size.asReference ?? 0;
      buffer
        ..writeln('$indent// Fixed array of $sizeValue elements')
        ..writeln('${indent}final _array$varName = <$dartType>[];')
        ..writeln('${indent}for (int i = 0; i < $sizeValue; i++) {')
        ..write(generate('final item', type, '$indent  ', null, streamVar))
        ..writeln('$indent  _array$varName.add(item);')
        ..writeln('$indent}')
        ..writeln('$indent$varDecl = _array$varName;');
    } else {
      buffer.writeln('$indent// Variable array');
      final lengthVar = '${varName}Length';
      buffer.writeln('${indent}final $lengthVar = $streamVar.readInt();');
      final sizeValue = length.size.asInt ?? -1;
      if (sizeValue > 0) {
        buffer
          ..writeln('${indent}if ($lengthVar > $sizeValue) {')
          ..writeln(
            "$indent  throw ArgumentError('Array length exceeds maximum of $sizeValue');",
          )
          ..writeln('$indent}');
      }
      buffer
        ..writeln('${indent}final _array$varName = <$dartType>[];')
        ..writeln('${indent}for (int i = 0; i < $lengthVar; i++) {')
        ..write(generate('final item', type, '$indent  ', null, streamVar))
        ..writeln('$indent  _array$varName.add(item);')
        ..writeln('$indent}')
        ..writeln('$indent$varDecl = _array$varName;');
    }
  }

  String _getDartType(final TypeSpecifier type) {
    if (type is IntTypeSpecifier) return 'int';
    if (type is HyperTypeSpecifier) return 'BigInt';
    if (type is FloatTypeSpecifier) return 'double';
    if (type is DoubleTypeSpecifier) return 'double';
    if (type is BooleanTypeSpecifier) return 'bool';
    if (type is StringTypeSpecifier) return 'String';
    if (type is OpaqueTypeSpecifier) return 'Uint8List';
    if (type is UserDefinedTypeSpecifier) return type.name;
    return 'Object';
  }
}
