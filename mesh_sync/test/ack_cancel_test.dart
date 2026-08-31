import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/messages/mesh_message.dart';
import 'package:mesh_sync/messages/mesh_router.dart';

import 'support/fake_mesh.dart';

void main() {
  group('ACK', () {
    test('a responder confirms automatically, with no human tap', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();

      // The ACK travelled back and A knows its SOS reached a responder.
      expect(await mesh.nodes['A']!.store.isAcked(sos.id), isTrue);

      final ack = rao.accepted.firstWhere(
        (m) => m.core.type == MessageType.ack,
      );
      expect(ack.core.ref, sos.id);
      expect(ack.core.origin, 'R');
    });

    test('carries no location', () async {
      // Responders should not broadcast their position to every device in
      // range.
      final mesh = FakeMesh();
      mesh.addNode('A');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'R');

      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      final ack =
          rao.accepted.firstWhere((m) => m.core.type == MessageType.ack);
      expect(ack.core.loc, isNull);
    });

    test('a victim does not ACK anything', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final b = mesh.addNode('B');
      mesh.link('A', 'B');

      await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      expect(b.accepted.where((m) => m.core.type == MessageType.ack), isEmpty);
    });

    test('a responder does not ACK its own SOS', () async {
      final mesh = FakeMesh();
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;

      await rao.router.createSos(txt: 'responder needs help');
      await mesh.settle();

      expect(rao.accepted.where((m) => m.core.type == MessageType.ack),
          isEmpty);
    });

    test('travels back over multiple hops to the origin', () async {
      // A —— B —— R, with A and R out of range of each other. The ACK floods
      // back through the same machinery, with no routing table and no return
      // path.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'B');
      mesh.link('B', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      expect(await mesh.nodes['A']!.store.isAcked(sos.id), isTrue);
      // The stranger in the middle relayed it without knowing either party.
      expect(await mesh.nodes['B']!.store.isAcked(sos.id), isTrue);
    });

    test('suppresses further relay of the SOS but keeps it stored', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();

      final forwardable =
          await mesh.nodes['A']!.store.forwardable(now: mesh.clock.seconds);
      expect(forwardable.map((m) => m.id), isNot(contains(sos.id)),
          reason: 'an acked SOS stops consuming bandwidth');

      // But a responder arriving later still wants the record.
      expect(await mesh.nodes['A']!.held(sos.id), isNotNull);
    });

    test('an ACK arriving before its SOS is still recorded', () async {
      // Out-of-order arrival is normal and must never block acceptance.
      final mesh = FakeMesh();
      final node = mesh.addNode('A');

      final orphan = MeshMessage.createAck(
        origin: 'R',
        uid: 'R',
        seq: 1,
        now: mesh.clock.seconds,
        sosId: 'aaaaaaaaaaaaaaaa',
      );

      await node.router.onBytes('X', orphan.encode());

      expect(await node.store.isAcked('aaaaaaaaaaaaaaaa'), isTrue);
      expect(await node.held(orphan.id), isNotNull,
          reason: 'the ACK itself is stored and forwarded regardless');
    });
  });

  group('CANCEL', () {
    test('purges the referenced SOS from local storage', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();
      expect(await mesh.nodes['B']!.held(sos.id), isNotNull);

      await mesh.nodes['A']!.router.createCancel(
            sosId: sos.id,
            reason: CancelReason.selfResolved,
          );
      await mesh.settle();

      expect(await mesh.nodes['A']!.held(sos.id), isNull);
      expect(await mesh.nodes['B']!.held(sos.id), isNull);
    });

    test('refuses the SOS if a peer offers it again afterwards', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();
      await mesh.nodes['A']!.router.createCancel(
            sosId: sos.id,
            reason: CancelReason.rescued,
          );
      await mesh.settle();

      // A stranger who never got the CANCEL re-offers the original.
      await mesh.nodes['B']!.router.onBytes('X', sos.encode());

      expect(await mesh.nodes['B']!.held(sos.id), isNull,
          reason: 'a rescued person\'s SOS must not come back');
    });

    test('a CANCEL arriving before its SOS still refuses it', () async {
      // The out-of-order case. Without a tombstone recorded from the CANCEL
      // alone, a node that had not yet seen the SOS would happily accept and
      // re-flood a closed incident.
      final mesh = FakeMesh();
      final node = mesh.addNode('A');

      final sos = MeshMessage.createSos(
        origin: 'victim',
        uid: 'victim',
        seq: 1,
        now: mesh.clock.seconds,
        txt: 'trapped',
      );
      final cancel = MeshMessage.createCancel(
        origin: 'victim',
        uid: 'victim',
        seq: 2,
        now: mesh.clock.seconds,
        sosId: sos.id,
        reason: CancelReason.rescued,
      );

      await node.router.onBytes('X', cancel.encode());
      await node.router.onBytes('X', sos.encode());

      expect(await node.held(sos.id), isNull);
      expect(node.drops, contains(DropReason.cancelled));
    });

    test('a responder can close someone else\'s incident', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();

      await rao.router.createCancel(
        sosId: sos.id,
        reason: CancelReason.rescued,
      );
      await mesh.settle();

      expect(await mesh.nodes['A']!.held(sos.id), isNull);
    });

    test('a CANCEL for an unknown message is stored and forwarded anyway',
        () async {
      final mesh = FakeMesh();
      final node = mesh.addNode('A');

      final orphan = MeshMessage.createCancel(
        origin: 'someone',
        uid: 'someone',
        seq: 1,
        now: mesh.clock.seconds,
        sosId: 'bbbbbbbbbbbbbbbb',
        reason: CancelReason.duplicate,
      );

      await node.router.onBytes('X', orphan.encode());

      expect(await node.held(orphan.id), isNotNull,
          reason: 'out-of-order arrival must never block acceptance');
      expect(await node.store.isCancelled('bbbbbbbbbbbbbbbb'), isTrue);
    });

    test('all three types travel through identical machinery', () async {
      // No special-case routing anywhere: an ACK or CANCEL is just a message
      // that happens to reference another one.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      final rao = mesh.addNode('R');
      rao.router.isResponder = true;
      mesh.link('A', 'B');
      mesh.link('B', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'help');
      await mesh.settle();
      await rao.router.createCancel(
        sosId: sos.id,
        reason: CancelReason.rescued,
      );
      await mesh.settle();

      // The middle node relayed an SOS, an ACK and a CANCEL without any of
      // them being routed differently.
      final types = mesh.nodes['B']!.accepted.map((m) => m.core.type).toSet();
      expect(types, containsAll([MessageType.sos, MessageType.ack,
          MessageType.cancel]));
    });
  });
}
