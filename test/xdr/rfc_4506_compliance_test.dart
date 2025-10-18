import 'dart:typed_data';

import 'package:dart_oncrpc/src/xdr/xdr_exceptions.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

/// RFC 4506 XDR Compliance Tests
/// Tests based on examples from RFC 4506: XDR: External Data Representation Standard
void main() {
  group('RFC 4506 Compliance Tests', () {
    group('Integer Encoding', () {
      test('signed integers are big-endian 32-bit', () {
        final stream = XdrOutputStream()..writeInt(42);
        expect(stream.toBytes(), equals([0, 0, 0, 42]));
      });

      test("negative integers use two's complement", () {
        final stream = XdrOutputStream()..writeInt(-1);
        expect(stream.toBytes(), equals([0xFF, 0xFF, 0xFF, 0xFF]));
      });

      test('unsigned integers encode correctly', () {
        final stream = XdrOutputStream()..writeUnsignedInt(0xFFFFFFFF);
        expect(stream.toBytes(), equals([0xFF, 0xFF, 0xFF, 0xFF]));
      });
    });

    group('Hyper Integer Encoding (64-bit)', () {
      test('hyper encodes as 8 bytes big-endian', () {
        final stream = XdrOutputStream()
          ..writeHyper(BigInt.from(0x0123456789ABCDEF));
        expect(
          stream.toBytes(),
          equals([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]),
        );
      });

      test("negative hyper uses two's complement", () {
        final stream = XdrOutputStream()..writeHyper(BigInt.from(-1));
        expect(
          stream.toBytes(),
          equals([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
        );
      });
    });

    group('Boolean Encoding', () {
      test('true encodes as 1', () {
        final stream = XdrOutputStream()..writeBoolean(true);
        expect(stream.toBytes(), equals([0, 0, 0, 1]));
      });

      test('false encodes as 0', () {
        final stream = XdrOutputStream()..writeBoolean(false);
        expect(stream.toBytes(), equals([0, 0, 0, 0]));
      });
    });

    group('String Encoding', () {
      test('strings are length-prefixed', () {
        final stream = XdrOutputStream()..writeString('hello');
        expect(
          stream.toBytes(),
          equals([
            0, 0, 0, 5, // length
            104, 101, 108, 108, 111, // 'hello'
            0, 0, 0, // padding to 4-byte boundary
          ]),
        );
      });

      test('empty strings encode correctly', () {
        final stream = XdrOutputStream()..writeString('');
        expect(stream.toBytes(), equals([0, 0, 0, 0]));
      });

      test('ASCII-only validation in strict mode', () {
        final stream = XdrOutputStream();
        expect(
          () => stream.writeString('hello\u00A9', strict: true),
          throwsA(isA<XdrFormatException>()),
        );
      });

      test('null bytes are rejected for C compatibility', () {
        final stream = XdrOutputStream();
        // Null byte in regular mode (UTF-8)
        expect(
          () => stream.writeString('hello\u0000world'),
          throwsA(isA<XdrFormatException>()),
        );

        // Null byte in strict mode (ASCII)
        expect(
          () => stream.writeString('test\u0000', strict: true),
          throwsA(isA<XdrFormatException>()),
        );
      });

      test('null bytes are rejected on read', () {
        // Manually construct XDR with embedded null
        final malformed = Uint8List.fromList([
          0, 0, 0, 5, // length = 5
          104, 0, 108, 108, 111, // 'h\0llo'
          0, 0, 0, // padding
        ]);

        final inp = XdrInputStream(malformed);
        expect(
          inp.readString,
          throwsA(isA<XdrFormatException>()),
        );
      });
    });

    group('Opaque Data Encoding', () {
      test('variable opaque is length-prefixed', () {
        final stream = XdrOutputStream();
        final data = Uint8List.fromList([1, 2, 3]);
        stream.writeOpaque(data);
        expect(
          stream.toBytes(),
          equals([
            0, 0, 0, 3, // length
            1, 2, 3, // data
            0, // padding
          ]),
        );
      });

      test('fixed opaque has no length prefix', () {
        final stream = XdrOutputStream();
        final data = Uint8List.fromList([1, 2, 3]);
        stream.writeOpaque(data, fixed: true);
        expect(
          stream.toBytes(),
          equals([1, 2, 3, 0]), // data + padding
        );
      });
    });

    group('Alignment Requirements', () {
      test('all data aligned to 4-byte boundaries', () {
        final stream = XdrOutputStream()
          ..writeString('a') // 1 byte + 3 padding
          ..writeString('ab') // 2 bytes + 2 padding
          ..writeString('abc') // 3 bytes + 1 padding
          ..writeString('abcd'); // 4 bytes + 0 padding

        final bytes = stream.toBytes();
        expect(bytes.length % 4, equals(0)); // Total should be aligned
      });
    });

    group('Decoding', () {
      test('round-trip integers', () {
        final out = XdrOutputStream()..writeInt(42);
        final bytes = out.toBytes();

        final inp = XdrInputStream(bytes);
        expect(inp.readInt(), equals(42));
      });

      test('round-trip strings', () {
        final out = XdrOutputStream()..writeString('Hello, World!');
        final bytes = out.toBytes();

        final inp = XdrInputStream(bytes);
        expect(inp.readString(), equals('Hello, World!'));
      });

      test('EOF detection', () {
        final bytes = Uint8List.fromList([0, 0, 0, 1]);
        final inp = XdrInputStream(bytes)..readInt();
        expect(inp.readInt, throwsA(isA<XdrEofException>()));
      });
    });

    group('Length Validation', () {
      test('enforces max string length', () {
        final out = XdrOutputStream();
        expect(
          () => out.writeString('hello', maxLength: 3),
          throwsA(isA<XdrRangeException>()),
        );
      });

      test('enforces max opaque length', () {
        final out = XdrOutputStream();
        final data = Uint8List(10);
        expect(
          () => out.writeOpaque(data, maxLength: 5),
          throwsA(isA<XdrRangeException>()),
        );
      });

      test('rejects oversized strings on read', () {
        final out = XdrOutputStream()..writeString('hello world');
        final bytes = out.toBytes();

        final inp = XdrInputStream(bytes);
        expect(
          () => inp.readString(maxLength: 5),
          throwsA(isA<XdrRangeException>()),
        );
      });
    });
  });
}
