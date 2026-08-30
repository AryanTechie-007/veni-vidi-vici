import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/messages/mesh_message.dart';

const int _now = 1756280431;

MeshMessage _sampleSos() => MeshMessage.createSos(
      origin: 'kJ9xQm2',
      uid: 'kJ9xQm2',
      seq: 7,
      now: _now,
      cat: Category.medical,
      n: 2,
      txt: 'leg injury, 2nd floor, cannot walk',
      loc: const GeoPoint(lat: 13.0827, lon: 80.2707, acc: 18),
    );

Uint8List _bytesOf(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

Map<String, dynamic> _validJson() => _sampleSos().toJson();

void main() {
  group('id', () {
    test('is deterministic for the same origin and seq', () {
      expect(
        MeshMessage.computeId('kJ9xQm2', 7),
        MeshMessage.computeId('kJ9xQm2', 7),
      );
    });

    test('differs across seq and across origin', () {
      final a = MeshMessage.computeId('kJ9xQm2', 7);
      expect(a, isNot(MeshMessage.computeId('kJ9xQm2', 8)));
      expect(a, isNot(MeshMessage.computeId('other', 7)));
    });

    test('is 16 lowercase hex characters', () {
      expect(MeshMessage.computeId('kJ9xQm2', 7), matches(r'^[0-9a-f]{16}$'));
    });
  });

  group('codec', () {
    test('round-trips a full SOS', () {
      final original = _sampleSos();
      final decoded = MeshMessage.decode(original.encode());

      expect(decoded.core.id, original.core.id);
      expect(decoded.core.type, MessageType.sos);
      expect(decoded.core.origin, 'kJ9xQm2');
      expect(decoded.core.seq, 7);
      expect(decoded.core.ts, _now);
      expect(decoded.core.cat, Category.medical);
      expect(decoded.core.n, 2);
      expect(decoded.core.txt, 'leg injury, 2nd floor, cannot walk');
      expect(decoded.core.loc, const GeoPoint(lat: 13.0827, lon: 80.2707, acc: 18));
      expect(decoded.env.hops, 0);
      expect(decoded.env.exp, _now + kExpirySeconds);
    });

    test('omits null fields to keep packets small', () {
      final bare = MeshMessage.createSos(
        origin: 'abc',
        uid: 'abc',
        seq: 1,
        now: _now,
      );
      final json = bare.toJson()['core'] as Map<String, dynamic>;

      expect(json.containsKey('loc'), isFalse);
      expect(json.containsKey('cat'), isFalse);
      expect(json.containsKey('txt'), isFalse);
      expect(json.containsKey('ref'), isFalse);
      expect(json.containsKey('reason'), isFalse);
    });

    test('a realistic SOS stays well inside the 32KB payload limit', () {
      // The spec budgets ~300 bytes; the point is that BYTES is never a
      // constraint, not that the number is exact.
      expect(_sampleSos().encode().length, lessThan(400));
    });

    test('sets the frame type', () {
      expect(_sampleSos().toJson()['t'], 'MSG');
    });
  });

  group('forward compatibility', () {
    test('an unrecognised type still decodes and relays intact', () {
      final json = _validJson();
      (json['core'] as Map<String, dynamic>)['type'] = 'FUTURE_TYPE';

      final decoded = MeshMessage.decode(_bytesOf(json));

      expect(decoded.core.type, MessageType.unknown);
      // Preserved verbatim, so relaying does not corrupt it for newer builds.
      expect(decoded.core.typeWire, 'FUTURE_TYPE');
      expect(decoded.encode(), _bytesOf(json));
    });

    test('an unknown category decodes to null rather than failing', () {
      final json = _validJson();
      (json['core'] as Map<String, dynamic>)['cat'] = 'VOLCANO';

      expect(MeshMessage.decode(_bytesOf(json)).core.cat, isNull);
    });

    test('uid falls back to origin when absent', () {
      final json = _validJson();
      (json['core'] as Map<String, dynamic>).remove('uid');

      expect(MeshMessage.decode(_bytesOf(json)).core.uid, 'kJ9xQm2');
    });
  });

  group('decode rejects malformed input', () {
    void expectRejected(String label, void Function(Map<String, dynamic>) mutate) {
      test(label, () {
        final json = _validJson();
        mutate(json);
        expect(
          () => MeshMessage.decode(_bytesOf(json)),
          throwsA(isA<MalformedMessageException>()),
        );
      });
    }

    expectRejected('wrong frame type', (j) => j['t'] = 'NOPE');
    expectRejected('missing core', (j) => j.remove('core'));
    expectRejected('missing env', (j) => j.remove('env'));
    expectRejected(
        'missing id', (j) => (j['core'] as Map).remove('id'));
    expectRejected(
        'missing origin', (j) => (j['core'] as Map).remove('origin'));
    expectRejected('missing seq', (j) => (j['core'] as Map).remove('seq'));
    expectRejected('missing ts', (j) => (j['core'] as Map).remove('ts'));
    expectRejected(
        'missing hops', (j) => (j['env'] as Map).remove('hops'));
    expectRejected('missing exp', (j) => (j['env'] as Map).remove('exp'));
    expectRejected(
        'id that is not 16 hex chars', (j) => (j['core'] as Map)['id'] = 'zzz');
    expectRejected('negative hops', (j) => (j['env'] as Map)['hops'] = -1);
    expectRejected(
        'hops past the 64 backstop', (j) => (j['env'] as Map)['hops'] = 65);
    expectRejected('txt over 140 chars',
        (j) => (j['core'] as Map)['txt'] = 'x' * (kMaxTextLength + 1));
    expectRejected(
        'wrong field type', (j) => (j['core'] as Map)['seq'] = 'seven');
    expectRejected('loc without lat', (j) => (j['core'] as Map)['loc'] = {'lon': 1});

    test('bytes that are not JSON at all', () {
      expect(
        () => MeshMessage.decode(Uint8List.fromList(utf8.encode('hello there'))),
        throwsA(isA<MalformedMessageException>()),
      );
    });

    test('JSON that is not an object', () {
      expect(
        () => MeshMessage.decode(Uint8List.fromList(utf8.encode('[1,2,3]'))),
        throwsA(isA<MalformedMessageException>()),
      );
    });

    test('empty payload', () {
      expect(
        () => MeshMessage.decode(Uint8List(0)),
        throwsA(isA<MalformedMessageException>()),
      );
    });

    test('createSos refuses over-long text at the source too', () {
      expect(
        () => MeshMessage.createSos(
          origin: 'abc',
          uid: 'abc',
          seq: 1,
          now: _now,
          txt: 'x' * (kMaxTextLength + 1),
        ),
        throwsA(isA<MalformedMessageException>()),
      );
    });
  });

  group('incrementHops', () {
    test('bumps hops and leaves core byte-identical', () {
      final original = _sampleSos();
      final forwarded = original.incrementHops();

      expect(forwarded.env.hops, 1);
      expect(forwarded.env.exp, original.env.exp);
      // core is frozen: no relay may alter a single byte of it.
      expect(forwarded.core.toJson(), original.core.toJson());
      expect(identical(forwarded.core, original.core), isTrue);
      expect(original.env.hops, 0, reason: 'original must not be mutated');
    });
  });
}
