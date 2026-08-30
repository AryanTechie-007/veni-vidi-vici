import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/messages/mesh_message.dart';
import 'package:mesh_sync/messages/message_store.dart';

const int _now = 1756280431;

MeshMessage _sos({String origin = 'alice', int seq = 1, int? at, int hops = 0}) {
  final message = MeshMessage.createSos(
    origin: origin,
    uid: origin,
    seq: seq,
    now: at ?? _now,
  );
  return hops == 0 ? message : _withHops(message, hops);
}

MeshMessage _withHops(MeshMessage message, int hops) {
  var out = message;
  for (var i = 0; i < hops; i++) {
    out = out.incrementHops();
  }
  return out;
}

void main() {
  late InMemoryMessageStore store;

  setUp(() => store = InMemoryMessageStore());

  group('seq', () {
    test('starts at 1 and increments', () async {
      expect(await store.nextSeq(), 1);
      expect(await store.nextSeq(), 2);
      expect(await store.nextSeq(), 3);
    });

    test('resumes from a persisted value', () async {
      final resumed = InMemoryMessageStore(startingSeq: 7);
      expect(await resumed.nextSeq(), 8);
    });
  });

  group('seen', () {
    test('records and reports ids', () async {
      expect(await store.hasSeen('abc'), isFalse);
      await store.markSeen('abc', expiresAt: _now + 100);
      expect(await store.hasSeen('abc'), isTrue);
    });

    test('survives past 24h and still suppresses a re-offer', () async {
      // The decision that departs from the spec's 24h LRU: a seen entry lives
      // as long as the message it refers to, so the flood cannot restart on
      // day two while the message is still alive.
      await store.markSeen('abc', expiresAt: _now + kExpirySeconds);

      await store.pruneExpired(now: _now + Duration(hours: 25).inSeconds);

      expect(await store.hasSeen('abc'), isTrue);
    });

    test('is pruned once the message it refers to has expired', () async {
      await store.markSeen('abc', expiresAt: _now + 100);
      await store.pruneExpired(now: _now + 101);
      expect(await store.hasSeen('abc'), isFalse);
    });

    test('evicts soonest-expiring entries past the cap', () async {
      for (var i = 0; i < kMaxSeenEntries + 10; i++) {
        // Later ids get later expiries, so the earliest should be dropped.
        await store.markSeen('id$i', expiresAt: _now + i);
      }
      expect(await store.hasSeen('id0'), isFalse);
      expect(await store.hasSeen('id${kMaxSeenEntries + 9}'), isTrue);
    });
  });

  group('put', () {
    test('stores and returns a message', () async {
      final message = _sos();
      await store.put(message, localExpiry: message.env.exp);

      expect((await store.get(message.id))!.id, message.id);
    });

    test('keeps the lowest hop count when the same id arrives again', () async {
      final near = _sos(hops: 2);
      final far = _sos(hops: 5);

      await store.put(far, localExpiry: far.env.exp);
      await store.put(near, localExpiry: near.env.exp);
      expect((await store.get(near.id))!.env.hops, 2);

      // And does not rise again when a longer path arrives afterwards.
      await store.put(far, localExpiry: far.env.exp);
      expect((await store.get(near.id))!.env.hops, 2);
    });

    test('keeps the original local expiry on re-receipt', () async {
      final message = _sos();
      await store.put(message, localExpiry: _now + 100);
      await store.put(message, localExpiry: _now + 99999);

      // The 72h local clock started at first receipt; a later copy of the same
      // message must not extend it.
      await store.pruneExpired(now: _now + 101);
      expect(await store.get(message.id), isNull);
    });
  });

  group('forwardable', () {
    test('excludes messages past their local expiry', () async {
      final live = _sos(seq: 1);
      final dead = _sos(seq: 2);
      await store.put(live, localExpiry: _now + 100);
      await store.put(dead, localExpiry: _now - 1);

      final out = await store.forwardable(now: _now);

      expect(out.map((m) => m.id), [live.id]);
    });

    test('is empty on a fresh store', () async {
      expect(await store.forwardable(now: _now), isEmpty);
    });
  });

  test('delete removes the message but not the seen entry', () async {
    final message = _sos();
    await store.markSeen(message.id, expiresAt: message.env.exp);
    await store.put(message, localExpiry: message.env.exp);

    await store.delete(message.id);

    expect(await store.get(message.id), isNull);
    // A CANCEL deletes the message, but the node must still refuse it if a
    // peer offers it again.
    expect(await store.hasSeen(message.id), isTrue);
  });
}
