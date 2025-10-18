import 'dart:io';

import 'package:dart_oncrpc/src/xdr/xdr_io.dart';

// Import the test types from xdr_compatibility_test.dart
// We'll duplicate them here for simplicity
const arraySize = 5;

enum Color {
  red(0),
  green(1),
  blue(2);

  final int value;

  // ignore: sort_constructors_first
  const Color(this.value);
}

class Point {
  Point({required this.x, required this.y});
  final int x;
  final int y;

  void encode(XdrOutputStream stream) {
    stream
      ..writeInt(x)
      ..writeInt(y);
  }
}

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

  void encode(XdrOutputStream stream) {
    stream
      ..writeString(name)
      ..writeInt(age)
      ..writeInt(favoriteColor.value);
    scores.forEach(stream.writeInt);
  }
}

abstract class Result {
  Result(this.status);
  final int status;

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
}

void main() async {
  // Create output directory in the xdr subdirectory
  final dir = Directory('test/compatibility/xdr/output_dart');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  // Generate Point
  print('Generating Point...');
  final point = Point(x: 100, y: 200);
  final pointOutput = XdrOutputStream();
  point.encode(pointOutput);
  await File('test/compatibility/xdr/output_dart/point.xdr')
      .writeAsBytes(pointOutput.bytes);

  // Generate Person
  print('Generating Person...');
  final person = Person(
    name: 'Alice Johnson',
    age: 30,
    favoriteColor: Color.green,
    scores: [10, 20, 30, 40, 50],
  );
  final personOutput = XdrOutputStream();
  person.encode(personOutput);
  await File('test/compatibility/xdr/output_dart/person.xdr')
      .writeAsBytes(personOutput.bytes);

  // Generate Result (success)
  print('Generating Result (success)...');
  final resultSuccess = ResultSuccess(
    Person(
      name: 'Bob Smith',
      age: 25,
      favoriteColor: Color.blue,
      scores: [5, 10, 15, 20, 25],
    ),
  );
  final successOutput = XdrOutputStream();
  resultSuccess.encode(successOutput);
  await File('test/compatibility/xdr/output_dart/result_success.xdr')
      .writeAsBytes(successOutput.bytes);

  // Generate Result (error)
  print('Generating Result (error)...');
  final resultError = ResultError('Something went wrong');
  final errorOutput = XdrOutputStream();
  resultError.encode(errorOutput);
  await File('test/compatibility/xdr/output_dart/result_error.xdr')
      .writeAsBytes(errorOutput.bytes);

  print(
    '\nAll Dart XDR files generated in test/compatibility/xdr/output_dart/',
  );
  print('You can now verify them with: ./verify_dart_xdr <command> <file>');
}
