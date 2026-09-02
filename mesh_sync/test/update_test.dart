import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/messages/mesh_message.dart';
import 'package:mesh_sync/messages/mesh_router.dart';

import 'support/fake_mesh.dart';

void main() {
  group('codec', () {
    test('round-trips an UPDATE', () {
      final update = MeshMessage.createUpdate(
        origin: 'alice',
        uid: 'alice',
        seq: 2,
        now: 1756280431,
        sosId: 'aaaaaaaaaaaaaaaa',
        status: UpdateStatus.worse,
        txt: 'water is rising',
      );

      final decoded = MeshMessage.decode(update.encode());

      expect(decoded.core.type, MessageType.update);
      expect(decoded.core.ref, 'aaaaaaaaaaaaaaaa');
      expect(decoded.core.st, UpdateStatus.worse);
      expect(decoded.core.txt, 'water is rising');
    });

    test('an unknown status decodes to null rather than failing', () {
      final update = MeshMessage.createUpdate(
        origin: 'alice',
        uid: 'alice',
        seq: 2,
        now: 1756280431,
        sosId: 'aaaaaaaaaaaaaaaa',
        status: UpdateStatus.worse,
      );
      final json = update.toJson();
      (json['core'] as Map<String, dynamic>)['st'] = 'ON_FIRE_SOMEHOW';

      final decoded = MeshMessage.decode(
        MeshMessage(
          core: MessageCore.fromJson(json['core'] as Map<Object?, Object?>),
          env: update.env,
        ).encode(),
      );

      expect(decoded.core.st, isNull);
      expect(decoded.core.type, MessageType.update);
    });

    test('refuses text over the cap', () {
      expect(
        () => MeshMessage.createUpdate(
          origin: 'alice',
          uid: 'alice',
          seq: 2,
          now: 1,
          sosId: 'aaaaaaaaaaaaaaaa',
          status: UpdateStatus.stillHere,
          txt: 'x' * (kMaxTextLength + 1),
        ),
        throwsA(isA<MalformedMessageException>()),
      );
    });
  });

  group('relay', () {
    test('does not acknowledge the SOS it refers to', () async {
      // The trap this whole design avoids: an acknowledged message stops being
      // relayed, so an update must never mark its own SOS acked.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();

      mesh.clock.advance(const Duration(seconds: 90));
      await mesh.nodes['A']!.router.createUpdate(
        sosId: sos.id,
        status: UpdateStatus.worse,
      );
      await mesh.settle();

      final forwardable = await mesh.nodes['B']!.store.forwardable(
        now: mesh.clock.seconds,
      );
      expect(
        forwardable.map((m) => m.id),
        contains(sos.id),
        reason: 'the SOS must still be relayable after an update',
      );
    });

    test('floods two hops like any other type', () async {
      final mesh = FakeMesh();
      for (final name in ['A', 'B', 'C']) {
        mesh.addNode(name);
      }
      mesh.link('A', 'B');
      mesh.link('B', 'C');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();
      mesh.clock.advance(const Duration(seconds: 90));

      final update = await mesh.nodes['A']!.router.createUpdate(
        sosId: sos.id,
        status: UpdateStatus.moved,
      );
      await mesh.settle();

      final atC = await mesh.nodes['C']!.held(update!.id);
      expect(atC, isNotNull);
      expect(atC!.env.hops, 2);
      expect(atC.core.st, UpdateStatus.moved);
    });

    test('arriving before its SOS is still stored and forwarded', () async {
      // Out-of-order arrival is normal and must never block acceptance.
      final mesh = FakeMesh();
      mesh.addNode('A');
      mesh.addNode('B');
      mesh.link('A', 'B');

      final orphan = MeshMessage.createUpdate(
        origin: 'stranger',
        uid: 'stranger',
        seq: 1,
        now: mesh.clock.seconds,
        sosId: 'ffffffffffffffff',
        status: UpdateStatus.stillHere,
      );

      await mesh.nodes['A']!.router.onBytes('X', orphan.encode());
      await mesh.settle();

      expect(await mesh.nodes['A']!.held(orphan.id), isNotNull);
      expect(await mesh.nodes['B']!.held(orphan.id), isNotNull);
    });

    test('a responder does not auto-ACK an update', () async {
      // Only SOS triggers the automatic acknowledgement. ACKing every update
      // would roughly double ACK traffic for very little.
      final mesh = FakeMesh();
      mesh.addNode('A');
      final responder = mesh.addNode('R');
      responder.router.isResponder = true;
      mesh.link('A', 'R');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();

      final acksAfterSos = responder.accepted
          .where((m) => m.core.type == MessageType.ack)
          .length;

      mesh.clock.advance(const Duration(seconds: 90));
      await mesh.nodes['A']!.router.createUpdate(
        sosId: sos.id,
        status: UpdateStatus.worse,
      );
      await mesh.settle();

      final acksAfterUpdate = responder.accepted
          .where((m) => m.core.type == MessageType.ack)
          .length;

      expect(acksAfterUpdate, acksAfterSos);
    });

    test('one referencing a cancelled SOS is refused', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final b = mesh.addNode('B');
      mesh.link('A', 'B');

      final sos = await mesh.nodes['A']!.router.createSos(txt: 'trapped');
      await mesh.settle();

      // B learns the incident is closed.
      await b.router.createCancel(sosId: sos.id, reason: CancelReason.rescued);
      await mesh.settle();

      // A never heard the CANCEL, so it keeps talking.
      final update = MeshMessage.createUpdate(
        origin: 'A',
        uid: 'A',
        seq: 99,
        now: mesh.clock.seconds,
        sosId: sos.id,
        status: UpdateStatus.stillHere,
      );
      await b.router.onBytes('A', update.encode());

      expect(await b.held(update.id), isNull);
      expect(b.drops, contains(DropReason.cancelled));
    });
  });

  group('rate limit', () {
    test(
      'refuses a second update inside the window, allows one after',
      () async {
        final mesh = FakeMesh();
        mesh.addNode('A');
        final router = mesh.nodes['A']!.router;

        final sos = await router.createSos(txt: 'trapped');

        final first = await router.createUpdate(
          sosId: sos.id,
          status: UpdateStatus.stillHere,
        );
        expect(first, isNotNull);

        mesh.clock.advance(const Duration(seconds: 30));
        expect(
          await router.createUpdate(sosId: sos.id, status: UpdateStatus.worse),
          isNull,
        );
        expect(router.secondsUntilNextUpdate(sos.id), 30);

        mesh.clock.advance(const Duration(seconds: 31));
        expect(router.secondsUntilNextUpdate(sos.id), 0);
        expect(
          await router.createUpdate(sosId: sos.id, status: UpdateStatus.worse),
          isNotNull,
        );
      },
    );

    test('holds the per-incident cap', () async {
      final mesh = FakeMesh();
      mesh.addNode('A');
      final router = mesh.nodes['A']!.router;
      final sos = await router.createSos(txt: 'trapped');

      for (var i = 0; i < kMaxUpdatesPerIncident; i++) {
        final sent = await router.createUpdate(
          sosId: sos.id,
          status: UpdateStatus.stillHere,
        );
        expect(sent, isNotNull, reason: 'update $i should be allowed');
        mesh.clock.advance(const Duration(seconds: 61));
      }

      expect(
        await router.createUpdate(
          sosId: sos.id,
          status: UpdateStatus.stillHere,
        ),
        isNull,
        reason: 'past the cap',
      );
    });

    test(
      'refuses an update on an incident this device knows is closed',
      () async {
        final mesh = FakeMesh();
        mesh.addNode('A');
        final router = mesh.nodes['A']!.router;
        final sos = await router.createSos(txt: 'trapped');

        await router.createCancel(
          sosId: sos.id,
          reason: CancelReason.selfResolved,
        );

        expect(
          await router.createUpdate(
            sosId: sos.id,
            status: UpdateStatus.stillHere,
          ),
          isNull,
        );
      },
    );
  });

  test('an ACK still suppresses the SOS with updates in play', () async {
    // The existing suppression must be untouched by any of this.
    final mesh = FakeMesh();
    final a = mesh.addNode('A');
    final responder = mesh.addNode('R');
    responder.router.isResponder = true;
    mesh.link('A', 'R');

    final sos = await a.router.createSos(txt: 'trapped');
    await mesh.settle();

    mesh.clock.advance(const Duration(seconds: 90));
    await a.router.createUpdate(sosId: sos.id, status: UpdateStatus.worse);
    await mesh.settle();

    final forwardable = await a.store.forwardable(now: mesh.clock.seconds);
    expect(
      forwardable.map((m) => m.id),
      isNot(contains(sos.id)),
      reason: 'the responder ACK should still suppress the SOS',
    );
  });
}
