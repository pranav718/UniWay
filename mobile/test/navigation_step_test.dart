import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/data/models/navigation_step.dart';

void main() {
  group('NavigationStep Generator', () {
    test('returns empty list for empty points', () {
      expect(generateNavigationSteps([]), isEmpty);
    });

    test('returns single arrival step for single point', () {
      final steps = generateNavigationSteps([const LatLng(26.843, 75.564)]);
      expect(steps.length, 1);
      expect(steps.first.maneuver, NavigationManeuver.arrive);
    });

    test('generates depart, straight, and arrive for a collinear path', () {
      final points = [
        const LatLng(26.840, 75.564),
        const LatLng(26.841, 75.564),
        const LatLng(26.842, 75.564),
      ];

      final steps = generateNavigationSteps(points, destinationName: 'Dome');
      expect(steps.length, 2);
      expect(steps[0].maneuver, NavigationManeuver.depart);
      expect(steps[0].instruction, 'Head toward Dome');
      expect(steps[0].distanceMeters, greaterThan(200));
      expect(steps[1].maneuver, NavigationManeuver.arrive);
      expect(steps[1].instruction, 'Arrive at Dome');
    });

    test('detects right and left turns correctly', () {
      final points = [
        const LatLng(26.840, 75.564),
        const LatLng(26.841, 75.564),
        const LatLng(26.841, 75.565),
        const LatLng(26.842, 75.565),
      ];

      final steps = generateNavigationSteps(points, destinationName: 'Library');
      expect(steps.length, 4);

      expect(steps[0].maneuver, NavigationManeuver.depart);

      expect(steps[1].maneuver, NavigationManeuver.turnRight);
      expect(steps[1].instruction, 'Turn right');

      expect(steps[2].maneuver, NavigationManeuver.turnLeft);
      expect(steps[2].instruction, 'Turn left');

      expect(steps[3].maneuver, NavigationManeuver.arrive);
      expect(steps[3].instruction, 'Arrive at Library');
    });
  });
}
