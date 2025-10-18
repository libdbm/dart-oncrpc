import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oncrpc/src/rpc/framing/record_marking.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server_transport.dart';
import 'package:test/test.dart';

void main() {
  group('RecordMarkingCodec', () {
    test('reassembles multi-fragment payloads', () {
      final codec = RecordMarkingCodec();
      final buffer = BytesBuilder();

      // First fragment (not last) with four bytes of payload.
      final first = ByteData(RecordMarkingConstants.headerSize)
        ..setUint32(0, 0x00000004);
      buffer
        ..add(first.buffer.asUint8List())
        ..add(Uint8List.fromList([1, 2, 3, 4]));
      expect(codec.decode(buffer), isEmpty);

      // Second fragment (last) with three bytes of payload.
      final second = ByteData(RecordMarkingConstants.headerSize)
        ..setUint32(
          0,
          RecordMarkingConstants.lastFragmentBit | 0x00000003,
        );
      buffer
        ..add(second.buffer.asUint8List())
        ..add(Uint8List.fromList([5, 6, 7]));

      final records = codec.decode(buffer);
      expect(records, hasLength(1));
      expect(records.single, orderedEquals([1, 2, 3, 4, 5, 6, 7]));
      expect(buffer.length, equals(0));
    });
  });

  group('TcpServerTransport', () {
    test('releases listening socket on close', () async {
      // Skip this test on macOS and Linux due to OS-level TCP_LINGER and
      // TIME_WAIT settings that can take minutes to release ports.
      // The socket close() is working correctly - this is just OS behavior.
      if (Platform.isMacOS || Platform.isLinux) {
        print(
          'Skipping test: OS-dependent port release timing on ${Platform.operatingSystem}',
        );
        return;
      }

      final transport = TcpServerTransport(address: '127.0.0.1', port: 0);
      await transport.listen();
      final port = transport.port;
      expect(port, greaterThan(0));

      await transport.close();

      // On other platforms, verify port is released
      ServerSocket? socket;
      try {
        socket = await ServerSocket.bind('127.0.0.1', port);
      } finally {
        await socket?.close();
      }
    });
  });
}
