import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/navigation_step.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';

class FakeNavRoutingRepository implements RoutingRepository {
  CampusRoute? routeToReturn;
  int getRouteCallCount = 0;
  double? lastFromLat;
  double? lastFromLng;

  @override
  Future<RoutingResult> getRoute({
    required String campusId,
    Destination? origin,
    required Destination destination,
    double? fromLat,
    double? fromLng,
    bool accessible = false,
  }) async {
    getRouteCallCount++;
    lastFromLat = fromLat;
    lastFromLng = fromLng;
    return RoutingResult(
      route: routeToReturn,
      statusCode: 200,
      latencyMs: 15,
    );
  }

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return const DestinationsResult(
      destinations: [
        Destination(
          id: 'D1',
          routingNodeId: 'N1',
          name: 'Academic Block 1',
          category: 'academic',
          latitude: 26.8430,
          longitude: 75.5640,
        ),
        Destination(
          id: 'D2',
          routingNodeId: 'N2',
          name: 'Dome Building',
          category: 'academic',
          latitude: 26.8450,
          longitude: 75.5650,
        ),
      ],
      statusCode: 200,
    );
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNavLocationService extends Fake implements LocationService {
  final StreamController<LocationFix> fixController =
      StreamController<LocationFix>.broadcast();

  @override
  Future<LocationResult> getCurrentLocation() async {
    return const LocationResult(
      latitude: 26.8430,
      longitude: 75.5640,
      accuracyMeters: 5.0,
    );
  }

  @override
  Stream<LocationFix> positionStream() => fixController.stream;
}

void main() {
  group('RoutingController Turn-by-Turn Navigation', () {
    late FakeNavRoutingRepository repo;
    late FakeNavLocationService locationService;
    late CampusRoute sampleRoute;

    setUp(() {
      repo = FakeNavRoutingRepository();
      locationService = FakeNavLocationService();
      sampleRoute = const CampusRoute(
        distanceMeters: 250.0,
        points: [
          LatLng(26.8430, 75.5640),
          LatLng(26.8440, 75.5640),
          LatLng(26.8440, 75.5650),
          LatLng(26.8450, 75.5650),
        ],
        rawCoordinates: [
          [75.5640, 26.8430],
          [75.5640, 26.8440],
          [75.5650, 26.8440],
          [75.5650, 26.8450],
        ],
        rawFeature: {},
      );
      repo.routeToReturn = sampleRoute;
    });

    test('startNavigation initializes steps and sets isNavigating', () async {
      final controller = RoutingController(
        repository: repo,
        locationService: locationService,
      );
      await pumpEventQueue();

      controller.setDestination(const Destination(
        id: 'D2',
        routingNodeId: 'N2',
        name: 'Dome Building',
        category: 'academic',
        latitude: 26.8450,
        longitude: 75.5650,
      ));
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);

      expect(controller.currentRoute, isNotNull);
      expect(controller.isNavigating, isFalse);

      controller.startNavigation();

      expect(controller.isNavigating, isTrue);
      expect(controller.navigationSteps, isNotEmpty);
      expect(controller.currentStepIndex, 0);
      expect(controller.currentStep?.maneuver, NavigationManeuver.depart);
      expect(controller.nextStep?.maneuver, NavigationManeuver.turnRight);
      expect(controller.remainingDistanceMeters, 250.0);

      controller.stopNavigation();
      expect(controller.isNavigating, isFalse);
      expect(controller.navigationSteps, isEmpty);
      controller.dispose();
    });

    test('clearRoute resets navigation state', () async {
      final controller = RoutingController(
        repository: repo,
        locationService: locationService,
      );
      await pumpEventQueue();

      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      expect(controller.isNavigating, isTrue);

      controller.clearRoute();
      expect(controller.isNavigating, isFalse);
      expect(controller.currentRoute, null);
      expect(controller.navigationSteps, isEmpty);
      controller.dispose();
    });

    test('advances step when user reaches the next maneuver waypoint', () async {
      final controller = RoutingController(
        repository: repo,
        locationService: locationService,
      );
      await pumpEventQueue();

      controller.setDestination(const Destination(
        id: 'D2',
        routingNodeId: 'N2',
        name: 'Dome Building',
        category: 'academic',
        latitude: 26.8450,
        longitude: 75.5650,
      ));
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      expect(controller.currentStepIndex, 0);

      locationService.fixController.add(LocationFix(
        latitude: 26.844001,
        longitude: 75.564001,
        accuracyMeters: 4.0,
        timestamp: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(controller.currentStepIndex, 1);
      expect(controller.currentStep?.maneuver, NavigationManeuver.turnRight);

      controller.dispose();
    });

    test('detects arrival when user reaches destination within 12m', () async {
      final controller = RoutingController(
        repository: repo,
        locationService: locationService,
      );
      await pumpEventQueue();

      controller.setDestination(const Destination(
        id: 'D2',
        routingNodeId: 'N2',
        name: 'Dome Building',
        category: 'academic',
        latitude: 26.8450,
        longitude: 75.5650,
      ));
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      expect(controller.isArrived, isFalse);

      locationService.fixController.add(LocationFix(
        latitude: 26.845001,
        longitude: 75.565001,
        accuracyMeters: 3.0,
        timestamp: DateTime.now(),
      ));
      await pumpEventQueue();

      expect(controller.isArrived, isTrue);
      expect(controller.remainingDistanceMeters, 0.0);
      expect(controller.currentStep?.maneuver, NavigationManeuver.arrive);

      controller.dispose();
    });

    test('triggers automatic reroute after 2 consecutive off-route fixes > 25m', () async {
      final controller = RoutingController(
        repository: repo,
        locationService: locationService,
      );
      await pumpEventQueue();

      controller.setDestination(const Destination(
        id: 'D2',
        routingNodeId: 'N2',
        name: 'Dome Building',
        category: 'academic',
        latitude: 26.8450,
        longitude: 75.5650,
      ));
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();

      final initialCalls = repo.getRouteCallCount;

      locationService.fixController.add(LocationFix(
        latitude: 26.8435,
        longitude: 75.5635,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      ));
      await pumpEventQueue();
      expect(repo.getRouteCallCount, initialCalls);

      locationService.fixController.add(LocationFix(
        latitude: 26.8435,
        longitude: 75.5635,
        accuracyMeters: 5.0,
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
      ));
      await pumpEventQueue();
      expect(repo.getRouteCallCount, initialCalls + 1);

      controller.dispose();
    });
  });
}
