import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';
import 'package:uniway_mobile/presentation/widgets/navigation_bottom_bar.dart';
import 'package:uniway_mobile/presentation/widgets/navigation_step_banner.dart';
import 'package:uniway_mobile/presentation/widgets/route_picker_card.dart';

class _FakeRoutingRepo implements RoutingRepository {
  CampusRoute? routeToReturn;
  Completer<RoutingResult>? pendingRouteCompleter;

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
  Future<RoutingResult> getRoute({
    required String campusId,
    Destination? origin,
    required Destination destination,
    double? fromLat,
    double? fromLng,
    bool accessible = false,
  }) async {
    if (pendingRouteCompleter != null) {
      return pendingRouteCompleter!.future;
    }
    return RoutingResult(
      route: routeToReturn,
      statusCode: 200,
      latencyMs: 15,
    );
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamableLocationService extends Fake implements LocationService {
  final StreamController<LocationFix> streamCtrl =
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
  Stream<LocationFix> positionStream() => streamCtrl.stream;
}

void main() {
  group('Navigation UI & Widget Tests', () {
    late _FakeRoutingRepo fakeRepo;
    late _StreamableLocationService locationService;
    late CampusRoute sampleRoute;

    const sampleDestination = Destination(
      id: 'D2',
      routingNodeId: 'N2',
      name: 'Dome Building',
      category: 'academic',
      latitude: 26.8450,
      longitude: 75.5650,
    );

    setUp(() {
      fakeRepo = _FakeRoutingRepo();
      locationService = _StreamableLocationService();
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
      fakeRepo.routeToReturn = sampleRoute;
    });

    tearDown(() {
      locationService.streamCtrl.close();
    });

    testWidgets('NavigationStepBanner displays active maneuver and next step preview', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => NavigationStepBanner(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationStepBanner), findsOneWidget);
      expect(find.text('Start Route'), findsOneWidget);
      expect(find.textContaining('Head'), findsOneWidget);
      expect(find.textContaining('Then'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('NavigationStepBanner reflects rerouting state', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => NavigationStepBanner(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      await tester.pumpAndSettle();

      final completer = Completer<RoutingResult>();
      fakeRepo.pendingRouteCompleter = completer;

      final t0 = DateTime.now();
      locationService.streamCtrl.add(LocationFix(
        latitude: 26.8435,
        longitude: 75.5635,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));
      await tester.pump(const Duration(seconds: 1));

      locationService.streamCtrl.add(LocationFix(
        latitude: 26.8435,
        longitude: 75.5635,
        accuracyMeters: 5.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isRerouting, isTrue);
      expect(find.textContaining('Rerouting'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(RoutingResult(
        route: sampleRoute,
        statusCode: 200,
        latencyMs: 12,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isRerouting, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      fakeRepo.pendingRouteCompleter = null;
      controller.dispose();
    });

    testWidgets('NavigationStepBanner reflects arrival state', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => NavigationStepBanner(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      await tester.pumpAndSettle();

      final t0 = DateTime.now();
      locationService.streamCtrl.add(LocationFix(
        latitude: 26.8450,
        longitude: 75.5650,
        accuracyMeters: 3.0,
        timestamp: t0,
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(controller.isArrived, isTrue);
      expect(find.text('You Have Arrived!'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      controller.dispose();
    });

    testWidgets('NavigationBottomBar displays distance, ETA, and stops navigation on End', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => NavigationBottomBar(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      controller.startNavigation();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBottomBar), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.textContaining('m)'), findsOneWidget);
      expect(find.textContaining('ETA:'), findsOneWidget);

      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();

      expect(controller.isNavigating, isFalse);

      controller.dispose();
    });

    testWidgets('NavigationBottomBar displays Re-center button when showRecenter is true', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );
      bool recenterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationBottomBar(
              controller: controller,
              showRecenter: true,
              onRecenter: () => recenterTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Re-center'), findsOneWidget);
      await tester.tap(find.text('Re-center'));
      await tester.pumpAndSettle();

      expect(recenterTapped, isTrue);

      controller.dispose();
    });

    testWidgets('RoutePickerCard shows Start button and starts navigation', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => RoutePickerCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(controller.isNavigating, isTrue);

      controller.dispose();
    });

    testWidgets('MapScreen transitions from picker to NavigationStepBanner & BottomBar when navigating', (tester) async {
      final controller = RoutingController(
        repository: fakeRepo,
        locationService: locationService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            mapBuilder: (context, onCreated, onStyle) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoutePickerCard), findsOneWidget);
      expect(find.byType(NavigationStepBanner), findsNothing);
      expect(find.byType(NavigationBottomBar), findsNothing);

      controller.setDestination(sampleDestination);
      await controller.fetchRoute(customLat: 26.8430, customLng: 75.5640);
      await tester.pumpAndSettle();

      controller.startNavigation();
      await tester.pumpAndSettle();

      expect(find.byType(RoutePickerCard), findsNothing);
      expect(find.byType(NavigationStepBanner), findsOneWidget);
      expect(find.byType(NavigationBottomBar), findsOneWidget);

      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();

      expect(find.byType(RoutePickerCard), findsOneWidget);
      expect(find.byType(NavigationStepBanner), findsNothing);
      expect(find.byType(NavigationBottomBar), findsNothing);

      controller.dispose();
    });
  });
}
