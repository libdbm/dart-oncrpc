import '../xdr/xdr_io.dart';
import 'rpc_authentication.dart';
import 'rpc_client.dart';
import 'rpc_transport.dart';

// RFC 1833: Binding Protocols for ONC RPC Version 2
// RPCBIND program constants (Port Mapper v3/v4)
// ignore_for_file: constant_identifier_names
const RPCBIND_PROG = 100000;
const RPCBIND_VERS3 = 3;
const RPCBIND_VERS4 = 4;

// RPCBIND v3/v4 procedures
const RPCBINDPROC_NULL = 0;
const RPCBINDPROC_SET = 1;
const RPCBINDPROC_UNSET = 2;
const RPCBINDPROC_GETADDR = 3;
const RPCBINDPROC_DUMP = 4;
const RPCBINDPROC_BCAST = 5; // v3 broadcast
const RPCBINDPROC_GETTIME = 6;
const RPCBINDPROC_UADDR2TADDR = 7;
const RPCBINDPROC_TADDR2UADDR = 8;

// RPCBIND port
const RPCBIND_PORT = 111;

/// Universal address representation (e.g., "192.168.1.1.8.1" for TCP)
class Rpcb extends XdrType {
  // Owner of the mapping

  Rpcb({
    required this.program,
    required this.version,
    required this.protocol,
    required this.addr,
    required this.owner,
  });

  final int program;
  final int version;
  final String protocol; // Network ID (e.g., "tcp", "udp", "tcp6")
  final String addr; // Universal address
  final String owner;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(program)
      ..writeInt(version)
      ..writeString(protocol)
      ..writeString(addr)
      ..writeString(owner);
  }

  // ignore: prefer_constructors_over_static_methods
  static Rpcb decode(final XdrInputStream stream) => Rpcb(
        program: stream.readInt(),
        version: stream.readInt(),
        protocol: stream.readString(),
        addr: stream.readString(),
        owner: stream.readString(),
      );
}

/// List of RPC bind entries
class RpcbList extends XdrType {
  RpcbList({this.rpcb, this.next});

  final Rpcb? rpcb;
  RpcbList? next;

  @override
  void encode(final XdrOutputStream stream) {
    if (rpcb != null) {
      stream.writeInt(1); // Present
      rpcb!.encode(stream);
      if (next != null) {
        next!.encode(stream);
      } else {
        stream.writeInt(0); // No more entries
      }
    } else {
      stream.writeInt(0); // Not present
    }
  }

  static RpcbList? decode(final XdrInputStream stream) {
    // Use iterative approach to avoid stack overflow
    RpcbList? head;
    RpcbList? current;

    while (true) {
      final present = stream.readInt();
      if (present == 0) {
        break;
      }

      final rpcb = Rpcb.decode(stream);
      final node = RpcbList(rpcb: rpcb);

      if (head == null) {
        head = current = node;
      } else {
        current!.next = node;
        current = node;
      }
    }

    return head;
  }

  List<Rpcb> toList() {
    final result = <Rpcb>[];
    RpcbList? current = this;
    while (current != null && current.rpcb != null) {
      result.add(current.rpcb!);
      current = current.next;
    }
    return result;
  }
}

/// RPCBIND client for v3/v4 protocol
class RpcbindClient {
  RpcbindClient._(this._client, this._version);

  final RpcClient _client;
  final int _version;

  static Future<RpcbindClient> connect({
    String host = 'localhost',
    int port = RPCBIND_PORT,
    bool useTcp = true,
    int version = RPCBIND_VERS4,
  }) async {
    if (version != RPCBIND_VERS3 && version != RPCBIND_VERS4) {
      throw ArgumentError('RPCBIND version must be 3 or 4');
    }

    final transport = useTcp
        ? TcpTransport(host: host, port: port)
        : UdpTransport(host: host, port: port);

    final client = RpcClient(
      transport: transport,
      auth: AuthNone(),
    );

    await client.connect();
    return RpcbindClient._(client, version);
  }

  Future<void> close() async {
    await _client.close();
  }

  Future<void> null_() async {
    await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_NULL,
    );
  }

  Future<bool> set(final Rpcb mapping) async {
    final result = await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_SET,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readInt() != 0;
    }
    return false;
  }

  Future<bool> unset(final Rpcb mapping) async {
    final result = await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_UNSET,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readInt() != 0;
    }
    return false;
  }

  Future<String?> getAddr({
    required int program,
    required int version,
    required String protocol,
  }) async {
    final mapping = Rpcb(
      program: program,
      version: version,
      protocol: protocol,
      addr: '',
      owner: '',
    );

    final result = await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_GETADDR,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      final addr = stream.readString();
      return addr.isEmpty ? null : addr;
    }
    return null;
  }

  Future<List<Rpcb>> dump() async {
    final result = await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_DUMP,
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      final list = RpcbList.decode(stream);
      return list?.toList() ?? [];
    }
    return [];
  }

  Future<int> getTime() async {
    final result = await _client.call(
      program: RPCBIND_PROG,
      version: _version,
      procedure: RPCBINDPROC_GETTIME,
    );

    if (result != null) {
      final stream = XdrInputStream(result);
      return stream.readInt();
    }
    return 0;
  }
}

/// Helper to convert between universal address and transport address
class UniversalAddress {
  /// Number of bits in a byte (8).
  static const int _bitsPerByte = 8;

  /// Byte mask (0xFF) for extracting 8-bit values.
  static const int _byteMask = 0xFF;

  /// Parse universal address (e.g., "192.168.1.1.8.1") to host/port
  static (String host, int port)? parse(final String uaddr) {
    final parts = uaddr.split('.');
    if (parts.length < 6) return null;

    // IPv4: a.b.c.d.p1.p2 where port = (p1 << 8) | p2
    final host = parts.sublist(0, 4).join('.');
    final p1 = int.tryParse(parts[4]) ?? 0;
    final p2 = int.tryParse(parts[5]) ?? 0;
    final port = (p1 << _bitsPerByte) | p2;

    return (host, port);
  }

  /// Convert host/port to universal address
  static String format(final String host, final int port) {
    final p1 = (port >> _bitsPerByte) & _byteMask;
    final p2 = port & _byteMask;
    return '$host.$p1.$p2';
  }
}
