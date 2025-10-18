import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('struct parsing', () {
    test('simple struct', () {
      final result = RPCParser.parse('''
      // Simple struct
      struct coord {
 	      int x;
 	      hyper y;
 	    };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('coord'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'x');
      expect(type.fields[0].type, isA<IntTypeSpecifier>());
      expect(type.fields[1].name, 'y');
      expect(type.fields[1].type, isA<HyperTypeSpecifier>());
    });
    test('nested structs', () {
      final result = RPCParser.parse('''
      struct data {
 	      struct {
 	         int coord;
 	         struct {
 	           int units;
 	           int amount;
 	         } value;
 	      } x;
        struct {
 	         int coord;
 	         int value;
 	      } y;
 	    };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('data'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'x');
      expect(type.fields[0].type, isA<StructTypeSpecifier>());
      expect(type.fields[0].length, isNull);
      expect(type.fields[1].name, 'y');
      expect(type.fields[1].type, isA<StructTypeSpecifier>());
      expect(type.fields[1].length, isNull);
    });
    test('nested enum', () {
      final result = RPCParser.parse('''
      struct point {
 	      enum {
 	         RED = 1,
 	         GREEN = 2,
 	         BLUE = 3
 	      } color;
        int coord;
 	    };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('point'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'color');
      expect(type.fields[0].type, isA<EnumTypeSpecifier>());
      expect(type.fields[0].length, isNull);
      expect(type.fields[1].name, 'coord');
      expect(type.fields[1].type, isA<IntTypeSpecifier>());
      expect(type.fields[1].length, isNull);
    });
    test('nested union', () {
      final result = RPCParser.parse('''
      struct point {
 	      union switch (bool opted) {
         case TRUE:
            int value;
         case FALSE:
            void;
         } value;
        int coord;
 	    };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('point'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'value');
      expect(type.fields[0].type, isA<UnionTypeSpecifier>());
      expect(type.fields[0].length, isNull);
      expect(type.fields[1].name, 'coord');
      expect(type.fields[1].type, isA<IntTypeSpecifier>());
      expect(type.fields[1].length, isNull);
    });
    test('struct with pointer member', () {
      final result = RPCParser.parse('''
      struct stringentry {
        string item<>;
        stringentry *next;
      };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('stringentry'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'item');
      expect(type.fields[0].type, isA<StringTypeSpecifier>());
      expect(type.fields[0].length, isNotNull);
      expect(type.fields[1].name, 'next');
      expect(type.fields[1].type, isA<PointerTypeSpecifier>());
    });
    test('struct with fixed length string array should fail', () {
      final result = RPCParser.parse('''
      struct stringentry {
        string items[2];
        stringentry *next;
      };
      ''');
      expect(result is Failure, true);
    });
    test('struct with variable length string array', () {
      final result = RPCParser.parse('''
      struct stringentry {
           string items<2>;
           stringentry *next;
        };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('stringentry'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'items');
      expect(type.fields[0].type, isA<StringTypeSpecifier>());
      expect(type.fields[0].length, isNotNull);
      expect(type.fields[0].length?.size.asInt, 2);
      expect(type.fields[0].length?.isFixedLength, false);
      expect(type.fields[1].name, 'next');
      expect(type.fields[1].type, isA<PointerTypeSpecifier>());
    });
    test('struct with unqualified variable length', () {
      final result = RPCParser.parse('''
      struct stringentry {
        string items<>;
        stringentry next<1>;
      };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('stringentry'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);

      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(2));
      expect(type.fields[0].name, 'items');
      expect(type.fields[0].type, isA<StringTypeSpecifier>());
      expect(type.fields[0].length, isNotNull);
      expect(type.fields[0].length?.size.asInt, -1);
      expect(type.fields[0].length?.isFixedLength, false);
      expect(type.fields[1].name, 'next');
      expect(type.fields[1].type, isA<UserDefinedTypeSpecifier>());
      expect(type.fields[1].length, isNotNull);
      expect(type.fields[1].length?.size.asInt, 1);
      expect(type.fields[1].length?.isFixedLength, false);
    });
    test('struct with struct fixed length field', () {
      final result = RPCParser.parse('''
      struct entry {
        struct {
          int x;
          int y;
        } values[100];  
      };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<StructTypeDefinition>());
      expect(result.value.types[0].name, equals('entry'));
      expect(result.value.types[0].type, isA<StructTypeSpecifier>());
      expect(result.value.types[0].length, isNull);

      final type = result.value.types[0].type as StructTypeSpecifier;
      expect(type.fields.length, equals(1));
      expect(type.fields[0].name, 'values');
      expect(type.fields[0].type, isA<StructTypeSpecifier>());
      expect(type.fields[0].length!.isFixedLength, true);
      expect(type.fields[0].length!.size.asInt, 100);
    });
  });
}
