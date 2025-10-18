// lib/xdr_annotations.dart
class XdrStruct {
  const XdrStruct();
}

class XdrUnion {
  const XdrUnion();
}

/// Field metadata (optional for unions, required for naming)
class XdrField {
  // for unions only
  const XdrField({this.discriminant});
  final int? discriminant;
}
