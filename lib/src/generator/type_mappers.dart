import '../parser/ast.dart';
import 'type_visitor.dart';

/// Maps XDR TypeSpecifiers to Dart type names
class DartTypeMapper extends TypeSpecifierVisitor<String> {
  const DartTypeMapper();

  @override
  String visitInt(final IntTypeSpecifier type) => 'int';

  @override
  String visitHyper(final HyperTypeSpecifier type) => 'BigInt';

  @override
  String visitFloat(final FloatTypeSpecifier type) => 'double';

  @override
  String visitDouble(final DoubleTypeSpecifier type) => 'double';

  @override
  String visitQuadruple(final QuadrupleTypeSpecifier type) => 'double';

  @override
  String visitBoolean(final BooleanTypeSpecifier type) => 'bool';

  @override
  String visitVoid(final VoidTypeSpecifier type) => 'void';

  @override
  String visitOpaque(final OpaqueTypeSpecifier type) => 'Uint8List';

  @override
  String visitString(final StringTypeSpecifier type) => 'String';

  @override
  String visitPointer(final PointerTypeSpecifier type) =>
      type.type.accept(this); // Unwrap pointer

  @override
  String visitUserDefined(final UserDefinedTypeSpecifier type) => type.name;

  @override
  String visitEnum(final EnumTypeSpecifier type) => 'int'; // Inline enum

  @override
  String visitStruct(final StructTypeSpecifier type) =>
      'Map<String, Object?>'; // Inline struct

  @override
  String visitUnion(final UnionTypeSpecifier type) =>
      'Map<String, Object?>'; // Inline union
}

/// Maps XDR TypeSpecifiers to C base type names
class CTypeMapper extends TypeSpecifierVisitor<String> {
  const CTypeMapper();

  @override
  String visitInt(final IntTypeSpecifier type) =>
      type.isUnsigned ? 'u_int' : 'int';

  @override
  String visitHyper(final HyperTypeSpecifier type) =>
      type.isUnsigned ? 'u_int64_t' : 'int64_t';

  @override
  String visitFloat(final FloatTypeSpecifier type) => 'float';

  @override
  String visitDouble(final DoubleTypeSpecifier type) => 'double';

  @override
  String visitQuadruple(final QuadrupleTypeSpecifier type) => 'double';

  @override
  String visitBoolean(final BooleanTypeSpecifier type) => 'bool_t';

  @override
  String visitVoid(final VoidTypeSpecifier type) => 'void';

  @override
  String visitOpaque(final OpaqueTypeSpecifier type) => 'char';

  @override
  String visitString(final StringTypeSpecifier type) => 'char *';

  @override
  String visitPointer(final PointerTypeSpecifier type) =>
      '${type.type.accept(this)} *';

  @override
  String visitUserDefined(final UserDefinedTypeSpecifier type) => type.name;

  @override
  String visitEnum(final EnumTypeSpecifier type) => 'int';

  @override
  String visitStruct(final StructTypeSpecifier type) =>
      'void'; // Should not happen

  @override
  String visitUnion(final UnionTypeSpecifier type) =>
      'void'; // Should not happen
}

/// Maps XDR TypeSpecifiers to XDR function names for C
class CXdrFunctionMapper extends TypeSpecifierVisitor<String> {
  const CXdrFunctionMapper();

  @override
  String visitInt(final IntTypeSpecifier type) =>
      type.isUnsigned ? 'xdr_u_int' : 'xdr_int';

  @override
  String visitHyper(final HyperTypeSpecifier type) =>
      type.isUnsigned ? 'xdr_u_int64_t' : 'xdr_int64_t';

  @override
  String visitFloat(final FloatTypeSpecifier type) => 'xdr_float';

  @override
  String visitDouble(final DoubleTypeSpecifier type) => 'xdr_double';

  @override
  String visitQuadruple(final QuadrupleTypeSpecifier type) => 'xdr_double';

  @override
  String visitBoolean(final BooleanTypeSpecifier type) => 'xdr_bool';

  @override
  String visitVoid(final VoidTypeSpecifier type) => 'xdr_void';

  @override
  String visitOpaque(final OpaqueTypeSpecifier type) => 'xdr_opaque';

  @override
  String visitString(final StringTypeSpecifier type) => 'xdr_string';

  @override
  String visitPointer(final PointerTypeSpecifier type) => 'xdr_pointer';

  @override
  String visitUserDefined(final UserDefinedTypeSpecifier type) =>
      'xdr_${type.name}';

  @override
  String visitEnum(final EnumTypeSpecifier type) => 'xdr_enum';

  @override
  String visitStruct(final StructTypeSpecifier type) => 'xdr_void';

  @override
  String visitUnion(final UnionTypeSpecifier type) => 'xdr_void';
}

/// Maps XDR TypeSpecifiers to Java type names
class JavaTypeMapper extends TypeSpecifierVisitor<String> {
  const JavaTypeMapper();

  @override
  String visitInt(final IntTypeSpecifier type) =>
      'int'; // Java doesn't have unsigned

  @override
  String visitHyper(final HyperTypeSpecifier type) => 'long';

  @override
  String visitFloat(final FloatTypeSpecifier type) => 'float';

  @override
  String visitDouble(final DoubleTypeSpecifier type) => 'double';

  @override
  String visitQuadruple(final QuadrupleTypeSpecifier type) => 'double';

  @override
  String visitBoolean(final BooleanTypeSpecifier type) => 'boolean';

  @override
  String visitVoid(final VoidTypeSpecifier type) => 'void';

  @override
  String visitOpaque(final OpaqueTypeSpecifier type) => 'byte[]';

  @override
  String visitString(final StringTypeSpecifier type) => 'String';

  @override
  String visitPointer(final PointerTypeSpecifier type) =>
      type.type.accept(this); // Unwrap pointer (nullable by default in Java)

  @override
  String visitUserDefined(final UserDefinedTypeSpecifier type) {
    // Handle built-in types that might be parsed as user-defined
    if (type.name == 'string') return 'String';
    return type.name;
  }

  @override
  String visitEnum(final EnumTypeSpecifier type) => 'int';

  @override
  String visitStruct(final StructTypeSpecifier type) => 'Object';

  @override
  String visitUnion(final UnionTypeSpecifier type) => 'Object';
}
