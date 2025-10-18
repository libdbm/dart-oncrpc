import 'dart:convert';
import 'dart:typed_data';

import 'xdr_exceptions.dart';

/// XDR alignment requirement: all data types are padded to 4-byte boundaries.
/// Per RFC 4506, this ensures compatibility across different architectures.
const int _xdrAlignment = 4;

/// Maximum value for a 7-bit ASCII character (0-127).
/// RFC 4506 XDR strings are defined to use ASCII encoding.
const int _maxAsciiValue = 127;

/// Number of bits in a 32-bit word.
/// Used for splitting 64-bit values into high/low 32-bit words.
const int _bitsPerWord = 32;

/// Size of XDR int, unsigned int, float, and enum types in bytes.
const int _xdrIntSize = 4;

/// Size of XDR hyper, unsigned hyper, and double types in bytes.
const int _xdrHyperSize = 8;

/// Calculates padding bytes needed for XDR 4-byte alignment.
///
/// XDR requires all data to be aligned on 4-byte boundaries. This function
/// returns the number of padding bytes (0-3) needed for a given length.
int _padLength(final int length) =>
    (_xdrAlignment - (length % _xdrAlignment)) % _xdrAlignment;

// Sentinel BigInt values for min/max signed 64-bit integers.
final _minSigned64 = BigInt.parse('-9223372036854775808');
final _maxSigned64 = BigInt.parse('9223372036854775807');
final _maxUnsigned64 = BigInt.parse('18446744073709551615');

/// Base class for user-defined XDR structs/unions
abstract class XdrType {
  void encode(final XdrOutputStream out);

  /// Factory method each subclass should implement
  static T decode<T extends XdrType>(final XdrInputStream input) {
    throw UnimplementedError('XdrType.decode must be implemented in subclass');
  }

  /// Helper to encode this type to bytes
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

/// Wrapper for an integer to conform to XdrType
class XdrInt extends XdrType {
  XdrInt(this.value);

  final int value;

  @override
  void encode(final XdrOutputStream out) {
    out.writeInt(value);
  }

  /// Decode an XdrInt from the stream
  // ignore: prefer_constructors_over_static_methods
  static XdrInt decode(final XdrInputStream inp) {
    final v = inp.readInt();
    return XdrInt(v);
  }
}

/// Wrapper for a string to conform to XdrType
class XdrString extends XdrType {
  XdrString(this.value);

  final String value;

  @override
  void encode(final XdrOutputStream out) {
    out.writeString(value);
  }

  /// Decode an XdrString from the stream
  // ignore: prefer_constructors_over_static_methods
  static XdrString decode(final XdrInputStream inp) {
    final v = inp.readString();
    return XdrString(v);
  }
}

/// Base class for all discriminated unions in XDR.
///
/// All subclasses carry a discriminant and a nullable `value`
/// representing the active arm. Encoding is shared.
abstract class XdrUnion extends XdrType {
  /// Base constructor for all unions.
  XdrUnion(this.discriminant, this.value);

  /// Discriminant value selecting the active union arm.
  final int discriminant;

  /// Active union arm (nullable if none).
  final XdrType? value;

  /// Default implementation: write the discriminant, then the value if non-null.
  @override
  void encode(final XdrOutputStream out) {
    out.writeInt(discriminant);
    value?.encode(out);
  }
}

/// XDR (External Data Representation) output stream for encoding data.
///
/// [XdrOutputStream] provides methods for encoding various data types into the
/// XDR format as defined in RFC 4506. XDR is a standard for representing data
/// structures in a machine-independent way, commonly used in RPC protocols.
///
/// ## Features
///
/// - Automatic 4-byte alignment padding
/// - Big-endian byte ordering (network byte order)
/// - Support for all XDR primitive types (int, hyper, float, double, etc.)
/// - Variable and fixed-length arrays
/// - Opaque data (byte arrays) with optional size limits
/// - String encoding (UTF-8 by default, strict ASCII mode available)
///
/// ## Example Usage
///
/// ```dart
/// final stream = XdrOutputStream();
///
/// // Write primitives
/// stream.writeInt(42);
/// stream.writeString('Hello');
/// stream.writeBoolean(true);
///
/// // Write arrays
/// stream.writeVarArray([1, 2, 3], (item, out) => out.writeInt(item));
///
/// // Get encoded bytes
/// final bytes = stream.toBytes();
/// ```
///
/// ## Type Mapping
///
/// - `int` (32-bit): writeInt / writeUnsignedInt
/// - `hyper` (64-bit): writeHyper / writeUnsignedHyper (BigInt)
/// - `float`: writeFloat
/// - `double`: writeDouble
/// - `bool`: writeBoolean
/// - `opaque`: writeOpaque / writeBytes
/// - `string`: writeString
///
/// See also:
/// - [XdrInputStream] for decoding XDR data
/// - RFC 4506 for XDR specification
class XdrOutputStream {
  final BytesBuilder _builder = BytesBuilder();

  /// Returns the encoded bytes as a [Uint8List].
  ///
  /// This method can be called multiple times without affecting the stream.
  Uint8List toBytes() => _builder.toBytes();

  /// Alias for [toBytes] that returns the encoded bytes.
  Uint8List get bytes => _builder.toBytes();

  // ---- Primitive Writers ----
  void writeInt(final int value) {
    final b = ByteData(_xdrIntSize)..setInt32(0, value);
    _builder.add(b.buffer.asUint8List());
  }

  void writeUnsignedInt(final int value) {
    final b = ByteData(_xdrIntSize)..setUint32(0, value);
    _builder.add(b.buffer.asUint8List());
  }

  void _writeBigInt(final BigInt value) {
    final b = ByteData(_xdrHyperSize)
      ..setUint32(0, (value >> _bitsPerWord).toUnsigned(_bitsPerWord).toInt())
      ..setUint32(_xdrIntSize, value.toUnsigned(_bitsPerWord).toInt());
    _builder.add(b.buffer.asUint8List());
  }

  void _writeBigIntWithRange(
    final BigInt value,
    final BigInt min,
    final BigInt max,
    final String typeName,
  ) {
    if (value < min || value > max) {
      throw XdrRangeException(value, typeName);
    }
    _writeBigInt(value);
  }

  void writeLong(final BigInt value) {
    _writeBigIntWithRange(
      value,
      _minSigned64,
      _maxSigned64,
      'signed 64-bit integer',
    );
  }

  void writeUnsignedLong(final BigInt value) {
    _writeBigIntWithRange(
      value,
      BigInt.zero,
      _maxUnsigned64,
      'unsigned 64-bit integer',
    );
  }

  void writeHyper(final BigInt value) => writeLong(value);

  void writeUnsignedHyper(final BigInt value) => writeUnsignedLong(value);

  // ignore: avoid_positional_boolean_parameters
  void writeBoolean(final bool value) => writeInt(value ? 1 : 0);

  void writeFloat(final double value) {
    final b = ByteData(_xdrIntSize)..setFloat32(0, value);
    _builder.add(b.buffer.asUint8List());
  }

  void writeDouble(final double value) {
    final b = ByteData(_xdrHyperSize)..setFloat64(0, value);
    _builder.add(b.buffer.asUint8List());
  }

  void writeQuadruple(final Object value) {
    // RFC 4506 defines quadruple-precision (128-bit IEEE), but Dart
    // doesn't have native support. This would require a BigFloat library.
    throw UnimplementedError(
      'Quadruple-precision floating point is not supported. '
      'Dart lacks native 128-bit float support. Use double instead.',
    );
  }

  void writeBytes(final Uint8List data, {final bool fixed = false}) {
    writeOpaque(data, fixed: fixed);
  }

  void writeOpaque(
    final Uint8List data, {
    final bool fixed = false,
    final int? maxLength,
  }) {
    if (maxLength != null && data.length > maxLength) {
      throw XdrRangeException(
        data.length,
        'opaque data (max: $maxLength bytes)',
      );
    }
    if (!fixed) {
      writeInt(data.length);
    }
    _builder.add(data);
    final pad = _padLength(data.length);
    if (pad > 0) {
      _builder.add(Uint8List(pad));
    }
  }

  void writeString(
    final String s, {
    final bool strict = false,
    final int? maxLength,
  }) {
    // RFC 4506: XDR strings are ASCII (7-bit), but most implementations
    // support UTF-8 for compatibility. Use strict mode to enforce ASCII.
    final bytes = strict ? _encodeAscii(s) : _encodeUtf8(s);
    if (maxLength != null && bytes.length > maxLength) {
      throw XdrRangeException(
        bytes.length,
        'string (max: $maxLength bytes)',
      );
    }
    writeInt(bytes.length);
    _builder.add(bytes);
    final pad = _padLength(bytes.length);
    if (pad > 0) {
      _builder.add(Uint8List(pad));
    }
  }

  /// Encode string as UTF-8, validating no null bytes present.
  ///
  /// XDR strings should not contain null bytes for C string compatibility.
  Uint8List _encodeUtf8(final String s) {
    final bytes = utf8.encode(s);
    // Validate no null bytes (important for C interop)
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        throw XdrFormatException(
          'Null byte at position $i is not allowed in XDR strings. '
          'XDR strings must be compatible with C null-terminated strings.',
        );
      }
    }
    return bytes;
  }

  /// Encode string as ASCII, throwing if non-ASCII characters present
  Uint8List _encodeAscii(final String s) {
    final bytes = <int>[];
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code == 0) {
        throw XdrFormatException(
          'Null byte at position $i is not allowed in XDR strings. '
          'XDR strings must be compatible with C null-terminated strings.',
        );
      }
      if (code > _maxAsciiValue) {
        throw XdrFormatException(
          'Non-ASCII character at position $i (code: $code). '
          'RFC 4506 XDR strings must be ASCII.',
        );
      }
      bytes.add(code);
    }
    return Uint8List.fromList(bytes);
  }

  // ---- Array Writers ----
  void writeFixedArray<T>(
    final List<T> items,
    final void Function(T, XdrOutputStream) encodeElem,
  ) {
    for (final e in items) {
      encodeElem(e, this);
    }
  }

  void writeVarArray<T>(
    final List<T> items,
    final void Function(T, XdrOutputStream) encodeElem, {
    final int? maxLength,
  }) {
    if (maxLength != null && items.length > maxLength) {
      throw XdrRangeException(
        items.length,
        'variable array (max: $maxLength elements)',
      );
    }
    writeInt(items.length);
    for (final e in items) {
      encodeElem(e, this);
    }
  }

  void writeFixedArrayXdr(final List<XdrType> items) =>
      writeFixedArray(items, (e, out) => e.encode(out));

  void writeVarArrayXdr(final List<XdrType> items) =>
      writeVarArray(items, (e, out) => e.encode(out));
}

/// XDR (External Data Representation) input stream for decoding data.
///
/// [XdrInputStream] provides methods for decoding XDR-encoded data as defined
/// in RFC 4506. It reads from a byte buffer and automatically handles 4-byte
/// alignment padding and big-endian byte ordering.
///
/// ## Features
///
/// - Automatic 4-byte alignment padding handling
/// - Big-endian byte ordering (network byte order)
/// - Support for all XDR primitive types
/// - Variable and fixed-length arrays
/// - Opaque data (byte arrays) with optional size limits
/// - String decoding (UTF-8 by default, strict ASCII mode available)
/// - Bounds checking with [XdrEofException] on buffer underrun
///
/// ## Example Usage
///
/// ```dart
/// final bytes = ...; // XDR-encoded bytes
/// final stream = XdrInputStream(bytes);
///
/// // Read primitives
/// final id = stream.readInt();
/// final name = stream.readString();
/// final active = stream.readBoolean();
///
/// // Read arrays
/// final items = stream.readVariableLengthArray((s) => s.readInt());
///
/// // Check remaining bytes
/// if (stream.remaining > 0) {
///   print('${stream.remaining} bytes left');
/// }
/// ```
///
/// ## Error Handling
///
/// - Throws [XdrEofException] if attempting to read beyond buffer
/// - Throws [XdrRangeException] if size limits are exceeded
/// - Throws [XdrFormatException] for invalid string encoding
///
/// See also:
/// - [XdrOutputStream] for encoding XDR data
/// - RFC 4506 for XDR specification
class XdrInputStream {
  /// Creates an XDR input stream from encoded bytes.
  ///
  /// The stream maintains an internal offset that advances as data is read.
  XdrInputStream(final Uint8List bytes)
      : _data = ByteData.sublistView(bytes),
        _size = bytes.lengthInBytes;
  final ByteData _data;
  final int _size;
  int _offset = 0;

  /// Returns the total size of the input buffer in bytes.
  int get size => _size;

  /// Returns the number of bytes remaining to be read.
  ///
  /// This is useful for checking if all data has been consumed or for
  /// reading optional trailing data.
  int get remaining => _size - _offset;

  /// Checks if at least [bytes] are available to read
  bool canRead(final int bytes) => remaining >= bytes;

  /// Ensures at least [bytes] are available, throws XdrEofException otherwise
  void _ensureAvailable(final int bytes) {
    if (!canRead(bytes)) {
      throw XdrEofException(bytes, remaining);
    }
  }

  // ---- Primitive Readers ----
  int readInt() {
    _ensureAvailable(_xdrIntSize);
    final v = _data.getInt32(_offset);
    _offset += _xdrIntSize;
    return v;
  }

  int readUnsignedInt() {
    _ensureAvailable(_xdrIntSize);
    final v = _data.getUint32(_offset);
    _offset += _xdrIntSize;
    return v;
  }

  BigInt _readBigIntWithSign(final bool signed) {
    _ensureAvailable(_xdrHyperSize);
    final high = signed ? _data.getInt32(_offset) : _data.getUint32(_offset);
    final low = _data.getUint32(_offset + _xdrIntSize);
    _offset += _xdrHyperSize;
    return (BigInt.from(high) << _bitsPerWord) | BigInt.from(low);
  }

  BigInt readLong() => _readBigIntWithSign(true);

  BigInt readUnsignedLong() => _readBigIntWithSign(false);

  BigInt readHyper() => _readBigIntWithSign(true);

  BigInt readUnsignedHyper() => _readBigIntWithSign(false);

  bool readBoolean() => readInt() != 0;

  double readFloat() {
    _ensureAvailable(_xdrIntSize);
    final v = _data.getFloat32(_offset);
    _offset += _xdrIntSize;
    return v;
  }

  double readDouble() {
    _ensureAvailable(_xdrHyperSize);
    final v = _data.getFloat64(_offset);
    _offset += _xdrHyperSize;
    return v;
  }

  Object readQuadruple() {
    // RFC 4506 defines quadruple-precision (128-bit IEEE), but Dart
    // doesn't have native support. This would require a BigFloat library.
    throw UnimplementedError(
      'Quadruple-precision floating point is not supported. '
      'Dart lacks native 128-bit float support. Use double instead.',
    );
  }

  Uint8List readBytes([final int? fixedLen]) => readOpaque(fixedLen);

  Uint8List readOpaque([final int? fixedLen, final int? maxLength]) {
    int len;
    if (fixedLen == null) {
      len = readInt();
      if (maxLength != null && len > maxLength) {
        throw XdrRangeException(
          len,
          'opaque data (max: $maxLength bytes)',
        );
      }
    } else {
      len = fixedLen;
    }

    final pad = _padLength(len);
    _ensureAvailable(len + pad);

    // Use sublistView to create a view without copying bytes
    final data = Uint8List.sublistView(
      _data.buffer.asUint8List(),
      _data.offsetInBytes + _offset,
      _data.offsetInBytes + _offset + len,
    );
    _offset += len;
    _offset += pad;
    return data;
  }

  String readString({final bool strict = false, final int? maxLength}) {
    final len = readInt();
    if (maxLength != null && len > maxLength) {
      throw XdrRangeException(
        len,
        'string (max: $maxLength bytes)',
      );
    }
    final pad = _padLength(len);
    _ensureAvailable(len + pad);

    // Use sublistView to create a view without copying bytes
    final bytes = Uint8List.sublistView(
      _data.buffer.asUint8List(),
      _data.offsetInBytes + _offset,
      _data.offsetInBytes + _offset + len,
    );
    _offset += len;
    _offset += pad;

    // Validate no null bytes (C string compatibility)
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        throw XdrFormatException(
          'Null byte at position $i is not allowed in XDR strings. '
          'XDR strings must be compatible with C null-terminated strings.',
        );
      }
    }

    try {
      // RFC 4506: XDR strings should be ASCII, but we support UTF-8
      // for compatibility unless strict mode is enabled
      if (strict) {
        return _decodeAscii(bytes);
      }
      return utf8.decode(bytes);
    } catch (e) {
      throw XdrFormatException('Invalid string encoding: $e');
    }
  }

  /// Decode ASCII string, throwing if non-ASCII bytes present
  String _decodeAscii(final Uint8List bytes) {
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] > _maxAsciiValue) {
        throw XdrFormatException(
          'Non-ASCII byte at position $i (value: ${bytes[i]}). '
          'RFC 4506 XDR strings must be ASCII.',
        );
      }
    }
    return String.fromCharCodes(bytes);
  }

  // ---- Array Readers ----
  List<T> readFixedLengthArray<T>(
    final int length,
    final T Function(XdrInputStream) decoder,
  ) {
    final list = <T>[];
    for (int i = 0; i < length; i++) {
      list.add(decoder(this));
    }
    return list;
  }

  List<T> readVariableLengthArray<T>(
    final T Function(XdrInputStream) decoder, {
    final int? maxLength,
  }) {
    final len = readInt();
    if (maxLength != null && len > maxLength) {
      throw XdrRangeException(
        len,
        'variable array (max: $maxLength elements)',
      );
    }
    final list = <T>[];
    for (int i = 0; i < len; i++) {
      list.add(decoder(this));
    }
    return list;
  }
}
