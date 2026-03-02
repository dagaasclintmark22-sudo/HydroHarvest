import 'package:firebase_database/firebase_database.dart';

class ManualSensorService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Logs a new TDS reading with the current timestamp
  Future<void> logTdsReading(double fullValue) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // 1. Add to history (Moved to 'maintenance' to match security rules)
    await _db.child('maintenance/manual_logs').push().set({
      'type': 'TDS',
      'value': fullValue,
      'unit': 'ppm',
      'timestamp': timestamp,
    });

    // 2. Update latest cache (Moved to 'maintenance' to match security rules)
    await _db.child('maintenance/latest_tds').set({
      'value': fullValue,
      'timestamp': timestamp,
    });
  }

  /// Get the stream of the latest TDS reading
  Stream<Map<String, dynamic>?> get latestTdsStream {
    return _db.child('maintenance/latest_tds').onValue.map((event) {
        final val = event.snapshot.value;
        if (val == null || val is! Map) return null;
        return Map<String, dynamic>.from(val as Map);
    });
  }
}
