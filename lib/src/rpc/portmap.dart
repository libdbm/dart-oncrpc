/// Port Mapper (portmap/rpcbind) client implementation.
///
/// The port mapper is a special RPC service that maps RPC program numbers to
/// network ports. It runs on port 111 and allows clients to discover which
/// port a particular RPC service is listening on.
///
/// This implementation provides version 2 of the portmap protocol (program 100000),
/// which is the most widely deployed version. It supports:
/// - Service registration (PMAPPROC_SET)
/// - Service unregistration (PMAPPROC_UNSET)
/// - Port lookup (PMAPPROC_GETPORT)
/// - Service enumeration (PMAPPROC_DUMP)
///
/// ## Client Usage
///
/// ```dart
/// // Look up the port for an RPC service
/// final port = await PortmapRegistration.lookup(
///   prog: 100005,  // MOUNT program
///   vers: 3,
///   useTcp: true,
///   portmapHost: 'nfs-server.local',
/// );
///
/// if (port != 0) {
///   print('MOUNT v3 is listening on port $port');
/// }
/// ```
///
/// ## Server Usage
///
/// ```dart
/// // Register your service with the portmapper
/// final registered = await PortmapRegistration.register(
///   prog: 0x20000001,
///   vers: 1,
///   port: 8080,
///   useTcp: true,
/// );
///
/// // Later, unregister when shutting down
/// await PortmapRegistration.unregister(
///   prog: 0x20000001,
///   vers: 1,
///   useTcp: true,
/// );
/// ```
///
/// ## Protocol Details
///
/// The portmap protocol uses the following procedures:
/// - PMAPPROC_NULL (0): Ping/health check
/// - PMAPPROC_SET (1): Register a service
/// - PMAPPROC_UNSET (2): Unregister a service
/// - PMAPPROC_GETPORT (3): Look up service port
/// - PMAPPROC_DUMP (4): List all registered services
/// - PMAPPROC_CALLIT (5): Indirect call (broadcast)
///
/// See RFC 1833 for the complete specification.
library;

import 'dart:typed_data';

import '../xdr/xdr_io.dart';
import 'rpc_authentication.dart';
import 'rpc_client.dart';
import 'rpc_errors.dart';
import 'rpc_transport.dart';

// Portmapper program constants
// ignore_for_file: constant_identifier_names
const PMAP_PROG = 100000;
const PMAP_VERS = 2;
const PMAPPROC_NULL = 0;
const PMAPPROC_SET = 1;
const PMAPPROC_UNSET = 2;
const PMAPPROC_GETPORT = 3;
const PMAPPROC_DUMP = 4;
const PMAPPROC_CALLIT = 5;

// Portmapper port
const PMAP_PORT = 111;

// Protocol constants
const IPPROTO_TCP = 6;
const IPPROTO_UDP = 17;

/// Portmap mapping entry describing a registered RPC service.
///
/// Contains the program number, version, protocol, and port.
class Mapping extends XdrType {
  Mapping({
    required this.prog,
    required this.vers,
    required this.prot,
    required this.port,
  });

  final int prog;
  final int vers;
  final int prot;
  final int port;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(prog)
      ..writeInt(vers)
      ..writeInt(prot)
      ..writeInt(port);
  }

  // ignore: prefer_constructors_over_static_methods
  static Mapping decode(final XdrInputStream stream) => Mapping(
        prog: stream.readInt(),
        vers: stream.readInt(),
        prot: stream.readInt(),
        port: stream.readInt(),
      );
}

/// Singly-linked list of [Mapping] entries returned by PMAPPROC_DUMP.
class PmapList extends XdrType {
  PmapList({this.map, this.next});

  final Mapping? map;
  PmapList? next;

  @override
  void encode(final XdrOutputStream stream) {
    if (map != null) {
      stream.writeInt(1); // Present
      map!.encode(stream);
      if (next != null) {
        next!.encode(stream);
      } else {
        stream.writeInt(0); // No more entries
      }
    } else {
      stream.writeInt(0); // Not present
    }
  }

  static PmapList? decode(final XdrInputStream stream) {
    // Use iterative approach to avoid stack overflow with large lists
    PmapList? head;
    PmapList? current;

    while (true) {
      final present = stream.readInt();
      if (present == 0) {
        break;
      }

      final map = Mapping.decode(stream);
      final node = PmapList(map: map);

      if (head == null) {
        head = current = node;
      } else {
        current!.next = node;
        current = node;
      }
    }

    return head;
  }

  List<Mapping> toList() {
    final result = <Mapping>[];
    PmapList? current = this;
    while (current != null && current.map != null) {
      result.add(current.map!);
      current = current.next;
    }
    return result;
  }
}

/// Arguments for PMAPPROC_CALLIT indirect call.
class CallArgs extends XdrType {
  CallArgs({
    required this.prog,
    required this.vers,
    required this.proc,
    required this.args,
  });

  final int prog;
  final int vers;
  final int proc;
  final Uint8List args;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(prog)
      ..writeInt(vers)
      ..writeInt(proc)
      ..writeOpaque(args);
  }

  CallArgs decode(final XdrInputStream stream) {
    final prog = stream.readInt();
    final vers = stream.readInt();
    final proc = stream.readInt();
    final args = stream.readOpaque();

    return CallArgs(
      prog: prog,
      vers: vers,
      proc: proc,
      args: args,
    );
  }
}

class CallResult extends XdrType {
  CallResult({
    required this.port,
    required this.res,
  });

  final int port;
  final Uint8List res;

  @override
  void encode(final XdrOutputStream stream) {
    stream
      ..writeInt(port)
      ..writeOpaque(res);
  }

  // ignore: prefer_constructors_over_static_methods
  static CallResult decode(final XdrInputStream stream) {
    final port = stream.readInt();
    final res = stream.readOpaque();

    return CallResult(
      port: port,
      res: res,
    );
  }
}

class PortmapClient {
  PortmapClient._(this._client);

  final RpcClient _client;

  static Future<PortmapClient> connect({
    String host = 'localhost',
    int port = PMAP_PORT,
    bool useTcp = true,
  }) async {
    final transport = useTcp
        ? TcpTransport(host: host, port: port)
        : UdpTransport(host: host, port: port);

    final client = RpcClient(
      transport: transport,
      auth: AuthNone(),
    );

    await client.connect();
    return PortmapClient._(client);
  }

  Future<void> close() async {
    await _client.close();
  }

  Future<void> null_() async {
    await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_NULL,
    );
  }

  Future<bool> set(final Mapping mapping) async {
    final result = await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_SET,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final resultStream = XdrInputStream(result);
      return resultStream.readInt() != 0;
    }
    return false;
  }

  Future<bool> unset(final Mapping mapping) async {
    final result = await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_UNSET,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final resultStream = XdrInputStream(result);
      return resultStream.readInt() != 0;
    }
    return false;
  }

  Future<int> port({
    required int prog,
    required int vers,
    required int prot,
  }) async {
    final mapping = Mapping(
      prog: prog,
      vers: vers,
      prot: prot,
      port: 0,
    );

    final result = await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_GETPORT,
      params: mapping.toXdr(),
    );

    if (result != null) {
      final resultStream = XdrInputStream(result);
      return resultStream.readInt();
    }
    return 0;
  }

  Future<List<Mapping>> dump() async {
    final result = await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_DUMP,
    );

    if (result != null) {
      final resultStream = XdrInputStream(result);
      final pmapList = PmapList.decode(resultStream);
      return pmapList?.toList() ?? [];
    }
    return [];
  }

  Future<CallResult> callIt(final CallArgs args) async {
    final result = await _client.call(
      program: PMAP_PROG,
      version: PMAP_VERS,
      procedure: PMAPPROC_CALLIT,
      params: args.toXdr(),
    );

    if (result != null) {
      final resultStream = XdrInputStream(result);
      return CallResult.decode(resultStream);
    }
    throw RpcProtocolError('No result received from portmap CALLIT');
  }
}

// Helper class to register services with portmapper
class PortmapRegistration {
  static Future<bool> register({
    required int prog,
    required int vers,
    required int port,
    bool useTcp = true,
    String portmapHost = 'localhost',
    int portmapPort = PMAP_PORT,
  }) async {
    final client = await PortmapClient.connect(
      host: portmapHost,
      port: portmapPort,
    );

    try {
      final mapping = Mapping(
        prog: prog,
        vers: vers,
        prot: useTcp ? IPPROTO_TCP : IPPROTO_UDP,
        port: port,
      );

      return await client.set(mapping);
    } finally {
      await client.close();
    }
  }

  static Future<bool> unregister({
    required int prog,
    required int vers,
    bool useTcp = true,
    String portmapHost = 'localhost',
    int portmapPort = PMAP_PORT,
  }) async {
    final client = await PortmapClient.connect(
      host: portmapHost,
      port: portmapPort,
    );

    try {
      final mapping = Mapping(
        prog: prog,
        vers: vers,
        prot: useTcp ? IPPROTO_TCP : IPPROTO_UDP,
        port: 0,
      );

      return await client.unset(mapping);
    } finally {
      await client.close();
    }
  }

  static Future<int> lookup({
    required int prog,
    required int vers,
    bool useTcp = true,
    String portmapHost = 'localhost',
    int portmapPort = PMAP_PORT,
  }) async {
    final client = await PortmapClient.connect(
      host: portmapHost,
      port: portmapPort,
    );

    try {
      return await client.port(
        prog: prog,
        vers: vers,
        prot: useTcp ? IPPROTO_TCP : IPPROTO_UDP,
      );
    } finally {
      await client.close();
    }
  }
}
