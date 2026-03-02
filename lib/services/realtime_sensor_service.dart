import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class RealtimeSensorService {
  // Singleton Pattern
  static final RealtimeSensorService _instance = RealtimeSensorService._internal();

  factory RealtimeSensorService() {
    return _instance;
  }

  RealtimeSensorService._internal() {
    _initDismissalPersistence();
    _initAlertMonitoring();
  }

  final DatabaseReference _ref = FirebaseDatabase.instance.ref('sensors/current');
  final DatabaseReference _controlsRef = FirebaseDatabase.instance.ref('controls');
  final DatabaseReference _maintenanceRef = FirebaseDatabase.instance.ref('maintenance');
  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref('settings');
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref('logs/alerts');
  late final DatabaseReference _dismissalsRef = _maintenanceRef.child('dismissed_alerts');

  // Alert Monitoring State
  List<String> _previousAlertFingerprints = [];
  bool _isMonitoring = false;

  // Global Dismissal State
  final Map<String, DateTime> _dismissedAlertTimestamps = {};
  final StreamController<Map<String, DateTime>> _dismissalController = StreamController<Map<String, DateTime>>.broadcast();

  // Getters for Dismissals
  Map<String, DateTime> get dismissedAlertsMap => Map.unmodifiable(_dismissedAlertTimestamps);
  Stream<Map<String, DateTime>> get dismissalStream => _dismissalController.stream;

  void _emitDismissals() {
    _dismissalController.add(Map.unmodifiable(_dismissedAlertTimestamps));
  }

  String _alertKey(String type) => Uri.encodeComponent(type);

  void _initDismissalPersistence() {
    _dismissalsRef.onValue.listen((event) {
      final value = event.snapshot.value;
      final parsed = <String, DateTime>{};

      if (value is Map) {
        for (final entry in value.entries) {
          final raw = entry.value;
          if (raw is! Map) continue;

          final rawType = raw['type']?.toString();
          final serverMs = raw['acknowledged_at'];
          final localMs = raw['acknowledged_at_local'];

          int? timestampMs;
          if (serverMs is int) {
            timestampMs = serverMs;
          } else if (serverMs is double) {
            timestampMs = serverMs.toInt();
          } else if (serverMs is String) {
            timestampMs = int.tryParse(serverMs);
          }

          timestampMs ??= localMs is int
              ? localMs
              : (localMs is double ? localMs.toInt() : int.tryParse(localMs?.toString() ?? ''));

          if (rawType != null && timestampMs != null) {
            parsed[rawType] = DateTime.fromMillisecondsSinceEpoch(timestampMs);
          }
        }
      }

      _dismissedAlertTimestamps
        ..clear()
        ..addAll(parsed);
      _emitDismissals();
    }, onError: (error) {
      debugPrint('Failed to load dismissed alerts: $error');
    });
  }

  void dismissAlert(String type) {
    final now = DateTime.now();
    _dismissedAlertTimestamps[type] = now;
    _emitDismissals();

    unawaited(
      _dismissalsRef.child(_alertKey(type)).set({
        'type': type,
        'acknowledged_at': ServerValue.timestamp,
        'acknowledged_at_local': now.millisecondsSinceEpoch,
      }),
    );
  }

  void undoDismissAlert(String type) {
    _dismissedAlertTimestamps.remove(type);
    _emitDismissals();
    unawaited(_dismissalsRef.child(_alertKey(type)).remove());
  }

  void _clearDismissedWhenConditionResolves(Set<String> activeTypes) {
    final toRemove = _dismissedAlertTimestamps.keys
        .where((type) => !activeTypes.contains(type))
        .toList();

    if (toRemove.isEmpty) return;

    for (final type in toRemove) {
      _dismissedAlertTimestamps.remove(type);
      unawaited(_dismissalsRef.child(_alertKey(type)).remove());
    }

    _emitDismissals();
  }

  void _initAlertMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Listen to the alerts stream continuously in the background
    alertsStream.listen((currentAlerts) {
      final List<String> currentFingerprints = [];
      
      for (final alert in currentAlerts) {
        // Create a unique ID for this specific alert instance
        // (e.g., "Unsafe Water Detected-critical")
        // We don't include timestamp so we can detect if it's the SAME alert persisting
        final fingerprint = "${alert['type']}-${alert['severity']}";
        currentFingerprints.add(fingerprint);

        // If this is a NEW alert we haven't seen in the previous frame
        if (!_previousAlertFingerprints.contains(fingerprint)) {
          _logAlertToDatabase(alert);
        }
      }

      // Update state
      _previousAlertFingerprints = currentFingerprints;
    });
  }

  Future<void> _logAlertToDatabase(Map<String, dynamic> alert) async {
    // Only log critical/warning alerts to persistent history to save DB space
    if (alert['severity'] != 'info') {
      try {
        await _logsRef.push().set({
          ...alert,
          'timestamp_epoch': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('Failed to log alert: $e');
      }
    }
  }

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

  Stream<bool> get uvActiveStream => _ref.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return false;
        return data['uv_active'] ?? false;
      });

  Stream<bool> get collectingStream => _ref.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return false;
        return data['collecting'] ?? false;
      });

  Stream<bool> get rainCooldownStream => _ref.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return false;
        return data['rain_cooldown'] ?? false;
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

  Stream<Map<String, dynamic>> get fullSensorDataStream => _ref.onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      return {
        'ph': 7.0, 
        'turbidity': 0.0, 
        'waterLevel': 0.0,
        'waterFull': false
      };
    }
    
    return {
      'ph': _toDouble(data['ph'] ?? data['pH']) ?? 7.0,
      'turbidity': _toDouble(data['turbidity'] ?? data['turbidityNTU']) ?? 0.0,
      'waterLevel': _toDouble(data['waterLevel'] ?? data['water_level']) ?? 0.0,
      'waterFull': (data['waterFull'] ?? data['water_full']) == true,
    };
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

  Stream<Map<String, int>> get maintenanceStream => _maintenanceRef.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return {};
        return data.map((key, value) {
          int parsedValue = 0;
          if (value is int) {
            parsedValue = value;
          } else if (value is double) {
            parsedValue = value.toInt();
          } else if (value is String) {
            parsedValue = int.tryParse(value) ?? 0;
          }
          return MapEntry(key.toString(), parsedValue);
        });
      });


  Future<void> resetUvRuntime() async {
    await _maintenanceRef.update({
      'uv_runtime_seconds': 0,
    });
  }

  Stream<int> get uvRuntimeStream => _maintenanceRef.child('uv_runtime_seconds').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is int) return val;
        if (val is double) return val.toInt();
        return 0;
      });

  Stream<List<Map<String, dynamic>>> get alertsStream => _ref.onValue.asyncMap((event) async {
    final sensorData = event.snapshot.value as Map<dynamic, dynamic>?;
    List<Map<String, dynamic>> alerts = [];

    if (sensorData != null) {
      final ph = _toDouble(sensorData['ph'] ?? sensorData['pH']) ?? 7.0;
      final turbidity = _toDouble(sensorData['turbidity'] ?? sensorData['turbidityNTU']) ?? 0.0;
      final waterLevel = _toDouble(sensorData['waterLevel'] ?? sensorData['water_level']) ?? 0.0;
      final waterFull = (sensorData['waterFull'] ?? sensorData['water_full']) == true;

      // 1. Water Safety Analysis (Pinpointed)
      List<String> violations = [];
      if (ph < 6.5) violations.add("pH is acidic (${ph.toStringAsFixed(1)})");
      if (ph > 8.5) violations.add("pH is alkaline (${ph.toStringAsFixed(1)})");
      if (turbidity > 0.5) violations.add("High Turbidity (${turbidity.toStringAsFixed(1)} NTU)");

      if (violations.isNotEmpty) {
        alerts.add({
          'type': 'Unsafe Water Detected',
          'message': 'Issues: ${violations.join(", ")}. Do not drink.',
          'severity': 'critical',
          'timestamp': 'Now',
          'status': 'active',
        });
      }

      // 2. Tank Alerts
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

    // 3. Sensor Disconnected (Simulated if data is null or old)
    if (sensorData == null) {
      alerts.add({
        'type': 'Sensor Disconnected',
        'message': 'Lost connection to sensors.',
        'severity': 'critical',
        'timestamp': 'Now',
        'status': 'active',
      });
    }

    final activeTypes = alerts
      .map((alert) => alert['type'] as String)
      .toSet();
    _clearDismissedWhenConditionResolves(activeTypes);

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
