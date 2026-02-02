import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class RealtimeSensorService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('sensors/current');
  final DatabaseReference _controlsRef = FirebaseDatabase.instance.ref('controls');
  final DatabaseReference _maintenanceRef = FirebaseDatabase.instance.ref('maintenance');
  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref('settings');

  Stream<double> get phStream => _ref.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final v = data == null ? null : (data['ph'] ?? data['pH']);
        return _toDouble(v) ?? 7.0;
      });

  Stream<double> get turbidityStream => _ref.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final v = data == null ? null : (data['turbidity'] ?? data['turbidityNTU']);
        return _toDouble(v) ?? 0.0;
      });

  Stream<int> get harvestLidStream => _controlsRef.child('harvest_lid').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
        return 0;
      });

  Future<void> setHarvestLid(bool isOpen) async {
    await _controlsRef.child('harvest_lid').set(isOpen ? 90 : 0);
  }

  Stream<Map<String, dynamic>> get settingsStream => _settingsRef.onValue.map((event) {
    final value = event.snapshot.value;
    if (value == null || value is! Map) {
      return {
        'ph': {'min': 6.5, 'max': 8.5},
        'turbidity': {'max': 5.0},
        'notifications': {
          'unsafe_water': true,
          'high_turbidity': true,
          'ph_out_of_range': true,
          'tank_alert': true,
          'system_error': true,
          'method': 'push'
        },
        'calibration': {}
      };
    }
    
    // Safely convert to Map<String, dynamic>
    try {
      return Map<String, dynamic>.from(value);
    } catch (e) {
      debugPrint('Error parsing settings: $e');
      return <String, dynamic>{};
    }
  });

  Stream<int> get waterLevelPercentageStream => _ref.onValue.map((event) {
        final val = event.snapshot.value;
        if (val == null) return 0;
        if (val is! Map) return 0; // Safety check
        final data = val;
        final v = data['waterLevel'] ?? data['water_level'];
        return _toDouble(v)?.toInt() ?? 0;
      });

  Stream<String> get waterLevelStatusStream => _ref.onValue.map((event) {
        final val = event.snapshot.value;
        if (val == null || val is! Map) return "Unknown";
        final data = val;
        
        final v = data['waterLevel'] ?? data['water_level'];
        final percentage = _toDouble(v)?.toInt() ?? 0;
        
        if (percentage >= 90) return "Full";
        if (percentage <= 20) return "Low";
        return "$percentage%";
      });

  Stream<bool> get isWaterSafeStream => _ref.onValue.map((event) {
        final val = event.snapshot.value;
        if (val == null || val is! Map) return false;
        final data = val;
        
        final ph = _toDouble(data['ph'] ?? data['pH']) ?? 7.0;
        final turbidity = _toDouble(data['turbidity'] ?? data['turbidityNTU']) ?? 0.0;
        
        // pH 6.5-8.5 and Turbidity < 0.5 (Clear)
        return (ph >= 6.5 && ph <= 8.5) && (turbidity < 0.5);
      });

  Stream<bool> get uvActiveStream => _ref.onValue.map((event) {
        final val = event.snapshot.value;
        if (val == null || val is! Map) return false;
        final data = val;
        return (data['uv_active'] ?? false) == true;
      });

  Stream<Map<String, int>> get maintenanceStream => _maintenanceRef.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return {};
        return data.map((key, value) => MapEntry(key.toString(), value as int));
      });

  Stream<int> get uvRuntimeStream => _maintenanceRef.child('uv_runtime_seconds').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is int) return val;
        if (val is double) return val.toInt();
        return 0;
      });

  Stream<List<Map<String, dynamic>>> get alertsStream => _ref.onValue.map((event) {
    final sensorData = event.snapshot.value as Map<dynamic, dynamic>?;
    List<Map<String, dynamic>> alerts = [];
    
    if (sensorData != null) {
      final ph = _toDouble(sensorData['ph'] ?? sensorData['pH']) ?? 7.0;
      final turbidity = _toDouble(sensorData['turbidity'] ?? sensorData['turbidityNTU']) ?? 0.0;
      final waterLevel = _toDouble(sensorData['waterLevel'] ?? sensorData['water_level']) ?? 0.0;
      final waterFull = (sensorData['waterFull'] ?? sensorData['water_full']) == true;

      // 1. Unsafe Water Alert
      if (ph < 6.5 || ph > 8.5 || turbidity > 0.5) {
        alerts.add({
          'type': 'Unsafe Water Detected',
          'message': 'Water fails pH or turbidity limits. Do not drink.',
          'severity': 'critical',
          'timestamp': 'Now',
          'status': 'active',
        });
      }

      // 2. High Turbidity Warning
      if (turbidity > 5.0 && turbidity <= 10.0) {
        alerts.add({
          'type': 'High Turbidity Warning',
          'message': 'Water is cloudy but may still be filtered.',
          'severity': 'warning',
          'timestamp': 'Now',
          'status': 'active',
        });
      }

      // 3. Tank Alerts
      if (waterFull) {
        alerts.add({
          'type': 'Tank Full',
          'message': 'Water tank is full.',
          'severity': 'info',
          'timestamp': 'Now',
          'status': 'active',
        });
      } else if (waterLevel < 0.1) {
         alerts.add({
          'type': 'Tank Empty',
          'message': 'Water tank is nearly empty.',
          'severity': 'info',
          'timestamp': 'Now',
          'status': 'active',
        });
      }
    }

    // 4. Sensor Disconnected (Simulated if data is null or old)
    if (sensorData == null) {
      alerts.add({
        'type': 'Sensor Disconnected',
        'message': 'Lost connection to sensors.',
        'severity': 'critical',
        'timestamp': 'Now',
        'status': 'active',
      });
    }

    return alerts;
  });

  Stream<List<Map<String, String>>> get errorLogsStream => FirebaseDatabase.instance.ref('logs/errors').onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return [];
    
    List<Map<String, String>> logs = [];
    data.forEach((key, value) {
      if (value is Map) {
        logs.add({
          'title': value['title']?.toString() ?? 'Error',
          'message': value['message']?.toString() ?? '',
          'timestamp': value['timestamp']?.toString() ?? '',
        });
      }
    });
    return logs;
  });

  Stream<Map<String, String>> get sensorStatusStream => _ref.onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      return {
        'ph': 'Offline',
        'turbidity': 'Offline',
        'waterLevel': 'Offline',
      };
    }

    // 1. Heartbeat Check
    final lastSeen = data['last_seen'];
    if (lastSeen != null && lastSeen is int) {
      final lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final diff = DateTime.now().difference(lastUpdate);
      if (diff.inSeconds > 60) {
        // If no data for > 60 seconds, assume system is offline
        return {
          'ph': 'Offline (Last seen ${diff.inMinutes}m ago)',
          'turbidity': 'Offline',
          'waterLevel': 'Offline',
        };
      }
    } else {
      // If 'last_seen' is missing, it might be an old firmware or first run
      // We can optionally flag this, or just proceed with range checks.
      // For now, let's treat missing timestamp as "Unknown/Warning"
    }
    
    // Check pH
    String phStatus = 'OK';
    final ph = _toDouble(data['ph'] ?? data['pH']);
    if (ph == null || ph < 0 || ph > 14) phStatus = 'Error (Range)';
    
    // Check Turbidity
    String turbStatus = 'OK';
    final turb = _toDouble(data['turbidity'] ?? data['turbidityNTU']);
    if (turb == null || turb < 0) turbStatus = 'Error (Range)';
    
    // Check Water Level
    String levelStatus = 'OK';
    final level = _toDouble(data['waterLevel'] ?? data['water_level']);
    if (level == null) levelStatus = 'Error (Read)';
    
    return {
      'ph': phStatus,
      'turbidity': turbStatus,
      'waterLevel': levelStatus,
    };
  });

  Future<void> updatePhSettings(double min, double max) async {
    await _settingsRef.child('ph').update({
      'min': min,
      'max': max,
    });
  }

  Future<void> updateTurbiditySettings(double max) async {
    await _settingsRef.child('turbidity').update({
      'max': max,
    });
  }

  Future<void> updateNotificationSettings(String key, dynamic value) async {
    await _settingsRef.child('notifications').update({
      key: value,
    });
  }

  Future<void> updateCalibrationDate(String sensor) async {
    await _settingsRef.child('calibration').update({
      '${sensor}_last_calibrated': ServerValue.timestamp,
    });
  }

  Future<void> updateMaintenanceDate(String key) async {
    await _maintenanceRef.update({
      key: ServerValue.timestamp,
    });
  }

  Future<void> setServoAngle(int angle) async {
    await _controlsRef.update({'servo_angle': angle});
  }

  Future<void> setInitialData({
    double ph = 7.0,
    double turbidity = 0.0,
    double waterLevel = 0.0,
    bool waterFull = false,
  }) async {
    await _ref.set({
      'ph': ph,
      'turbidity': turbidity,
      'waterLevel': waterLevel,
      'waterFull': waterFull,
      'updatedAt': ServerValue.timestamp,
    });
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
