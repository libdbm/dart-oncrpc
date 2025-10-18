/// Exception thrown when XDR stream operations fail
abstract class XdrException implements Exception {
  XdrException(this.message);
  final String message;

  @override
  String toString() => 'XdrException: $message';
}

/// Exception thrown when attempting to read beyond available data
class XdrEofException extends XdrException {
  XdrEofException(this.requested, this.available)
      : super('Cannot read $requested bytes, only $available bytes available');
  final int requested;
  final int available;

  @override
  String toString() =>
      'XdrEofException: Cannot read $requested bytes, only $available bytes available';
}

/// Exception thrown when XDR data is malformed or invalid
class XdrFormatException extends XdrException {
  XdrFormatException(super.message);

  @override
  String toString() => 'XdrFormatException: $message';
}

/// Exception thrown when a value is out of valid range for XDR type
class XdrRangeException extends XdrException {
  XdrRangeException(this.value, this.type)
      : super('Value $value is out of range for XDR type $type');
  final dynamic value;
  final String type;

  @override
  String toString() =>
      'XdrRangeException: Value $value is out of range for XDR type $type';
}
