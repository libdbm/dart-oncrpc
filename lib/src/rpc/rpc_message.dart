import 'dart:typed_data';

import '../xdr/xdr_io.dart';

/// RPC message type as defined by RFC 5531.
///
/// - [MessageType.call] represents a client call message.
/// - [MessageType.reply] represents a server reply message.
enum MessageType {
  call(0),
  reply(1);

  final int value;

  // ignore: sort_constructors_first
  const MessageType(this.value);

  static MessageType fromValue(final int value) =>
      MessageType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Invalid MessageType value: $value'),
      );
}

/// Reply status for an RPC reply message.
///
/// Indicates whether a server reply was accepted or denied.
enum ReplyStatus {
  accepted(0),
  denied(1);

  final int value;

  // ignore: sort_constructors_first
  const ReplyStatus(this.value);

  static ReplyStatus fromValue(final int value) =>
      ReplyStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Invalid ReplyStatus value: $value'),
      );
}

/// Accept status indicating the outcome of a successfully received call.
///
/// Returned within an accepted reply body to specify whether the call
/// succeeded or failed due to program/procedure issues.
enum AcceptStatus {
  success(0),
  progUnavail(1),
  progMismatch(2),
  procUnavail(3),
  garbageArgs(4),
  systemErr(5);

  final int value;

  // ignore: sort_constructors_first
  const AcceptStatus(this.value);

  static AcceptStatus fromValue(final int value) =>
      AcceptStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Invalid AcceptStatus value: $value'),
      );
}

/// Reject status indicating why a reply was denied at the RPC layer.
///
/// Used when the server could not process the call due to a protocol or
/// authentication mismatch.
enum RejectStatus {
  rpcMismatch(0),
  authError(1);

  final int value;

  // ignore: sort_constructors_first
  const RejectStatus(this.value);

  static RejectStatus fromValue(final int value) =>
      RejectStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Invalid RejectStatus value: $value'),
      );
}

/// Authentication status codes for AUTH flavors.
///
/// Returned by the server to indicate authentication/verification result.
enum AuthStatus {
  ok(0),
  badcred(1),
  rejectedcred(2),
  badverf(3),
  rejectedverf(4),
  tooweak(5),
  invalidresp(6),
  failed(7);

  final int value;

  // ignore: sort_constructors_first
  const AuthStatus(this.value);

  static AuthStatus fromValue(final int value) => AuthStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Invalid AuthStatus value: $value'),
      );
}

/// Represents a complete RPC message with header and body.
///
/// The message consists of an XID, a [MessageType], and a body that is either
/// a [CallBody] or [ReplyBody] depending on the type.
class RpcMessage {
  RpcMessage({
    required this.xid,
    required this.messageType,
    required this.body,
  });
  final int xid;
  final MessageType messageType;
  final RpcMessageBody body;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(xid)
      ..writeInt(messageType.value);
    body.encode(stream);
  }

  // ignore: prefer_constructors_over_static_methods
  static RpcMessage decode(final XdrInputStream stream) {
    final xid = stream.readInt();
    final messageType = MessageType.fromValue(stream.readInt());

    RpcMessageBody body;
    if (messageType == MessageType.call) {
      body = CallBody.decode(stream);
    } else {
      body = ReplyBody.decode(stream);
    }

    return RpcMessage(
      xid: xid,
      messageType: messageType,
      body: body,
    );
  }
}

/// Base type for all RPC message bodies.
///
/// Implemented by [CallBody] for call messages and [ReplyBody] for replies.
abstract class RpcMessageBody {
  void encode(final XdrOutputStream stream);
}

/// RPC call message body.
///
/// Contains program, version, procedure numbers, authentication credentials
/// and optional raw parameters encoded using XDR.
class CallBody extends RpcMessageBody {
  CallBody({
    this.rpcvers = 2,
    required this.prog,
    required this.vers,
    required this.proc,
    required this.cred,
    required this.verf,
    this.params,
  });
  final int rpcvers;
  final int prog;
  final int vers;
  final int proc;
  final OpaqueAuth cred;
  final OpaqueAuth verf;
  final Uint8List? params;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(rpcvers)
      ..writeInt(prog)
      ..writeInt(vers)
      ..writeInt(proc);
    cred.encode(stream);
    verf.encode(stream);
    if (params != null) {
      stream.writeBytes(params!, fixed: true);
    }
  }

  // ignore: prefer_constructors_over_static_methods
  static CallBody decode(final XdrInputStream stream) {
    final rpcvers = stream.readInt();
    final prog = stream.readInt();
    final vers = stream.readInt();
    final proc = stream.readInt();
    final cred = OpaqueAuth.decode(stream);
    final verf = OpaqueAuth.decode(stream);

    // Transport layer provides message boundaries.
    // Any remaining bytes are procedure parameters (no length prefix).
    final remaining = stream.remaining;
    final params = remaining > 0 ? stream.readBytes(remaining) : null;

    return CallBody(
      rpcvers: rpcvers,
      prog: prog,
      vers: vers,
      proc: proc,
      cred: cred,
      verf: verf,
      params: params,
    );
  }
}

/// RPC reply message body.
///
/// Includes the high-level [ReplyStatus] and the detailed reply data for
/// accepted or rejected replies.
class ReplyBody extends RpcMessageBody {
  ReplyBody({
    required this.replyStatus,
    required this.data,
  });
  final ReplyStatus replyStatus;
  final ReplyData data;

  @override
  void encode(final XdrOutputStream stream) {
    stream.writeInt(replyStatus.value);
    data.encode(stream);
  }

  // ignore: prefer_constructors_over_static_methods
  static ReplyBody decode(final XdrInputStream stream) {
    final replyStatus = ReplyStatus.fromValue(stream.readInt());

    ReplyData data;
    if (replyStatus == ReplyStatus.accepted) {
      data = AcceptedReply.decode(stream);
    } else {
      data = RejectedReply.decode(stream);
    }

    return ReplyBody(
      replyStatus: replyStatus,
      data: data,
    );
  }
}

abstract class ReplyData {
  void encode(final XdrOutputStream stream);
}

/// Details for an accepted RPC reply.
///
/// Contains the server verifier, the [AcceptStatus], and optional status data
/// such as version mismatch info or success payload metadata.
class AcceptedReply extends ReplyData {
  AcceptedReply({
    required this.verf,
    required this.acceptStatus,
    this.data,
  });
  final OpaqueAuth verf;
  final AcceptStatus acceptStatus;
  final AcceptData? data;

  @override
  void encode(final XdrOutputStream stream) {
    verf.encode(stream);
    stream.writeInt(acceptStatus.value);
    data?.encode(stream);
  }

  // ignore: prefer_constructors_over_static_methods
  static AcceptedReply decode(final XdrInputStream stream) {
    final verf = OpaqueAuth.decode(stream);
    final acceptStatus = AcceptStatus.fromValue(stream.readInt());

    AcceptData? data;
    switch (acceptStatus) {
      case AcceptStatus.progMismatch:
        data = MismatchInfo.decode(stream);
        break;
      case AcceptStatus.success:
        data = SuccessData.decode(stream);
        break;
      case AcceptStatus.progUnavail:
      case AcceptStatus.procUnavail:
      case AcceptStatus.garbageArgs:
      case AcceptStatus.systemErr:
        break;
    }

    return AcceptedReply(
      verf: verf,
      acceptStatus: acceptStatus,
      data: data,
    );
  }
}

/// Details for a rejected RPC reply.
///
/// Contains the [RejectStatus] and optional data describing the reason for
/// rejection (e.g., version mismatch or authentication failure).
class RejectedReply extends ReplyData {
  RejectedReply({
    required this.rejectStatus,
    this.data,
  });
  final RejectStatus rejectStatus;
  final RejectData? data;

  @override
  void encode(final XdrOutputStream stream) {
    stream.writeInt(rejectStatus.value);
    data?.encode(stream);
  }

  // ignore: prefer_constructors_over_static_methods
  static RejectedReply decode(final XdrInputStream stream) {
    final rejectStatus = RejectStatus.fromValue(stream.readInt());

    RejectData? data;
    switch (rejectStatus) {
      case RejectStatus.rpcMismatch:
        data = MismatchInfo.decode(stream);
        break;
      case RejectStatus.authError:
        data = AuthError.decode(stream);
        break;
    }

    return RejectedReply(
      rejectStatus: rejectStatus,
      data: data,
    );
  }
}

/// Base class for additional data accompanying an accepted reply.
abstract class AcceptData {
  void encode(final XdrOutputStream stream);
}

/// Success result payload for an accepted reply.
///
/// Contains the raw XDR-encoded procedure result bytes if present.
class SuccessData extends AcceptData {
  SuccessData(this.result);
  final Uint8List? result;

  @override
  void encode(final XdrOutputStream stream) {
    if (result != null) {
      stream.writeBytes(result!, fixed: true);
    }
  }

  // ignore: prefer_constructors_over_static_methods
  static SuccessData decode(final XdrInputStream stream) {
    // Transport layer provides message boundaries.
    // Any remaining bytes are the procedure result (no length prefix).
    final remaining = stream.remaining;
    return SuccessData(remaining > 0 ? stream.readBytes(remaining) : null);
  }
}

/// Base class for additional data accompanying a rejected reply.
abstract class RejectData {
  void encode(final XdrOutputStream stream);
}

/// RPC authentication flavor identifiers.
///
/// Used inside [OpaqueAuth] to indicate the authentication mechanism.
enum AuthFlavor {
  /// Unknown/unsupported flavor value received from the wire.
  ///
  /// This variant is only used while decoding incoming messages.
  unknown(-1),
  none(0),
  unix(1),
  short(2),
  des(3),
  gss(6);

  final int value;

  // ignore: sort_constructors_first
  const AuthFlavor(this.value);

  static AuthFlavor fromValue(final int value) => AuthFlavor.values.firstWhere(
        (e) => e.value == value,
        orElse: () => AuthFlavor.unknown,
      );
}

/// Authentication verifier/credentials structure used in RPC headers.
///
/// Contains the [AuthFlavor] and an opaque byte body whose structure depends
/// on the selected flavor.
class OpaqueAuth {
  OpaqueAuth({required this.flavor, required this.body});

  factory OpaqueAuth.none() =>
      OpaqueAuth(flavor: AuthFlavor.none, body: Uint8List(0));
  final AuthFlavor flavor;
  final Uint8List body;

  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(flavor.value)
      ..writeOpaque(body);
  }

  // ignore: prefer_constructors_over_static_methods
  static OpaqueAuth decode(final XdrInputStream stream) {
    final flavor = AuthFlavor.fromValue(stream.readInt());
    final body = stream.readOpaque();
    return OpaqueAuth(flavor: flavor, body: body);
  }
}

/// Version mismatch information for accepted/rejected replies.
///
/// Communicates the supported version range when the requested version is
/// not supported.
class MismatchInfo extends AcceptData implements RejectData {
  MismatchInfo({required this.low, required this.high});
  final int low;
  final int high;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(low)
      ..writeInt(high);
  }

  // ignore: prefer_constructors_over_static_methods
  static MismatchInfo decode(final XdrInputStream stream) {
    final low = stream.readInt();
    final high = stream.readInt();
    return MismatchInfo(low: low, high: high);
  }
}

/// Authentication error details for a rejected reply.
///
/// Wraps an [AuthStatus] code describing the specific authentication failure.
class AuthError extends RejectData {
  AuthError({required this.status});
  final AuthStatus status;

  @override
  void encode(final XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  // ignore: prefer_constructors_over_static_methods
  static AuthError decode(final XdrInputStream stream) {
    final status = AuthStatus.fromValue(stream.readInt());
    return AuthError(status: status);
  }
}
