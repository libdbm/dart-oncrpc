import '../parser/ast.dart';

/// Utility class for inspecting and classifying XDR type specifiers
///
/// Provides common type checking operations used across all generators
class TypeInspector {
  const TypeInspector();

  /// Check if a type is void
  bool isVoid(final TypeSpecifier type) => type is VoidTypeSpecifier;

  /// Check if a type is a primitive type
  bool isPrimitive(final TypeSpecifier type) =>
      type is IntTypeSpecifier ||
      type is HyperTypeSpecifier ||
      type is FloatTypeSpecifier ||
      type is DoubleTypeSpecifier ||
      type is BooleanTypeSpecifier;

  /// Check if a type is a string
  bool isString(final TypeSpecifier type) => type is StringTypeSpecifier;

  /// Check if a type is opaque (bytes)
  bool isOpaque(final TypeSpecifier type) => type is OpaqueTypeSpecifier;

  /// Check if a type is user-defined
  bool isUserDefined(final TypeSpecifier type) =>
      type is UserDefinedTypeSpecifier;

  /// Check if a type is an enum
  bool isEnum(final TypeSpecifier type) => type is EnumTypeSpecifier;

  /// Check if a type is a struct
  bool isStruct(final TypeSpecifier type) => type is StructTypeSpecifier;

  /// Check if a type is a union
  bool isUnion(final TypeSpecifier type) => type is UnionTypeSpecifier;

  /// Check if a type is a pointer (optional)
  bool isPointer(final TypeSpecifier type) => type is PointerTypeSpecifier;

  /// Check if a type is signed integer type
  bool isSigned(final TypeSpecifier type) {
    if (type is IntTypeSpecifier) return !type.isUnsigned;
    if (type is HyperTypeSpecifier) return !type.isUnsigned;
    return false;
  }

  /// Check if a type is unsigned integer type
  bool isUnsigned(final TypeSpecifier type) {
    if (type is IntTypeSpecifier) return type.isUnsigned;
    if (type is HyperTypeSpecifier) return type.isUnsigned;
    return false;
  }

  /// Check if dimensions represent a fixed-length array
  bool isFixedArray(final List<ArraySpecifier> dimensions) =>
      dimensions.isNotEmpty && dimensions.first.isFixedLength;

  /// Check if dimensions represent a variable-length array
  bool isVariableArray(final List<ArraySpecifier> dimensions) =>
      dimensions.isNotEmpty && !dimensions.first.isFixedLength;

  /// Check if type requires custom XDR functions (not built-in)
  bool needsCustomXdr(final TypeSpecifier type) =>
      isUserDefined(type) || isEnum(type) || isStruct(type) || isUnion(type);

  /// Get the size value from an ArraySpecifier
  dynamic getSize(final ArraySpecifier spec) =>
      spec.size.asInt ?? spec.size.asReference;

  /// Check if a field is optional (pointer with size 1)
  bool isOptionalField(
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions,
  ) {
    if (type is PointerTypeSpecifier) return true;

    // Check for optional pattern: user-defined type with <1> dimension
    return dimensions.isNotEmpty &&
        dimensions.first.size.asInt == 1 &&
        !dimensions.first.isFixedLength &&
        isUserDefined(type);
  }

  /// Get the base type from a pointer type, or return original type
  TypeSpecifier unwrapPointer(final TypeSpecifier type) {
    if (type is PointerTypeSpecifier) return type.type;
    return type;
  }

  /// Check if dimensions should be treated as max length (for strings)
  bool isMaxLengthDimension(
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions,
  ) =>
      isString(type) && dimensions.isNotEmpty;
}
