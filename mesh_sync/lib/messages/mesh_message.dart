// The wire format. Pure data and codec — no I/O, no transport, no storage.
//
// The two-part split is the central design decision:
//   core — frozen at creation. No relay may alter a byte. Every device in the
//          network holds an identical copy, which is what keeps message
//          identity stable without any device ever contacting a server.
//   env  — travel state. Mutates in transit, carries no identity.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Current packet format version.
const int kFormatVersion = 1;

/// Nothing forwards a message older than this.
const int kExpirySeconds = 72 * 60 * 60;

/// Free text cap, per the spec.
const int kMaxTextLength = 140;

/// Pure bug backstop. A message should never legitimately travel this far, and
/// nothing drops a message merely for a high hop count.
const int kMaxHops = 64;

/// Raised by [MeshMessage.decode] on anything it will not accept.
///
/// Decoding is a trust boundary: these bytes arrive from strangers' devices
/// over an unauthenticated radio link. A malformed packet must be droppable,
/// never fatal.
class MalformedMessageException implements Exception {
  const MalformedMessageException(this.reason);

  final String reason;

  @override
  String toString() => 'MalformedMessageException: $reason';
}

enum MessageType {
  sos('SOS'),
  ack('ACK'),
  cancel('CANCEL'),

  /// A type this build does not recognise.
  ///
  /// The spec keeps `v` so newer builds interoperate with older ones, and all
  /// types travel through identical flooding machinery. So an unknown type is
  /// still relayed — it is simply never acted on or rendered.
  unknown('');

  const MessageType(this.wire);

  final String wire;

  static MessageType fromWire(String value) => values.firstWhere(
        (t) => t.wire == value,
        orElse: () => MessageType.unknown,
      );
}

enum Category {
  medical('MEDICAL'),
  trapped('TRAPPED'),
  fire('FIRE'),
  supplies('SUPPLIES'),
  safe('SAFE');

  const Category(this.wire);

  final String wire;

  /// Unknown categories decode to null rather than failing the whole packet.
  static Category? fromWire(String? value) {
    if (value == null) return null;
    for (final c in values) {
      if (c.wire == value) return c;
    }
    return null;
  }
}

enum CancelReason {
  rescued('RESCUED'),
  selfResolved('SELF_RESOLVED'),
  duplicate('DUPLICATE');

  const CancelReason(this.wire);

  final String wire;

  static CancelReason? fromWire(String? value) {
    if (value == null) return null;
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}

@immutable
class GeoPoint {
  const GeoPoint({required this.lat, required this.lon, this.acc});

  final double lat;
  final double lon;

  /// GPS accuracy in metres.
  final double? acc;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        if (acc != null) 'acc': acc,
      };

  static GeoPoint? fromJson(Object? json) {
    if (json == null) return null;
    if (json is! Map) throw const MalformedMessageException('loc is not an object');
    final lat = _asDouble(json['lat'], 'loc.lat');
    final lon = _asDouble(json['lon'], 'loc.lon');
    if (lat == null || lon == null) {
      throw const MalformedMessageException('loc missing lat/lon');
    }
    return GeoPoint(lat: lat, lon: lon, acc: _asDouble(json['acc'], 'loc.acc'));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon && other.acc == acc;

  @override
  int get hashCode => Object.hash(lat, lon, acc);
}

/// Frozen at creation. Identical on every device that holds this message.
@immutable
class MessageCore {
  const MessageCore({
    required this.id,
    required this.type,
    required this.origin,
    required this.uid,
    required this.seq,
    required this.ts,
    this.v = kFormatVersion,
    this.rawType,
    this.loc,
    this.cat,
    this.n,
    this.txt,
    this.ref,
    this.reason,
  });

  /// Format version, so newer builds can interoperate with older ones.
  final int v;

  /// The unique name of this message, and the dedup key.
  /// `sha256(origin + seq)` truncated to 16 hex characters.
  final String id;

  final MessageType type;

  /// The wire string for [type]. Preserved verbatim so an unrecognised type
  /// still relays intact rather than being rewritten or dropped.
  final String? rawType;

  /// Who created it. Constant across all of that device's messages.
  final String origin;

  /// Firebase UID. A separate field from [origin] even though both currently
  /// hold the same value, so changing one does not disturb the other.
  final String uid;

  /// Per-device counter, starting at 1.
  final int seq;

  /// Creation time, unix seconds, from the sender's clock. Unreliable offline.
  final int ts;

  final GeoPoint? loc;
  final Category? cat;

  /// Number of people at the location.
  final int? n;

  final String? txt;

  /// On ACK and CANCEL only: the id of the message being referenced.
  final String? ref;

  /// On CANCEL only.
  final CancelReason? reason;

  String get typeWire => rawType ?? type.wire;

  Map<String, dynamic> toJson() => {
        'v': v,
        'id': id,
        'type': typeWire,
        'origin': origin,
        'uid': uid,
        'seq': seq,
        'ts': ts,
        if (loc != null) 'loc': loc!.toJson(),
        if (cat != null) 'cat': cat!.wire,
        if (n != null) 'n': n,
        if (txt != null) 'txt': txt,
        if (ref != null) 'ref': ref,
        if (reason != null) 'reason': reason!.wire,
      };

  factory MessageCore.fromJson(Map<Object?, Object?> json) {
    final id = _asString(json['id'], 'core.id');
    final origin = _asString(json['origin'], 'core.origin');
    final typeWire = _asString(json['type'], 'core.type');
    final seq = _asInt(json['seq'], 'core.seq');
    final ts = _asInt(json['ts'], 'core.ts');

    if (id == null || id.isEmpty) {
      throw const MalformedMessageException('core.id missing');
    }
    if (!_idPattern.hasMatch(id)) {
      throw MalformedMessageException('core.id is not 16 hex chars: $id');
    }
    if (origin == null || origin.isEmpty) {
      throw const MalformedMessageException('core.origin missing');
    }
    if (typeWire == null || typeWire.isEmpty) {
      throw const MalformedMessageException('core.type missing');
    }
    if (seq == null) throw const MalformedMessageException('core.seq missing');
    if (ts == null) throw const MalformedMessageException('core.ts missing');

    final txt = _asString(json['txt'], 'core.txt');
    if (txt != null && txt.length > kMaxTextLength) {
      throw MalformedMessageException(
          'core.txt is ${txt.length} chars, max $kMaxTextLength');
    }

    return MessageCore(
      v: _asInt(json['v'], 'core.v') ?? kFormatVersion,
      id: id,
      type: MessageType.fromWire(typeWire),
      rawType: typeWire,
      origin: origin,
      // uid is allowed to be absent; it falls back to origin.
      uid: _asString(json['uid'], 'core.uid') ?? origin,
      seq: seq,
      ts: ts,
      loc: GeoPoint.fromJson(json['loc']),
      cat: Category.fromWire(_asString(json['cat'], 'core.cat')),
      n: _asInt(json['n'], 'core.n'),
      txt: txt,
      ref: _asString(json['ref'], 'core.ref'),
      reason: CancelReason.fromWire(_asString(json['reason'], 'core.reason')),
    );
  }

  @override
  bool operator ==(Object other) => other is MessageCore && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Travel state. Mutates in transit — [MeshMessage.incrementHops] produces the
/// next copy rather than editing in place, since the store shares references.
@immutable
class MessageEnvelope {
  const MessageEnvelope({required this.hops, required this.exp});

  /// Devices passed through. Diagnostic only — nothing drops a message for a
  /// high hop count. [kMaxHops] is a bug backstop, not a TTL.
  final int hops;

  /// Unix seconds after which no device forwards this.
  final int exp;

  Map<String, dynamic> toJson() => {'hops': hops, 'exp': exp};

  factory MessageEnvelope.fromJson(Map<Object?, Object?> json) {
    final hops = _asInt(json['hops'], 'env.hops');
    final exp = _asInt(json['exp'], 'env.exp');
    if (hops == null) throw const MalformedMessageException('env.hops missing');
    if (exp == null) throw const MalformedMessageException('env.exp missing');
    if (hops < 0) throw MalformedMessageException('env.hops is negative: $hops');
    if (hops > kMaxHops) {
      throw MalformedMessageException('env.hops is $hops, over backstop $kMaxHops');
    }
    return MessageEnvelope(hops: hops, exp: exp);
  }

  @override
  bool operator ==(Object other) =>
      other is MessageEnvelope && other.hops == hops && other.exp == exp;

  @override
  int get hashCode => Object.hash(hops, exp);
}

@immutable
class MeshMessage {
  const MeshMessage({required this.core, required this.env});

  final MessageCore core;
  final MessageEnvelope env;

  String get id => core.id;

  /// The unique name of a message: `sha256(origin + seq)`, truncated.
  ///
  /// `origin` is unique to a person and `seq` is unique within that person, so
  /// the pair cannot collide with anyone else's — without any device ever
  /// contacting a server. That property is what makes offline identity work.
  static String computeId(String origin, int seq) {
    final digest = sha256.convert(utf8.encode('$origin$seq'));
    return digest.toString().substring(0, 16);
  }

  /// Builds a new SOS. [now] is unix seconds.
  factory MeshMessage.createSos({
    required String origin,
    required String uid,
    required int seq,
    required int now,
    Category? cat,
    int? n,
    String? txt,
    GeoPoint? loc,
  }) {
    if (txt != null && txt.length > kMaxTextLength) {
      throw MalformedMessageException(
          'txt is ${txt.length} chars, max $kMaxTextLength');
    }
    return MeshMessage(
      core: MessageCore(
        id: computeId(origin, seq),
        type: MessageType.sos,
        rawType: MessageType.sos.wire,
        origin: origin,
        uid: uid,
        seq: seq,
        ts: now,
        loc: loc,
        cat: cat,
        n: n,
        txt: txt,
      ),
      env: MessageEnvelope(hops: 0, exp: now + kExpirySeconds),
    );
  }

  /// The next copy to hand onward. [core] is carried by reference — it is
  /// frozen, so sharing it is the point.
  MeshMessage incrementHops() => MeshMessage(
        core: core,
        env: MessageEnvelope(hops: env.hops + 1, exp: env.exp),
      );

  Map<String, dynamic> toJson() => {
        't': 'MSG',
        'env': env.toJson(),
        'core': core.toJson(),
      };

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Parses [bytes] from the radio.
  ///
  /// Throws [MalformedMessageException] on anything unusable. Callers drop and
  /// log; they must never let this take the app down.
  factory MeshMessage.decode(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw MalformedMessageException('not valid UTF-8 JSON: ${e.message}');
    }

    if (decoded is! Map) {
      throw const MalformedMessageException('payload is not an object');
    }
    if (decoded['t'] != 'MSG') {
      throw MalformedMessageException('unknown frame type: ${decoded['t']}');
    }

    final core = decoded['core'];
    final env = decoded['env'];
    if (core is! Map) throw const MalformedMessageException('core missing');
    if (env is! Map) throw const MalformedMessageException('env missing');

    return MeshMessage(
      core: MessageCore.fromJson(core),
      env: MessageEnvelope.fromJson(env),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeshMessage && other.core == core && other.env == env;

  @override
  int get hashCode => Object.hash(core, env);

  @override
  String toString() =>
      'MeshMessage(${core.typeWire} ${core.id} from ${core.origin} hops=${env.hops})';
}

final RegExp _idPattern = RegExp(r'^[0-9a-f]{16}$');

String? _asString(Object? value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw MalformedMessageException('$field is not a string');
}

int? _asInt(Object? value, String field) {
  if (value == null) return null;
  if (value is int) return value;
  throw MalformedMessageException('$field is not an int');
}

double? _asDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw MalformedMessageException('$field is not a number');
}
