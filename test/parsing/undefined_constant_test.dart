import 'package:dart_oncrpc/src/parser/parser.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('undefined constant detection', () {
    test('accepts valid constant references', () {
      final result = RPCParser.parse('''
        const MAX_SIZE = 100;
        const MIN_SIZE = 10;
        
        struct Buffer {
          int data[MAX_SIZE];
          opaque padding[MIN_SIZE];
        };
      ''');

      expect(
        result is Success,
        isTrue,
        reason: 'Should parse when constants are defined',
      );
      final spec = result.value;
      expect(spec.constants.length, equals(2));
      expect(spec.types.length, equals(1));
    });

    test('rejects undefined constant in array size', () {
      final result = RPCParser.parse('''
        struct Buffer {
          int data[UNDEFINED_SIZE];
        };
      ''');

      expect(
        result is Failure,
        isTrue,
        reason: 'Should fail when constant is undefined',
      );
      if (result is Failure) {
        expect(
          result.message,
          contains('Undefined constant'),
          reason: 'Error should mention undefined constant',
        );
      }
    });

    test('rejects multiple undefined constants', () {
      final result = RPCParser.parse('''
        const DEFINED = 100;
        
        struct Buffer {
          int data[UNDEFINED1];
          opaque padding[UNDEFINED2];
          float values[DEFINED];
        };
      ''');

      expect(
        result is Failure,
        isTrue,
        reason: 'Should fail when constants are undefined',
      );
      if (result is Failure) {
        expect(
          result.message,
          contains('Undefined constant'),
          reason: 'Error should mention undefined constants',
        );
        // Both undefined constants should be reported
        expect(result.message, contains('UNDEFINED1'));
        expect(result.message, contains('UNDEFINED2'));
      }
    });

    test('accepts forward-referenced constants', () {
      final result = RPCParser.parse('''
        struct Buffer {
          int data[MAX_SIZE];
        };
        
        const MAX_SIZE = 100;
      ''');

      expect(
        result is Success,
        isTrue,
        reason: 'Should accept forward references (constants collected first)',
      );
      final spec = result.value;
      expect(spec.constants.length, equals(1));
      expect(spec.types.length, equals(1));
    });

    test('distinguishes between numeric literals and constant references', () {
      final result1 = RPCParser.parse('''
        struct Buffer {
          int data[100];  // Numeric literal - always valid
        };
      ''');

      expect(
        result1 is Success,
        isTrue,
        reason: 'Numeric literals should always be valid',
      );

      final result2 = RPCParser.parse('''
        struct Buffer {
          int data[SIZE];  // Identifier - must be defined
        };
      ''');

      expect(
        result2 is Failure,
        isTrue,
        reason: 'Identifiers must be defined as constants',
      );
    });
  });
}
