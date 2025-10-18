import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'framing/record_marking.dart';
import 'rpc_logger.dart';

/// Encapsulates an incoming RPC request from a transport.
///
/// It contains the raw XDR-encoded request data and a function
/// to send a response back to the originator.
class RpcRequest {
  RpcRequest(this.data, this.respond);

  /// The raw XDR-encoded request data.
  final Uint8List data;

  /// A function to send a response back to the client.
  final Future<void> Function(Uint8List response) respond;
}

/// Abstract base class for server-side network transports.
///
/// A transport is responsible for listening for incoming client connections,
/// decoding network data into discrete RPC request messages, and providing
/// a mechanism to send responses.
abstract class ServerTransport {
  /// A stream of incoming RPC requests.
  ///
  /// The [RpcServer] listens to this stream to process requests.
  Stream<RpcRequest> get requests;

  /// Starts the transport, making it listen for incoming requests.
  Future<void> listen();

  /// Stops the transport and releases any underlying resources.
  Future<void> close();
}

/// A [ServerTransport] implementation for TCP.
///
/// It handles the record marking protocol for RPC over TCP.
class TcpServerTransport implements ServerTransport {
  TcpServerTransport({
    String? address,
    required int port,
    SecurityContext? securityContext,
    bool useTls = false,
  })  : _address = address ?? InternetAddress.anyIPv4.address,
        _port = port,
        _securityContext = securityContext,
        _useTls = useTls;
  final String _address;
  final int _port;
  final SecurityContext? _securityContext;
  final bool _useTls;
  ServerSocket? _serverSocket;
  SecureServerSocket? _secureServerSocket;
  StreamSubscription<Socket>? _serverSubscription;
  final StreamController<RpcRequest> _requestController =
      StreamController<RpcRequest>();

  @override
  Stream<RpcRequest> get requests => _requestController.stream;

  /// Returns the effective listening port. Useful when binding to port 0.
  int get port => _serverSocket?.port ?? _secureServerSocket?.port ?? _port;

  @override
  Future<void> listen() async {
    if (_serverSocket != null || _secureServerSocket != null) {
      return; // Already listening
    }

    if (_useTls) {
      if (_securityContext == null) {
        throw ArgumentError('SecurityContext required for TLS');
      }
      _secureServerSocket = await SecureServerSocket.bind(
        InternetAddress(_address),
        _port,
        _securityContext!,
      );
      RpcLogger.info(
        'RPC server listening on TLS port ${_secureServerSocket!.port}',
      );
      _serverSubscription = _secureServerSocket!.listen(_handleClient);
    } else {
      _serverSocket = await ServerSocket.bind(InternetAddress(_address), _port);
      RpcLogger.info(
        'RPC server listening on TCP port ${_serverSocket!.port}',
      );
      _serverSubscription = _serverSocket!.listen(_handleClient);
    }
  }

  @override
  Future<void> close() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    if (_serverSocket != null) {
      await _serverSocket!.close();
      _serverSocket = null;
    }
    if (_secureServerSocket != null) {
      await _secureServerSocket!.close();
      _secureServerSocket = null;
    }
    await _requestController.close();
  }

  void _handleClient(final Socket client) {
    final buffer = BytesBuilder();
    final codec = RecordMarkingCodec();

    // Response queue to ensure serial response sending per connection
    final responseQueue = StreamController<Uint8List>();

    // Start the response sender for this connection
    _processResponseQueue(client, responseQueue.stream);

    client.listen(
      (final Uint8List data) {
        buffer.add(data);
        final records = codec.decode(buffer);

        for (final record in records) {
          final request = RpcRequest(
            record,
            (final response) async {
              // Queue the response instead of sending directly
              responseQueue.add(response);
            },
          );
          _requestController.add(request);
        }
      },
      onError: (final Object error) {
        RpcLogger.error('TCP client error', error);
        responseQueue.close();
        client.close();
      },
      onDone: () {
        responseQueue.close();
        client.close();
      },
    );
  }

  /// Process responses serially for a TCP connection
  Future<void> _processResponseQueue(
    final Socket client,
    final Stream<Uint8List> responses,
  ) async {
    final codec = RecordMarkingCodec();

    await for (final response in responses) {
      try {
        RpcLogger.debug('Sending TCP response: ${response.length} bytes');
        final encoded = codec.encode(response);
        RpcLogger.debug(
          'Encoded TCP response: ${encoded.length} bytes (with record marking)',
        );
        client.add(encoded);
        await client.flush();
        RpcLogger.debug('TCP response flushed successfully');
      } catch (e) {
        RpcLogger.error('Failed to send TCP response', e);
        break;
      }
    }
  }
}

/// A [ServerTransport] implementation for UDP.
class UdpServerTransport implements ServerTransport {
  UdpServerTransport({String? address, required int port})
      : _address = address ?? InternetAddress.anyIPv4.address,
        _port = port;
  final String _address;
  final int _port;
  RawDatagramSocket? _socket;
  final StreamController<RpcRequest> _requestController =
      StreamController<RpcRequest>();

  @override
  Stream<RpcRequest> get requests => _requestController.stream;

  @override
  Future<void> listen() async {
    if (_socket != null) return;
    _socket = await RawDatagramSocket.bind(InternetAddress(_address), _port);
    _socket!.listen((final RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          final request = RpcRequest(
            datagram.data,
            (final response) async {
              _socket!.send(response, datagram.address, datagram.port);
            },
          );
          _requestController.add(request);
        }
      }
    });
    RpcLogger.info('RPC server listening on UDP port $_port');
  }

  @override
  Future<void> close() async {
    _socket?.close();
    await _requestController.close();
    _socket = null;
  }
}
