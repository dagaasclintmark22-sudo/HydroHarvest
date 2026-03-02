import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class CollectedWaterAnalytics {
  const CollectedWaterAnalytics({
    required this.date,
    required this.totalCollectedLiters,
    required this.safeCollectedLiters,
    required this.unsafeCollectedLiters,
    required this.sampleCount,
    required this.collectionEventCount,
    required this.peakCollectionHourLabel,
    required this.peakCollectionLiters,
  });

  final DateTime date;
  final double totalCollectedLiters;
  final double safeCollectedLiters;
  final double unsafeCollectedLiters;
  final int sampleCount;
  final int collectionEventCount;
  final String peakCollectionHourLabel;
  final double peakCollectionLiters;

  double get safeYieldPercent {
    if (totalCollectedLiters <= 0) return 0;
    return (safeCollectedLiters / totalCollectedLiters) * 100;
  }
}

class DailyCollectedWaterPoint {
  const DailyCollectedWaterPoint({
    required this.date,
    required this.totalCollectedLiters,
  });

  final DateTime date;
  final double totalCollectedLiters;
}

class CollectedWaterRangeAnalytics {
  const CollectedWaterRangeAnalytics({
    required this.startDate,
    required this.endDate,
    required this.totalCollectedLiters,
    required this.safeCollectedLiters,
    required this.unsafeCollectedLiters,
    required this.sampleCount,
    required this.collectionEventCount,
    required this.peakDayLabel,
    required this.peakDayLiters,
    required this.points,
  });

  final DateTime startDate;
  final DateTime endDate;
  final double totalCollectedLiters;
  final double safeCollectedLiters;
  final double unsafeCollectedLiters;
  final int sampleCount;
  final int collectionEventCount;
  final String peakDayLabel;
  final double peakDayLiters;
  final List<DailyCollectedWaterPoint> points;

  double get safeYieldPercent {
    if (totalCollectedLiters <= 0) return 0;
    return (safeCollectedLiters / totalCollectedLiters) * 100;
  }
}

class CollectedWaterAnalyticsService {
  CollectedWaterAnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? FirebaseDatabase.instance;

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  static const double _tankCapacityLiters = 20;
  static const double _minSafePh = 6.5;
  static const double _maxSafePh = 8.5;
  static const double _maxSafeTurbidity = 0.5;

  // --- In-memory cache (survives tab switches) ---
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  Future<T> _cached<T>(String key, Future<T> Function() fetch) async {
    final existing = _cache[key];
    if (existing != null && !existing.isExpired(_cacheTTL)) {
      return existing.value as T;
    }
    final result = await fetch();
    _cache[key] = _CacheEntry(value: result, createdAt: DateTime.now());
    return result;
  }

  /// Clear the in-memory cache (e.g. on pull-to-refresh).
  static void clearCache() => _cache.clear();

  Future<CollectedWaterAnalytics> getDailyAnalytics({
    required DateTime date,
    String deviceId = 'hydroharvest-main',
  }) {
    final key = 'daily_${date.year}_${date.month}_${date.day}_$deviceId';
    return _cached(key, () => _fetchDailyAnalytics(date: date, deviceId: deviceId));
  }

  Future<CollectedWaterAnalytics> _fetchDailyAnalytics({
    required DateTime date,
    String deviceId = 'hydroharvest-main',
  }) async {
    final localDay = DateTime(date.year, date.month, date.day);
    final startUtc = DateTime.utc(date.year, date.month, date.day);
    final endUtc = startUtc.add(const Duration(days: 1));
    final startMs = startUtc.millisecondsSinceEpoch;
    final endMs = endUtc.millisecondsSinceEpoch;

    try {
      final dailySnap = await _firestore
          .collection('analytics_collected_water_daily')
          .where('deviceId', isEqualTo: deviceId)
          .where('dayStartMs', isGreaterThanOrEqualTo: startMs)
          .where('dayStartMs', isLessThan: endMs)
          .limit(1)
          .get();

      double totalCollectedLiters = 0;
      double safeCollectedLiters = 0;
      double unsafeCollectedLiters = 0;
      int sampleCount = 0;
      int collectionEventCount = 0;

      if (dailySnap.docs.isNotEmpty) {
        final data = dailySnap.docs.first.data();
        totalCollectedLiters = _toDouble(data['totalCollectedLiters']);
        safeCollectedLiters = _toDouble(data['safeCollectedLiters']);
        unsafeCollectedLiters = _toDouble(data['unsafeCollectedLiters']);
        sampleCount = _toInt(data['sampleCount']);
        collectionEventCount = _toInt(data['collectionEventCount']);
      }

      final hourlySnap = await _firestore
          .collection('analytics_collected_water_hourly')
          .where('deviceId', isEqualTo: deviceId)
          .where('hourStartMs', isGreaterThanOrEqualTo: startMs)
          .where('hourStartMs', isLessThan: endMs)
          .orderBy('hourStartMs')
          .get();

      // If no Firestore aggregate docs exist yet (Spark/no Functions), fallback to RTDB.
      if (dailySnap.docs.isEmpty && hourlySnap.docs.isEmpty) {
        return _dailyFromRtdb(
          date: localDay,
          startMs: startMs,
          endMs: endMs,
          deviceId: deviceId,
        );
      }

      double peakCollectionLiters = 0;
      String peakCollectionHourLabel = '--';

      for (final doc in hourlySnap.docs) {
        final data = doc.data();
        final hourCollected = _toDouble(data['totalCollectedLiters']);
        if (hourCollected > peakCollectionLiters) {
          peakCollectionLiters = hourCollected;
          final hourMs = _toInt(data['hourStartMs']);
          final dt = DateTime.fromMillisecondsSinceEpoch(hourMs, isUtc: true);
          final hour = dt.hour.toString().padLeft(2, '0');
          peakCollectionHourLabel = '$hour:00';
        }
      }

      return CollectedWaterAnalytics(
        date: localDay,
        totalCollectedLiters: totalCollectedLiters,
        safeCollectedLiters: safeCollectedLiters,
        unsafeCollectedLiters: unsafeCollectedLiters,
        sampleCount: sampleCount,
        collectionEventCount: collectionEventCount,
        peakCollectionHourLabel: peakCollectionHourLabel,
        peakCollectionLiters: peakCollectionLiters,
      );
    } on FirebaseException catch (e) {
      if (_isPermissionDenied(e)) {
        debugPrint('CollectedWaterAnalyticsService: Firestore denied (daily), using RTDB');
        return _dailyFromRtdb(
          date: localDay,
          startMs: startMs,
          endMs: endMs,
          deviceId: deviceId,
        );
      }
      rethrow;
    }
  }

  Future<List<DailyCollectedWaterPoint>> getLastSevenDaysTrend({
    required DateTime endDate,
    String deviceId = 'hydroharvest-main',
  }) {
    final key = 'trend7_${endDate.year}_${endDate.month}_${endDate.day}_$deviceId';
    return _cached(key, () => _fetchLastSevenDaysTrend(endDate: endDate, deviceId: deviceId));
  }

  Future<List<DailyCollectedWaterPoint>> _fetchLastSevenDaysTrend({
    required DateTime endDate,
    String deviceId = 'hydroharvest-main',
  }) async {
    final endUtcDay = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final startUtcDay = endUtcDay.subtract(const Duration(days: 6));
    final endExclusive = endUtcDay.add(const Duration(days: 1));

    try {
      final snap = await _firestore
          .collection('analytics_collected_water_daily')
          .where('deviceId', isEqualTo: deviceId)
          .where('dayStartMs', isGreaterThanOrEqualTo: startUtcDay.millisecondsSinceEpoch)
          .where('dayStartMs', isLessThan: endExclusive.millisecondsSinceEpoch)
          .orderBy('dayStartMs')
          .get();

      if (snap.docs.isEmpty) {
        final range = await _rangeFromRtdb(
          startDate: DateTime(
            startUtcDay.year,
            startUtcDay.month,
            startUtcDay.day,
          ),
          endDate: DateTime(
            endUtcDay.year,
            endUtcDay.month,
            endUtcDay.day,
          ),
          deviceId: deviceId,
        );
        return range.points;
      }

      final byDayStartMs = <int, double>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final dayStartMs = _toInt(data['dayStartMs']);
        byDayStartMs[dayStartMs] = _toDouble(data['totalCollectedLiters']);
      }

      final points = <DailyCollectedWaterPoint>[];
      for (int i = 0; i < 7; i++) {
        final day = startUtcDay.add(Duration(days: i));
        final dayMs = day.millisecondsSinceEpoch;
        points.add(
          DailyCollectedWaterPoint(
            date: DateTime(day.year, day.month, day.day),
            totalCollectedLiters: byDayStartMs[dayMs] ?? 0,
          ),
        );
      }

      return points;
    } on FirebaseException catch (e) {
      if (_isPermissionDenied(e)) {
        debugPrint('CollectedWaterAnalyticsService: Firestore denied (trend), using RTDB');
        final range = await _rangeFromRtdb(
          startDate: DateTime(
            startUtcDay.year,
            startUtcDay.month,
            startUtcDay.day,
          ),
          endDate: DateTime(
            endUtcDay.year,
            endUtcDay.month,
            endUtcDay.day,
          ),
          deviceId: deviceId,
        );
        return range.points;
      }
      rethrow;
    }
  }

  Future<CollectedWaterRangeAnalytics> getRangeAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    String deviceId = 'hydroharvest-main',
  }) {
    final key = 'range_${startDate.year}_${startDate.month}_${startDate.day}'
        '_${endDate.year}_${endDate.month}_${endDate.day}_$deviceId';
    return _cached(key, () => _fetchRangeAnalytics(startDate: startDate, endDate: endDate, deviceId: deviceId));
  }

  Future<CollectedWaterRangeAnalytics> _fetchRangeAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    String deviceId = 'hydroharvest-main',
  }) async {
    final safeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final safeEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final normalizedStart = safeStart.isBefore(safeEnd) ? safeStart : safeEnd;
    final normalizedEnd = safeStart.isBefore(safeEnd) ? safeEnd : safeStart;

    try {
      final startUtc = DateTime.utc(
        normalizedStart.year,
        normalizedStart.month,
        normalizedStart.day,
      );
      final endUtc = DateTime.utc(
        normalizedEnd.year,
        normalizedEnd.month,
        normalizedEnd.day,
      );
      final endExclusive = endUtc.add(const Duration(days: 1));

      final snap = await _firestore
          .collection('analytics_collected_water_daily')
          .where('deviceId', isEqualTo: deviceId)
          .where('dayStartMs', isGreaterThanOrEqualTo: startUtc.millisecondsSinceEpoch)
          .where('dayStartMs', isLessThan: endExclusive.millisecondsSinceEpoch)
          .orderBy('dayStartMs')
          .get();

      if (snap.docs.isEmpty) {
        return _rangeFromRtdb(
          startDate: normalizedStart,
          endDate: normalizedEnd,
          deviceId: deviceId,
        );
      }

      final byDayStartMs = <int, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final dayStartMs = _toInt(data['dayStartMs']);
        byDayStartMs[dayStartMs] = data;
      }

      final points = <DailyCollectedWaterPoint>[];
      double totalCollectedLiters = 0;
      double safeCollectedLiters = 0;
      double unsafeCollectedLiters = 0;
      int sampleCount = 0;
      int collectionEventCount = 0;
      double peakDayLiters = 0;
      String peakDayLabel = '--';

      final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
      for (int i = 0; i < dayCount; i++) {
        final localDay = normalizedStart.add(Duration(days: i));
        final utcDay = DateTime.utc(localDay.year, localDay.month, localDay.day);
        final dayMs = utcDay.millisecondsSinceEpoch;
        final data = byDayStartMs[dayMs];

        final dayCollected = _toDouble(data?['totalCollectedLiters']);
        final daySafe = _toDouble(data?['safeCollectedLiters']);
        final dayUnsafe = _toDouble(data?['unsafeCollectedLiters']);
        final daySampleCount = _toInt(data?['sampleCount']);
        final dayEventCount = _toInt(data?['collectionEventCount']);

        totalCollectedLiters += dayCollected;
        safeCollectedLiters += daySafe;
        unsafeCollectedLiters += dayUnsafe;
        sampleCount += daySampleCount;
        collectionEventCount += dayEventCount;

        if (dayCollected > peakDayLiters) {
          peakDayLiters = dayCollected;
          final m = localDay.month.toString().padLeft(2, '0');
          final d = localDay.day.toString().padLeft(2, '0');
          peakDayLabel = '$m/$d';
        }

        points.add(
          DailyCollectedWaterPoint(
            date: localDay,
            totalCollectedLiters: dayCollected,
          ),
        );
      }

      return CollectedWaterRangeAnalytics(
        startDate: normalizedStart,
        endDate: normalizedEnd,
        totalCollectedLiters: totalCollectedLiters,
        safeCollectedLiters: safeCollectedLiters,
        unsafeCollectedLiters: unsafeCollectedLiters,
        sampleCount: sampleCount,
        collectionEventCount: collectionEventCount,
        peakDayLabel: peakDayLabel,
        peakDayLiters: peakDayLiters,
        points: points,
      );
    } on FirebaseException catch (e) {
      if (_isPermissionDenied(e)) {
        debugPrint('CollectedWaterAnalyticsService: Firestore denied (range), using RTDB');
        return _rangeFromRtdb(
          startDate: normalizedStart,
          endDate: normalizedEnd,
          deviceId: deviceId,
        );
      }
      rethrow;
    }
  }

  Future<CollectedWaterAnalytics> _dailyFromRtdb({
    required DateTime date,
    required int startMs,
    required int endMs,
    required String deviceId,
  }) async {
    final samples = await _loadRtdbSamples(
      startMs: startMs,
      endMs: endMs,
      deviceId: deviceId,
    );

    if (samples.length < 2) return _emptyDaily(date);

    double totalCollected = 0;
    double safeCollected = 0;
    double unsafeCollected = 0;
    int eventCount = 0;
    final hourlyBuckets = <int, double>{};

    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i - 1];
      final curr = samples[i];
      final deltaPercent = curr.waterLevel - prev.waterLevel;
      if (curr.collecting && deltaPercent > 0) {
        final liters = (deltaPercent / 100) * _tankCapacityLiters;
        totalCollected += liters;
        eventCount += 1;

        if (_isSafe(curr.ph, curr.turbidity)) {
          safeCollected += liters;
        } else {
          unsafeCollected += liters;
        }

        final hour = DateTime.fromMillisecondsSinceEpoch(curr.timestampMs, isUtc: true).hour;
        hourlyBuckets[hour] = (hourlyBuckets[hour] ?? 0) + liters;
      }
    }

    double peakLiters = 0;
    int peakHour = -1;
    hourlyBuckets.forEach((hour, liters) {
      if (liters > peakLiters) {
        peakLiters = liters;
        peakHour = hour;
      }
    });

    final peakLabel = peakHour >= 0 ? '${peakHour.toString().padLeft(2, '0')}:00' : '--';

    return CollectedWaterAnalytics(
      date: date,
      totalCollectedLiters: totalCollected,
      safeCollectedLiters: safeCollected,
      unsafeCollectedLiters: unsafeCollected,
      sampleCount: samples.length,
      collectionEventCount: eventCount,
      peakCollectionHourLabel: peakLabel,
      peakCollectionLiters: peakLiters,
    );
  }

  Future<CollectedWaterRangeAnalytics> _rangeFromRtdb({
    required DateTime startDate,
    required DateTime endDate,
    required String deviceId,
  }) async {
    final normalizedStart =
        startDate.isBefore(endDate) ? DateTime(startDate.year, startDate.month, startDate.day) : DateTime(endDate.year, endDate.month, endDate.day);
    final normalizedEnd =
        startDate.isBefore(endDate) ? DateTime(endDate.year, endDate.month, endDate.day) : DateTime(startDate.year, startDate.month, startDate.day);

    final startUtc = DateTime.utc(normalizedStart.year, normalizedStart.month, normalizedStart.day);
    final endUtc = DateTime.utc(normalizedEnd.year, normalizedEnd.month, normalizedEnd.day).add(const Duration(days: 1));

    final samples = await _loadRtdbSamples(
      startMs: startUtc.millisecondsSinceEpoch,
      endMs: endUtc.millisecondsSinceEpoch,
      deviceId: deviceId,
    );

    final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
    final dailyCollected = <String, double>{};
    final dailySafe = <String, double>{};
    final dailyUnsafe = <String, double>{};
    final dailySamples = <String, int>{};
    final dailyEvents = <String, int>{};

    for (final sample in samples) {
      final local = DateTime.fromMillisecondsSinceEpoch(sample.timestampMs, isUtc: true).toLocal();
      final key = _dayKey(local);
      dailySamples[key] = (dailySamples[key] ?? 0) + 1;
    }

    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i - 1];
      final curr = samples[i];
      final deltaPercent = curr.waterLevel - prev.waterLevel;
      if (!curr.collecting || deltaPercent <= 0) continue;

      final liters = (deltaPercent / 100) * _tankCapacityLiters;
      final local = DateTime.fromMillisecondsSinceEpoch(curr.timestampMs, isUtc: true).toLocal();
      final key = _dayKey(local);

      dailyCollected[key] = (dailyCollected[key] ?? 0) + liters;
      dailyEvents[key] = (dailyEvents[key] ?? 0) + 1;
      if (_isSafe(curr.ph, curr.turbidity)) {
        dailySafe[key] = (dailySafe[key] ?? 0) + liters;
      } else {
        dailyUnsafe[key] = (dailyUnsafe[key] ?? 0) + liters;
      }
    }

    final points = <DailyCollectedWaterPoint>[];
    double totalCollected = 0;
    double totalSafe = 0;
    double totalUnsafe = 0;
    int totalSampleCount = 0;
    int totalEventCount = 0;
    double peakDayLiters = 0;
    String peakDayLabel = '--';

    for (int i = 0; i < dayCount; i++) {
      final day = normalizedStart.add(Duration(days: i));
      final key = _dayKey(day);
      final collected = dailyCollected[key] ?? 0;
      final safe = dailySafe[key] ?? 0;
      final unsafe = dailyUnsafe[key] ?? 0;
      final sampleCount = dailySamples[key] ?? 0;
      final eventCount = dailyEvents[key] ?? 0;

      totalCollected += collected;
      totalSafe += safe;
      totalUnsafe += unsafe;
      totalSampleCount += sampleCount;
      totalEventCount += eventCount;

      if (collected > peakDayLiters) {
        peakDayLiters = collected;
        peakDayLabel = '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}';
      }

      points.add(
        DailyCollectedWaterPoint(
          date: day,
          totalCollectedLiters: collected,
        ),
      );
    }

    return CollectedWaterRangeAnalytics(
      startDate: normalizedStart,
      endDate: normalizedEnd,
      totalCollectedLiters: totalCollected,
      safeCollectedLiters: totalSafe,
      unsafeCollectedLiters: totalUnsafe,
      sampleCount: totalSampleCount,
      collectionEventCount: totalEventCount,
      peakDayLabel: peakDayLabel,
      peakDayLiters: peakDayLiters,
      points: points,
    );
  }

  Future<List<_MinuteSample>> _loadRtdbSamples({
    required int startMs,
    required int endMs,
    required String deviceId,
  }) async {
    final query = _database
        .ref('analytics/minutes/$deviceId')
        .orderByChild('timestamp')
        .startAt(startMs)
        .endAt(endMs - 1);

    final snap = await query.get();
    final value = snap.value;
    if (value is! Map) return [];

    final result = <_MinuteSample>[];
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;

      final map = Map<dynamic, dynamic>.from(raw);
      final timestamp = _toInt(map['timestamp']);
      final waterLevel = _toDouble(map['waterLevel']);
      final ph = _toDouble(map['ph']);
      final turbidity = _toDouble(map['turbidity']);
      final collecting = map['collecting'] == true;

      if (timestamp <= 0) continue;
      result.add(
        _MinuteSample(
          timestampMs: timestamp,
          waterLevel: waterLevel,
          ph: ph,
          turbidity: turbidity,
          collecting: collecting,
        ),
      );
    }

    result.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return result;
  }

  bool _isSafe(double ph, double turbidity) {
    return ph >= _minSafePh && ph <= _maxSafePh && turbidity < _maxSafeTurbidity;
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isPermissionDenied(FirebaseException e) {
    return e.code == 'permission-denied' ||
        e.code == 'permission_denied' ||
        (e.message?.contains('Missing or insufficient permissions') ?? false);
  }

  CollectedWaterAnalytics _emptyDaily(DateTime date) {
    return CollectedWaterAnalytics(
      date: date,
      totalCollectedLiters: 0,
      safeCollectedLiters: 0,
      unsafeCollectedLiters: 0,
      sampleCount: 0,
      collectionEventCount: 0,
      peakCollectionHourLabel: '--',
      peakCollectionLiters: 0,
    );
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class _CacheEntry {
  _CacheEntry({required this.value, required this.createdAt});
  final dynamic value;
  final DateTime createdAt;
  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

class _MinuteSample {
  _MinuteSample({
    required this.timestampMs,
    required this.waterLevel,
    required this.ph,
    required this.turbidity,
    required this.collecting,
  });

  final int timestampMs;
  final double waterLevel;
  final double ph;
  final double turbidity;
  final bool collecting;
}
