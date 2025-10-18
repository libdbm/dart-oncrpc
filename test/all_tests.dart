import 'package:test/test.dart';

import 'compatibility/xdr/xdr_compatibility_test.dart' as compatibility_tests;
import 'parsing/constant_parsing_tests.dart' as constant_type_parsing_tests;
import 'parsing/declaration_parsing_tests.dart' as declaration_parsing_tests;
import 'parsing/enum_parsing_tests.dart' as enum_parsing_tests;
import 'parsing/program_parsing_tests.dart' as program_parsing_tests;
import 'parsing/struct_parsing_tests.dart' as struct_parsing_tests;
import 'parsing/typedef_parsing_tests.dart' as typedef_parsing_tests;
import 'parsing/union_parsing_tests.dart' as union_parsing_tests;
import 'preprocessor/preprocessor_tests.dart' as preprocessor_tests;
import 'xdr/xdr_io_tests.dart' as xdr_io_tests;

void main() {
  group('preprocessor tests', preprocessor_tests.main);
  group('xdr tests', xdr_io_tests.main);
  group('parsing tests', () {
    constant_type_parsing_tests.main();
    declaration_parsing_tests.main();
    typedef_parsing_tests.main();
    enum_parsing_tests.main();
    struct_parsing_tests.main();
    union_parsing_tests.main();
    program_parsing_tests.main();
  });
  group('compatibility tests', compatibility_tests.main);
}
