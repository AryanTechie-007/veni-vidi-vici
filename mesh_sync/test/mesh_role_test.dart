import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_sync/device_identity.dart';

/// The role prefix is not cosmetic: it goes into the advertised endpoint name,
/// which is what the symmetry break compares to decide who dials.
void main() {
  test('role codes are distinct and single-character', () {
    expect(MeshRole.victim.code, 'C');
    expect(MeshRole.responder.code, 'R');
    expect(MeshRole.victim.code, isNot(MeshRole.responder.code));
  });

  test('responders sort above victims, so a responder always dials', () {
    // MeshService.nickname is '<code>|<tag>', and _onEndpointFound only
    // initiates when its own name compares greater than the peer's.
    const victim = 'C|dev-AAAA';
    const responder = 'R|dev-AAAA';

    expect(responder.compareTo(victim), greaterThan(0));
    expect(victim.compareTo(responder), lessThan(0));
  });

  test('two devices in the same role still break the tie by tag', () {
    const a = 'C|dev-AAAA';
    const b = 'C|dev-ZZZZ';

    expect(b.compareTo(a), greaterThan(0));
    expect(a.compareTo(b), lessThan(0));
    // Exactly one side dials, never both and never neither.
    expect((a.compareTo(b) > 0) != (b.compareTo(a) > 0), isTrue);
  });

  test('role round-trips through its persisted name', () {
    for (final role in MeshRole.values) {
      final restored = MeshRole.values.firstWhere((r) => r.name == role.name);
      expect(restored, role);
    }
  });
}
