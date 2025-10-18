import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:petitparser/petitparser.dart' hide anyOf;
import 'package:test/test.dart';

void main() {
  group('Error reporting', () {
    test('reports line and column for missing semicolon', () {
      final result = RPCParser.parse('''
      struct Point {
        int x
        int y;
      };
      ''');

      expect(result is Failure, true);
      final failure = result as Failure;
      expect(failure.message, contains('line'));
      expect(failure.message, contains('column'));
    });

    test('shows token context in error', () {
      final result = RPCParser.parse('''
      struct Test {
        int x;;  // Double semicolon
      };
      ''');

      expect(result is Failure, true, reason: 'Double semicolon should fail');
      if (result is Failure) {
        // New error format shows "expected" and includes position info
        expect(result.message, contains('expected'));
        expect(result.message, contains('at line'));
      }
    });

    test('shows line snippet with pointer', () {
      final result = RPCParser.parse('''
      const MAX = 100;
      struct Test {
        int field@;
      };
      ''');

      expect(result is Failure, true);
      final failure = result as Failure;
      // Should contain the actual line and a pointer
      expect(failure.message, contains('struct Test'));
      expect(failure.message, contains('^'));
    });

    test('handles end of file errors gracefully', () {
      final result = RPCParser.parse('''
      struct Test {
        int x;
      '''); // Missing closing brace

      expect(result is Failure, true);
      final failure = result as Failure;
      expect(failure.message, isNotEmpty);
    });

    test('provides helpful message for invalid type', () {
      // Note: 'invalid_type' might be interpreted as a user-defined type,
      // so let's use something that's definitely invalid
      final result = RPCParser.parse('''
      struct Test {
        123invalid field;
      };
      ''');

      expect(
        result is Failure,
        true,
        reason: '123invalid should not be a valid type name',
      );
      if (result is Failure) {
        // Should mention the position or token
        expect(
          result.message.toLowerCase(),
          anyOf(
            contains('unexpected'),
            contains('invalid'),
            contains('expected'),
            contains('near'),
          ),
        );
      }
    });
  });
}
