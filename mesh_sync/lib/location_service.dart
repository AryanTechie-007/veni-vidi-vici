// Reading this device's position for an outgoing SOS.
//
// The spec is explicit that sending must not wait on a fresh fix: a stale
// position beats no message. So the default read is the cached last-known one,
// which returns instantly, and a fresh fix is only taken when the user asks
// for it by name.
//
// GPS itself needs no network, which is the whole reason this works at all.

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import 'messages/mesh_message.dart';

class LocationService {
  LocationService();

  /// Resolved addresses, keyed by coordinates rounded to ~10m.
  ///
  /// Worth caching hard: the lookup needs the network, so a hit found while
  /// briefly online stays readable long after coverage is gone.
  final Map<String, String?> _addresses = {};

  /// geocoding 5.x is instance-based rather than a set of top-level functions.
  final geocoding.Geocoding _geocoder = geocoding.Geocoding();

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

  /// A human-readable address for [point], or null if it cannot be resolved.
  ///
  /// **Needs the network.** Android's geocoder is an online service, so in the
  /// disaster this app is built for it will usually return nothing. The
  /// coordinates are the real payload and are always shown; an address is a
  /// convenience on top when a device happens to have coverage.
  ///
  /// Deliberately never travels on the wire. It is derived from `loc`, would
  /// cost bytes on every hop, and `core` is frozen — so each device resolves
  /// what it can, for itself.
  Future<String?> describe(GeoPoint point) async {
    final key =
        '${point.lat.toStringAsFixed(4)},${point.lon.toStringAsFixed(4)}';
    if (_addresses.containsKey(key)) return _addresses[key];

    try {
      // Cheap check first: with no geocoder present there is nothing to wait on.
      if (!await _geocoder.isPresent()) return null;
      final places = await _geocoder.placemarkFromCoordinates(
        point.lat,
        point.lon,
      );
      final address = places.isEmpty ? null : _format(places.first);
      _addresses[key] = address;
      return address;
    } catch (_) {
      // Offline, no geocoder, or nothing at those coordinates. Not cached —
      // a later attempt with coverage should be allowed to succeed.
      return null;
    }
  }

  /// Street-level and above, skipping anything empty.
  static String? _format(geocoding.Placemark place) {
    final parts = <String>[
      for (final part in [place.name, place.subLocality, place.locality])
        if (part != null && part.isNotEmpty) part,
    ];
    // name often repeats subLocality; drop consecutive duplicates.
    final seen = <String>[];
    for (final part in parts) {
      if (seen.isEmpty || seen.last != part) seen.add(part);
    }
    return seen.isEmpty ? null : seen.join(', ');
  }
}
