import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('typedef parsing', () {
    test('void typedef', () {
      final result = RPCParser.parse('''
      typedef void;
      ''');
      expect(result is Failure, true);
    });
    // int
    test('int typedef', () {
      final result = RPCParser.parse('''
      typedef int int32_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('int32_t'));
      expect(result.value.types[0].type, isA<IntTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as IntTypeSpecifier;
      expect(type.isUnsigned, equals(false));
    });
    test('unsigned int typedef', () {
      final result = RPCParser.parse('''
      typedef unsigned int uint32_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('uint32_t'));
      expect(result.value.types[0].type, isA<IntTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as IntTypeSpecifier;
      expect(type.isUnsigned, equals(true));
    });
    // hyper
    test('hyper typedef', () {
      final result = RPCParser.parse('''
      typedef hyper hyper_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('hyper_t'));
      expect(result.value.types[0].type, isA<HyperTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as HyperTypeSpecifier;
      expect(type.isUnsigned, equals(false));
    });
    test('unsigned hyper typedef', () {
      final result = RPCParser.parse('''
      typedef unsigned hyper uhyper_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('uhyper_t'));
      expect(result.value.types[0].type, isA<HyperTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as HyperTypeSpecifier;
      expect(type.isUnsigned, equals(true));
    });
    test('float typedef', () {
      final result = RPCParser.parse('''
      typedef float float_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('float_t'));
      expect(result.value.types[0].type, isA<FloatTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
    });
    test('double typedef', () {
      final result = RPCParser.parse('''
      typedef double double_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('double_t'));
      expect(result.value.types[0].type, isA<DoubleTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
    });
    test('quadruple typedef', () {
      final result = RPCParser.parse('''
      typedef quadruple quadruple_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('quadruple_t'));
      expect(result.value.types[0].type, isA<QuadrupleTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
    });
    test('boolean typedef', () {
      final result = RPCParser.parse('''
      typedef bool boolean_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('boolean_t'));
      expect(result.value.types[0].type, isA<BooleanTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
    });
    test('user defined typedef', () {
      final result = RPCParser.parse('''
      typedef color color_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('color_t'));
      expect(result.value.types[0].type, isA<UserDefinedTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
    });
    test('typedef enum', () {
      final result = RPCParser.parse('''
      typedef enum {
         FIRST = 1,
         SECOND = 2 
      } enum_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('enum_t'));
      expect(result.value.types[0].type, isA<EnumTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as EnumTypeSpecifier;
      expect(type.values.length, equals(2));
    });
    test('typedef struct', () {
      final result = RPCParser.parse('''
      typedef struct {
         int first;
         int second; 
      } struct_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('struct_t'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
    });
    test('typedef union', () {
      final result = RPCParser.parse('''
      typedef union switch(bool d) {
         case TRUE:
            int first;
         case FALSE:
            int second;
         default:
            void; 
      } union_t;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('union_t'));
      expect(result.value.types[0].type, isA<UnionTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as UnionTypeSpecifier;
      expect(type.arms.length, equals(2));
      expect(type.otherwise, isNotNull);
      expect(type.otherwise, isA<VoidTypeDefinition>());
    });
    test('fixed array size with simple type', () {
      final result = RPCParser.parse('''
      typedef int FOO[100];
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('FOO'));
      expect(result.value.types[0].type, isA<IntTypeSpecifier>());
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, true);
      expect(result.value.types[0].length!.size.asInt, 100);
    });
    test('fixed array with enum', () {
      final result = RPCParser.parse('''
      typedef enum {
         FIRST = 1,
         SECOND = 2
      } map_t[256];
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('map_t'));
      expect(result.value.types[0].type, isA<EnumTypeSpecifier>());
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, true);
      expect(result.value.types[0].length!.size.asInt, 256);
    });
    test('fixed array with struct', () {
      final result = RPCParser.parse('''
      typedef struct {
         int size;
         hyper timestamp;
      } data_t[256];
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('data_t'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, true);
      expect(result.value.types[0].length!.size.asInt, 256);
    });
    test('variable array size with maximum', () {
      final result = RPCParser.parse('''
      typedef int FOO<100>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('FOO'));
      expect(result.value.types[0].type, isA<IntTypeSpecifier>());
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, 100);
    });
    test('variable array size without maximum', () {
      final result = RPCParser.parse('''
      typedef int FOO<>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<TypeDefinition>());
      expect(result.value.types[0].name, equals('FOO'));
      expect(result.value.types[0].type, isA<IntTypeSpecifier>());
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, -1);
    });
    test('pointer typedef', () {
      final result = RPCParser.parse('''
      typedef int * FOO;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<PointerTypeDefinition>());
      expect(result.value.types[0].name, equals('FOO'));
      expect(result.value.types[0].type, isA<PointerTypeSpecifier>());
      final type = result.value.types[0].type as PointerTypeSpecifier;
      expect(type.type, isA<IntTypeSpecifier>());
    });
    test('opaque typedef fixed size', () {
      final result = RPCParser.parse('''
      typedef opaque bytes_t[123];
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<OpaqueTypeDefinition>());
      expect(result.value.types[0].name, equals('bytes_t'));
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, true);
      expect(result.value.types[0].length!.size.asInt, 123);
    });
    test('opaque typedef variable length with minimum', () {
      final result = RPCParser.parse('''
      typedef opaque bytes_t<23>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<OpaqueTypeDefinition>());
      expect(result.value.types[0].name, equals('bytes_t'));
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, 23);
    });
    test('opaque typedef variable length', () {
      final result = RPCParser.parse('''
      typedef opaque bytes_t<>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<OpaqueTypeDefinition>());
      expect(result.value.types[0].name, equals('bytes_t'));
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, -1);
    });
    // Strings
    test('string typedef variable length with minimum', () {
      final result = RPCParser.parse('''
      typedef string strings_t<23>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StringTypeDefinition>());
      expect(result.value.types[0].name, equals('strings_t'));
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, 23);
    });
    test('string typedef variable length', () {
      final result = RPCParser.parse('''
      typedef string strings_t<>;
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StringTypeDefinition>());
      expect(result.value.types[0].name, equals('strings_t'));
      expect(result.value.types[0].length, isNotNull);
      expect(result.value.types[0].length!.isFixedLength, false);
      expect(result.value.types[0].length!.size.asInt, -1);
    });
  });
}
