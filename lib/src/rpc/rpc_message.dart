import 'dart:typed_data';

import '../xdr/xdr_io.dart';

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

abstract class RpcMessageBody {
  void encode(final XdrOutputStream stream);
}

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

abstract class AcceptData {
  void encode(final XdrOutputStream stream);
}

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

abstract class RejectData {
  void encode(final XdrOutputStream stream);
}

enum AuthFlavor {
  none(0),
  unix(1),
  short(2),
  des(3),
  gss(6);

  final int value;

  // ignore: sort_constructors_first
  const AuthFlavor(this.value);

  static AuthFlavor fromValue(final int value) => AuthFlavor.values
      .firstWhere((e) => e.value == value, orElse: () => AuthFlavor.none);
}

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
