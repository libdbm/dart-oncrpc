import 'package:dart_oncrpc/src/parser/ast.dart';
import 'package:dart_oncrpc/src/parser/parser.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('Multi-dimensional array parsing', () {
    test('parses fixed-length arrays', () {
      final result = RPCParser.parse('''
        struct Matrix2D {
          int values[1];
          float data[2][3];
          bool flags[4][5][6];
        };
      ''');

      expect(result is Success, isTrue, reason: 'Should parse 2D arrays');
      final spec = result.value;
      final struct = spec.types[0] as StructTypeDefinition;
      final type = struct.type as StructTypeSpecifier;

      expect(type.fields.length, equals(3));

      // Check first field - int values[1]
      final field1 = type.fields[0];
      expect(field1.name, equals('values'));
      expect(field1.type, isA<IntTypeSpecifier>());
      expect(field1.dimensions.length, equals(1));
      expect(field1.dimensions[0].size.asInt, equals(1));
      expect(field1.dimensions[0].isFixedLength, isTrue);

      // Check second field - float data[2][3]
      final field2 = type.fields[1];
      expect(field2.name, equals('data'));
      expect(field2.type, isA<FloatTypeSpecifier>());
      expect(field2.dimensions.length, equals(2));
      expect(field2.dimensions[0].size.asInt, equals(2));
      expect(field2.dimensions[0].isFixedLength, isTrue);
      expect(field2.dimensions[1].size.asInt, equals(3));
      expect(field2.dimensions[1].isFixedLength, isTrue);

      // Check third field - bool flags[4][5][6]
      final field3 = type.fields[2];
      expect(field3.name, equals('flags'));
      expect(field3.type, isA<BooleanTypeSpecifier>());
      expect(field3.dimensions.length, equals(3));
      expect(field3.dimensions[0].size.asInt, equals(4));
      expect(field3.dimensions[0].isFixedLength, isTrue);
      expect(field3.dimensions[1].size.asInt, equals(5));
      expect(field3.dimensions[1].isFixedLength, isTrue);
      expect(field3.dimensions[2].size.asInt, equals(6));
      expect(field3.dimensions[2].isFixedLength, isTrue);
    });
  });
}
