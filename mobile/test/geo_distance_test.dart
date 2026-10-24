import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/utils/geo_distance.dart';

void main() {
  group('Geo Distance & Bearing Utilities', () {
    test('initialBearingDegrees returns correct cardinal directions', () {
      expect(initialBearingDegrees(0, 0, 1, 0), closeTo(0, 0.1));
      expect(initialBearingDegrees(0, 0, 0, 1), closeTo(90, 0.1));
      expect(initialBearingDegrees(0, 0, -1, 0), closeTo(180, 0.1));
      expect(initialBearingDegrees(0, 0, 0, -1), closeTo(270, 0.1));
    });

    test('relativeTurnAngle correctly computes signed delta', () {
      expect(relativeTurnAngle(45, 45), 0.0);
      expect(relativeTurnAngle(0, 90), 90.0);
      expect(relativeTurnAngle(350, 80), 90.0);
      expect(relativeTurnAngle(90, 0), -90.0);
      expect(relativeTurnAngle(10, 280), -90.0);
      expect(relativeTurnAngle(0, 180).abs(), 180.0);
    });

    test('distanceToSegmentMeters computes perpendicular distance accurately', () {
      final dist = distanceToSegmentMeters(0.001, 0.005, 0.0, 0.0, 0.0, 0.01);
      expect(dist, closeTo(111.0, 1.0));

      final distBefore = distanceToSegmentMeters(0.0, -0.005, 0.0, 0.0, 0.0, 0.01);
      expect(distBefore, closeTo(556.0, 2.0));

      final distAfter = distanceToSegmentMeters(0.0, 0.015, 0.0, 0.0, 0.0, 0.01);
      expect(distAfter, closeTo(556.0, 2.0));
    });

    test('distanceToPolylineMeters finds closest segment', () {
      final polyline = [
        [0.0, 0.0],
        [0.0, 0.01],
        [0.01, 0.01],
      ];

      final dist = distanceToPolylineMeters(0.005, 0.00045, polyline);
      expect(dist, closeTo(50.0, 2.0));
    });
  });
}
