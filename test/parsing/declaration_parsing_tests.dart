import 'package:dart_oncrpc/src/parser/ast.dart';
import 'package:dart_oncrpc/src/parser/parser.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('const declaration parsing', () {
    test('parse const declaration', () {
      final result = RPCParser.parse('''
      const MAX = 1234;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse const');
      final spec = result.value;
      expect(spec.constants.length, equals(1));
      expect(spec.constants[0].name, equals('MAX'));
      expect(spec.constants[0].value, equals(1234));
    });
  });
  group('simple type declaration parsing', () {
    test('parses typedef type prefix and keywords', () {
      // Ensure that the keyword exclusion rule applies after an identifier
      // is recognized
      final result = RPCParser.parse('''
      typedef int inst32_t;
      typedef int int32_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse identifiers');
      final error = RPCParser.parse('''
      typedef int float;
      typedef float void;
      ''');
      expect(error is Failure, isTrue, reason: 'Should not allow keywords');
    });
    test('parse not in strict mode', () {
      final definitions = [
        'struct node { int id; }; typedef struct node node_t;',
      ];
      for (final line in definitions) {
        final result = RPCParser.parse(line);
        expect(result is Success, isTrue, reason: 'String mode is off');
      }
    });
    test('parse typedef with reserved word', () {
      final definitions = [
        'typedef string string_t;',
        'typedef void void_t;',
        'typedef opaque opaque_t;',
        'typedef typedef typedef_t;',
        // rpcgen accepts this, should fail in strict mode
        'struct node { int id; }; typedef struct node node_t;',
      ];
      for (final line in definitions) {
        final result = RPCParser.parse(line, strict: true);
        expect(result is Failure, isTrue, reason: 'Fail on reserved words');
      }
    });
    test('parse typedef using void', () {
      final result = RPCParser.parse('''
      typedef void;
      ''');
      // This is valid according to the RFC grammar, but does not make sense
      expect(result is Failure, isTrue, reason: 'Fail on void');
    });
    test('parses typedef using simple primitives', () {
      final result = RPCParser.parse('''
      typedef int int32_t;
      typedef unsigned int uint32_t;
      typedef hyper int64_t;
      typedef unsigned hyper uint64_t;
      typedef float float_t;
      typedef double double_t;
      typedef quadruple bigint_t;
      typedef bool boolean_t;
      typedef unsigned unsigned_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse basic types');
      final spec = result.value;
      expect(spec.types.length, equals(9));
      expect(spec.types[0].name, equals('int32_t'));
      expect(spec.types[0].type, isA<IntTypeSpecifier>());
      expect(spec.types[1].name, equals('uint32_t'));
      expect(spec.types[1].type, isA<IntTypeSpecifier>());
      expect((spec.types[1].type as IntTypeSpecifier).isUnsigned, true);
      expect(spec.types[2].name, equals('int64_t'));
      expect(spec.types[2].type, isA<HyperTypeSpecifier>());
      expect(spec.types[3].name, equals('uint64_t'));
      expect(spec.types[3].type, isA<HyperTypeSpecifier>());
      expect((spec.types[3].type as HyperTypeSpecifier).isUnsigned, true);
      expect(spec.types[4].name, equals('float_t'));
      expect(spec.types[4].type, isA<FloatTypeSpecifier>());
      expect(spec.types[5].name, equals('double_t'));
      expect(spec.types[5].type, isA<DoubleTypeSpecifier>());
      expect(spec.types[6].name, equals('bigint_t'));
      expect(spec.types[6].type, isA<QuadrupleTypeSpecifier>());
      expect(spec.types[7].name, equals('boolean_t'));
      expect(spec.types[7].type, isA<BooleanTypeSpecifier>());
      expect(spec.types[8].name, equals('unsigned_t'));
      expect(spec.types[8].type, isA<IntTypeSpecifier>());
      expect((spec.types[8].type as IntTypeSpecifier).isUnsigned, true);
    });
    test('parses typedef using user defined types', () {
      final result = RPCParser.parse('''
      typedef foo foo_t;
      ''');
      expect(
        result is Success,
        isTrue,
        reason: 'Should parse user defined types',
      );
      final spec = result.value;
      expect(spec.types.length, equals(1));
      final definition = spec.types[0];
      expect(definition.name, equals('foo_t'));
      expect(definition.type, isA<UserDefinedTypeSpecifier>());
      expect((definition.type as UserDefinedTypeSpecifier).name, equals('foo'));
    });
    test('parses typedef using arrays', () {
      final result = RPCParser.parse('''
      const MAX = 10;
      typedef int array_t[2];
      typedef int array_t<>;
      typedef unsigned int array_t<4>;
      typedef opaque id_t[6];
      typedef opaque id_t<>;
      typedef opaque id_t<8>;
      typedef string array_t<>;
      typedef string array_t<10>;
      typedef string array_t<MAX>;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse array types');
      final spec = result.value;
      expect(spec.types.length, equals(9));
      expect(spec.types[0].name, equals('array_t'));
      expect(spec.types[0].type, isA<IntTypeSpecifier>());
      expect(spec.types[0].dimensions.length, equals(1));
      expect(spec.types[0].dimensions[0].isFixedLength, true);
      expect(spec.types[0].dimensions[0].size.asInt!, equals(2));
      expect(spec.types[1].name, equals('array_t'));
      expect(spec.types[1].type, isA<IntTypeSpecifier>());
      expect(spec.types[1].dimensions.length, equals(1));
      expect(spec.types[1].dimensions[0].isFixedLength, false);
      expect(spec.types[1].dimensions[0].size.asInt!, equals(-1));
      expect(spec.types[2].name, equals('array_t'));
      expect(spec.types[2].type, isA<IntTypeSpecifier>());
      expect(spec.types[2].dimensions.length, equals(1));
      expect(spec.types[2].dimensions[0].isFixedLength, false);
      expect(spec.types[2].dimensions[0].size.asInt!, equals(4));
      expect(spec.types[3].type is OpaqueTypeSpecifier, true);
      expect(spec.types[3].dimensions.length, equals(1));
      expect(spec.types[3].dimensions[0].isFixedLength, true);
      expect(spec.types[3].dimensions[0].size.asInt!, equals(6));
      expect(spec.types[4].name, equals('id_t'));
      expect(spec.types[4].type is OpaqueTypeSpecifier, true);
      expect(spec.types[4].dimensions.length, equals(1));
      expect(spec.types[4].dimensions[0].isFixedLength, false);
      expect(spec.types[4].dimensions[0].size.asInt!, equals(-1));
      expect(spec.types[5].name, equals('id_t'));
      expect(spec.types[5].type is OpaqueTypeSpecifier, true);
      expect(spec.types[5].dimensions.length, equals(1));
      expect(spec.types[5].dimensions[0].isFixedLength, false);
      expect(spec.types[5].dimensions[0].size.asInt!, equals(8));
      expect(spec.types[6].name, equals('array_t'));
      expect(spec.types[6].type is StringTypeSpecifier, true);
      expect(spec.types[6].dimensions.length, equals(1));
      expect(spec.types[6].dimensions[0].isFixedLength, false);
      expect(spec.types[6].dimensions[0].size.asInt!, equals(-1));
      expect(spec.types[7].name, equals('array_t'));
      expect(spec.types[7].type is StringTypeSpecifier, true);
      expect(spec.types[7].dimensions.length, equals(1));
      expect(spec.types[7].dimensions[0].isFixedLength, false);
      expect(spec.types[7].dimensions[0].size.asInt!, equals(10));
      expect(spec.types[8].name, equals('array_t'));
      expect(spec.types[8].type is StringTypeSpecifier, true);
      expect(spec.types[8].dimensions.length, equals(1));
      expect(spec.types[8].dimensions[0].isFixedLength, false);
      expect(spec.types[8].dimensions[0].size.asReference!, equals('MAX'));
    });
    test('parses typedef using pointers', () {
      final result = RPCParser.parse('''
      typedef int* int_ptr_t;
      typedef bool* bool_ptr_t;
      typedef foo* foo_ptr_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse pointers');
      final spec = result.value;
      expect(spec.types.length, equals(3));
    });
  });
  group('struct declaration parsing', () {
    test('parses simple struct', () {
      final result = RPCParser.parse('''
      struct node {
        int value;
        string name<20>;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse struct');
      final spec = result.value;
      final struct = spec.types[0] as StructTypeDefinition;
      final type = struct.type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, equals('value'));
      expect(type.fields[1].name, equals('name'));
    });
    test('parses basic nested struct', () {
      final result = RPCParser.parse('''
      struct node {
        int value;
        struct {
          string name<20>;
          int flags;
        } meta;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse struct');
      final spec = result.value;
      final struct = spec.types[0] as StructTypeDefinition;
      final type = struct.type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, equals('value'));
      expect(type.fields[1].name, equals('meta'));
      expect(type.fields[1].type is StructTypeSpecifier, true);
    });
    test('parses linked structures', () {
      final result = RPCParser.parse('''
      struct node {
        int value;
        node* next;
        int* optional;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse pointers');
      final spec = result.value;
      final struct = spec.types[0] as StructTypeDefinition;
      final type = struct.type as StructTypeSpecifier;
      expect(type.fields.length, equals(3));
      expect(type.fields[0].name, equals('value'));
      expect(type.fields[1].name, equals('next'));
      expect(type.fields[2].name, equals('optional'));
      expect(type.fields[1].type is PointerTypeSpecifier, true);
      final ptr = type.fields[1].type as PointerTypeSpecifier;
      expect(ptr.type, isA<UserDefinedTypeSpecifier>());
      expect((ptr.type as UserDefinedTypeSpecifier).name, equals('node'));
    });
    test('parses anonymous struct typedef declarations', () {
      final result = RPCParser.parse('''
      typedef struct { 
         int id; 
      } node_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse typedef');
      final spec = result.value;
      final type = spec.types[0];
      final struct = spec.types[0].type as StructTypeSpecifier;
      expect(type.name, equals('node_t'));
      expect(struct.fields.length, equals(1));
    });
    test('parses named struct typedef declarations', () {
      final result = RPCParser.parse('''
      struct node {
        int id;
      };
      typedef node node_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse struct');
      final spec = result.value;
      expect(spec.types.length, equals(2));
      final struct = spec.types[0] as StructTypeDefinition;
      final node = struct.type as StructTypeSpecifier;
      expect(node.fields.length, equals(1));
      expect(spec.types[1].name, equals('node_t'));
      expect(spec.types[1].type, isA<UserDefinedTypeSpecifier>());
      expect(
        (spec.types[1].type as UserDefinedTypeSpecifier).name,
        equals('node'),
      );
    });
    test('parses nested structs', () {
      final result = RPCParser.parse('''
      struct filled_circles {
        struct {
          struct {
             int x;
            int y;
          } point;
          int radius;
        } shape<>;
        unsigned int color;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse struct');
      final spec = result.value;
      expect(spec.types.length, equals(1));
      expect(spec.types[0].type is StructTypeSpecifier, true);
      final type = spec.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].type is StructTypeSpecifier, true);
      expect(type.fields[0].dimensions.length, equals(1));
      expect(type.fields[0].length!.isFixedLength, false);
    });
    test('parses declarations with constants', () {
      final result = RPCParser.parse('''
      const PIXELS = 307200;
      const DEPTH = 32;
        
      struct Screen {
        int pixels[PIXELS];
        opaque colormap[DEPTH];
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse with constants');
      final spec = result.value;
      expect(spec.constants.length, equals(2));
      expect(
        spec.constants.map((c) => c.name),
        containsAll(['PIXELS', 'DEPTH']),
      );
      expect(spec.types.length, equals(1));
    });
  });
  group('enum declaration parsing', () {
    test('parses named enum declarations', () {
      final result = RPCParser.parse('''
          enum level {
            NONE = 0,
            SOME = 1,
            ALL = 2
          };
          ''');
      expect(result is Success, isTrue, reason: 'Should parse enum');
      final spec = result.value;
      final definition = spec.types[0] as EnumTypeDefinition;
      expect(definition.name, equals('level'));
      final type = definition.type as EnumTypeSpecifier;
      expect(type.values.length, equals(3));
      expect(type.values[0].name, equals('NONE'));
      expect(type.values[0].value.asInt, equals(0));
      expect(type.values[1].name, equals('SOME'));
      expect(type.values[1].value.asInt, equals(1));
      expect(type.values[2].name, equals('ALL'));
      expect(type.values[2].value.asInt, equals(2));
    });
    test('parses anonymous enum declarations', () {
      final result = RPCParser.parse('''
          typedef enum {
            NONE = 0,
            SOME = 1,
            ALL = 2
          } level_t;
          ''');
      expect(result is Success, isTrue, reason: 'Should parse enum');
      final spec = result.value;
      final definition = spec.types[0];
      expect(definition.name, equals('level_t'));
      final type = definition.type as EnumTypeSpecifier;
      expect(type.values.length, equals(3));
      expect(type.values[0].name, equals('NONE'));
      expect(type.values[0].value.asInt, equals(0));
      expect(type.values[1].name, equals('SOME'));
      expect(type.values[1].value.asInt, equals(1));
      expect(type.values[2].name, equals('ALL'));
      expect(type.values[2].value.asInt, equals(2));
    });
    test('parses enum in struct declaration', () {
      final result = RPCParser.parse('''
          typedef struct {
            enum {
              NONE = 0,
              SOME = 1,
              ALL = 2
            } levels<10>;
            int value;
          } type_t;
          ''');
      expect(result is Success, isTrue, reason: 'Should parse enum');
      final spec = result.value;
      final definition = spec.types[0];
      expect(definition.name, equals('type_t'));
      final type = definition.type as StructTypeSpecifier;
      expect(type.fields[0].type, isA<EnumTypeSpecifier>());
      expect(type.fields[0].dimensions.length, equals(1));
      expect(type.fields[0].length!.size.asInt!, equals(10));
    });
  });
  group('union declaration parsing', () {
    test('parses union declaration', () {
      final result = RPCParser.parse('''
      union Result switch (bool success) {
      case TRUE:
        int value;
      case FALSE:
        string message<>;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse union');
      final spec = result.value;
      expect(spec.types.length, equals(1));
      expect(spec.types[0], isA<UnionTypeDefinition>());
      final union = spec.types[0] as UnionTypeDefinition;
      expect(union.type, isA<UnionTypeSpecifier>());
      final type = union.type as UnionTypeSpecifier;
      expect(type.arms.length, equals(2));
    });
    test('parses union typedef declaration', () {
      final result = RPCParser.parse('''
      typedef union switch (bool success) {
      case TRUE:
        int value;
      case FALSE:
        string message<>;
      } result_t;
      ''');
      expect(result is Success, isTrue, reason: 'Should parse union');
      final spec = result.value;
      expect(spec.types.length, equals(1));
      expect(spec.types[0], isA<TypeDefinition>());
      expect(spec.types[0].type, isA<UnionTypeSpecifier>());
      final union = spec.types[0].type as UnionTypeSpecifier;
      expect(union.arms.length, equals(2));
    });
    test('parses void in union declarations', () {
      final result = RPCParser.parse('''
      union Result switch (bool error) {
      case FALSE:
        void;
      case TRUE:
        int value;
      };
      ''');
      expect(result is Success, isTrue, reason: 'Should parse union with void');
      final spec = result.value;
      final union = spec.types[0] as UnionTypeDefinition;
      expect(union.type, isA<UnionTypeSpecifier>());
    });
  });
  group('miscellaneous', () {
    test('parses nested anonymous declarations', () {
      final result = RPCParser.parse('''
        struct Nested {
          struct {
            int x;
            int y;
          } point;
          enum {
            NONE = 0,
            SOME = 1,
            ALL = 2
          } level;
          union switch (int type) {
          case 0:
            int num;
          case 1:
            string text<>;
          default:
            void;
          } data;
        };
      ''');

      expect(
        result is Success,
        isTrue,
        reason: 'Should parse nested declarations',
      );
      final spec = result.value;
      final struct = spec.types[0] as StructTypeDefinition;
      final type = struct.type as StructTypeSpecifier;
      expect(type.fields.length, equals(3));

      // Check field types
      expect(type.fields[0].type, isA<StructTypeSpecifier>());
      expect(type.fields[1].type, isA<EnumTypeSpecifier>());
      expect(type.fields[2].type, isA<UnionTypeSpecifier>());
    });

    test('parses complex mixed declarations', () {
      final result = RPCParser.parse('''
        typedef int MyInt;
        const MAX_SIZE = 1024;
        
        struct Everything {
          // Simple types
          int simple;
          MyInt custom;
          
          // Arrays
          int fixed_array[10];
          int var_array<MAX_SIZE>;
          int unbounded_array<>;
          
          // Special types
          string name<255>;
          opaque data[64];
          opaque buffer<>;
          
          // Pointers
          int *optional;
          Everything *next;
          
          // Nested
          struct {
            float x;
            float y;
            float z;
          } vector;
        };
      ''');

      expect(result is Success, isTrue, reason: 'Should parse complex struct');
      final spec = result.value;

      // Should have typedef and struct
      expect(spec.types.where((t) => t.name == 'MyInt').length, equals(1));
      expect(spec.types.where((t) => t.name == 'Everything').length, equals(1));
    });
  });
}
