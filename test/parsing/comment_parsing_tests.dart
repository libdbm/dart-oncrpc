import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('Comment parsing', () {
    test('block and line comment', () {
      final result = RPCParser.parse('''
      const FIRST = 1234;
      /*
          Status of a service
       */
      enum status
      { // All good
          OK = 0x1,
          // Ooops
          BROKEN = 0x2
      };
      ''');
      expect(result is Success, true);
      expect(result.value.constants.length, 1);
      expect(result.value.constants[0].name, 'FIRST');
      expect(result.value.constants[0].value, 1234);
      expect(result.value.types.length, equals(1));
      expect(result.value.types[0], isA<EnumTypeDefinition>());
    });
    test('single line block comment', () {
      final result = RPCParser.parse('''
      const FIRST = 1234;
      /* Status of a service */
      enum status
      { // All good
          OK = 0x1,
          // Ooops
          BROKEN = 0x2
      };
      ''');
      expect(result is Success, true);
      expect(result.value.constants.length, 1);
      expect(result.value.constants[0].name, 'FIRST');
      expect(result.value.constants[0].value, 1234);
      expect(result.value.types.length, equals(1));
      expect(result.value.types[0], isA<EnumTypeDefinition>());
    });
  });
}
