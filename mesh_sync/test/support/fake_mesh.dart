// An in-process mesh: N nodes, a shared fake clock, and links you can make and
// break to simulate radio range.
//
// This is what turns a three-phone field test into a unit test.

import 'dart:typed_data';

import 'package:mesh_sync/messages/mesh_message.dart';
import 'package:mesh_sync/messages/mesh_router.dart';
import 'package:mesh_sync/messages/mesh_transport.dart';
import 'package:mesh_sync/messages/message_store.dart';

/// A clock the test drives by hand.
class FakeClock {
  FakeClock(this.seconds);

  int seconds;

  void advance(Duration by) => seconds += by.inSeconds;

  int call() => seconds;
}

/// One simulated device.
class FakeNode {
  FakeNode({
    required this.name,
    required this.router,
    required this.store,
    required this.transport,
  });

  final String name;
  final MeshRouter router;
  final InMemoryMessageStore store;
  final FakeTransport transport;

  /// Messages this node accepted into its store, in arrival order.
  final List<MeshMessage> accepted = [];

  /// Reasons this node rejected something.
  final List<DropReason> drops = [];

  Future<MeshMessage?> held(String id) => store.get(id);

  int get acceptedCount => accepted.length;
}

/// The transport for one node. Delivery is routed by [FakeMesh].
class FakeTransport implements MeshTransport {
  FakeTransport(this.nodeName, this._mesh);

  final String nodeName;
  final FakeMesh _mesh;

  /// Every individual peer-delivery this node has performed. The length of
  /// this list is what proves a flood terminates.
  int sendCount = 0;

  @override
  Future<int> broadcast(Uint8List bytes, {String? exceptEndpointId}) async {
    var sent = 0;
    for (final peer in _mesh.peersOf(nodeName)) {
      if (peer == exceptEndpointId) continue;
      sendCount++;
      _mesh.enqueue(from: nodeName, to: peer, bytes: bytes);
      sent++;
    }
    return sent;
  }

  @override
  Future<bool> sendTo(String endpointId, Uint8List bytes) async {
    if (!_mesh.peersOf(nodeName).contains(endpointId)) return false;
    sendCount++;
    _mesh.enqueue(from: nodeName, to: endpointId, bytes: bytes);
    return true;
  }
}

class _Delivery {
  const _Delivery({required this.from, required this.to, required this.bytes});

  final String from;
  final String to;
  final Uint8List bytes;
}

/// A simulated mesh. Endpoint ids and node names are the same string here,
/// which keeps assertions readable.
class FakeMesh {
  FakeMesh({int startAt = 1_700_000_000}) : clock = FakeClock(startAt);

  final FakeClock clock;

  final Map<String, FakeNode> nodes = {};

  /// Undirected adjacency — radio range is symmetric.
  final Map<String, Set<String>> _links = {};

  final List<_Delivery> _queue = [];

  /// Guards against a genuine infinite flood hanging the test suite.
  static const int _maxDeliveries = 1000;

  FakeNode addNode(String name) {
    final store = InMemoryMessageStore();
    final transport = FakeTransport(name, this);
    final router = MeshRouter(
      store: store,
      transport: transport,
      origin: name,
      clock: clock.call,
    );
    final node = FakeNode(
      name: name,
      router: router,
      store: store,
      transport: transport,
    );
    router.onAccepted = node.accepted.add;
    router.onDropped = (reason, _) => node.drops.add(reason);
    nodes[name] = node;
    _links[name] = {};
    return node;
  }

  void link(String a, String b) {
    _links[a]!.add(b);
    _links[b]!.add(a);
  }

  void unlink(String a, String b) {
    _links[a]!.remove(b);
    _links[b]!.remove(a);
  }

  Set<String> peersOf(String name) => _links[name] ?? {};

  void enqueue({
    required String from,
    required String to,
    required Uint8List bytes,
  }) =>
      _queue.add(_Delivery(from: from, to: to, bytes: bytes));

  /// Delivers everything queued, including anything queued as a result.
  Future<void> settle() async {
    var delivered = 0;
    while (_queue.isNotEmpty) {
      if (++delivered > _maxDeliveries) {
        throw StateError(
          'mesh did not settle after $_maxDeliveries deliveries — '
          'this is a flood loop',
        );
      }
      final next = _queue.removeAt(0);
      await nodes[next.to]!.router.onBytes(next.from, next.bytes);
    }
  }

  /// Connects [a] and [b] and runs both sides' store-and-forward flush, the way
  /// a real connection event would.
  Future<void> connect(String a, String b) async {
    link(a, b);
    await nodes[a]!.router.onPeerConnected(b, b);
    await nodes[b]!.router.onPeerConnected(a, a);
    await settle();
  }

  /// Total peer-deliveries performed by every node.
  int get totalSends =>
      nodes.values.fold(0, (sum, node) => sum + node.transport.sendCount);
}
