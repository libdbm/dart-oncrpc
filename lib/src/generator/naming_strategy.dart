/// Base class for language-specific naming conventions
///
/// Provides a consistent interface for converting names between
/// different case styles and sanitizing identifiers
abstract class NamingStrategy {
  const NamingStrategy();

  /// Convert to PascalCase (e.g., "my_type" -> "MyType")
  String toPascalCase(final String name) => convertToPascalCase(name);

  /// Convert to camelCase (e.g., "my_function" -> "myFunction")
  String toCamelCase(final String name) {
    final pascal = toPascalCase(name);
    if (pascal.isEmpty) return '';
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  /// Convert to snake_case (e.g., "MyType" -> "my_type")
  String toSnakeCase(final String name) => name
      .replaceAllMapped(
        RegExp('([A-Z])'),
        (final match) => '_${match.group(0)!.toLowerCase()}',
      )
      .replaceAll(RegExp('^_'), '');

  /// Convert to UPPER_CASE (e.g., "myConst" -> "MY_CONST")
  String toUpperCase(final String name) => toSnakeCase(name).toUpperCase();

  /// Sanitize an identifier to avoid reserved words
  String sanitize(final String identifier);

  /// Format a constant name
  String formatConstant(final String name) => name;

  /// Format a type name
  String formatType(final String name) => name;

  /// Format a field/variable name
  String formatField(final String name) => name;

  /// Format a method/function name
  String formatMethod(final String name) => name;

  /// Shared implementation for PascalCase conversion
  static String convertToPascalCase(final String name) =>
      name.split('_').map((final word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join();
}

/// Dart naming conventions
class DartNamingStrategy extends NamingStrategy {
  const DartNamingStrategy({this.useDartConventions = false});

  final bool useDartConventions;

  static const _reservedWords = {
    'class',
    'enum',
    'extends',
    'abstract',
    'implements',
    'interface',
    'new',
    'static',
    'final',
    'const',
    'var',
    'void',
    'null',
    'true',
    'false',
    'this',
    'super',
    'return',
    'break',
    'continue',
    'if',
    'else',
    'for',
    'while',
    'do',
    'switch',
    'case',
    'default',
    'try',
    'catch',
    'finally',
    'throw',
    'assert',
    'async',
    'await',
    'yield',
    'import',
    'export',
    'library',
    'part',
    'typedef',
    'operator',
    'get',
    'set',
    'factory',
  };

  @override
  String sanitize(final String identifier) {
    if (_reservedWords.contains(identifier)) {
      return '${identifier}_';
    }
    return identifier;
  }

  @override
  String formatConstant(final String name) {
    if (!useDartConventions) return name;

    // Check if name is all uppercase (with optional underscores)
    final isUpperCase = name.split('_').every(
          (final part) => part.isEmpty || part == part.toUpperCase(),
        );

    if (isUpperCase) {
      return toCamelCase(name);
    }

    return name;
  }

  @override
  String formatType(final String name) => name;

  @override
  String formatField(final String name) => sanitize(name);

  @override
  String formatMethod(final String name) => toCamelCase(name);
}

/// C naming conventions
class CNamingStrategy extends NamingStrategy {
  const CNamingStrategy();

  @override
  String sanitize(final String identifier) => identifier;

  @override
  String formatConstant(final String name) => name;

  @override
  String formatType(final String name) => name;

  @override
  String formatField(final String name) => name;

  @override
  String formatMethod(final String name) => name.toLowerCase();
}

/// Java naming conventions
class JavaNamingStrategy extends NamingStrategy {
  const JavaNamingStrategy();

  @override
  String sanitize(final String identifier) {
    // Java reserved words - extend as needed
    const reservedWords = {
      'abstract',
      'assert',
      'boolean',
      'break',
      'byte',
      'case',
      'catch',
      'char',
      'class',
      'const',
      'continue',
      'default',
      'do',
      'double',
      'else',
      'enum',
      'extends',
      'final',
      'finally',
      'float',
      'for',
      'goto',
      'if',
      'implements',
      'import',
      'instanceof',
      'int',
      'interface',
      'long',
      'native',
      'new',
      'package',
      'private',
      'protected',
      'public',
      'return',
      'short',
      'static',
      'strictfp',
      'super',
      'switch',
      'synchronized',
      'this',
      'throw',
      'throws',
      'transient',
      'try',
      'void',
      'volatile',
      'while',
    };

    if (reservedWords.contains(identifier)) {
      return '${identifier}_';
    }
    return identifier;
  }

  String capitalize(final String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  String formatConstant(final String name) => name;

  @override
  String formatType(final String name) => name;

  @override
  String formatField(final String name) => name;

  @override
  String formatMethod(final String name) => name.toLowerCase();
}
