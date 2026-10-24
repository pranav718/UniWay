import 'dart:math' as math;

const _earthRadiusMeters = 6371000.0;

/// Great-circle distance in meters between two WGS84 coordinates.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final sinLat = math.sin(_toRadians(lat2 - lat1) / 2);
  final sinLng = math.sin(_toRadians(lng2 - lng1) / 2);
  final a = sinLat * sinLat +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * sinLng * sinLng;
  // Rounding can push [a] a hair above 1 for near-antipodal points; clamping
  // keeps asin in its domain instead of returning NaN.
  return 2 * _earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(a)));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
double _toDegrees(double radians) => radians * 180 / math.pi;

double initialBearingDegrees(double lat1, double lng1, double lat2, double lng2) {
  final dLng = _toRadians(lng2 - lng1);
  final phi1 = _toRadians(lat1);
  final phi2 = _toRadians(lat2);

  final y = math.sin(dLng) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLng);

  if (x == 0 && y == 0) return 0.0;
  final theta = math.atan2(y, x);
  return (_toDegrees(theta) + 360) % 360;
}

double relativeTurnAngle(double fromBearing, double toBearing) {
  var diff = (toBearing - fromBearing) % 360;
  if (diff > 180) diff -= 360;
  if (diff <= -180) diff += 360;
  return diff;
}

double distanceToSegmentMeters(
  double pLat,
  double pLng,
  double aLat,
  double aLng,
  double bLat,
  double bLng,
) {
  final meanLatRad = _toRadians((aLat + bLat) / 2);
  final cosLat = math.cos(meanLatRad);

  final dx = (bLng - aLng) * cosLat;
  final dy = bLat - aLat;
  final segLenSq = dx * dx + dy * dy;

  if (segLenSq == 0) {
    return haversineMeters(pLat, pLng, aLat, aLng);
  }

  final px = (pLng - aLng) * cosLat;
  final py = pLat - aLat;

  final t = (px * dx + py * dy) / segLenSq;
  final clampedT = math.max(0.0, math.min(1.0, t));

  final nearestLat = aLat + clampedT * (bLat - aLat);
  final nearestLng = aLng + clampedT * (bLng - aLng);

  return haversineMeters(pLat, pLng, nearestLat, nearestLng);
}

double distanceToPolylineMeters(
  double pLat,
  double pLng,
  List<List<double>> polylineCoordinates,
) {
  if (polylineCoordinates.isEmpty) return double.infinity;
  if (polylineCoordinates.length == 1) {
    return haversineMeters(
      pLat,
      pLng,
      polylineCoordinates[0][1],
      polylineCoordinates[0][0],
    );
  }

  var minDistance = double.infinity;
  for (var i = 0; i < polylineCoordinates.length - 1; i++) {
    final aLng = polylineCoordinates[i][0];
    final aLat = polylineCoordinates[i][1];
    final bLng = polylineCoordinates[i + 1][0];
    final bLat = polylineCoordinates[i + 1][1];

    final dist = distanceToSegmentMeters(pLat, pLng, aLat, aLng, bLat, bLng);
    if (dist < minDistance) {
      minDistance = dist;
    }
  }

  return minDistance;
}
