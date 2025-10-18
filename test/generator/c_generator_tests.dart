import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:test/test.dart';

void main() {
  group('CGenerator', () {
    test('generates constants correctly', () {
      const xdr = '''
const MAX_SIZE = 1024;
const MIN_SIZE = 64;
const VERSION = 1;
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('#define MAX_SIZE 1024'));
      expect(output, contains('#define MIN_SIZE 64'));
      expect(output, contains('#define VERSION 1'));
    });

    test('generates enums correctly', () {
      const xdr = '''
enum Status {
  OK = 0,
  ERROR = 1,
  BUSY = 2
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('enum Status {'));
      expect(output, contains('  OK = 0,'));
      expect(output, contains('  ERROR = 1,'));
      expect(output, contains('  BUSY = 2'));
      expect(output, contains('typedef enum Status Status;'));
      expect(output, contains('extern bool_t xdr_Status(XDR *, Status *);'));
    });

    test('generates structs correctly', () {
      const xdr = '''
struct Point {
  int x;
  int y;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('struct Point {'));
      expect(output, contains('  int x;'));
      expect(output, contains('  int y;'));
      expect(output, contains('typedef struct Point Point;'));
      expect(output, contains('extern bool_t xdr_Point(XDR *, Point *);'));
      expect(output, contains('bool_t xdr_Point(XDR *xdrs, Point *objp)'));
    });

    test('generates unions correctly', () {
      const xdr = '''
union Result switch (int status) {
  case 0:
    int value;
  case 1:
    string error_msg<>;
  default:
    void;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('struct Result {'));
      expect(output, contains('  int status;'));
      expect(output, contains('  union {'));
      expect(output, contains('    int value;'));
      expect(output, contains('    char * error_msg;'));
      expect(output, contains('  } Result_u;'));
      expect(output, contains('typedef struct Result Result;'));
      expect(output, contains('extern bool_t xdr_Result(XDR *, Result *);'));
    });

    test('generates typedefs correctly', () {
      const xdr = '''
typedef int UserID;
typedef string Name<256>;
typedef int IntArray[10];
typedef float FloatList<>;
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('typedef int UserID;'));
      expect(output, contains('typedef char * Name;'));
      expect(output, contains('typedef int IntArray[10];'));
      expect(output, contains('typedef float *FloatList;'));
    });

    test('generates array types correctly', () {
      const xdr = '''
struct Data {
  int fixed_array[5];
  float variable_array<10>;
  opaque bytes[20];
  string names<100>;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('int fixed_array[5];'));
      expect(output, contains('float *variable_array;'));
      expect(output, contains('char bytes[20];'));
      expect(output, contains('char * names;'));
    });

    test('generates hyper and unsigned types correctly', () {
      const xdr = '''
struct BigNumbers {
  hyper big_signed;
  unsigned hyper big_unsigned;
  unsigned int small_unsigned;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('int64_t big_signed;'));
      expect(output, contains('u_int64_t big_unsigned;'));
      expect(output, contains('u_int small_unsigned;'));
    });

    test('generates RPC program definitions correctly', () {
      const xdr = '''
program CALCULATOR {
  version CALC_V1 {
    int ADD(int) = 1;
    int SUBTRACT(int) = 2;
    void RESET(void) = 3;
  } = 1;
} = 0x20000001;
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('#define CALCULATOR 0x20000001'));
      expect(output, contains('#define CALC_V1 1'));
      expect(output, contains('#define ADD 1'));
      expect(output, contains('#define SUBTRACT 2'));
      expect(output, contains('#define RESET 3'));
      expect(output, contains('extern int * add_1(int, CLIENT *);'));
      expect(output, contains('extern int * subtract_1(int, CLIENT *);'));
      expect(output, contains('extern void * reset_1(void, CLIENT *);'));
    });

    test('generates XDR functions for structs correctly', () {
      const xdr = '''
struct Person {
  string name<50>;
  int age;
  float height;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('bool_t xdr_Person(XDR *xdrs, Person *objp)'));
      expect(output, contains('if (!xdr_string(xdrs, &objp->name, 50))'));
      expect(output, contains('if (!xdr_int(xdrs, &objp->age))'));
      expect(output, contains('if (!xdr_float(xdrs, &objp->height))'));
      expect(output, contains('return TRUE;'));
    });

    test('generates XDR functions for unions correctly', () {
      const xdr = '''
union FileData switch (int type) {
  case 0:
    opaque binary_data<1024>;
  case 1:
    string text_data<>;
  default:
    void;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(
        output,
        contains('bool_t xdr_FileData(XDR *xdrs, FileData *objp)'),
      );
      expect(output, contains('if (!xdr_int(xdrs, &objp->type))'));
      expect(output, contains('switch (objp->type) {'));
      expect(output, contains('case 0:'));
      expect(
        output,
        contains('xdr_bytes(xdrs, (char **)&objp->FileData_u.binary_data'),
      );
      expect(output, contains('case 1:'));
      expect(output, contains('xdr_string(xdrs, &objp->FileData_u.text_data'));
    });

    test('handles nested structs correctly', () {
      const xdr = '''
struct Address {
  string street<100>;
  string city<50>;
};

struct Person {
  string name<50>;
  Address address;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('struct Address {'));
      expect(output, contains('struct Person {'));
      expect(output, contains('  Address address;'));
      expect(output, contains('xdr_Address(xdrs, &objp->address)'));
    });

    test('handles optional types correctly', () {
      const xdr = '''
struct Node {
  int value;
  Node *next;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('struct Node {'));
      expect(output, contains('  int value;'));
      expect(output, contains('  Node * next;'));
    });

    test('generates header guards correctly', () {
      const xdr = 'const TEST = 1;';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {'inputFilename': 'test.x'});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('#ifndef _TEST_H_RPCGEN'));
      expect(output, contains('#define _TEST_H_RPCGEN'));
      expect(output, contains('#endif /* !_TEST_H_RPCGEN */'));
      expect(output, contains('#ifdef __cplusplus'));
      expect(output, contains('extern "C" {'));
    });

    test('includes necessary headers', () {
      const xdr = 'const TEST = 1;';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = CGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('#include <rpc/rpc.h>'));
      // Note: rpcgen doesn't include rpc/xdr.h separately, stdlib.h, or string.h in header
      expect(output, contains('#ifdef __cplusplus'));
    });
  });
}
