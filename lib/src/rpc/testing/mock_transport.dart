import 'dart:async';

import '../rpc_errors.dart';
import '../rpc_message.dart';
import '../rpc_transport.dart';

/// Mock RPC transport for testing
///
/// Allows tests to simulate RPC communication without real network connections.
///
/// Example:
/// ```dart
/// final mock = MockTransport();
/// final client = RpcClient(transport: mock);
///
/// // Inject a response
/// mock.injectReply(RpcMessage(...));
///
/// // Make a call
/// await client.call(...);
///
/// // Verify what was sent
/// expect(mock.sentMessages, hasLength(1));
/// ```
class MockTransport extends RpcTransport {
  /// Creates a mock transport
  ///
  /// If [autoReply] is true, automatically generates success replies for calls.
  /// If [replyGenerator] is provided, uses it to generate replies.
  MockTransport({
    bool autoReply = false,
    RpcMessage Function(RpcMessage)? replyGenerator,
  })  : _autoReply = autoReply,
        _replyGenerator = replyGenerator;
  final _messageController = StreamController<RpcMessage>.broadcast();
  final List<RpcMessage> sentMessages = [];
  bool _isConnected = false;
  final bool _autoReply;
  final RpcMessage Function(RpcMessage)? _replyGenerator;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<RpcMessage> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    if (_isConnected) {
      throw RpcConnectionError.alreadyConnected();
    }
    _isConnected = true;
  }

  @override
  Future<void> close() async {
    _isConnected = false;
    await _messageController.close();
    sentMessages.clear();
  }

  @override
  Future<void> send(final RpcMessage message) async {
    if (!_isConnected) {
      throw RpcConnectionError.notConnected();
    }

    sentMessages.add(message);

    // Auto-reply if enabled
    if (_autoReply || _replyGenerator != null) {
      final reply =
          _replyGenerator?.call(message) ?? _createSuccessReply(message);
      // Simulate async network delay
      Future.delayed(const Duration(milliseconds: 1), () {
        if (_isConnected) {
          _messageController.add(reply);
        }
      });
    }
  }

  /// Injects a reply message into the stream
  ///
  /// Use this to simulate server responses in tests.
  void injectReply(final RpcMessage message) {
    if (!_isConnected) {
      throw RpcConnectionError.notConnected();
    }
    _messageController.add(message);
  }

  /// Injects an error into the message stream
  void injectError(final Object error) {
    if (!_isConnected) {
      throw RpcConnectionError.notConnected();
    }
    _messageController.addError(error);
  }

  /// Creates a success reply for a call message
  RpcMessage _createSuccessReply(final RpcMessage call) => RpcMessage(
        xid: call.xid,
        messageType: MessageType.reply,
        body: ReplyBody(
          replyStatus: ReplyStatus.accepted,
          data: AcceptedReply(
            verf: OpaqueAuth.none(),
            acceptStatus: AcceptStatus.success,
            data: SuccessData(null),
          ),
        ),
      );

  /// Clears all sent messages
  void clearSentMessages() {
    sentMessages.clear();
  }

  /// Returns the last sent message, or null if none
  RpcMessage? get lastSentMessage =>
      sentMessages.isEmpty ? null : sentMessages.last;

  /// Returns the number of sent messages
  int get sentCount => sentMessages.length;
}

/// Mock transport that always fails to connect
class FailingMockTransport extends RpcTransport {
  FailingMockTransport({this.errorMessage = 'Connection failed'});

  final String errorMessage;

  @override
  bool get isConnected => false;

  @override
  Stream<RpcMessage> get messages => const Stream.empty();

  @override
  Future<void> connect() async {
    throw RpcTransportError(errorMessage);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> send(final RpcMessage message) async {
    throw RpcConnectionError.notConnected();
  }
}

/// Mock transport that simulates timeouts
class TimeoutMockTransport extends RpcTransport {
  TimeoutMockTransport({this.delay = const Duration(seconds: 5)});

  final Duration delay;
  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<RpcMessage> get messages => const Stream.empty();

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> close() async {
    _isConnected = false;
  }

  @override
  Future<void> send(final RpcMessage message) async {
    // Never send a reply, simulating timeout
    await Future<void>.delayed(delay);
  }
}

/// Mock transport with configurable behavior
class ConfigurableMockTransport extends RpcTransport {
  bool _isConnected = false;
  final _messageController = StreamController<RpcMessage>.broadcast();
  final List<RpcMessage> sentMessages = [];

  Future<void> Function()? onConnect;
  Future<void> Function()? onClose;
  Future<void> Function(RpcMessage)? onSendMessage;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<RpcMessage> get messages => _messageController.stream;

  @override
  Future<void> connect() async {
    if (onConnect != null) {
      await onConnect!();
    }
    _isConnected = true;
  }

  @override
  Future<void> close() async {
    if (onClose != null) {
      await onClose!();
    }
    _isConnected = false;
    await _messageController.close();
  }

  @override
  Future<void> send(final RpcMessage message) async {
    if (!_isConnected) {
      throw RpcConnectionError.notConnected();
    }

    sentMessages.add(message);

    if (onSendMessage != null) {
      await onSendMessage!(message);
    }
  }

  void injectReply(final RpcMessage message) {
    _messageController.add(message);
  }

  void injectError(final Object error) {
    _messageController.addError(error);
  }
}
