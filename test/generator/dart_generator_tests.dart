import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:test/test.dart';

void main() {
  group('dart code generation', () {
    test('simple constant generation', () {
      final parsed = RPCParser.parse('''
      const FIRST = 1234;
      const SECOND = 0x1234;
      const THIRD = 01234;
      ''');
      final generator = DartGenerator(parsed.value, {});
      final result = generator.generate();
      final output = result.artifacts.first.content;
      // The generator normalizes numeric literals to decimal
      expect(output, contains('const FIRST = 1234;'));
      expect(output, contains('const SECOND = 4660;'));
      expect(output, contains('const THIRD = 668;'));
    });
    test('simple enum generation', () {
      final parsed = RPCParser.parse('''
      enum color {
	      RED = 0,
	      GREEN = 1,
	      BLUE = 2
      };
      ''');
      final generator = DartGenerator(parsed.value, {});
      final result = generator.generate();
      final output = result.artifacts.first.content;
      expect(output, contains('enum color {'));
      expect(output, contains('red(0),'));
      expect(output, contains('green(1),'));
      expect(output, contains('blue(2),'));
      expect(output, contains('factory color.fromValue'));
    });
    test('struct', () {
      final parsed = RPCParser.parse('''
      const MAXNAMELEN = 255;
      struct file_t {
        string name<MAXNAMELEN>;
        unsigned hyper size;
        unsigned int modified_on;
        unsigned int created_on;
      };
      ''');
      final generator = DartGenerator(parsed.value, {});
      final result = generator.generate();
      final output = result.artifacts.first.content;
      expect(output, contains('class file_t {'));
      expect(output, contains('final String name;'));
      expect(output, contains('final BigInt size;'));
      expect(output, contains('final int modified_on;'));
      expect(output, contains('final int created_on;'));
      expect(output, contains('void encode(XdrOutputStream stream)'));
      expect(output, contains('static file_t decode(XdrInputStream stream)'));
    });
  });

  test('respects generation flags', () {
    final parsed = RPCParser.parse('''
      const VALUE = 42;
      program SAMPLE {
        version V1 {
          void PING(void) = 1;
        } = 1;
      } = 0x40000000;
      ''');

    final generator = DartGenerator(parsed.value, {
      'generateTypes': false,
      'generateClient': true,
      'generateServer': false,
    });

    final output = generator.generate().artifacts.first.content;
    expect(output, contains('const VALUE = 42;'));
    expect(output, contains('class SampleClient'));
    expect(output, isNot(contains('enum')));
  });

  test('omits all sections when disabled', () {
    final parsed = RPCParser.parse('struct foo { int value; };');
    final generator = DartGenerator(parsed.value, {
      'generateTypes': false,
      'generateClient': false,
      'generateServer': false,
    });

    final output = generator.generate().artifacts.first.content;
    expect(output.trim(), isEmpty);
  });
}
