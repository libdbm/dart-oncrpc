import 'dart:io';

import 'package:dart_oncrpc/src/parser/parser.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void main() {
  group('RPC program parsing tests', () {
    test('should parse a complete RPC specification', () {
      const simpleRpc = '''
        /*
         * SAMPLE
         */
        const TEST_CONST = 42;
        
        enum Status {
          OK = 0,
          ERROR = 1
        };
        
        struct Point {
          int x;
          int y;
        };
        
        program TestProgram {
          version TestVersion {
            Status test(Point) = 1;
            Point  translate(Point, int) = 2;
            int    status(void) = 3;
          } = 1;
        } = 100000;
      ''';

      // Parse the RPC specification
      final result = RPCParser.parse(simpleRpc);
      expect(result is Success, isTrue);

      final spec = result.value;
      expect(spec.constants.length, equals(1));
      expect(spec.types.length, equals(2)); // enum and struct
      expect(spec.programs.length, equals(1));
      final program = spec.programs[0];
      expect(program.versions.length, equals(1));
      final version = program.versions[0];
      expect(version.procedures.length, equals(3));
      expect(version.procedures[0].name, equals('test'));
      expect(version.procedures[0].arguments.length, equals(1));
      expect(version.procedures[1].name, equals('translate'));
      expect(version.procedures[1].arguments.length, equals(2));
      expect(version.procedures[2].name, equals('status'));
      expect(version.procedures[2].arguments.length, equals(1));
    });
    test('should parse existing definition with strict set to false', () async {
      // Test with actual .x files in the test/fixtures directory
      final files = [
        'test/fixtures/definitions/ping.x',
        'test/fixtures/definitions/time.x',
        'test/fixtures/definitions/strlen.x',
        'test/fixtures/definitions/mount.x',
        'test/fixtures/definitions/nfs.x',
        'test/fixtures/definitions/nfs4.x',
        'test/fixtures/definitions/nlm.x',
        'test/fixtures/definitions/nsm.x',
        'test/fixtures/definitions/portmap.x',
      ];
      for (final path in files) {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final result = RPCParser.parse(content);
          print(result);
          expect(result is Success, isTrue, reason: 'Failed to parse $path');
        } else {
          print('missing $path');
        }
      }
    });
  });
}
