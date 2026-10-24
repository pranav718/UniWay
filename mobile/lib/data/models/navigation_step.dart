import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/utils/geo_distance.dart';

enum NavigationManeuver {
  depart,
  straight,
  slightRight,
  turnRight,
  sharpRight,
  uTurn,
  sharpLeft,
  turnLeft,
  slightLeft,
  arrive,
}

class NavigationStep {
  final int stepIndex;
  final NavigationManeuver maneuver;
  final String instruction;
  final double distanceMeters;
  final LatLng point;
  final double targetBearing;

  const NavigationStep({
    required this.stepIndex,
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    required this.point,
    required this.targetBearing,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  IconData get icon {
    switch (maneuver) {
      case NavigationManeuver.depart:
        return Icons.navigation;
      case NavigationManeuver.straight:
        return Icons.straight;
      case NavigationManeuver.slightRight:
        return Icons.turn_slight_right;
      case NavigationManeuver.turnRight:
        return Icons.turn_right;
      case NavigationManeuver.sharpRight:
        return Icons.turn_sharp_right;
      case NavigationManeuver.uTurn:
        return Icons.u_turn_left;
      case NavigationManeuver.sharpLeft:
        return Icons.turn_sharp_left;
      case NavigationManeuver.turnLeft:
        return Icons.turn_left;
      case NavigationManeuver.slightLeft:
        return Icons.turn_slight_left;
      case NavigationManeuver.arrive:
        return Icons.location_on;
    }
  }

  @override
  String toString() =>
      'Step $stepIndex: $instruction ($formattedDistance, $maneuver)';
}

List<NavigationStep> generateNavigationSteps(
  List<LatLng> points, {
  String? destinationName,
}) {
  if (points.isEmpty) return const [];
  if (points.length == 1) {
    return [
      NavigationStep(
        stepIndex: 0,
        maneuver: NavigationManeuver.arrive,
        instruction: destinationName != null
            ? 'Arrive at $destinationName'
            : 'Arrive at destination',
        distanceMeters: 0,
        point: points.first,
        targetBearing: 0,
      ),
    ];
  }

  final steps = <NavigationStep>[];
  final initialBearing = initialBearingDegrees(
    points[0].latitude,
    points[0].longitude,
    points[1].latitude,
    points[1].longitude,
  );

  var currentManeuver = NavigationManeuver.depart;
  var currentInstruction = destinationName != null
      ? 'Head toward $destinationName'
      : 'Start navigation';
  var stepStartPoint = points[0];
  var accumulatedDistance = 0.0;
  var currentBearing = initialBearing;

  for (var i = 0; i < points.length - 1; i++) {
    final from = points[i];
    final to = points[i + 1];
    final segDist = haversineMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final segBearing = initialBearingDegrees(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    accumulatedDistance += segDist;

    if (i < points.length - 2) {
      final nextPoint = points[i + 2];
      final nextBearing = initialBearingDegrees(
        to.latitude,
        to.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );
      final turnAngle = relativeTurnAngle(segBearing, nextBearing);

      final nextManeuver = _classifyTurn(turnAngle);
      if (nextManeuver != NavigationManeuver.straight) {
        steps.add(NavigationStep(
          stepIndex: steps.length,
          maneuver: currentManeuver,
          instruction: currentInstruction,
          distanceMeters: accumulatedDistance,
          point: stepStartPoint,
          targetBearing: currentBearing,
        ));

        currentManeuver = nextManeuver;
        currentInstruction = _maneuverInstruction(nextManeuver);
        stepStartPoint = to;
        accumulatedDistance = 0.0;
        currentBearing = nextBearing;
      }
    }
  }

  steps.add(NavigationStep(
    stepIndex: steps.length,
    maneuver: currentManeuver,
    instruction: currentInstruction,
    distanceMeters: accumulatedDistance,
    point: stepStartPoint,
    targetBearing: currentBearing,
  ));

  steps.add(NavigationStep(
    stepIndex: steps.length,
    maneuver: NavigationManeuver.arrive,
    instruction: destinationName != null
        ? 'Arrive at $destinationName'
        : 'Arrive at destination',
    distanceMeters: 0.0,
    point: points.last,
    targetBearing: currentBearing,
  ));

  return steps;
}

NavigationManeuver _classifyTurn(double angle) {
  if (angle.abs() < 25.0) {
    return NavigationManeuver.straight;
  }
  if (angle >= 25.0 && angle < 65.0) {
    return NavigationManeuver.slightRight;
  }
  if (angle >= 65.0 && angle < 115.0) {
    return NavigationManeuver.turnRight;
  }
  if (angle >= 115.0 && angle < 160.0) {
    return NavigationManeuver.sharpRight;
  }
  if (angle.abs() >= 160.0) {
    return NavigationManeuver.uTurn;
  }
  if (angle <= -25.0 && angle > -65.0) {
    return NavigationManeuver.slightLeft;
  }
  if (angle <= -65.0 && angle > -115.0) {
    return NavigationManeuver.turnLeft;
  }
  return NavigationManeuver.sharpLeft;
}

String _maneuverInstruction(NavigationManeuver maneuver) {
  switch (maneuver) {
    case NavigationManeuver.slightRight:
      return 'Slight right';
    case NavigationManeuver.turnRight:
      return 'Turn right';
    case NavigationManeuver.sharpRight:
      return 'Sharp right';
    case NavigationManeuver.uTurn:
      return 'Make a U-turn';
    case NavigationManeuver.slightLeft:
      return 'Slight left';
    case NavigationManeuver.turnLeft:
      return 'Turn left';
    case NavigationManeuver.sharpLeft:
      return 'Sharp left';
    default:
      return 'Continue straight';
  }
}
