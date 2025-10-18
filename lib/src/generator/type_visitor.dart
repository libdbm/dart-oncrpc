import '../parser/ast.dart';

/// Base visitor interface for traversing TypeSpecifier nodes
///
/// Implements the Visitor pattern for type-safe traversal of the TypeSpecifier
/// AST hierarchy. Subclasses implement visit methods to perform operations
/// on each type node.
///
/// Type parameter [R] is the return type of visit operations.
///
/// Example:
/// ```dart
/// class TypeNameVisitor extends TypeSpecifierVisitor<String> {
///   @override
///   String visitInt(IntTypeSpecifier type) => 'int';
///
///   @override
///   String visitString(StringTypeSpecifier type) => 'String';
///   // ... implement other visit methods
/// }
/// ```
abstract class TypeSpecifierVisitor<R> {
  const TypeSpecifierVisitor();

  R visitInt(final IntTypeSpecifier type);
  R visitHyper(final HyperTypeSpecifier type);
  R visitFloat(final FloatTypeSpecifier type);
  R visitDouble(final DoubleTypeSpecifier type);
  R visitQuadruple(final QuadrupleTypeSpecifier type);
  R visitBoolean(final BooleanTypeSpecifier type);
  R visitVoid(final VoidTypeSpecifier type);
  R visitOpaque(final OpaqueTypeSpecifier type);
  R visitString(final StringTypeSpecifier type);
  R visitPointer(final PointerTypeSpecifier type);
  R visitUserDefined(final UserDefinedTypeSpecifier type);
  R visitEnum(final EnumTypeSpecifier type);
  R visitStruct(final StructTypeSpecifier type);
  R visitUnion(final UnionTypeSpecifier type);
}

/// Extension to add visitor pattern support to TypeSpecifier
///
/// Provides the accept() method that dispatches to the appropriate
/// visitor method based on the runtime type.
extension TypeSpecifierVisitable on TypeSpecifier {
  /// Accept a visitor and dispatch to the appropriate visit method
  R accept<R>(final TypeSpecifierVisitor<R> visitor) {
    final self = this;

    if (self is IntTypeSpecifier) {
      return visitor.visitInt(self);
    } else if (self is HyperTypeSpecifier) {
      return visitor.visitHyper(self);
    } else if (self is FloatTypeSpecifier) {
      return visitor.visitFloat(self);
    } else if (self is DoubleTypeSpecifier) {
      return visitor.visitDouble(self);
    } else if (self is QuadrupleTypeSpecifier) {
      return visitor.visitQuadruple(self);
    } else if (self is BooleanTypeSpecifier) {
      return visitor.visitBoolean(self);
    } else if (self is VoidTypeSpecifier) {
      return visitor.visitVoid(self);
    } else if (self is OpaqueTypeSpecifier) {
      return visitor.visitOpaque(self);
    } else if (self is StringTypeSpecifier) {
      return visitor.visitString(self);
    } else if (self is PointerTypeSpecifier) {
      return visitor.visitPointer(self);
    } else if (self is UserDefinedTypeSpecifier) {
      return visitor.visitUserDefined(self);
    } else if (self is EnumTypeSpecifier) {
      return visitor.visitEnum(self);
    } else if (self is StructTypeSpecifier) {
      return visitor.visitStruct(self);
    } else if (self is UnionTypeSpecifier) {
      return visitor.visitUnion(self);
    }

    throw UnimplementedError('Unknown TypeSpecifier: ${self.runtimeType}');
  }
}
