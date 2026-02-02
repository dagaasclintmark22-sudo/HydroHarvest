import 'package:cloud_firestore/cloud_firestore.dart';

class SensorService {

  /// Doc path: `sensors/current`.
  /// Fields expected (recommended):
  ///  - ph: number
  ///  - turbidity: number (NTU)
  ///  - water_level: number (0..1 as fraction OR liters)
  ///  - water_full: bool (optional)
  final DocumentReference<Map<String, dynamic>> _doc =
      FirebaseFirestore.instance.collection('sensors').doc('current').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (map, _) => map,
          );

  Stream<double> get phStream =>
      _doc.snapshots().map((snap) => _numToDouble(snap.data()?['ph']) ?? 7.0);

  Stream<double> get turbidityStream => _doc.snapshots().map((snap) =>
      _numToDouble(snap.data()?['turbidity']) ?? 0.0);

  /// Returns a fraction between 0.0 and 1.0 representing tank fill percentage.
  Stream<double> get waterLevelPercentStream => _doc.snapshots().map((snap) {
        final data = snap.data();
        final raw = _numToDouble(data?['waterLevel'] ?? data?['water_level']);
        if (raw == null) return 0.0;
        // If sensor reports fraction (<= 1) treat as fraction.
        if (raw <= 1.0) return _clamp(raw, 0.0, 1.0);
        // Otherwise treat as liters and normalize against default max (1.5L).
        const double defaultMaxL = 1.5;
        return _clamp(raw / defaultMaxL, 0.0, 1.0);
      });

  Stream<bool> get waterFullStream => _doc.snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return false;
        if (data.containsKey('waterFull')) {
          final val = data['waterFull'];
          if (val is bool) return val;
        }
        if (data.containsKey('water_full')) {
          final val = data['water_full'];
          if (val is bool) return val;
        }
        // fallback to percent threshold
        final percent = _numToDouble(data['waterLevel'] ?? data['water_level']);
        if (percent == null) return false;
        final computed = percent <= 1.0 ? percent : (percent / 1.5);
        return _clamp(computed, 0.0, 1.0) >= 0.95;
      });

    /// Create or overwrite the `sensors/current` document with provided values.
    Future<void> setInitialData({
      double ph = 7.0,
      double turbidity = 0.0,
      double waterLevel = 0.0,
      bool waterFull = false,
    }) async {
      try {
        await _doc.set({
          'ph': ph,
          'turbidity': turbidity,
          'water_level': waterLevel,
          'water_full': waterFull,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        rethrow;
      }
    }

    /// Update only the provided fields on `sensors/current` document.
    Future<void> updateSensorData(Map<String, dynamic> data) async {
      try {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await _doc.update(data);
      } catch (e) {
        rethrow;
      }
    }

  double? _numToDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
}
