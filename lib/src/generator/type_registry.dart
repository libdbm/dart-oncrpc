import '../parser/ast.dart';

/// Registry for tracking type definitions during code generation
///
/// Provides centralized storage and lookup for type definitions,
/// helping avoid duplicate generation and enabling cross-references
class TypeRegistry {
  final Map<String, TypeDefinition> _types = {};
  final Set<String> _defined = {};

  /// Register a type definition
  void register(final TypeDefinition definition) {
    _types[definition.name] = definition;
  }

  /// Register multiple type definitions
  void registerAll(final Iterable<TypeDefinition> definitions) {
    definitions.forEach(register);
  }

  /// Lookup a type by name
  TypeDefinition? lookup(final String name) => _types[name];

  /// Check if a type has been registered
  bool contains(final String name) => _types.containsKey(name);

  /// Mark a type as defined (generated)
  void markDefined(final String name) {
    _defined.add(name);
  }

  /// Check if a type has been defined (generated)
  bool isDefined(final String name) => _defined.contains(name);

  /// Get all registered types
  Iterable<TypeDefinition> get all => _types.values;

  /// Get all type names
  Iterable<String> get names => _types.keys;

  /// Get count of registered types
  int get count => _types.length;

  /// Clear all registrations
  void clear() {
    _types.clear();
    _defined.clear();
  }

  /// Check if a user-defined type name refers to an enum
  bool isEnumType(final String name) {
    final type = lookup(name);
    return type is EnumTypeDefinition;
  }

  /// Check if a user-defined type name refers to a struct
  bool isStructType(final String name) {
    final type = lookup(name);
    return type is StructTypeDefinition;
  }

  /// Check if a user-defined type name refers to a union
  bool isUnionType(final String name) {
    final type = lookup(name);
    return type is UnionTypeDefinition;
  }

  /// Get the underlying type specifier for a user-defined type
  TypeSpecifier? getTypeSpecifier(final String name) {
    final type = lookup(name);
    return type?.type;
  }
}
