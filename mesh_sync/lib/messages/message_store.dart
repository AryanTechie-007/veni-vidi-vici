// Local persistence for the mesh: the seen set, the message store, and seq.
//
// The interface is async even though the in-memory implementation returns
// immediately — SQLite lands behind this same interface later, and retrofitting
// async through the router would touch every call site.

import 'mesh_message.dart';

/// Overflow backstop for the seen set. Normal eviction is by expiry.
const int kMaxSeenEntries = 5000;

/// Overflow backstop for the message store.
const int kMaxStoredMessages = 2000;

abstract interface class MessageStore {
  /// Returns the next per-device counter value and persists the increment.
  ///
  /// Load-bearing for message identity: `id = hash(origin + seq)`, so if this
  /// ever restarts at 1 for an origin that has sent before, the regenerated
  /// ids collide with old ones and real messages are dropped as duplicates.
  Future<int> nextSeq();

  /// Whether this id has ever been processed. The dedup check, run at every
  /// hop rather than only at the destination.
  Future<bool> hasSeen(String id);

  /// Records [id] as processed until [expiresAt] (unix seconds).
  ///
  /// The caller passes `min(message.exp, localReceipt + 72h)` so a wrong sender
  /// clock can only make us hold the entry too long, never drop it too early.
  ///
  /// A seen entry deliberately outlives the stored message: a CANCEL deletes
  /// the message but we must still refuse it if a peer offers it again.
  Future<void> markSeen(String id, {required int expiresAt});

  /// Stores [message]. [localExpiry] is `min(env.exp, localReceipt + 72h)` —
  /// the clock-skew bound, recorded so pruning need not re-derive it.
  ///
  /// Re-storing an id keeps the lowest hop count and the *original*
  /// localExpiry, since the 72h local clock started at first receipt.
  Future<void> put(MeshMessage message, {required int localExpiry});

  Future<MeshMessage?> get(String id);

  /// Records that the message with id [sosId] has been acknowledged.
  ///
  /// Kept separately from the message itself because an ACK routinely arrives
  /// before the SOS it references — out-of-order arrival is normal and must
  /// never block acceptance.
  Future<void> markAcked(String sosId);

  Future<bool> isAcked(String id);

  /// Records that [sosId] has been cancelled, so it is refused if a peer
  /// offers it again after we have deleted it.
  Future<void> markCancelled(String sosId);

  Future<bool> isCancelled(String id);

  /// Everything still worth pushing to peers at [now].
  ///
  /// Excludes anything acknowledged: once a node holds both an SOS and an ACK
  /// referencing it, that SOS has been delivered and stops consuming
  /// bandwidth. It stays in storage — a responder arriving later still wants
  /// the record.
  Future<List<MeshMessage>> forwardable({required int now});

  /// All held messages, expired or not — for the UI.
  Future<List<MeshMessage>> all();

  Future<void> delete(String id);

  /// Drops expired seen entries and expired messages.
  Future<void> pruneExpired({required int now});
}

/// In-memory implementation. Everything is lost on process death, which is why
/// this is a step towards SQLite rather than the destination.
class InMemoryMessageStore implements MessageStore {
  InMemoryMessageStore({int startingSeq = 0, this.onSeqAdvanced})
      : _seq = startingSeq;

  /// Fired on every increment so the app can persist the counter.
  ///
  /// A callback rather than a decorator class because SQLite replaces this
  /// whole implementation later — a hook beats pass-through boilerplate that
  /// gets deleted.
  final void Function(int seq)? onSeqAdvanced;

  int _seq;

  /// id -> unix seconds after which the entry may be dropped.
  final Map<String, int> _seen = {};

  /// SOS ids we have seen an ACK for. Populated even when we do not hold the
  /// referenced message yet.
  final Set<String> _acked = {};

  /// SOS ids we have seen a CANCEL for.
  final Set<String> _cancelled = {};

  final Map<String, _StoredMessage> _messages = {};

  @override
  Future<int> nextSeq() async {
    final next = ++_seq;
    onSeqAdvanced?.call(next);
    return next;
  }

  @override
  Future<bool> hasSeen(String id) async => _seen.containsKey(id);

  @override
  Future<void> markSeen(String id, {required int expiresAt}) async {
    _seen[id] = expiresAt;
    if (_seen.length > kMaxSeenEntries) {
      // Backstop only. Drop whatever expires soonest — those entries are
      // closest to being useless anyway.
      final ordered = _seen.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in ordered.take(_seen.length - kMaxSeenEntries)) {
        _seen.remove(entry.key);
      }
    }
  }

  @override
  Future<void> put(MeshMessage message, {required int localExpiry}) async {
    final existing = _messages[message.id];

    // core is identical by definition, so the only thing worth merging is the
    // hop count — keep the lowest, the same rule the server upsert uses.
    final hops = existing == null
        ? message.env.hops
        : (existing.message.env.hops < message.env.hops
            ? existing.message.env.hops
            : message.env.hops);

    _messages[message.id] = _StoredMessage(
      message: MeshMessage(
        core: message.core,
        env: MessageEnvelope(hops: hops, exp: message.env.exp),
      ),
      // First receipt started the local clock; a later copy does not reset it.
      localExpiry: existing?.localExpiry ?? localExpiry,
    );

    if (_messages.length > kMaxStoredMessages) {
      final ordered = _messages.entries.toList()
        ..sort((a, b) => a.value.localExpiry.compareTo(b.value.localExpiry));
      for (final entry in ordered.take(_messages.length - kMaxStoredMessages)) {
        _messages.remove(entry.key);
      }
    }
  }

  @override
  Future<MeshMessage?> get(String id) async => _messages[id]?.message;

  @override
  Future<void> markAcked(String sosId) async => _acked.add(sosId);

  @override
  Future<bool> isAcked(String id) async => _acked.contains(id);

  @override
  Future<void> markCancelled(String sosId) async => _cancelled.add(sosId);

  @override
  Future<bool> isCancelled(String id) async => _cancelled.contains(id);

  @override
  Future<List<MeshMessage>> forwardable({required int now}) async => [
        for (final stored in _messages.values)
          if (stored.localExpiry > now && !_acked.contains(stored.message.id))
            stored.message,
      ];

  @override
  Future<List<MeshMessage>> all() async =>
      [for (final stored in _messages.values) stored.message];

  @override
  Future<void> delete(String id) async => _messages.remove(id);

  @override
  Future<void> pruneExpired({required int now}) async {
    _seen.removeWhere((_, expiresAt) => expiresAt <= now);
    _messages.removeWhere((_, stored) => stored.localExpiry <= now);
  }
}

class _StoredMessage {
  const _StoredMessage({required this.message, required this.localExpiry});

  final MeshMessage message;

  /// `min(env.exp, localReceipt + 72h)` — the clock-skew bound.
  final int localExpiry;
}
