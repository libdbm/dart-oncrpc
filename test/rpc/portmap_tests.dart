import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/portmap.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';
import 'package:test/test.dart';

void main() {
  group('Portmap CALLIT encoding', () {
    test('CallArgs encodes args as opaque once', () {
      final args = Uint8List.fromList([1, 2, 3, 4, 5]);
      final callArgs = CallArgs(
        prog: 100000,
        vers: 2,
        proc: 5,
        args: args,
      );

      final encoded = callArgs.toXdr();
      final stream = XdrInputStream(encoded);

      expect(stream.readInt(), equals(100000));
      expect(stream.readInt(), equals(2));
      expect(stream.readInt(), equals(5));
      expect(stream.readOpaque(), orderedEquals(args));
      expect(stream.remaining, equals(0));
    });

    test('CallResult round-trips with opaque payload', () {
      final payload = Uint8List.fromList([9, 8, 7, 6]);
      final callResult = CallResult(port: 2049, res: payload);

      final encoded = callResult.toXdr();
      final decoded = CallResult.decode(XdrInputStream(encoded));

      expect(decoded.port, equals(2049));
      expect(decoded.res, orderedEquals(payload));
    });
  });
}
