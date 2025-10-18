import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _xdrStructChecker = TypeChecker.fromUrl(
  'package:dart_oncrpc/src/xdr/xdr_annotations.dart#XdrStruct',
);
const _xdrUnionChecker = TypeChecker.fromUrl(
  'package:dart_oncrpc/src/xdr/xdr_annotations.dart#XdrUnion',
);
const _xdrFieldChecker = TypeChecker.fromUrl(
  'package:dart_oncrpc/src/xdr/xdr_annotations.dart#XdrField',
);

/// Generator for @XdrStruct and @XdrUnion annotated classes.
class XdrGenerator extends GeneratorForAnnotation<Object> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    if (element is! ClassElement) return '';

    final className = element.name;
    if (className == null) return '';

    if (_xdrStructChecker.hasAnnotationOfExact(element)) {
      return _generateStruct(className, element);
    } else if (_xdrUnionChecker.hasAnnotationOfExact(element)) {
      return _generateUnion(className, element);
    }

    return '';
  }

  /// Generate struct subclass
  String _generateStruct(final String className, final ClassElement clazz) {
    final genName = '_${className}Xdr';
    final fields = clazz.fields.where((f) => !f.isStatic).toList();
    final encodeBody = fields.map(_encodeField).join('\n    ');
    final decodeBody = fields.map(_decodeField).join('\n    ');
    final decodeParams = fields.map((f) => f.name).join(', ');

    final arrayHelpers = '''
  static List<$genName> decodeArray(XdrInputStream inp) {
    final len = inp.readInt();
    return List.generate(len, (_) => $genName.decode(inp));
  }

  static void encodeArray(List<$genName> list, XdrOutputStream out) {
    out.writeInt(list.length);
    for (final e in list) {
      e.encode(out);
    }
  }
''';

    return '''
class $genName implements XdrType {
  final ${fields.map((f) => '${f.type} ${f.name}').join(', ')};

  const $genName(${fields.map((f) => 'this.${f.name}').join(', ')});

  @override
  void encode(XdrOutputStream out) {
    $encodeBody
  }

  static $genName decode(XdrInputStream inp) {
    $decodeBody
    return $genName($decodeParams);
  }
$arrayHelpers
}
''';
  }

  /// Generate union subclass extending XdrUnion
  String _generateUnion(final String className, final ClassElement clazz) {
    final genName = '_${className}Xdr';

    final arms = <String>[];
    for (final f in clazz.fields.where((f) => !f.isStatic)) {
      final ann =
          _xdrFieldChecker.firstAnnotationOfExact(f, throwOnUnresolved: false);
      if (ann != null) {
        final disc = ann.getField('discriminant')!.toIntValue();
        arms.add('''
      case $disc:
        return $genName(disc, ${_decodeArm(f)});
''');
      }
    }

    return '''
class $genName extends XdrUnion {
  const $genName(int discriminant, XdrType? value) : super(discriminant, value);

  /// Static decode factory constructs the correct arm based on discriminant.
  static $genName decode(XdrInputStream inp) {
    final disc = inp.readInt();
    switch (disc) {
      ${arms.join("\n      ")}      default:
        return $genName(disc, null);
    }
  }
}
''';
  }

  /// Encode a field (primitive, nested XdrType, or List)
  String _encodeField(final FieldElement f) {
    final name = f.name;
    final type = f.type;
    if (type.isDartCoreInt) return 'out.writeInt($name);';
    if (type.isDartCoreString) return 'out.writeString($name);';

    if (_isList(type)) {
      final itemType = _listItemType(type);
      if (itemType == 'int') {
        return '''
out.writeInt($name.length);
for (final e in $name) {
  out.writeInt(e);
}''';
      } else if (itemType == 'String') {
        return '''
out.writeInt($name.length);
for (final e in $name) {
  out.writeString(e);
}''';
      } else {
        return '''
out.writeInt($name.length);
for (final e in $name) {
  e.encode(out);
}''';
      }
    }

    // Nested XdrType
    return '$name.encode(out);';
  }

  /// Decode a field (primitive, nested XdrType, or List)
  String _decodeField(final FieldElement f) {
    final name = f.name;
    final type = f.type;
    final typeStr = type.getDisplayString();

    if (type.isDartCoreInt) return 'final $name = inp.readInt();';
    if (type.isDartCoreString) return 'final $name = inp.readString();';

    if (_isList(type)) {
      final itemType = _listItemType(type);
      if (itemType == 'int') {
        return '''
final len_$name = inp.readInt();
final $name = List<int>.generate(len_$name, (_) => inp.readInt());''';
      } else if (itemType == 'String') {
        return '''
final len_$name = inp.readInt();
final $name = List<String>.generate(len_$name, (_) => inp.readString());''';
      } else {
        return '''
final len_$name = inp.readInt();
final $name = List<$itemType>.generate(len_$name, (_) => $itemType.decode(inp));''';
      }
    }

    // Nested XdrType
    return 'final $name = $typeStr.decode(inp);';
  }

  /// Generate code to decode a union arm
  String _decodeArm(final FieldElement f) {
    final type = f.type.getDisplayString();
    if (f.type.isDartCoreInt) return 'XdrInt()..decode(inp)';
    if (f.type.isDartCoreString) return 'XdrString()..decode(inp)';
    return '$type.decode(inp)';
  }

  bool _isList(final DartType type) => type.isDartCoreList;

  String _listItemType(final DartType type) {
    final t = type is ParameterizedType && type.typeArguments.isNotEmpty
        ? type.typeArguments.first
        : null;
    return t?.getDisplayString() ?? 'dynamic';
  }
}
