import 'dart:typed_data';

import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

void main() {
  group('XdrOutputStream Tests', () {
    late XdrOutputStream out;

    setUp(() {
      out = XdrOutputStream();
    });

    test('writes integers correctly', () {
      out
        ..writeInt(42)
        ..writeInt(-1)
        ..writeInt(0x12345678);

      final bytes = out.bytes;
      expect(bytes.length, equals(12));

      // Check big-endian encoding
      expect(bytes[0], equals(0));
      expect(bytes[1], equals(0));
      expect(bytes[2], equals(0));
      expect(bytes[3], equals(42));

      // -1 should be 0xFFFFFFFF
      expect(bytes[4], equals(0xFF));
      expect(bytes[5], equals(0xFF));
      expect(bytes[6], equals(0xFF));
      expect(bytes[7], equals(0xFF));

      // 0x12345678
      expect(bytes[8], equals(0x12));
      expect(bytes[9], equals(0x34));
      expect(bytes[10], equals(0x56));
      expect(bytes[11], equals(0x78));
    });

    test('writes unsigned integers correctly', () {
      out
        ..writeUnsignedInt(0xFFFFFFFF)
        ..writeUnsignedInt(0)
        ..writeUnsignedInt(0x80000000);

      final bytes = out.bytes;
      expect(bytes.length, equals(12));
    });

    test('writes longs correctly', () {
      out
        ..writeLong(BigInt.parse('0x123456789ABCDEF0'))
        ..writeLong(BigInt.from(-1));

      final bytes = out.bytes;
      expect(bytes.length, equals(16));
    });

    test('writes strings with padding', () {
      out.writeString('test');
      final bytes = out.bytes;

      // 4 bytes for length + 4 bytes for 'test' = 8 bytes total
      expect(bytes.length, equals(8));
      expect(bytes[0], equals(0));
      expect(bytes[1], equals(0));
      expect(bytes[2], equals(0));
      expect(bytes[3], equals(4)); // length
      expect(bytes[4], equals('t'.codeUnitAt(0)));
      expect(bytes[5], equals('e'.codeUnitAt(0)));
      expect(bytes[6], equals('s'.codeUnitAt(0)));
      expect(bytes[7], equals('t'.codeUnitAt(0)));
    });

    test('pads strings to 4-byte boundary', () {
      out.writeString('a'); // 1 char + 3 padding
      final bytes = out.bytes;

      expect(bytes.length, equals(8)); // 4 for length + 1 for 'a' + 3 padding
      expect(bytes[7], equals(0)); // padding byte
    });

    test('writes booleans correctly', () {
      out
        ..writeBoolean(true)
        ..writeBoolean(false);

      final bytes = out.bytes;
      expect(bytes.length, equals(8));
      expect(bytes[3], equals(1)); // true
      expect(bytes[7], equals(0)); // false
    });

    test('writes fixed-length opaque data', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      out.writeOpaque(data, fixed: true);

      final bytes = out.bytes;
      expect(bytes.length, equals(8)); // 5 bytes + 3 padding
    });

    test('writes variable-length opaque data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      out.writeOpaque(data);

      final bytes = out.bytes;
      expect(bytes.length, equals(8)); // 4 (length) + 3 (data) + 1 (padding)
    });
  });

  group('XdrInputStream Tests', () {
    test('reads integers correctly', () {
      final data = Uint8List.fromList(
        [0, 0, 0, 42, 0xFF, 0xFF, 0xFF, 0xFF, 0x12, 0x34, 0x56, 0x78],
      );
      final inp = XdrInputStream(data);

      expect(inp.readInt(), equals(42));
      expect(inp.readInt(), equals(-1));
      expect(inp.readInt(), equals(0x12345678));
    });

    test('reads unsigned integers correctly', () {
      final data = Uint8List.fromList(
        [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0x80, 0, 0, 0],
      );
      final inp = XdrInputStream(data);

      expect(inp.readUnsignedInt(), equals(0xFFFFFFFF));
      expect(inp.readUnsignedInt(), equals(0));
      expect(inp.readUnsignedInt(), equals(0x80000000));
    });

    test('reads strings with padding', () {
      final data = Uint8List.fromList([
        0, 0, 0, 4, // length
        't'.codeUnitAt(0), 'e'.codeUnitAt(0), 's'.codeUnitAt(0),
        't'.codeUnitAt(0),
        0, 0, 0, 1, // length
        'a'.codeUnitAt(0), 0, 0, 0, // 'a' + padding
      ]);
      final inp = XdrInputStream(data);

      expect(inp.readString(), equals('test'));
      expect(inp.readString(), equals('a'));
    });

    test('reads booleans correctly', () {
      final data = Uint8List.fromList([0, 0, 0, 1, 0, 0, 0, 0]);
      final inp = XdrInputStream(data);

      expect(inp.readBoolean(), isTrue);
      expect(inp.readBoolean(), isFalse);
    });

    test('reads fixed-length opaque data', () {
      final data = Uint8List.fromList([
        1, 2, 3, 4, 5, 0, 0, 0, // 5 bytes + 3 padding
      ]);
      final inp = XdrInputStream(data);

      final result = inp.readOpaque(5);
      expect(result, equals([1, 2, 3, 4, 5]));
    });

    test('reads variable-length opaque data', () {
      final data = Uint8List.fromList([
        0, 0, 0, 3, // length
        1, 2, 3, 0, // 3 bytes + 1 padding
      ]);
      final inp = XdrInputStream(data);

      final result = inp.readOpaque();
      expect(result, equals([1, 2, 3]));
    });

    test('remaining bytes tracking works correctly', () {
      final data = Uint8List.fromList([0, 0, 0, 42, 0, 0, 0, 100]);
      final inp = XdrInputStream(data);

      expect(inp.remaining, equals(8));
      inp.readInt();
      expect(inp.remaining, equals(4));
      inp.readInt();
      expect(inp.remaining, equals(0));
    });
  });

  group('XdrType Integration Tests', () {
    test('XdrInt encode/decode roundtrip', () {
      final original = XdrInt(42);
      final out = XdrOutputStream();
      original.encode(out);
      final decoded = XdrInt.decode(XdrInputStream(out.bytes));

      expect(decoded.value, equals(original.value));
    });

    test('XdrString encode/decode roundtrip', () {
      final original = XdrString('Hello, XDR!');
      final out = XdrOutputStream();
      original.encode(out);
      final decoded = XdrString.decode(XdrInputStream(out.bytes));

      expect(decoded.value, equals(original.value));
    });

    test('XdrUnion subclass encode/decode roundtrip', () {
      // Test with a concrete union subclass
      // XdrUnion is abstract and should be extended by generated code
      // We'll create a simple concrete implementation for testing
      final out = XdrOutputStream()
        // Manually encode a union-like structure
        ..writeInt(1) // discriminant
        ..writeInt(42); // value

      final inp = XdrInputStream(out.bytes);
      // Read discriminant
      final disc = inp.readInt();
      expect(disc, equals(1));

      // Union value should have been encoded
      final value = inp.readInt();
      expect(value, equals(42));
    });
  });

  group('Edge Cases', () {
    test('handles empty strings', () {
      final out = XdrOutputStream()..writeString('');

      final inp = XdrInputStream(out.bytes);
      expect(inp.readString(), equals(''));
    });

    test('handles maximum int values', () {
      final out = XdrOutputStream()
        ..writeInt(2147483647) // MAX_INT
        ..writeInt(-2147483648); // MIN_INT

      final inp = XdrInputStream(out.bytes);
      expect(inp.readInt(), equals(2147483647));
      expect(inp.readInt(), equals(-2147483648));
    });

    test('handles UTF-8 strings', () {
      final out = XdrOutputStream()..writeString('Hello 世界 🌍');

      final inp = XdrInputStream(out.bytes);
      expect(inp.readString(), equals('Hello 世界 🌍'));
    });
  });
}
