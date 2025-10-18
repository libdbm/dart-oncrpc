import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

/*
      constant-def:
         "const" identifier "=" constant ";"

      constant:
         decimal-constant | hexadecimal-constant | octal-constant
 */
void main() {
  group('constant parsing', () {
    test('decimal constant', () {
      final result = RPCParser.parse('''
      const FIRST = 1234;
      ''');
      expect(result is Success, true);
      expect(result.value.constants.length, 1);
      expect(result.value.constants[0].name, 'FIRST');
      expect(result.value.constants[0].value, 1234);
    });
    test('hexadecimal constant', () {
      final result = RPCParser.parse('''
      const FIRST = 0x1234;
      ''');
      expect(result is Success, true);
      expect(result.value.constants.length, 1);
      expect(result.value.constants[0].name, 'FIRST');
      expect(result.value.constants[0].value, 0x1234);
    });
    test('octal constant', () {
      final result = RPCParser.parse('''
      const FIRST = 01234;
      ''');
      expect(result is Success, true);
      expect(result.value.constants.length, 1);
      expect(result.value.constants[0].name, 'FIRST');
      expect(result.value.constants[0].value, 668);
    });
  });
}
