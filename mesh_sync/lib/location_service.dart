// Reading this device's position for an outgoing SOS.
//
// The spec is explicit that sending must not wait on a fresh fix: a stale
// position beats no message. So the default read is the cached last-known one,
// which returns instantly, and a fresh fix is only taken when the user asks
// for it by name.
//
// GPS itself needs no network, which is the whole reason this works at all.

import 'package:geolocator/geolocator.dart';

import 'messages/mesh_message.dart';

class LocationService {
  const LocationService();

  /// The cached fix. Returns immediately, or null if the device has none.
  Future<GeoPoint?> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return _toPoint(position);
    } catch (_) {
      // Permission refused, location off, no cached fix — all the same to the
      // caller, and none of them may block an SOS.
      return null;
    }
  }

  /// Takes a new reading. Only ever called from an explicit Refresh, never on
  /// the send path.
  Future<GeoPoint?> refresh() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _toPoint(position);
    } catch (_) {
      return null;
    }
  }

  static GeoPoint? _toPoint(Position? position) {
    if (position == null) return null;
    return GeoPoint(
      lat: position.latitude,
      lon: position.longitude,
      acc: position.accuracy,
    );
  }
}
