import '../parser/ast.dart';
import 'type_inspector.dart';

/// Information about array dimensions
class ArrayInfo {
  const ArrayInfo({
    required this.isArray,
    required this.isFixedLength,
    required this.isMultiDimensional,
    required this.dimensionCount,
    required this.size,
  });

  final bool isArray;
  final bool isFixedLength;
  final bool isMultiDimensional;
  final int dimensionCount;
  final dynamic size; // int or String (reference)

  bool get isVariableLength => isArray && !isFixedLength;
}

/// Utility for handling array dimensions
class ArrayDimensionHandler {
  const ArrayDimensionHandler(this.inspector);

  final TypeInspector inspector;

  /// Get information about array dimensions
  ArrayInfo analyze(final List<ArraySpecifier> dimensions) {
    if (dimensions.isEmpty) {
      return const ArrayInfo(
        isArray: false,
        isFixedLength: false,
        isMultiDimensional: false,
        dimensionCount: 0,
        size: null,
      );
    }

    final firstDim = dimensions.first;
    return ArrayInfo(
      isArray: true,
      isFixedLength: firstDim.isFixedLength,
      isMultiDimensional: dimensions.length > 1,
      dimensionCount: dimensions.length,
      size: inspector.getSize(firstDim),
    );
  }

  /// Check if dimensions represent a simple array (not multi-dimensional)
  bool isSimpleArray(final List<ArraySpecifier> dimensions) =>
      dimensions.length == 1;

  /// Get the size of the first dimension
  dynamic getFirstDimensionSize(final List<ArraySpecifier> dimensions) {
    if (dimensions.isEmpty) return null;
    return inspector.getSize(dimensions.first);
  }

  /// Check if this is a fixed-length opaque array
  bool isFixedOpaque(
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions,
  ) =>
      inspector.isOpaque(type) &&
      dimensions.isNotEmpty &&
      dimensions.first.isFixedLength;

  /// Check if this is a variable-length opaque array
  bool isVariableOpaque(
    final TypeSpecifier type,
    final List<ArraySpecifier> dimensions,
  ) =>
      inspector.isOpaque(type) &&
      dimensions.isNotEmpty &&
      !dimensions.first.isFixedLength;

  /// Format a size value (handles both int and string references)
  String formatSize(final dynamic size) {
    if (size is int) return size.toString();
    if (size is String) return size;
    return '0';
  }

  /// Get max size for variable-length arrays
  String maxSize(final ArraySpecifier spec) {
    final size = inspector.getSize(spec);
    if (size is int && size > 0) return size.toString();
    return '~0'; // Unlimited
  }
}
