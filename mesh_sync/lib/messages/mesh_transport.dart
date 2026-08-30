// The seam between the message layer and the radio.
//
// MeshRouter depends on this rather than on MeshService, so the whole routing
// layer can be stood up in a plain Dart test with no phones and no plugin.

import 'package:flutter/foundation.dart';

abstract interface class MeshTransport {
  /// Sends [bytes] to every connected peer except [exceptEndpointId].
  ///
  /// Returns how many peers it reached. The exclusion is the propagation
  /// rule's "forward to every connected peer except the one it arrived from" —
  /// without it a message echoes straight back to its sender.
  Future<int> broadcast(Uint8List bytes, {String? exceptEndpointId});

  /// Sends [bytes] to one peer.
  ///
  /// Needed for the store-and-forward flush: when a peer connects, we push our
  /// backlog to that peer alone. Broadcast-with-exclusions cannot express it.
  Future<bool> sendTo(String endpointId, Uint8List bytes);
}
