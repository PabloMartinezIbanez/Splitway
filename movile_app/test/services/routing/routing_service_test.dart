import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/src/services/routing/routing_service.dart';

/// Canned Directions response with a trivial 2-point geometry.
String _directionsBody() => jsonEncode({
      'routes': [
        {
          'geometry': {
            'coordinates': [
              [0.0, 0.0],
              [0.01, 0.0],
            ],
          },
        },
      ],
    });

/// Canned Map Matching response with a single 12.5s match.
String _matchingBody() => jsonEncode({
      'code': 'Ok',
      'matchings': [
        {'duration': 12.5, 'confidence': 0.9},
      ],
    });

void main() {
  group('RoutingService.snapToRoads', () {
    test('sends a per-waypoint bearings parameter for the travel direction',
        () async {
      late Uri captured;
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(_directionsBody(), 200);
        }),
      );

      // Two waypoints heading due east → bearing 90° at both ends.
      await service.snapToRoads(const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ]);

      expect(captured.queryParameters['bearings'], '90,45;90,45');
    });

    test('omits bearings when waypoints are too close to derive a direction',
        () async {
      late Uri captured;
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(_directionsBody(), 200);
        }),
      );

      // ~2 m apart — direction is just tap noise, so no bearing is sent.
      final a = const GeoPoint(latitude: 0, longitude: 0);
      final b = a.destinationPoint(90, 2);
      await service.snapToRoads([a, b]);

      expect(captured.queryParameters.containsKey('bearings'), isFalse);
    });

    test('returns the parsed road geometry on success', () async {
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async => http.Response(_directionsBody(), 200)),
      );

      final result = await service.snapToRoads(const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.path!.length, 2);
      expect(result.path!.first.latitude, 0.0);
      expect(result.path!.last.longitude, 0.01);
      expect(result.failure, isNull);
    });

    test('surfaces a rateLimited failure on 429 and records a cooldown',
        () async {
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async => http.Response(
              '{"error":"rate"}',
              429,
              headers: {'retry-after': '30'},
            )),
      );

      final result = await service.snapToRoads(const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.isRateLimited, isTrue);
      expect(result.failure!.reason, RoutingFailureReason.rateLimited);
      expect(result.failure!.retryAfter, const Duration(seconds: 30));
      // Cooldown is now populated for the same coordinates+profile.
      expect(service.cooldownsForTesting, isNotEmpty);
    });

    test('short-circuits with a cooldown failure while under cooldown',
        () async {
      var httpCalls = 0;
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async {
          httpCalls++;
          return http.Response(
            '{"error":"rate"}',
            429,
            headers: {'retry-after': '30'},
          );
        }),
      );

      const wp = [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ];

      final first = await service.snapToRoads(wp);
      expect(first.failure!.reason, RoutingFailureReason.rateLimited);
      expect(httpCalls, 1);

      // Second call for the same input should NOT hit the network.
      final second = await service.snapToRoads(wp);
      expect(httpCalls, 1);
      expect(second.failure!.reason, RoutingFailureReason.cooldown);
      expect(second.isRateLimited, isTrue);
      expect(second.failure!.retryAfter, isNotNull);
    });
  });

  group('RoutingService.matchDuration', () {
    test('returns a parsed duration on success', () async {
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async => http.Response(_matchingBody(), 200)),
      );

      final result = await service.matchDuration(const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.duration, const Duration(milliseconds: 12500));
    });

    test('reports noRoute when Map Matching returns a non-Ok code', () async {
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async => http.Response(
              jsonEncode({'code': 'NoMatch', 'matchings': []}),
              200,
            )),
      );

      final result = await service.matchDuration(const [
        GeoPoint(latitude: 0, longitude: 0),
        GeoPoint(latitude: 0, longitude: 0.01),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.failure!.reason, RoutingFailureReason.noRoute);
    });

    test('retries on 429 up to maxRateLimitRetries then succeeds', () async {
      var call = 0;
      final service = RoutingService(
        mapboxToken: 'tok',
        client: MockClient((_) async {
          call++;
          if (call == 1) {
            return http.Response(
              '{"error":"rate"}',
              429,
              headers: {'retry-after': '0'},
            );
          }
          return http.Response(_matchingBody(), 200);
        }),
      );

      final result = await service.matchDuration(
        const [
          GeoPoint(latitude: 0, longitude: 0),
          GeoPoint(latitude: 0, longitude: 0.01),
        ],
        maxRateLimitRetries: 1,
      );

      expect(call, 2);
      expect(result.isSuccess, isTrue);
      expect(result.duration, const Duration(milliseconds: 12500));
      // On success we clear the cooldown for that input.
      expect(service.cooldownsForTesting, isEmpty);
    });
  });

  group('RoutingService.parseDirections', () {
    test('extracts path and duration', () {
      final data = {
        'routes': [
          {
            'duration': 73.6,
            'geometry': {
              'coordinates': [
                [-3.70, 40.41],
                [-3.69, 40.42],
              ]
            }
          }
        ]
      };
      final result = RoutingService.parseDirections(data);
      expect(result, isNotNull);
      expect(result!.path!.length, 2);
      expect(result.duration, const Duration(milliseconds: 73600));
    });

    test('returns null when no routes', () {
      expect(RoutingService.parseDirections({'routes': []}), isNull);
    });
  });

  group('RoutingService.parseMatching', () {
    test('sums matching durations when code Ok', () {
      final data = {
        'code': 'Ok',
        'matchings': [
          {'duration': 30.0, 'confidence': 0.9},
          {'duration': 12.5, 'confidence': 0.8},
        ],
      };
      expect(
        RoutingService.parseMatching(data),
        const Duration(milliseconds: 42500),
      );
    });

    test('returns null when code not Ok', () {
      expect(
        RoutingService.parseMatching({'code': 'NoMatch', 'matchings': []}),
        isNull,
      );
    });
  });
}
