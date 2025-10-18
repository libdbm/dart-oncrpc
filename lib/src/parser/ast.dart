import 'package:meta/meta.dart';

/// Represents a complete RPC/XDR specification file.
///
/// A specification contains all RPC programs, constants, and type definitions
/// parsed from a .x file. This is the root node of the AST.
@immutable
class Specification {
  const Specification(this.programs, this.constants, this.types);

  /// All RPC program definitions in this specification.
  final List<Program> programs;

  /// All constant definitions in this specification.
  final List<Constant<Value>> constants;

  /// All type definitions in this specification.
  final List<TypeDefinition> types;

  @override
  String toString() =>
      'Specification{programs: $programs, constants: $constants, types: $types}';
}

/// Represents an RPC program definition.
///
/// An RPC program groups related remote procedures under a unique program
/// number. Each program contains one or more versions.
@immutable
class Program {
  const Program(this.name, this.constant, this.versions);

  /// The program name identifier.
  final String name;

  /// The unique program number.
  final int constant;

  /// All versions defined for this program.
  final List<Version> versions;
}

/// Represents a named constant definition.
///
/// Constants can be used in type definitions and array size specifications.
/// The value can be either a literal or a reference to another constant.
@immutable
class Constant<T> {
  const Constant(this.name, this.value);

  /// The constant name identifier.
  final String name;

  /// The constant value.
  final T value;
}

/// Represents a version of an RPC program.
///
/// Each version contains a set of procedures and is identified by a unique
/// version number within its program. Multiple versions allow protocols to
/// evolve while maintaining backward compatibility.
@immutable
class Version {
  const Version(this.name, this.constant, this.procedures);

  /// The version name identifier.
  final String name;

  /// The unique version number within the program.
  final int constant;

  /// All procedures defined in this version.
  final List<Procedure> procedures;
}

/// Represents a remote procedure in an RPC program version.
///
/// Each procedure has a unique number within its version, a return type,
/// and zero or more arguments. The procedure can be called remotely by
/// RPC clients.
@immutable
class Procedure {
  const Procedure(this.name, this.type, this.arguments, this.constant);

  /// The procedure name identifier.
  final String name;

  /// The unique procedure number within the version.
  final int constant;

  /// The return type of the procedure.
  final TypeSpecifier type;

  /// The argument types for the procedure.
  final List<TypeSpecifier> arguments;
}

/// Represents a value that can be either a literal integer or a constant reference
abstract class Value {
  const Value();

  /// Factory constructor for creating a literal value
  factory Value.literal(int value) = IntegerLiteral;

  /// Factory constructor for creating a reference value
  factory Value.reference(String name) = ReferenceValue;

  /// Returns the integer value if this is a literal, null otherwise
  int? get asInt;

  /// Returns the reference name if this is a constant reference, null otherwise
  String? get asReference;
}

/// A literal integer value
class IntegerLiteral extends Value {
  const IntegerLiteral(this.value);

  final int value;

  @override
  int? get asInt => value;

  @override
  String? get asReference => null;

  @override
  String toString() => value.toString();
}

/// A reference to a named constant
class ReferenceValue extends Value {
  const ReferenceValue(this.name);

  final String name;

  @override
  int? get asInt => null;

  @override
  String? get asReference => name;

  @override
  String toString() => name;
}

/// Specifies array dimensions for type declarations.
///
/// Arrays can be either fixed-length (with a compile-time size) or
/// variable-length (with a maximum size). The size can be a literal
/// integer or a reference to a named constant.
class ArraySpecifier {
  ArraySpecifier(this.size, {required this.isFixedLength});

  /// The array size (maximum for variable-length arrays).
  final Value size;

  /// Whether this is a fixed-length array.
  final bool isFixedLength;
}

/// Base class for all type specifiers in XDR.
///
/// Type specifiers represent the type portion of a declaration, without
/// the variable name. They can be primitive types (int, float, etc.),
/// structured types (struct, union, enum), or user-defined types.
abstract class TypeSpecifier {}

/// Represents a 32-bit integer type.
///
/// Can be signed or unsigned. Maps to XDR int or unsigned int.
class IntTypeSpecifier extends TypeSpecifier {
  IntTypeSpecifier({required this.isUnsigned});

  /// Whether this is an unsigned integer.
  final bool isUnsigned;
}

/// Represents a 64-bit integer type.
///
/// Can be signed or unsigned. Maps to XDR hyper or unsigned hyper.
class HyperTypeSpecifier extends TypeSpecifier {
  HyperTypeSpecifier({required this.isUnsigned});

  /// Whether this is an unsigned hyper.
  final bool isUnsigned;
}

/// Represents a single-precision floating-point type.
///
/// Maps to XDR float (IEEE 754 single-precision).
class FloatTypeSpecifier extends TypeSpecifier {}

/// Represents a double-precision floating-point type.
///
/// Maps to XDR double (IEEE 754 double-precision).
class DoubleTypeSpecifier extends TypeSpecifier {}

/// Represents a quadruple-precision floating-point type.
///
/// Maps to XDR quadruple (IEEE 754 quadruple-precision).
class QuadrupleTypeSpecifier extends TypeSpecifier {}

/// Represents a boolean type.
///
/// Maps to XDR bool (encoded as an integer 0 or 1).
class BooleanTypeSpecifier extends TypeSpecifier {}

/// Represents the void type for procedures with no return value.
class VoidTypeSpecifier extends TypeSpecifier {}

/// Represents an opaque data type.
///
/// Opaque data is an uninterpreted sequence of bytes, similar to a byte array.
class OpaqueTypeSpecifier extends TypeSpecifier {}

/// Represents a string type.
///
/// Strings are variable-length sequences of ASCII characters.
class StringTypeSpecifier extends TypeSpecifier {}

/// Represents an optional pointer type.
///
/// Pointers in XDR represent optional values that may or may not be present.
/// They are encoded with a boolean presence flag followed by the value if present.
class PointerTypeSpecifier extends TypeSpecifier {
  PointerTypeSpecifier(this.type);

  /// The type being pointed to.
  final TypeSpecifier type;
}

/// Represents a reference to a user-defined type.
///
/// This references a type defined elsewhere in the specification via
/// typedef, struct, union, or enum.
class UserDefinedTypeSpecifier extends TypeSpecifier {
  UserDefinedTypeSpecifier(this.name);

  /// The name of the user-defined type.
  final String name;
}

/// Represents an enumeration type.
///
/// Enums define a set of named integer constants. Each enum value has
/// a name and an associated integer value.
class EnumTypeSpecifier extends TypeSpecifier {
  EnumTypeSpecifier(this.values);

  /// The enumeration values.
  final List<Constant<Value>> values;
}

/// Represents a structure type.
///
/// Structs group multiple fields of different types together. Each field
/// is encoded sequentially in XDR.
class StructTypeSpecifier extends TypeSpecifier {
  StructTypeSpecifier(this.fields);

  /// The structure fields.
  final List<TypeDefinition> fields;
}

/// Represents a discriminated union type.
///
/// Unions encode one of several possible types based on a discriminant
/// variable. Each arm matches specific discriminant values to a type.
/// An optional default arm handles unmatched values.
class UnionTypeSpecifier extends TypeSpecifier {
  UnionTypeSpecifier(this.variable, this.arms, this.otherwise);

  /// The discriminant variable that determines which arm is active.
  final TypeDefinition variable;

  /// The union arms, each matching discriminant values to a type.
  final List<UnionArm> arms;

  /// The default arm for unmatched discriminant values.
  final TypeDefinition? otherwise;
}

/// Represents a single arm of a discriminated union.
///
/// Each arm matches one or more discriminant values to a specific type.
/// When the discriminant matches any of the labels, this arm's type is used.
class UnionArm {
  UnionArm(this.labels, this.type);

  /// The discriminant values that activate this arm.
  ///
  /// Labels can be either integers or string identifiers.
  final List<Value> labels;

  /// The type used when this arm is active.
  final TypeDefinition type;
}

/// Represents a complete type definition with name and optional array dimensions.
///
/// This is the base class for all type definitions, combining a type specifier
/// with a variable name and optional array dimensions. Used for struct fields,
/// procedure parameters, and typedef declarations.
class TypeDefinition {
  TypeDefinition(this.name, this.type, [List<ArraySpecifier>? dimensions])
      : dimensions = dimensions ?? [];

  /// The name of the defined type or variable.
  final String name;

  /// The type specifier.
  final TypeSpecifier type;

  /// Array dimensions (empty for non-array types).
  final List<ArraySpecifier> dimensions;

  /// Backward compatibility getter for single-dimensional arrays.
  ArraySpecifier? get length => dimensions.isNotEmpty ? dimensions.first : null;
}

/// Represents an enumeration type definition.
///
/// Specialized type definition for enum types, ensuring type safety
/// by requiring an EnumTypeSpecifier.
class EnumTypeDefinition extends TypeDefinition {
  EnumTypeDefinition(
    super.name,
    EnumTypeSpecifier super.type, [
    super.dimensions,
  ]);
}

/// Represents a structure type definition.
///
/// Specialized type definition for struct types, ensuring type safety
/// by requiring a StructTypeSpecifier.
class StructTypeDefinition extends TypeDefinition {
  StructTypeDefinition(
    super.name,
    StructTypeSpecifier super.type, [
    super.dimensions,
  ]);
}

/// Represents a discriminated union type definition.
///
/// Specialized type definition for union types, ensuring type safety
/// by requiring a UnionTypeSpecifier.
class UnionTypeDefinition extends TypeDefinition {
  UnionTypeDefinition(
    super.name,
    UnionTypeSpecifier super.type, [
    super.dimensions,
  ]);
}

/// Represents a void type definition.
///
/// Used for procedures that return no value. The name is always 'void'
/// and it has no array dimensions.
class VoidTypeDefinition extends TypeDefinition {
  VoidTypeDefinition() : super('void', VoidTypeSpecifier(), []);
}

/// Represents an opaque data type definition.
///
/// Specialized type definition for opaque types, ensuring type safety
/// by requiring an OpaqueTypeSpecifier.
class OpaqueTypeDefinition extends TypeDefinition {
  OpaqueTypeDefinition(
    super.name,
    OpaqueTypeSpecifier super.type, [
    super.dimensions,
  ]);
}

/// Represents a string type definition.
///
/// Specialized type definition for string types, ensuring type safety
/// by requiring a StringTypeSpecifier.
class StringTypeDefinition extends TypeDefinition {
  StringTypeDefinition(
    super.name,
    StringTypeSpecifier super.type, [
    super.dimensions,
  ]);
}

/// Represents an optional pointer type definition.
///
/// Specialized type definition for pointer types, ensuring type safety
/// by requiring a PointerTypeSpecifier.
class PointerTypeDefinition extends TypeDefinition {
  PointerTypeDefinition(
    super.name,
    PointerTypeSpecifier super.type, [
    super.dimensions,
  ]);
}
