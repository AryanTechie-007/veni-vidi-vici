import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/messages/mesh_message.dart';
import 'package:mesh_sync/messages/mesh_router.dart';

import 'support/fake_mesh.dart';

void main() {
  group('flooding', () {
    test('reaches a node two hops away', () async {
      // A —— B —— C, with A and C out of range of each other.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.addNode('C');
      mesh.link('A', 'B');
      mesh.link('B', 'C');

      final sent = await mesh.nodes['A']!.router.createSos(
            cat: Category.medical,
            n: 2,
            txt: 'leg injury, 2nd floor, cannot walk',
          );
      await mesh.settle();

      final atC = await mesh.nodes['C']!.held(sent.id);
      expect(atC, isNotNull, reason: 'C should have received it via B');
      expect(atC!.env.hops, 2);
      expect(atC.core.txt, 'leg injury, 2nd floor, cannot walk');

      // core is frozen — C holds a byte-identical copy of what A created.
      expect(atC.core.toJson(), sent.core.toJson());
    });

    test('a duplicate travels exactly one hop and dies', () async {
      // A, B and C all in range of one another, so B and C each re-offer the
      // message to the other.
      final mesh = FakeMesh();
      for (final name in ['A', 'B', 'C']) {
        mesh.addNode(name);
      }
      mesh.link('A', 'B');
      mesh.link('A', 'C');
      mesh.link('B', 'C');

      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      // Each node accepted it once and only once.
      expect(mesh.nodes['A']!.acceptedCount, 1);
      expect(mesh.nodes['B']!.acceptedCount, 1);
      expect(mesh.nodes['C']!.acceptedCount, 1);

      // And the redundant copies were dropped as duplicates, not stored.
      expect(mesh.nodes['B']!.drops, [DropReason.duplicate]);
      expect(mesh.nodes['C']!.drops, [DropReason.duplicate]);
    });

    test('terminates rather than looping between two nodes', () async {
      // The test that catches a flood storm. FakeMesh.settle() throws if the
      // network does not quiesce.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      // A sends to B; B has nowhere to forward but back to A, which it is
      // forbidden from doing. Two deliveries total, and it stops.
      expect(mesh.totalSends, 1);
      expect(mesh.nodes['B']!.acceptedCount, 1);
    });

    test('a node never accepts its own message back', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      final sent = await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      // Replay B's copy straight back at A.
      await mesh.nodes['A']!.router.onBytes('B', sent.incrementHops().encode());

      expect(mesh.nodes['A']!.acceptedCount, 1);
      expect(mesh.nodes['A']!.drops, [DropReason.duplicate]);
      // The stored copy still shows hops 0 — a returning copy cannot inflate it.
      expect((await mesh.nodes['A']!.held(sent.id))!.env.hops, 0);
    });

    test('does not forward back to the peer it arrived from', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      expect(mesh.nodes['B']!.transport.sendCount, 0);
    });
  });

  group('store and forward', () {
    test('a message created with no peers is delivered on connect', () async {
      // T+0: Priya sends with nobody in range. T+40s: a courier walks up.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');

      final sent = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();
      expect(await mesh.nodes['B']!.held(sent.id), isNull);

      await mesh.connect('A', 'B');

      expect(await mesh.nodes['B']!.held(sent.id), isNotNull);
    });

    test('a courier carries a stranger\'s message onward', () async {
      // A —— B, then B walks away and meets C. C was never in range of A.
      final mesh = FakeMesh();
      for (final name in ['A', 'B', 'C']) {
        mesh.addNode(name);
      }

      await mesh.connect('A', 'B');
      final sent = await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      mesh.unlink('A', 'B');
      await mesh.connect('B', 'C');

      final atC = await mesh.nodes['C']!.held(sent.id);
      expect(atC, isNotNull, reason: 'B is a valid data carrier');
      expect(atC!.core.origin, 'A');
    });

    test('the flush does not re-deliver what a peer already holds', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');

      await mesh.connect('A', 'B');
      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      final before = mesh.nodes['B']!.acceptedCount;
      // Reconnecting re-flushes, but dedup means nothing is accepted twice.
      await mesh.nodes['A']!.router.onPeerConnected('B', 'B');
      await mesh.settle();

      expect(mesh.nodes['B']!.acceptedCount, before);
      expect(mesh.nodes['B']!.drops, contains(DropReason.duplicate));
    });

    test('a flapping link stops re-sending the backlog', () async {
      // The churn case: with no per-peer tracking, every reconnect re-sends
      // everything held, forever. Correct but pure waste on a throughput-
      // limited radio.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');

      await mesh.nodes['A']!.router.createSos(txt: 'one');
      await mesh.nodes['A']!.router.createSos(txt: 'two');
      await mesh.settle();

      await mesh.connect('A', 'B');
      final afterFirstFlush = mesh.nodes['A']!.transport.sendCount;
      expect(afterFirstFlush, 2, reason: 'both held messages go across once');

      // Bounce the link repeatedly.
      for (var i = 0; i < 5; i++) {
        mesh.unlink('A', 'B');
        await mesh.connect('A', 'B');
      }

      expect(mesh.nodes['A']!.transport.sendCount, afterFirstFlush,
          reason: 'nothing is re-sent to a peer that already has it');
      expect(mesh.nodes['B']!.acceptedCount, 2);
    });

    test('a message created after a flush still reaches the peer', () async {
      // The reason this is per-message rather than a time-based cooldown: a
      // new SOS must not be held back by a recent flush.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');

      await mesh.nodes['A']!.router.createSos(txt: 'first');
      await mesh.connect('A', 'B');

      mesh.unlink('A', 'B');
      final later = await mesh.nodes['A']!.router.createSos(txt: 'second');
      await mesh.connect('A', 'B');

      expect(await mesh.nodes['B']!.held(later.id), isNotNull);
    });

    test('a failed transfer is retried on the next connect', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');

      final sent = await mesh.nodes['A']!.router.createSos(txt: 'help');

      // Flush to a peer that is not actually in range: sendTo returns false,
      // so nothing may be recorded as delivered.
      await mesh.nodes['A']!.router.onPeerConnected('B', 'B');
      expect(await mesh.nodes['B']!.held(sent.id), isNull);

      await mesh.connect('A', 'B');

      expect(await mesh.nodes['B']!.held(sent.id), isNotNull);
    });
  });

  group('expiry', () {
    test('an expired message is neither accepted nor forwarded', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.addNode('C');
      mesh.link('A', 'B');
      mesh.link('B', 'C');

      final sent = await mesh.nodes['A']!.router.createSos(txt: 'help');

      // Three days pass before anything is delivered.
      mesh.clock.advance(const Duration(hours: 73));
      await mesh.settle();

      expect(await mesh.nodes['B']!.held(sent.id), isNull);
      expect(mesh.nodes['B']!.drops, [DropReason.expired]);
      expect(await mesh.nodes['C']!.held(sent.id), isNull);
    });

    test('an unexpired message is forwarded regardless of distance travelled',
        () async {
      // There is no TTL. A message 60 hops out is still deliverable.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      var message = MeshMessage.createSos(
        origin: 'far-away',
        uid: 'far-away',
        seq: 1,
        now: mesh.clock.seconds,
        txt: 'help',
      );
      for (var i = 0; i < 60; i++) {
        message = message.incrementHops();
      }

      await mesh.nodes['A']!.router.onBytes('X', message.encode());

      expect(await mesh.nodes['A']!.held(message.id), isNotNull);
    });

    test('local receipt bounds expiry when the sender clock is wrong', () async {
      // A device with a badly skewed clock claims the message is valid for a
      // year. We hold it 72h from OUR receipt and no longer.
      final mesh = FakeMesh();
      mesh.addNode('A');

      final skewed = MeshMessage(
        core: MessageCore(
          id: MeshMessage.computeId('liar', 1),
          type: MessageType.sos,
          rawType: 'SOS',
          origin: 'liar',
          uid: 'liar',
          seq: 1,
          ts: mesh.clock.seconds,
        ),
        env: MessageEnvelope(
          hops: 0,
          exp: mesh.clock.seconds + const Duration(days: 365).inSeconds,
        ),
      );

      await mesh.nodes['A']!.router.onBytes('X', skewed.encode());
      expect(await mesh.nodes['A']!.held(skewed.id), isNotNull);

      mesh.clock.advance(const Duration(hours: 73));
      await mesh.nodes['A']!.router.prune();

      expect(await mesh.nodes['A']!.held(skewed.id), isNull,
          reason: 'a wrong clock must not let a message live forever');
    });

    test('a seen entry outlives the 24h mark and still suppresses', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');

      final sent = await mesh.nodes['A']!.router.createSos(txt: 'help');

      mesh.clock.advance(const Duration(hours: 25));
      await mesh.nodes['A']!.router.prune();

      // A peer re-offers the same message on day two.
      await mesh.nodes['A']!.router.onBytes('X', sent.incrementHops().encode());

      expect(mesh.nodes['A']!.drops, [DropReason.duplicate],
          reason: 'the flood must not restart after 24h');
    });
  });

  group('malformed input', () {
    test('is dropped without taking the node down', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      await mesh.nodes['A']!.router.onBytes(
            'B',
            Uint8List.fromList(utf8.encode('{"t":"MSG","core":{}}')),
          );

      expect(mesh.nodes['A']!.drops, [DropReason.malformed]);
      expect(mesh.nodes['A']!.acceptedCount, 0);

      // And the node still works afterwards.
      final ok = await mesh.nodes['A']!.router.createSos(txt: 'still alive');
      await mesh.settle();
      expect(await mesh.nodes['B']!.held(ok.id), isNotNull);
    });

    test('garbage bytes are dropped', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');

      await mesh.nodes['A']!.router.onBytes(
            'X',
            Uint8List.fromList([0xff, 0x00, 0x42, 0x99]),
          );

      expect(mesh.nodes['A']!.drops, [DropReason.malformed]);
    });
  });

  test('seq increments per message so ids never repeat', () async {
    final mesh = FakeMesh();
    mesh.addNode('A');

    final first = await mesh.nodes['A']!.router.createSos(txt: 'one');
    final second = await mesh.nodes['A']!.router.createSos(txt: 'two');

    expect(first.core.seq, 1);
    expect(second.core.seq, 2);
    expect(first.id, isNot(second.id));
  });
}
