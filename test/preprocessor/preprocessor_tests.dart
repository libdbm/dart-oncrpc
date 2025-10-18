import 'dart:io';

import 'package:dart_oncrpc/src/preprocessor/preprocessor.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('XDRPreprocessor', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('preprocessor_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('processes simple file without directives', () {
      final file = File(path.join(tempDir.path, 'simple.x'))
        ..writeAsStringSync('''
      const TEST = 123;
      typedef int myint;
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(file.path);

      expect(result, contains('const TEST = 123;'));
      expect(result, contains('typedef int myint;'));
    });

    test('handles #define directives', () {
      final file = File(path.join(tempDir.path, 'defines.x'))
        ..writeAsStringSync('''
      #define MAX_SIZE 100
      #define MIN_SIZE 10

      const SIZE = MAX_SIZE;
      typedef opaque data[MAX_SIZE];
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(file.path);

      expect(result, contains('/* define: MAX_SIZE = 100 */'));
      expect(result, contains('/* define: MIN_SIZE = 10 */'));
      expect(result, contains('const SIZE = 100;'));
      expect(result, contains('typedef opaque data[100];'));
    });

    test('handles #ifdef/#ifndef/#endif', () {
      final file = File(path.join(tempDir.path, 'conditionals.x'))
        ..writeAsStringSync('''
      #define USE_FEATURE
      
      #ifdef USE_FEATURE
      const FEATURE_ENABLED = 1;
      #else
      const FEATURE_ENABLED = 0;
      #endif
      
      #ifndef SKIP_THIS
      const NOT_SKIPPED = 1;
      #endif
      
      #ifdef UNDEFINED_MACRO
      const SHOULD_NOT_APPEAR = 1;
      #endif
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(file.path);

      expect(result, contains('const FEATURE_ENABLED = 1;'));
      expect(result, contains('const NOT_SKIPPED = 1;'));
      expect(result, isNot(contains('const FEATURE_ENABLED = 0;')));
      expect(result, isNot(contains('const SHOULD_NOT_APPEAR = 1;')));
    });

    test('handles #include directives', () {
      // Create included file
      File(path.join(tempDir.path, 'types.x')).writeAsStringSync('''
      typedef int myint;
      const INCLUDED_CONST = 42;
      ''');

      // Create main file
      final main = File(path.join(tempDir.path, 'main.x'))
        ..writeAsStringSync('''
      #include "types.x"
      
      const MAIN_CONST = 100;
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(main.path);

      expect(result, contains('/* BEGIN include: types.x */'));
      expect(result, contains('typedef int myint;'));
      expect(result, contains('const INCLUDED_CONST = 42;'));
      expect(result, contains('/* END include: types.x */'));
      expect(result, contains('const MAIN_CONST = 100;'));
    });

    test('detects circular includes', () {
      // Create file A that includes B
      final aPath = path.join(tempDir.path, 'a.x');
      File(aPath).writeAsStringSync('#include "b.x"');

      // Create file B that includes A (circular)
      File(path.join(tempDir.path, 'b.x')).writeAsStringSync('#include "a.x"');

      final preprocessor = Preprocessor();

      expect(
        () => preprocessor.preprocess(aPath),
        throwsA(
          isA<PreprocessorError>().having(
            (e) => e.message,
            'message',
            contains('Circular include'),
          ),
        ),
      );
    });

    test('handles include guards', () {
      // Create file with include guard
      File(path.join(tempDir.path, 'header.x')).writeAsStringSync('''
      #ifndef HEADER_X
      #define HEADER_X

      typedef int myint;

      #endif
      ''');

      // Create main file that includes header twice
      final main = File(path.join(tempDir.path, 'main.x'))
        ..writeAsStringSync('''
      #include "header.x"
      #include "header.x"
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(main.path);

      // Should only include content once due to include guard
      final typedefCount = 'typedef int myint;'.allMatches(result).length;
      expect(typedefCount, 1);
    });

    test('supports command-line defines', () {
      final file = File(path.join(tempDir.path, 'cmdline.x'))
        ..writeAsStringSync('''
      #ifdef DEBUG
      const DEBUG_MODE = 1;
      #endif
      
      #ifdef VERSION
      const VERSION_STRING = VERSION;
      #endif
      ''');

      final preprocessor = Preprocessor(
        definitions: {'DEBUG': '', 'VERSION': '"1.0.0"'},
      );
      final result = preprocessor.preprocess(file.path);

      expect(result, contains('const DEBUG_MODE = 1;'));
      expect(result, contains('const VERSION_STRING = "1.0.0";'));
    });

    test('searches include paths', () {
      // Create include directory
      final includes = Directory(path.join(tempDir.path, 'include'))
        ..createSync();

      // Create file in include directory
      File(path.join(includes.path, 'types.x'))
          .writeAsStringSync('typedef int myint;');

      // Create main file that uses system include
      final main = File(path.join(tempDir.path, 'main.x'))
        ..writeAsStringSync('#include <types.x>');

      final preprocessor = Preprocessor(
        paths: [includes.path],
      );
      final result = preprocessor.preprocess(main.path);

      expect(result, contains('typedef int myint;'));
    });

    test('handles nested conditionals', () {
      final file = File(path.join(tempDir.path, 'nested.x'))
        ..writeAsStringSync('''
      #define OUTER
      #define INNER
      
      #ifdef OUTER
        const OUTER_DEFINED = 1;
        #ifdef INNER
          const BOTH_DEFINED = 1;
        #else
          const ONLY_OUTER = 1;
        #endif
      #else
        const NEITHER_DEFINED = 1;
      #endif
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(file.path);

      expect(result, contains('const OUTER_DEFINED = 1;'));
      expect(result, contains('const BOTH_DEFINED = 1;'));
      expect(result, isNot(contains('const ONLY_OUTER = 1;')));
      expect(result, isNot(contains('const NEITHER_DEFINED = 1;')));
    });

    test('reports errors with file and line information', () {
      final file = File(path.join(tempDir.path, 'error.x'))
        ..writeAsStringSync('''
      const A = 1;
      #include "nonexistent.x"
      const B = 2;
      ''');

      final preprocessor = Preprocessor();

      expect(
        () => preprocessor.preprocess(file.path),
        throwsA(
          isA<PreprocessorError>()
              .having(
                (e) => e.message,
                'message',
                contains('Cannot find include'),
              )
              .having((e) => e.line, 'line', 2),
        ),
      );
    });

    test('handles percent-style includes', () {
      File(path.join(tempDir.path, 'types.x'))
          .writeAsStringSync('typedef int myint;');

      final main = File(path.join(tempDir.path, 'main.x'))
        ..writeAsStringSync('''
      %include "types.x"
      const TEST = 1;
      ''');

      final preprocessor = Preprocessor();
      final result = preprocessor.preprocess(main.path);

      expect(result, contains('typedef int myint;'));
      expect(result, contains('const TEST = 1;'));
    });
  });
}
