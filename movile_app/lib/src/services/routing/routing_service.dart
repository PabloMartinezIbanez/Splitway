import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:splitway_core/splitway_core.dart';

import '../logging/app_logger.dart';
import '../logging/http_logging.dart';

/// Why a routing call did not return a usable result.
enum RoutingFailureReason {
  /// Server refused with 429 (rate limit) — either Mapbox's own token limit
  /// or our Edge Function's per-user quota.
  rateLimited,

  /// The API responded but with no matching route (e.g. Directions returned
  /// no routes, or Map Matching returned code != Ok).
  noRoute,

  /// Local networking failure: no connectivity, timeout, DNS, etc.
  network,

  /// Server-side error (5xx, invalid token, malformed response…).
  server,

  /// Call skipped locally because the same input is still in cooldown after
  /// a recent rate-limit response (see [RoutingService._cooldownUntil]).
  cooldown,
}

/// Details of a failed routing call. [retryAfter] is only meaningful for
/// [RoutingFailureReason.rateLimited] and [RoutingFailureReason.cooldown];
/// it tells the caller how long to wait before trying again.
class RoutingFailure {
  const RoutingFailure({required this.reason, this.retryAfter});
  final RoutingFailureReason reason;
  final Duration? retryAfter;

  bool get isTransient =>
      reason == RoutingFailureReason.rateLimited ||
      reason == RoutingFailureReason.cooldown ||
      reason == RoutingFailureReason.network ||
      reason == RoutingFailureReason.server;
}

/// Road-snapped geometry plus the Mapbox-estimated travel time for it, or
/// a failure explaining why no path was produced. Callers can check
/// [isSuccess]/[isRateLimited] instead of doing a nullable dance.
class SnapResult {
  const SnapResult._({this.path, this.duration, this.failure});
  const SnapResult.success({required List<GeoPoint> path, Duration? duration})
      : this._(path: path, duration: duration);
  const SnapResult.failed(RoutingFailure failure) : this._(failure: failure);

  final List<GeoPoint>? path;
  final Duration? duration;
  final RoutingFailure? failure;

  bool get isSuccess => path != null && path!.isNotEmpty;
  bool get isRateLimited =>
      failure?.reason == RoutingFailureReason.rateLimited ||
      failure?.reason == RoutingFailureReason.cooldown;
}

/// Outcome of a Map Matching duration lookup.
class MatchResult {
  const MatchResult._({this.duration, this.failure});
  const MatchResult.success(Duration duration) : this._(duration: duration);
  const MatchResult.failed(RoutingFailure failure) : this._(failure: failure);

  final Duration? duration;
  final RoutingFailure? failure;

  bool get isSuccess => duration != null;
  bool get isRateLimited =>
      failure?.reason == RoutingFailureReason.rateLimited ||
      failure?.reason == RoutingFailureReason.cooldown;
}

/// Calls the Mapbox Directions API to convert a list of user-tapped
/// waypoints into a road-following path.
///
/// Uses the **public** Mapbox access token (same one used for the map tiles)
/// with the `mapbox/driving` profile by default.
///
/// The Directions API supports up to 25 waypoints per request. If the user
/// tapped more points, [snapToRoads] samples them evenly down to 25 and the
/// returned geometry is the full road-following polyline between those
/// sampled waypoints.
class RoutingService {
  RoutingService({
    required String mapboxToken,
    String baseUrl = 'https://api.mapbox.com',
    http.Client? client,
    DateTime Function()? now,
  })  : _token = mapboxToken,
        _base = baseUrl,
        _client = client,
        _now = now ?? DateTime.now;

  final String _token;
  final String _base;
  final http.Client? _client;
  final DateTime Function() _now;

  static const _maxWaypoints = 25;

  /// Half-angle (degrees) used for each waypoint's [bearings] filter. The two
  /// carriageways of a divided road run ~180° apart, so a 45° window keeps the
  /// snap on the carriage going the user's way while tolerating tap jitter.
  static const _bearingToleranceDeg = 45;

  /// Below this spacing (m) the direction between two consecutive taps is just
  /// jitter, so no bearing is constrained for that waypoint.
  static const _minBearingSpacingMeters = 10.0;

  /// Default wait when a 429 response has no [Retry-After] header. Roughly
  /// matches [mapbox_quota] window (60s) so we don't hammer the endpoint.
  static const _defaultRetryAfter = Duration(seconds: 60);

  /// Per-input cooldown: after a 429 for coordinates+profile, we short-circuit
  /// further calls with the same key until this timestamp. Ephemeral (process
  /// lifetime) — persistence is not worth the complexity.
  final Map<String, DateTime> _cooldownUntil = {};

  /// Test-only. Wipes the in-memory cooldown map.
  @visibleForTesting
  void clearCooldowns() => _cooldownUntil.clear();

  /// Test-only. Snapshot of cooldown state.
  @visibleForTesting
  Map<String, DateTime> get cooldownsForTesting =>
      Map.unmodifiable(_cooldownUntil);

  /// Returns the road-following geometry for [waypoints]. On failure the
  /// result carries a [RoutingFailure] instead of a path; callers can inspect
  /// [SnapResult.failure] to distinguish transient (rate limit, network)
  /// from permanent (no route) failures.
  ///
  /// [profile] defaults to `'driving'` but can be `'cycling'` or `'walking'`.
  ///
  /// When [maxRateLimitRetries] > 0, the call is retried with exponential
  /// backoff (+ jitter) on 429 responses, up to that many extra attempts.
  Future<SnapResult> snapToRoads(
    List<GeoPoint> waypoints, {
    String profile = 'driving',
    int maxRateLimitRetries = 0,
  }) async {
    if (waypoints.length < 2) {
      return const SnapResult.failed(
        RoutingFailure(reason: RoutingFailureReason.noRoute),
      );
    }

    final sampled = _sample(waypoints, _maxWaypoints);
    final coords =
        sampled.map((p) => '${p.longitude},${p.latitude}').join(';');
    final key = _cacheKey('snap', profile, coords);

    // Skip if we're still in cooldown from a prior 429 for this input.
    final cooldownFailure = _checkCooldown(key);
    if (cooldownFailure != null) return SnapResult.failed(cooldownFailure);

    final bearings = _bearingsParam(sampled);
    final uri = Uri.parse(
      '$_base/directions/v5/mapbox/$profile/$coords'
      '?geometries=geojson&overview=full'
      '${bearings != null ? '&bearings=$bearings' : ''}'
      '&access_token=$_token',
    );

    return _withRetry<SnapResult>(
      maxRetries: maxRateLimitRetries,
      call: () async {
        final res = await _get(uri);
        if (res == null) {
          return const SnapResult.failed(
            RoutingFailure(reason: RoutingFailureReason.network),
          );
        }
        if (res.statusCode == 429) {
          final retryAfter = _parseRetryAfter(res);
          _cooldownUntil[key] = _now().add(retryAfter);
          return SnapResult.failed(RoutingFailure(
            reason: RoutingFailureReason.rateLimited,
            retryAfter: retryAfter,
          ));
        }
        if (res.statusCode >= 500 || res.statusCode == 401 ||
            res.statusCode == 403) {
          return const SnapResult.failed(
            RoutingFailure(reason: RoutingFailureReason.server),
          );
        }
        if (res.statusCode != 200) {
          return const SnapResult.failed(
            RoutingFailure(reason: RoutingFailureReason.noRoute),
          );
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = parseDirections(data);
        if (parsed == null) {
          return const SnapResult.failed(
            RoutingFailure(reason: RoutingFailureReason.noRoute),
          );
        }
        // Successful response clears any lingering cooldown for this key.
        _cooldownUntil.remove(key);
        return SnapResult.success(path: parsed.path!, duration: parsed.duration);
      },
      isRateLimited: (r) => r.isRateLimited,
    );
  }

  /// Parses a Mapbox Directions response into a [SnapResult]. Returns null
  /// when no route is present.
  static SnapResult? parseDirections(Map<String, dynamic> data) {
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final geometry = routes[0]['geometry']['coordinates'] as List;
    final path = geometry
        .map((c) => GeoPoint(
              latitude: (c[1] as num).toDouble(),
              longitude: (c[0] as num).toDouble(),
            ))
        .toList();
    final durSec = (routes[0]['duration'] as num?)?.toDouble();
    return SnapResult.success(
      path: path,
      duration: durSec == null
          ? null
          : Duration(milliseconds: (durSec * 1000).round()),
    );
  }

  /// Parses a Mapbox Map Matching response into a total [Duration], summing
  /// every matching's duration. Returns null on a non-Ok code or empty match.
  static Duration? parseMatching(Map<String, dynamic> data) {
    if (data['code'] != 'Ok') return null;
    final matchings = data['matchings'] as List?;
    if (matchings == null || matchings.isEmpty) return null;
    var totalSec = 0.0;
    for (final m in matchings) {
      final d = ((m as Map)['duration'] as num?)?.toDouble();
      if (d != null) totalSec += d;
    }
    if (totalSec <= 0) return null;
    return Duration(milliseconds: (totalSec * 1000).round());
  }

  /// Calls the Map Matching API to estimate the travel time along [path].
  /// [path] is capped to 100 coordinates (the Map Matching limit) via [_sample].
  ///
  /// When [maxRateLimitRetries] > 0, the call is retried on 429 with
  /// exponential backoff. Use this for one-shot lookups whose result is
  /// worth persisting (free-ride save, history lazy compute, route metadata).
  Future<MatchResult> matchDuration(
    List<GeoPoint> path, {
    String profile = 'driving',
    int maxRateLimitRetries = 0,
  }) async {
    if (path.length < 2) {
      return const MatchResult.failed(
        RoutingFailure(reason: RoutingFailureReason.noRoute),
      );
    }
    final sampled = _sample(path, 100);
    final coords =
        sampled.map((p) => '${p.longitude},${p.latitude}').join(';');
    final key = _cacheKey('match', profile, coords);

    final cooldownFailure = _checkCooldown(key);
    if (cooldownFailure != null) return MatchResult.failed(cooldownFailure);

    final uri = Uri.parse(
      '$_base/matching/v5/mapbox/$profile/$coords'
      '?geometries=geojson&overview=full&access_token=$_token',
    );

    return _withRetry<MatchResult>(
      maxRetries: maxRateLimitRetries,
      call: () async {
        final res = await _get(uri);
        if (res == null) {
          return const MatchResult.failed(
            RoutingFailure(reason: RoutingFailureReason.network),
          );
        }
        if (res.statusCode == 429) {
          final retryAfter = _parseRetryAfter(res);
          _cooldownUntil[key] = _now().add(retryAfter);
          return MatchResult.failed(RoutingFailure(
            reason: RoutingFailureReason.rateLimited,
            retryAfter: retryAfter,
          ));
        }
        if (res.statusCode >= 500 || res.statusCode == 401 ||
            res.statusCode == 403) {
          return const MatchResult.failed(
            RoutingFailure(reason: RoutingFailureReason.server),
          );
        }
        if (res.statusCode != 200) {
          return const MatchResult.failed(
            RoutingFailure(reason: RoutingFailureReason.noRoute),
          );
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = parseMatching(data);
        if (parsed == null) {
          return const MatchResult.failed(
            RoutingFailure(reason: RoutingFailureReason.noRoute),
          );
        }
        _cooldownUntil.remove(key);
        return MatchResult.success(parsed);
      },
      isRateLimited: (r) => r.isRateLimited,
    );
  }

  /// Performs the HTTP GET with logging + timeout, returning null on any
  /// transport-level failure (offline, DNS, timeout, malformed response).
  Future<http.Response?> _get(Uri uri) async {
    try {
      final client = _client ?? http.Client();
      final response = await logHttp(
        'mapbox',
        uri,
        () => client.get(uri).timeout(const Duration(seconds: 10)),
      );
      if (_client == null) client.close();
      return response;
    } catch (e, st) {
      debugPrint('RoutingService error: $e');
      AppLogger.maybeInstance?.warning(
        'mapbox',
        'RoutingService HTTP call failed',
        error: e,
        stackTrace: st,
        context: {'url': uri.toString()},
      );
      return null;
    }
  }

  /// Runs [call] up to `maxRetries + 1` times, waiting between attempts when
  /// the outcome is a rate-limit. Backoff is `min(retryAfter, exp * jitter)`
  /// with a 10 s cap so a stale retry-after header can't hang the caller.
  Future<T> _withRetry<T>({
    required int maxRetries,
    required Future<T> Function() call,
    required bool Function(T) isRateLimited,
  }) async {
    var attempt = 0;
    while (true) {
      final result = await call();
      if (attempt >= maxRetries || !isRateLimited(result)) return result;
      final failure = result is SnapResult
          ? result.failure
          : result is MatchResult
              ? result.failure
              : null;
      final serverHint = failure?.retryAfter;
      final backoff = _backoffFor(attempt, serverHint);
      await Future<void>.delayed(backoff);
      attempt++;
    }
  }

  /// Exponential backoff (1s, 2s, 4s…) with ±20 % jitter, capped at 10 s and
  /// clamped to the server-provided [Retry-After] hint when it is shorter.
  Duration _backoffFor(int attempt, Duration? serverHint) {
    final base = Duration(seconds: math.min(10, 1 << attempt));
    final jitterMs = (base.inMilliseconds * 0.2 * math.Random().nextDouble())
        .round();
    final withJitter = base + Duration(milliseconds: jitterMs);
    if (serverHint == null) return withJitter;
    // Respect the server if it wants a longer wait, but never less than 500 ms.
    final serverMs = math.max(500, serverHint.inMilliseconds);
    return Duration(milliseconds: math.max(serverMs, withJitter.inMilliseconds));
  }

  RoutingFailure? _checkCooldown(String key) {
    final until = _cooldownUntil[key];
    if (until == null) return null;
    final remaining = until.difference(_now());
    if (remaining <= Duration.zero) {
      _cooldownUntil.remove(key);
      return null;
    }
    return RoutingFailure(
      reason: RoutingFailureReason.cooldown,
      retryAfter: remaining,
    );
  }

  /// Parses a `Retry-After` header value. Supports both the seconds form
  /// and the HTTP-date form. Falls back to [_defaultRetryAfter] on parse
  /// failure or a missing header.
  Duration _parseRetryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null || raw.isEmpty) return _defaultRetryAfter;
    final asInt = int.tryParse(raw.trim());
    if (asInt != null && asInt >= 0) {
      // RFC 7231 allows "0" to mean "may retry immediately". Cap at 1 h so a
      // malicious/misconfigured server can't stall the caller indefinitely.
      return Duration(seconds: math.min(asInt, 3600));
    }
    try {
      final when = HttpDate.parse(raw);
      final delta = when.difference(_now());
      if (delta > Duration.zero) {
        return delta > const Duration(hours: 1)
            ? const Duration(hours: 1)
            : delta;
      }
    } catch (_) {
      // fall through
    }
    return _defaultRetryAfter;
  }

  String _cacheKey(String op, String profile, String coords) =>
      '$op|$profile|$coords';

  /// Builds the Directions API `bearings` value: one `{angle},{tolerance}`
  /// pair per waypoint, empty where the local direction is unreliable. Returns
  /// `null` when no waypoint has a usable bearing (so the param is omitted).
  static String? _bearingsParam(List<GeoPoint> points) {
    final entries = <String>[];
    var anyConstrained = false;
    for (var i = 0; i < points.length; i++) {
      // Outgoing direction, or the incoming one for the last point.
      final from = i < points.length - 1 ? points[i] : points[i - 1];
      final to = i < points.length - 1 ? points[i + 1] : points[i];
      if (from.distanceTo(to) < _minBearingSpacingMeters) {
        entries.add('');
        continue;
      }
      anyConstrained = true;
      entries.add('${from.bearingTo(to).round()},$_bearingToleranceDeg');
    }
    return anyConstrained ? entries.join(';') : null;
  }

  /// Sample [points] evenly to at most [max] entries, always keeping the
  /// first and last point.
  static List<GeoPoint> _sample(List<GeoPoint> points, int max) {
    if (points.length <= max) return points;
    final result = <GeoPoint>[];
    final step = (points.length - 1) / (max - 1);
    for (var i = 0; i < max; i++) {
      result.add(points[(i * step).round()]);
    }
    return result;
  }
}

/// Minimal HTTP-date parser used by [RoutingService._parseRetryAfter] so we
/// don't drag in `dart:io` (which is unavailable on web). Accepts the three
/// standard formats defined in RFC 7231; throws on anything else.
class HttpDate {
  static DateTime parse(String value) {
    // Try RFC 1123: "Sun, 06 Nov 1994 08:49:37 GMT"
    try {
      return _parseRfc1123(value);
    } catch (_) {
      // Fallback: ISO 8601 (some servers do return this).
      return DateTime.parse(value).toUtc();
    }
  }

  static DateTime _parseRfc1123(String value) {
    final v = value.trim();
    // "Sun, 06 Nov 1994 08:49:37 GMT"
    final re = RegExp(
      r'^[A-Za-z]{3},\s+(\d{2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    );
    final m = re.firstMatch(v);
    if (m == null) throw FormatException('not RFC 1123', value);
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final month = months[m.group(2)];
    if (month == null) throw FormatException('bad month', value);
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}
