import 'dart:typed_data';

/// Constants for RPC record marking protocol (RFC 1831 Section 11)
class RecordMarkingConstants {
  /// Bit 31 (MSB) of the record marking header indicates last fragment.
  /// Set (0x80000000) means this is the final fragment of a message.
  static const int lastFragmentBit = 0x80000000;

  /// Mask for extracting fragment length from record marking header.
  /// Bits 0-30 contain the fragment length (0x7FFFFFFF masks out bit 31).
  static const int lengthMask = 0x7FFFFFFF;

  /// Size of the record marking header in bytes.
  static const int headerSize = 4;
}

/// Encodes and decodes RPC record marking for TCP transport.
///
/// Record marking protocol (RFC 1831):
/// - Each record has a 4-byte header followed by data
/// - Header format: bit 31 = last fragment flag, bits 0-30 = fragment length
class RecordMarkingCodec {
  // Track state between decode calls so multi-fragment messages are reconstructed.
  final BytesBuilder _currentMessage = BytesBuilder(copy: false);
  int? _expectedFragmentLength;
  bool _pendingLastFragmentFlag = false;

  /// Encodes data with record marking header.
  ///
  /// Sets the last fragment bit to indicate a complete message.
  Uint8List encode(final Uint8List data) {
    final fragmentLength = data.length;
    final header = ByteData(RecordMarkingConstants.headerSize)
      ..setUint32(
        0,
        RecordMarkingConstants.lastFragmentBit | fragmentLength,
      );

    final result = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(data);
    return result.toBytes();
  }

  /// Decodes a stream of bytes into complete records.
  ///
  /// Returns a list of complete records extracted from the buffer.
  /// Incomplete data remains in the internal buffer for the next call.
  List<Uint8List> decode(final BytesBuilder buffer) {
    final records = <Uint8List>[];

    while (true) {
      final bytes = buffer.toBytes();

      // Need at least 4 bytes for record header
      if (_expectedFragmentLength == null &&
          bytes.length < RecordMarkingConstants.headerSize) {
        break;
      }

      // Read record header if we haven't already
      if (_expectedFragmentLength == null) {
        final header = ByteData.view(
          bytes.buffer,
          bytes.offsetInBytes,
          RecordMarkingConstants.headerSize,
        );
        final headerValue = header.getUint32(0);
        _pendingLastFragmentFlag =
            (headerValue & RecordMarkingConstants.lastFragmentBit) != 0;
        _expectedFragmentLength =
            headerValue & RecordMarkingConstants.lengthMask;

        // Remove header from buffer
        buffer.clear();
        if (bytes.length > RecordMarkingConstants.headerSize) {
          buffer.add(bytes.sublist(RecordMarkingConstants.headerSize));
        }

        // Continue to evaluate if fragment bytes are available.
        continue;
      }

      // Check if we have the complete record
      final currentBytes = buffer.toBytes();
      if (currentBytes.length < _expectedFragmentLength!) {
        break;
      }

      // Extract the record
      final recordData = currentBytes.sublist(0, _expectedFragmentLength!);
      _currentMessage.add(recordData);

      // Remove record from buffer
      buffer.clear();
      if (currentBytes.length > _expectedFragmentLength!) {
        buffer.add(currentBytes.sublist(_expectedFragmentLength!));
      }

      // Process the complete record
      if (_pendingLastFragmentFlag) {
        records.add(_currentMessage.toBytes());
        _currentMessage.clear();
      }

      // Reset for next record
      _expectedFragmentLength = null;
      _pendingLastFragmentFlag = false;
    }

    return records;
  }
}
