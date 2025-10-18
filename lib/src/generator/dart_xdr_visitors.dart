import '../parser/ast.dart';
import 'type_registry.dart';
import 'type_visitor.dart';

/// Context for XDR encoding operations
class EncoderContext {
  EncoderContext({
    required this.buffer,
    required this.varName,
    required this.indent,
    required this.streamVar,
    required this.registry,
  });

  final StringBuffer buffer;
  final String varName;
  final String indent;
  final String streamVar;
  final TypeRegistry registry;
}

/// Context for XDR decoding operations
class DecoderContext {
  DecoderContext({
    required this.buffer,
    required this.varDecl,
    required this.indent,
    required this.streamVar,
    required this.registry,
  });

  final StringBuffer buffer;
  final String varDecl;
  final String indent;
  final String streamVar;
  final TypeRegistry registry;
}

/// Visitor for generating XDR encoding code
class DartEncoderVisitor extends TypeSpecifierVisitor<void> {
  DartEncoderVisitor(this.context);

  final EncoderContext context;

  @override
  void visitInt(final IntTypeSpecifier type) {
    final method = type.isUnsigned ? 'writeUnsignedInt' : 'writeInt';
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.$method(${context.varName});',
    );
  }

  @override
  void visitHyper(final HyperTypeSpecifier type) {
    final method = type.isUnsigned ? 'writeUnsignedHyper' : 'writeHyper';
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.$method(${context.varName});',
    );
  }

  @override
  void visitFloat(final FloatTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeFloat(${context.varName});',
    );
  }

  @override
  void visitDouble(final DoubleTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeDouble(${context.varName});',
    );
  }

  @override
  void visitQuadruple(final QuadrupleTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeQuadruple(${context.varName});',
    );
  }

  @override
  void visitBoolean(final BooleanTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeBoolean(${context.varName});',
    );
  }

  @override
  void visitVoid(final VoidTypeSpecifier type) {
    // Void encodes to nothing
  }

  @override
  void visitOpaque(final OpaqueTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeOpaque(${context.varName});',
    );
  }

  @override
  void visitString(final StringTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeString(${context.varName});',
    );
  }

  @override
  void visitPointer(final PointerTypeSpecifier type) {
    // Pointers should be handled at a higher level
    type.type.accept(this);
  }

  @override
  void visitUserDefined(final UserDefinedTypeSpecifier type) {
    final typeDef = context.registry.lookup(type.name);
    if (typeDef != null &&
        !(typeDef is StructTypeDefinition ||
            typeDef is UnionTypeDefinition ||
            typeDef is EnumTypeDefinition)) {
      // For typedefs, recursively resolve to underlying type and encode that
      typeDef.type.accept(this);
    } else if (typeDef is EnumTypeDefinition) {
      context.buffer.writeln(
        '${context.indent}${context.streamVar}.writeInt(${context.varName}.value);',
      );
    } else {
      context.buffer.writeln(
        '${context.indent}${context.varName}.encode(${context.streamVar});',
      );
    }
  }

  @override
  void visitEnum(final EnumTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.streamVar}.writeInt(${context.varName}.value);',
    );
  }

  @override
  void visitStruct(final StructTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varName}.encode(${context.streamVar});',
    );
  }

  @override
  void visitUnion(final UnionTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varName}.encode(${context.streamVar});',
    );
  }
}

/// Visitor for generating XDR decoding code
class DartDecoderVisitor extends TypeSpecifierVisitor<void> {
  DartDecoderVisitor(this.context);

  final DecoderContext context;

  String get _assignOp {
    if (context.varDecl.contains('=')) return '';
    return ' =';
  }

  @override
  void visitInt(final IntTypeSpecifier type) {
    final method = type.isUnsigned ? 'readUnsignedInt' : 'readInt';
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.$method();',
    );
  }

  @override
  void visitHyper(final HyperTypeSpecifier type) {
    final method = type.isUnsigned ? 'readUnsignedHyper' : 'readHyper';
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.$method();',
    );
  }

  @override
  void visitFloat(final FloatTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readFloat();',
    );
  }

  @override
  void visitDouble(final DoubleTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readDouble();',
    );
  }

  @override
  void visitQuadruple(final QuadrupleTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readQuadruple();',
    );
  }

  @override
  void visitBoolean(final BooleanTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readBoolean();',
    );
  }

  @override
  void visitVoid(final VoidTypeSpecifier type) {
    context.buffer
        .writeln('${context.indent}${context.varDecl}$_assignOp null;');
  }

  @override
  void visitOpaque(final OpaqueTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readOpaque();',
    );
  }

  @override
  void visitString(final StringTypeSpecifier type) {
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.readString();',
    );
  }

  @override
  void visitPointer(final PointerTypeSpecifier type) {
    // Pointers should be handled at a higher level
    type.type.accept(this);
  }

  @override
  void visitUserDefined(final UserDefinedTypeSpecifier type) {
    final typeDef = context.registry.lookup(type.name);
    if (typeDef != null &&
        !(typeDef is StructTypeDefinition ||
            typeDef is UnionTypeDefinition ||
            typeDef is EnumTypeDefinition)) {
      // For typedefs, recursively resolve to underlying type and decode that
      typeDef.type.accept(this);
    } else if (typeDef is EnumTypeDefinition) {
      final varName = context.varDecl.split(' ').last.replaceAll(
            RegExp('[^a-zA-Z0-9_]'),
            '',
          );
      context.buffer
        ..writeln(
          '${context.indent} final ${varName}Value = ${context.streamVar}.readInt();',
        )
        ..writeln(
          '${context.indent}${context.varDecl}$_assignOp${type.name}.fromValue(${varName}Value);',
        );
    } else {
      context.buffer.writeln(
        '${context.indent}${context.varDecl}$_assignOp ${type.name}.decode(${context.streamVar});',
      );
    }
  }

  @override
  void visitEnum(final EnumTypeSpecifier type) {
    // Inline enum - decode as int
    const method = 'readInt';
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp ${context.streamVar}.$method();',
    );
  }

  @override
  void visitStruct(final StructTypeSpecifier type) {
    // Inline struct
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp <String, Object?>{};',
    );
  }

  @override
  void visitUnion(final UnionTypeSpecifier type) {
    // Inline union
    context.buffer.writeln(
      '${context.indent}${context.varDecl}$_assignOp <String, Object?>{};',
    );
  }
}
