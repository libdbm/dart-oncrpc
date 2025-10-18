import 'package:dart_oncrpc/dart_oncrpc.dart';
import 'package:test/test.dart';

void main() {
  group('JavaGenerator', () {
    test('generates constants correctly', () {
      const xdr = '''
const MAX_SIZE = 1024;
const MIN_SIZE = 64;
const VERSION = 1;
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public static final int MAX_SIZE = 1024;'));
      expect(output, contains('public static final int MIN_SIZE = 64;'));
      expect(output, contains('public static final int VERSION = 1;'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public enum Status implements XdrAble {'));
      expect(output, contains('OK(0),'));
      expect(output, contains('ERROR(1),'));
      expect(output, contains('BUSY(2);'));
      expect(output, contains('private final int value;'));
      expect(output, contains('public int getValue()'));
      expect(output, contains('public static Status valueOf(int value)'));
      expect(output, contains('public void xdrEncode(XdrEncodingStream xdr)'));
      expect(
        output,
        contains('public static Status xdrDecode(XdrDecodingStream xdr)'),
      );
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class Point implements XdrAble {'));
      expect(output, contains('private int x;'));
      expect(output, contains('private int y;'));
      expect(output, contains('public Point()'));
      expect(output, contains('public Point(int x, int y)'));
      expect(output, contains('public int getX()'));
      expect(output, contains('public void setX(int x)'));
      expect(output, contains('public int getY()'));
      expect(output, contains('public void setY(int y)'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class Result implements XdrAble {'));
      expect(output, contains('private int status;'));
      expect(output, contains('private Object value;'));
      expect(output, contains('public int getStatus()'));
      expect(output, contains('public void setStatus(int status)'));
      expect(output, contains('public int getValue()'));
      expect(output, contains('public void setValue(int value)'));
      expect(output, contains('public String getError_msg()'));
      expect(output, contains('public void setError_msg(String error_msg)'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class UserID implements XdrAble {'));
      expect(output, contains('private int value;'));
      expect(output, contains('public class Name implements XdrAble {'));
      expect(output, contains('private String value;'));
      expect(output, contains('public class IntArray implements XdrAble {'));
      expect(output, contains('private int[] value;'));
      expect(output, contains('public class FloatList implements XdrAble {'));
      expect(output, contains('private float[] value;'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('private int[] fixed_array;'));
      expect(output, contains('private float[] variable_array;'));
      expect(output, contains('private byte[] bytes;'));
      // string<100> is a single string with max length, not an array of strings
      expect(output, contains('private String names;'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('private long big_signed;'));
      expect(output, contains('private long big_unsigned;'));
      expect(output, contains('private int small_unsigned;'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class CALCULATOR {'));
      expect(output, contains('public static final int PROGRAM = 0x20000001;'));
      expect(output, contains('public static final int CALC_V1 = 1;'));
      expect(output, contains('public static final int ADD = 1;'));
      expect(output, contains('public static final int SUBTRACT = 2;'));
      expect(output, contains('public static final int RESET = 3;'));
      expect(
        output,
        contains('public interface CALC_V1_Client extends OncRpcClient'),
      );
      expect(output, contains('public interface CALC_V1_Server'));
    });

    test('generates XDR encoding methods correctly', () {
      const xdr = '''
struct Person {
  string name<50>;
  int age;
  float height;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public void xdrEncode(XdrEncodingStream xdr)'));
      expect(output, contains('xdr.xdrEncodeString(name);'));
      expect(output, contains('xdr.xdrEncodeInt(age);'));
      expect(output, contains('xdr.xdrEncodeFloat(height);'));
    });

    test('generates XDR decoding methods correctly', () {
      const xdr = '''
struct Person {
  string name<50>;
  int age;
  float height;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(
        output,
        contains('public static Person xdrDecode(XdrDecodingStream xdr)'),
      );
      expect(output, contains('Person result = new Person();'));
      expect(output, contains('result.name = xdr.xdrDecodeString();'));
      expect(output, contains('result.age = xdr.xdrDecodeInt();'));
      expect(output, contains('result.height = xdr.xdrDecodeFloat();'));
      expect(output, contains('return result;'));
    });

    test('handles package configuration', () {
      const xdr = 'const TEST = 1;';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator =
          JavaGenerator(specification, {'package': 'com.example.rpc'});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('package com.example.rpc;'));
    });

    test('handles javaPackage configuration key', () {
      const xdr = 'const TEST = 1;';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator =
          JavaGenerator(specification, {'javaPackage': 'com.acme.rpc'});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('package com.acme.rpc;'));
    });

    test('generates imports correctly', () {
      const xdr = '''
struct Test {
  int value;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('import org.dcache.oncrpc4j.rpc.*;'));
      expect(output, contains('import org.dcache.oncrpc4j.xdr.*;'));
      expect(output, contains('import java.io.IOException;'));
      expect(output, contains('import java.nio.charset.StandardCharsets;'));
      expect(output, contains('import java.util.*;'));
    });

    test('handles variable-length arrays correctly', () {
      const xdr = '''
struct DataPacket {
  int sequence;
  opaque data<1024>;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('xdr.xdrEncodeInt(data.length);'));
      expect(output, contains('for (byte[] element : data)'));
      expect(output, contains('int data_length = xdr.xdrDecodeInt();'));
      expect(output, contains('result.data = new byte[][data_length];'));
    });

    test('handles fixed-length arrays correctly', () {
      const xdr = '''
struct Matrix {
  int values[3][3];
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('private int[][] values;'));
      expect(output, contains('result.values = new int[3][];'));
      expect(output, contains('for (int i = 0; i < 3; i++)'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class Address implements XdrAble'));
      expect(output, contains('public class Person implements XdrAble'));
      expect(output, contains('private Address address;'));
      expect(output, contains('address.xdrEncode(xdr);'));
      expect(output, contains('result.address = Address.xdrDecode(xdr);'));
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
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('public class Node implements XdrAble'));
      expect(output, contains('private int value;'));
      expect(output, contains('private Node next;'));
    });

    test('generates union switch statements correctly', () {
      const xdr = '''
union FileType switch (int type) {
  case 1:
    string text_file<>;
  case 2:
    opaque binary_file<>;
  case 3:
  case 4:
    int special_code;
  default:
    void;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('switch (type) {'));
      expect(output, contains('case 1:'));
      // Now generates properly typed code with casting
      expect(output, contains('text_fileTyped'));
      expect(output, contains('xdr.xdrEncodeString('));
      expect(output, contains('case 2:'));
      expect(output, contains('binary_fileTyped'));
      expect(output, contains('case 3:'));
      expect(output, contains('case 4:'));
      expect(output, contains('special_codeTyped'));
      expect(output, contains('xdr.xdrEncodeInt('));
      expect(output, contains('default:'));
      expect(output, contains('break;'));
    });

    test('generates boolean types correctly', () {
      const xdr = '''
struct Flags {
  bool is_active;
  bool is_visible;
};
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('private boolean is_active;'));
      expect(output, contains('private boolean is_visible;'));
      expect(output, contains('xdr.xdrEncodeBoolean(is_active);'));
      expect(output, contains('result.is_active = xdr.xdrDecodeBoolean();'));
    });

    test('handles void types correctly', () {
      const xdr = '''
program TEST {
  version V1 {
    void PING(void) = 1;
  } = 1;
} = 100000;
''';

      final parsed = RPCParser.parse(xdr);
      final specification = parsed.value;
      final generator = JavaGenerator(specification, {});
      final result = generator.generate();
      final output = result.artifacts.map((a) => a.content).join('\n\n');

      expect(output, contains('void ping(void arg)'));
    });
  });
}
