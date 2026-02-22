import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../xdr/xdr_io.dart';
import 'framing/record_marking.dart';
import 'rpc_errors.dart';
import 'rpc_message.dart';

/// Base class for RPC transport implementations.
///
/// [RpcTransport] defines the interface for network transports that carry
/// RPC messages between clients and servers. The library provides two
/// standard implementations:
///
/// - [TcpTransport]: Reliable, connection-oriented transport over TCP
/// - [UdpTransport]: Connectionless datagram transport over UDP
///
/// ## Usage
///
/// Transports are used by [RpcClient] for making RPC calls:
///
/// ```dart
/// // TCP transport for reliable communication
/// final transport = TcpTransport(host: 'server.local', port: 2049);
/// final client = RpcClient(transport: transport);
/// await client.connect();
/// ```
///
/// ## Custom Transports
///
/// You can implement custom transports by extending this class:
///
/// ```dart
/// class UnixSocketTransport extends RpcTransport {
///   @override
///   Future<void> connect() async {
///     // Connect to Unix socket
///   }
///
///   @override
///   Future<void> sendMessage(RpcMessage message) async {
///     // Send message over Unix socket
///   }
///
///   // Implement other methods...
/// }
/// ```
abstract class RpcTransport {
  /// Establishes the transport connection.
  ///
  /// Must be called before sending or receiving messages.
  /// Throws [RpcTransportError] if connection fails.
  Future<void> connect();

  /// Closes the transport connection and releases resources.
  Future<void> close();

  /// Sends an RPC message over the transport.
  ///
  /// The message is XDR-encoded before transmission. For TCP, record marking
  /// is applied. For UDP, the entire message is sent as a single datagram.
  ///
  /// Throws [RpcTransportError] if sending fails.
  Future<void> send(RpcMessage message);

  /// Stream of incoming RPC messages.
  ///
  /// Messages are automatically decoded from the transport format and
  /// delivered as [RpcMessage] objects.
  Stream<RpcMessage> get messages;

  /// Returns true if the transport is currently connected.
  bool get isConnected;
}

/// TCP transport for reliable RPC communication.
///
/// [TcpTransport] provides connection-oriented, reliable message delivery
/// using TCP sockets. It implements RFC 5531 record marking protocol for
/// framing RPC messages.
///
/// ## Features
///
/// - Reliable, ordered delivery of RPC messages
/// - Automatic reconnection support
/// - TLS/SSL encryption support
/// - Record marking for message framing
/// - Connection state management
///
/// ## Usage
///
/// ```dart
/// // Basic TCP transport
/// final transport = TcpTransport(
///   host: 'nfs-server.local',
///   port: 2049,
/// );
///
/// final client = RpcClient(transport: transport);
/// await client.connect();
/// ```
///
/// ## TLS/SSL Support
///
/// ```dart
/// // Create security context
/// final context = SecurityContext()
///   ..setTrustedCertificates('ca-cert.pem')
///   ..useCertificateChain('client-cert.pem')
///   ..usePrivateKey('client-key.pem');
///
/// // Use TLS transport
/// final transport = TcpTransport(
///   host: 'secure-server.local',
///   port: 2049,
///   useTls: true,
///   securityContext: context,
/// );
/// ```
///
/// ## When to Use TCP
///
/// TCP is recommended for:
/// - Production RPC services requiring reliability
/// - Large message payloads
/// - Services requiring ordered delivery
/// - Encrypted communication (with TLS)
///
/// See also:
/// - [UdpTransport] for connectionless communication
/// - RFC 5531 section 11 for TCP transport details
class TcpTransport extends RpcTransport {
  /// Creates a TCP transport to the specified host and port.
  ///
  /// Parameters:
  /// - [host]: The server hostname or IP address
  /// - [port]: The server port number
  /// - [securityContext]: Optional TLS security context
  /// - [useTls]: If true, use TLS/SSL encryption (default: false)
  TcpTransport({
    required this.host,
    required this.port,
    this.securityContext,
    this.useTls = false,
  });

  /// The server hostname or IP address to connect to.
  final String host;

  /// The TCP port number to connect to.
  final int port;

  /// Optional security context for TLS connections.
  final SecurityContext? securityContext;

  /// Whether to use TLS/SSL encryption.
  final bool useTls;
  Socket? _socket;
  final _messageController = StreamController<RpcMessage>.broadcast();
  final _buffer = BytesBuilder();
  final _codec = RecordMarkingCodec();

  @override
  bool get isConnected => _socket != null;

  @override
  Stream<RpcMessage> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    if (_socket != null) {
      throw RpcConnectionError.alreadyConnected();
    }

    try {
      if (useTls) {
        _socket = await SecureSocket.connect(
          host,
          port,
          context: securityContext,
          onBadCertificate: securityContext == null ? (_) => false : null,
        );
      } else {
        _socket = await Socket.connect(host, port);
      }

      _socket!.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );
    } catch (e) {
      throw RpcTransportError('Failed to connect to $host:$port', cause: e);
    }
  }

  @override
  Future<void> close() async {
    try {
      await _socket?.close();
    } catch (e) {
      // Socket may already be closed
    }
    _socket = null;
    await _messageController.close();
  }

  @override
  Future<void> send(final RpcMessage message) async {
    if (_socket == null) {
      throw RpcConnectionError.notConnected();
    }

    try {
      final stream = XdrOutputStream();
      message.encode(stream);
      final data = stream.toBytes();

      // Encode with record marking
      final encoded = _codec.encode(data);
      _socket!.add(encoded);
      await _socket!.flush();
    } catch (e) {
      throw RpcTransportError('Failed to send message', cause: e);
    }
  }

  void _handleData(final Uint8List data) {
    _buffer.add(data);
    try {
      _processBuffer();
    } catch (e) {
      _messageController.addError(e);
    }
  }

  void _processBuffer() {
    final records = _codec.decode(_buffer);

    for (final record in records) {
      try {
        final stream = XdrInputStream(record);
        final message = RpcMessage.decode(stream);
        _messageController.add(message);
      } catch (e) {
        _messageController.addError(e);
      }
    }
  }

  void _handleError(final Object error) {
    _messageController.addError(error);
  }

  void _handleDone() {
    _socket = null;
  }
}

/// UDP transport for connectionless RPC communication.
///
/// [UdpTransport] provides fast, low-overhead message delivery using UDP
/// datagrams. Each RPC message is sent as a single datagram.
///
/// ## Features
///
/// - Low latency communication
/// - Minimal connection overhead
/// - Simple request/response pattern
/// - Best-effort delivery (no guarantees)
///
/// ## Usage
///
/// ```dart
/// final transport = UdpTransport(
///   host: 'nfs-server.local',
///   port: 2049,
/// );
///
/// final client = RpcClient(transport: transport);
/// await client.connect();
/// ```
///
/// ## Limitations
///
/// UDP transport has several limitations:
///
/// - **No reliability**: Messages may be lost or arrive out of order
/// - **Size limits**: Message size limited by MTU (typically 1500 bytes)
/// - **No flow control**: May overwhelm server with requests
/// - **No encryption**: TLS/SSL not available (use TCP for encryption)
///
/// The [RpcClient] handles retries on timeout, providing some reliability
/// at the application layer.
///
/// ## When to Use UDP
///
/// UDP is recommended for:
/// - Low-latency services where occasional loss is acceptable
/// - Small message payloads (< 1KB)
/// - Local network communication
/// - Services with idempotent operations
///
/// ## When to Use TCP Instead
///
/// Use TCP if you need:
/// - Reliable delivery
/// - Large messages (> 1KB)
/// - Encryption (TLS/SSL)
/// - Ordered delivery
///
/// See also:
/// - [TcpTransport] for reliable communication
/// - RFC 5531 section 10 for UDP transport details
class UdpTransport extends RpcTransport {
  /// Creates a UDP transport to the specified host and port.
  ///
  /// Parameters:
  /// - [host]: The server hostname or IP address
  /// - [port]: The UDP port number
  UdpTransport({required this.host, required this.port});

  /// The server hostname or IP address to send datagrams to.
  final String host;

  /// The UDP port number to send datagrams to.
  final int port;
  RawDatagramSocket? _socket;
  InternetAddress? _targetAddress;
  final _messageController = StreamController<RpcMessage>.broadcast();

  @override
  bool get isConnected => _socket != null;

  @override
  Stream<RpcMessage> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    if (_socket != null) {
      throw RpcConnectionError.alreadyConnected();
    }

    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        throw RpcTransportError('Failed to resolve host: $host');
      }
      _targetAddress = addresses.first;

      final bindAddress = _targetAddress!.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;
      _socket = await RawDatagramSocket.bind(bindAddress, 0);
      _socket!.listen(_handleDatagram);
    } catch (e) {
      _targetAddress = null;
      if (e is RpcError) rethrow;
      throw RpcTransportError('Failed to bind UDP socket', cause: e);
    }
  }

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
    _targetAddress = null;
    await _messageController.close();
  }

  @override
  Future<void> send(final RpcMessage message) async {
    if (_socket == null) {
      throw RpcConnectionError.notConnected();
    }

    try {
      final stream = XdrOutputStream();
      message.encode(stream);
      final data = stream.toBytes();

      final targetAddress = _targetAddress;
      if (targetAddress == null) {
        throw RpcConnectionError.notConnected();
      }
      final sent = _socket!.send(data, targetAddress, port);
      if (sent == 0) {
        throw RpcTransportError('Failed to send datagram');
      }
    } catch (e) {
      if (e is RpcError) rethrow;
      throw RpcTransportError('Failed to send message', cause: e);
    }
  }

  void _handleDatagram(final RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final socket = _socket;
      final expectedAddress = _targetAddress;
      if (socket == null || expectedAddress == null) {
        return;
      }

      final datagram = socket.receive();
      if (datagram != null) {
        if (datagram.port != port ||
            !_sameAddress(datagram.address, expectedAddress)) {
          return;
        }
        try {
          final stream = XdrInputStream(datagram.data);
          final message = RpcMessage.decode(stream);
          _messageController.add(message);
        } catch (e) {
          _messageController.addError(e);
        }
      }
    }
  }

  bool _sameAddress(final InternetAddress a, final InternetAddress b) {
    if (a.type != b.type) {
      return false;
    }
    final left = a.rawAddress;
    final right = b.rawAddress;
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}
