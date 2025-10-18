import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/core.dart';
import 'package:test/test.dart';

void main() {
  group('enum parsing', () {
    test('simple enum', () {
      final result = RPCParser.parse('''
      enum color {
 	      RED = 0,
 	      GREEN = 1,
 	      BLUE = 2
      };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<EnumTypeDefinition>());
      expect(result.value.types[0].name, equals('color'));
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as EnumTypeSpecifier;
      expect(type.values.length, equals(3));
      expect(type.values[0].name, 'RED');
      expect((type.values[0].value as IntegerLiteral).value, 0);
      expect(type.values[1].name, 'GREEN');
      expect((type.values[1].value as IntegerLiteral).value, 1);
      expect(type.values[2].name, 'BLUE');
      expect((type.values[2].value as IntegerLiteral).value, 2);
    });
    test('different value types', () {
      final result = RPCParser.parse('''
      const IDENT = 1;
      enum test {
        first = 1234,
        second = 0x1234,
        third = 01234,
        fourth = IDENT
      };
      ''');
      expect(result is Success, true);
      expect(result.value.types.length, 1);
      expect(result.value.types[0], isA<EnumTypeDefinition>());
      expect(result.value.types[0].name, equals('test'));
      expect(result.value.types[0].length, isNull);
      final type = result.value.types[0].type as EnumTypeSpecifier;
      expect(type.values.length, equals(4));
      expect(type.values[0].name, 'first');
      expect((type.values[0].value as IntegerLiteral).value, 1234);
      expect(type.values[1].name, 'second');
      expect((type.values[1].value as IntegerLiteral).value, 0x1234);
      expect(type.values[2].name, 'third');
      expect((type.values[2].value as IntegerLiteral).value, 668);
      expect(type.values[3], isA<Constant<Value>>());
      expect(type.values[3].name, 'fourth');
      expect((type.values[3].value as ReferenceValue).asReference!, 'IDENT');
    });
  });
}
