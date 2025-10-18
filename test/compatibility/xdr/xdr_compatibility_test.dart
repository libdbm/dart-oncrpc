import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

// Constants matching test_types.x
const maxStringLen = 255;
const arraySize = 5;

// Enum matching Color in test_types.x
enum Color {
  red(0),
  green(1),
  blue(2);

  final int value;

  // ignore: sort_constructors_first
  const Color(this.value);

  static Color fromValue(int value) =>
      Color.values.firstWhere((e) => e.value == value);
}

// Struct matching Point in test_types.x
@immutable
class Point {
  const Point({required this.x, required this.y});
  final int x;
  final int y;

  // ignore: prefer_constructors_over_static_methods
  static Point decode(XdrInputStream stream) {
    final x = stream.readInt();
    final y = stream.readInt();
    return Point(x: x, y: y);
  }

  void encode(XdrOutputStream stream) {
    stream
      ..writeInt(x)
      ..writeInt(y);
  }

  @override
  String toString() => 'Point(x: $x, y: $y)';

  @override
  bool operator ==(Object other) =>
      other is Point && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

// Struct matching Person in test_types.x
class Person {
  Person({
    required this.name,
    required this.age,
    required this.favoriteColor,
    required this.scores,
  });
  final String name;
  final int age;
  final Color favoriteColor;
  final List<int> scores;

  // ignore: prefer_constructors_over_static_methods
  static Person decode(XdrInputStream stream) {
    final name = stream.readString();
    final age = stream.readInt(); // unsigned int in XDR
    final favoriteColor = Color.fromValue(stream.readInt());
    final scores = <int>[];
    for (int i = 0; i < arraySize; i++) {
      scores.add(stream.readInt());
    }
    return Person(
      name: name,
      age: age,
      favoriteColor: favoriteColor,
      scores: scores,
    );
  }

  void encode(XdrOutputStream stream) {
    stream
      ..writeString(name)
      ..writeInt(age) // unsigned int in XDR
      ..writeInt(favoriteColor.value);
    scores.forEach(stream.writeInt);
  }

  @override
  String toString() =>
      'Person(name: $name, age: $age, color: $favoriteColor, scores: $scores)';
}

// Union matching Result in test_types.x
abstract class Result {
  Result(this.status);
  final int status;

  static Result decode(XdrInputStream stream) {
    final status = stream.readInt();
    switch (status) {
      case 0:
        return ResultSuccess(Person.decode(stream));
      case 1:
        return ResultError(stream.readString());
      default:
        return ResultVoid();
    }
  }

  void encode(XdrOutputStream stream);
}

class ResultSuccess extends Result {
  ResultSuccess(this.person) : super(0);
  final Person person;

  @override
  void encode(XdrOutputStream stream) {
    stream.writeInt(status);
    person.encode(stream);
  }

  @override
  String toString() => 'ResultSuccess($person)';
}

class ResultError extends Result {
  ResultError(this.errorMessage) : super(1);
  final String errorMessage;

  @override
  void encode(XdrOutputStream stream) {
    stream
      ..writeInt(status)
      ..writeString(errorMessage);
  }

  @override
  String toString() => 'ResultError($errorMessage)';
}

class ResultVoid extends Result {
  ResultVoid() : super(2);

  @override
  void encode(XdrOutputStream stream) {
    stream.writeInt(status);
  }

  @override
  String toString() => 'ResultVoid()';
}

// ComplexType matching the struct in test_types.x
// ComplexType matching the struct in test_types.x
class ComplexType {
  ComplexType({
    required this.bigNumber,
    required this.unsignedBig,
    required this.floatVal,
    required this.doubleVal,
    required this.boolVal,
    required this.binaryData,
    this.optionalPoint,
  });
  final BigInt bigNumber;
  final BigInt unsignedBig;
  final double floatVal;
  final double doubleVal;
  final bool boolVal;
  final Uint8List binaryData;
  final Point? optionalPoint;

  // ignore: prefer_constructors_over_static_methods
  static ComplexType decode(XdrInputStream stream) {
    final bigNumber = stream.readHyper();
    final unsignedBig = stream.readUnsignedHyper();
    final floatVal = stream.readFloat();
    final doubleVal = stream.readDouble();
    final boolVal = stream.readBoolean();

    // Read opaque data
    final binaryData = stream.readOpaque();

    // Read optional point
    final hasPoint = stream.readBoolean();
    final optionalPoint = hasPoint ? Point.decode(stream) : null;

    return ComplexType(
      bigNumber: bigNumber,
      unsignedBig: unsignedBig,
      floatVal: floatVal,
      doubleVal: doubleVal,
      boolVal: boolVal,
      binaryData: binaryData,
      optionalPoint: optionalPoint,
    );
  }

  void encode(XdrOutputStream stream) {
    stream
      ..writeHyper(bigNumber)
      ..writeUnsignedHyper(unsignedBig)
      ..writeFloat(floatVal)
      ..writeDouble(doubleVal)
      ..writeBoolean(boolVal)
      // Write opaque data
      ..writeOpaque(binaryData)
      // Write optional point
      ..writeBoolean(optionalPoint != null);
    if (optionalPoint != null) {
      optionalPoint!.encode(stream);
    }
  }

  @override
  String toString() => 'ComplexType(big: $bigNumber, unsigned: $unsignedBig, '
      'float: $floatVal, double: $doubleVal, bool: $boolVal, '
      'data: ${binaryData.length} bytes, point: $optionalPoint)';
}

void main() {
  group('XDR Compatibility Tests', () {
    setUpAll(() async {
      // Check if rpcgen is available
      final rpcgenCheck = await Process.run('which', ['rpcgen']);
      if (rpcgenCheck.exitCode != 0) {
        throw Exception(
          'rpcgen not found. Please install rpcgen to run XDR compatibility tests.',
        );
      }

      // Clean up any existing generated files
      final workDir = Directory('test/compatibility/xdr');
      await Process.run(
        'rm',
        [
          '-f',
          'test_types_xdr.c',
          'test_types.h',
          'serialize_test_data',
          'verify_dart_xdr',
        ],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'rm',
        ['-rf', 'output'],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'rm',
        ['-rf', 'output_dart'],
        workingDirectory: workDir.path,
      );

      // Generate XDR code with rpcgen
      await Process.run(
        'rpcgen',
        ['-h', 'test_types.x', '-o', 'test_types.h'],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'rpcgen',
        ['-c', 'test_types.x', '-o', 'test_types_xdr.c'],
        workingDirectory: workDir.path,
      );

      // Compile C test programs
      await Process.run(
        'cc',
        [
          '-o',
          'serialize_test_data',
          'serialize_test_data.c',
          'test_types_xdr.c',
          '-Wno-deprecated-non-prototype',
        ],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'cc',
        [
          '-o',
          'verify_dart_xdr',
          'verify_dart_xdr.c',
          'test_types_xdr.c',
          '-Wno-deprecated-non-prototype',
        ],
        workingDirectory: workDir.path,
      );

      // Create output directory
      await Directory('test/compatibility/xdr/output').create();

      // Generate test data with C
      await Process.run(
        './serialize_test_data',
        [],
        workingDirectory: workDir.path,
      );

      // Generate test data with Dart
      await Process.run(
        'dart',
        ['run', 'test/compatibility/xdr/generate_dart_xdr.dart'],
      );
    });

    tearDownAll(() async {
      // Clean up generated files
      final workDir = Directory('test/compatibility/xdr');
      await Process.run(
        'rm',
        [
          '-f',
          'test_types_xdr.c',
          'test_types.h',
          'serialize_test_data',
          'verify_dart_xdr',
        ],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'rm',
        ['-rf', 'output'],
        workingDirectory: workDir.path,
      );
      await Process.run(
        'rm',
        ['-rf', 'output_dart'],
        workingDirectory: workDir.path,
      );
    });

    test('should deserialize Point from rpcgen-generated data', () async {
      final file = File('test/compatibility/xdr/output/point.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final point = Point.decode(stream);

      expect(point.x, equals(100));
      expect(point.y, equals(200));
    });

    test('should deserialize Person from rpcgen-generated data', () async {
      final file = File('test/compatibility/xdr/output/person.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final person = Person.decode(stream);

      expect(person.name, equals('Alice Johnson'));
      expect(person.age, equals(30));
      expect(person.favoriteColor, equals(Color.green));
      expect(person.scores, equals([10, 20, 30, 40, 50]));
    });

    test('should deserialize Result (success) from rpcgen-generated data',
        () async {
      final file = File('test/compatibility/xdr/output/result_success.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final result = Result.decode(stream);

      expect(result, isA<ResultSuccess>());
      final success = result as ResultSuccess;
      expect(success.person.name, equals('Bob Smith'));
      expect(success.person.age, equals(25));
      expect(success.person.favoriteColor, equals(Color.blue));
      expect(success.person.scores, equals([5, 10, 15, 20, 25]));
    });

    test('should deserialize Result (error) from rpcgen-generated data',
        () async {
      final file = File('test/compatibility/xdr/output/result_error.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final result = Result.decode(stream);

      expect(result, isA<ResultError>());
      final error = result as ResultError;
      expect(error.errorMessage, equals('Something went wrong'));
    });

    test('should deserialize ComplexType from rpcgen-generated data', () async {
      final file = File('test/compatibility/xdr/output/complex.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final complex = ComplexType.decode(stream);

      expect(complex.bigNumber, equals(BigInt.parse('9223372036854775807')));
      expect(complex.unsignedBig, equals(BigInt.parse('18446744073709551615')));
      expect(complex.floatVal, closeTo(3.14159, 0.00001));
      expect(complex.doubleVal, closeTo(2.718281828, 0.000000001));
      expect(complex.boolVal, isTrue);
      expect(complex.binaryData.length, equals(10));
      expect(
        complex.binaryData,
        equals(Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])),
      );
      expect(complex.optionalPoint, isNotNull);
      expect(complex.optionalPoint!.x, equals(42));
      expect(complex.optionalPoint!.y, equals(84));
    });

    test('should deserialize ComplexType with nulls from rpcgen-generated data',
        () async {
      final file = File('test/compatibility/xdr/output/complex_null.xdr');
      final bytes = await file.readAsBytes();
      final stream = XdrInputStream(bytes);

      final complex = ComplexType.decode(stream);

      expect(complex.bigNumber, equals(BigInt.parse('-9223372036854775808')));
      expect(complex.unsignedBig, equals(BigInt.zero));
      expect(complex.floatVal, closeTo(-123.456, 0.001));
      expect(complex.doubleVal, closeTo(-987.654321, 0.000001));
      expect(complex.boolVal, isFalse);
      expect(complex.binaryData.length, equals(0));
      expect(complex.optionalPoint, isNull);
    });

    test('should round-trip serialize and deserialize Point', () {
      const original = Point(x: 42, y: 84);

      // Encode
      final output = XdrOutputStream();
      original.encode(output);
      final bytes = Uint8List.fromList(output.bytes);

      // Decode
      final input = XdrInputStream(bytes);
      final decoded = Point.decode(input);

      expect(decoded, equals(original));
    });

    test('should round-trip serialize and deserialize Person', () {
      final original = Person(
        name: 'Test User',
        age: 35,
        favoriteColor: Color.red,
        scores: [100, 90, 80, 70, 60],
      );

      // Encode
      final output = XdrOutputStream();
      original.encode(output);
      final bytes = Uint8List.fromList(output.bytes);

      // Decode
      final input = XdrInputStream(bytes);
      final decoded = Person.decode(input);

      expect(decoded.name, equals(original.name));
      expect(decoded.age, equals(original.age));
      expect(decoded.favoriteColor, equals(original.favoriteColor));
      expect(decoded.scores, equals(original.scores));
    });

    test('should verify XDR padding is correct', () {
      // Test string padding
      final output = XdrOutputStream()
        ..writeString('ABC'); // 3 bytes + 1 pad byte
      expect(
        output.bytes.length,
        equals(8),
      ); // 4 (length) + 3 (string) + 1 (pad)

      // Test that the pad byte is 0
      expect(output.bytes[7], equals(0));
    });

    group('Serialization matches rpcgen', () {
      test('should serialize Point identically to rpcgen', () async {
        // Create the same point that C code serialized
        const point = Point(x: 100, y: 200);

        // Serialize with Dart
        final output = XdrOutputStream();
        point.encode(output);
        final dartBytes = Uint8List.fromList(output.bytes);

        // Read the C-generated file
        final file = File('test/compatibility/xdr/output/point.xdr');
        final cBytes = await file.readAsBytes();

        // Compare byte-for-byte
        expect(
          dartBytes,
          equals(cBytes),
          reason: 'Dart serialization should match rpcgen exactly',
        );
      });

      test('should serialize Person identically to rpcgen', () async {
        // Create the same person that C code serialized
        final person = Person(
          name: 'Alice Johnson',
          age: 30,
          favoriteColor: Color.green,
          scores: [10, 20, 30, 40, 50],
        );

        // Serialize with Dart
        final output = XdrOutputStream();
        person.encode(output);
        final dartBytes = Uint8List.fromList(output.bytes);

        // Read the C-generated file
        final file = File('test/compatibility/xdr/output/person.xdr');
        final cBytes = await file.readAsBytes();

        // Compare byte-for-byte
        expect(
          dartBytes,
          equals(cBytes),
          reason: 'Dart serialization should match rpcgen exactly',
        );
      });

      test('should serialize Result (success) identically to rpcgen', () async {
        // Create the same result that C code serialized
        final person = Person(
          name: 'Bob Smith',
          age: 25,
          favoriteColor: Color.blue,
          scores: [5, 10, 15, 20, 25],
        );
        final result = ResultSuccess(person);

        // Serialize with Dart
        final output = XdrOutputStream();
        result.encode(output);
        final dartBytes = Uint8List.fromList(output.bytes);

        // Read the C-generated file
        final file = File('test/compatibility/xdr/output/result_success.xdr');
        final cBytes = await file.readAsBytes();

        // Compare byte-for-byte
        expect(
          dartBytes,
          equals(cBytes),
          reason: 'Dart serialization should match rpcgen exactly',
        );
      });

      test('should serialize Result (error) identically to rpcgen', () async {
        // Create the same error result that C code serialized
        final result = ResultError('Something went wrong');

        // Serialize with Dart
        final output = XdrOutputStream();
        result.encode(output);
        final dartBytes = Uint8List.fromList(output.bytes);

        // Read the C-generated file
        final file = File('test/compatibility/xdr/output/result_error.xdr');
        final cBytes = await file.readAsBytes();

        // Compare byte-for-byte
        expect(
          dartBytes,
          equals(cBytes),
          reason: 'Dart serialization should match rpcgen exactly',
        );
      });

      test('should verify byte-level XDR format for all types', () {
        final output = XdrOutputStream()
          // Test int (4 bytes, big-endian)
          ..writeInt(0x12345678);
        expect(output.bytes.sublist(0, 4), equals([0x12, 0x34, 0x56, 0x78]));

        // Test string with padding
        final stringOutput = XdrOutputStream()
          ..writeString('Hi'); // 2 bytes + 2 padding
        expect(
          stringOutput.bytes,
          equals([
            0x00, 0x00, 0x00, 0x02, // length = 2
            0x48, 0x69, // "Hi"
            0x00, 0x00, // padding to 4-byte boundary
          ]),
        );

        // Test boolean (4 bytes)
        final boolOutput = XdrOutputStream()..writeBoolean(true);
        expect(boolOutput.bytes, equals([0x00, 0x00, 0x00, 0x01]));

        boolOutput.writeBoolean(false);
        expect(boolOutput.bytes.sublist(4), equals([0x00, 0x00, 0x00, 0x00]));
      });
    });

    group('Round-trip serialization', () {
      test('should round-trip Point through both implementations', () async {
        // Original point
        const original = Point(x: 42, y: 84);

        // Dart serialize
        final output = XdrOutputStream();
        original.encode(output);
        final serialized = Uint8List.fromList(output.bytes);

        // Dart deserialize
        final input = XdrInputStream(serialized);
        final deserialized = Point.decode(input);

        expect(deserialized, equals(original));
        expect(deserialized.x, equals(42));
        expect(deserialized.y, equals(84));
      });

      test('should handle empty strings correctly', () {
        final output = XdrOutputStream()..writeString('');

        // Empty string should be 4 bytes (just the length field = 0)
        expect(output.bytes.length, equals(4));
        expect(output.bytes, equals([0x00, 0x00, 0x00, 0x00]));

        // Deserialize
        final input = XdrInputStream(Uint8List.fromList(output.bytes));
        final str = input.readString();
        expect(str, equals(''));
      });

      test('should handle maximum string padding correctly', () {
        // Test all padding cases (0, 1, 2, 3 bytes of padding)
        final testCases = {
          'ABCD': 8, // 4 chars, 0 padding -> 4 (len) + 4 (data) = 8
          'ABC': 8, // 3 chars, 1 padding -> 4 (len) + 3 (data) + 1 (pad) = 8
          'AB': 8, // 2 chars, 2 padding -> 4 (len) + 2 (data) + 2 (pad) = 8
          'A': 8, // 1 char,  3 padding -> 4 (len) + 1 (data) + 3 (pad) = 8
          '': 4, // 0 chars, 0 padding -> 4 (len) = 4
        };

        for (final entry in testCases.entries) {
          final str = entry.key;
          final expectedLen = entry.value;
          final output = XdrOutputStream()..writeString(str);
          expect(
            output.bytes.length,
            equals(expectedLen),
            reason: 'String "$str" should result in $expectedLen bytes',
          );

          // Verify it deserializes correctly
          final input = XdrInputStream(Uint8List.fromList(output.bytes));
          expect(input.readString(), equals(str));
        }
      });
    });
  });
}
