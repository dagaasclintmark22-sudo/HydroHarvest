import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hydro_harvest/screens/notification/notification_page.dart';
import 'package:hydro_harvest/screens/dashboard/dashboard_page.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/screens/analytics/analytics_page.dart';
import 'package:hydro_harvest/screens/profile/profile_page.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';

class SystemLogsPage extends StatefulWidget {
  const SystemLogsPage({super.key});

  @override
  State<SystemLogsPage> createState() => _SystemLogsPageState();
}

class _SystemLogsPageState extends State<SystemLogsPage> {
  final RealtimeSensorService _sensorService = RealtimeSensorService();
  late final Stream<Map<String, int>> _maintenanceStream;
  late final Stream<Map<String, dynamic>> _settingsStream;

  @override
  void initState() {
    super.initState();
    _maintenanceStream = _sensorService.maintenanceStream;
    _settingsStream = _sensorService.settingsStream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/hydro_logo.png',
              height: 36,
              width: 36,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HydroHarvest',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283593),
                  ),
                ),
                Text(
                  'System',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfilePage()),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.person, color: Color(0xFF283593)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sensor Status Section
                    _buildSectionTitle('Sensor Status'),
                    StreamBuilder<Map<String, String>>(
                      stream: _sensorService.sensorStatusStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        final status = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(20), // Increased padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20), // 16 -> 20
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildStatusRow('pH Sensor', status['ph'] ?? 'Unknown'),
                              const Divider(),
                              _buildStatusRow('Turbidity Sensor', status['turbidity'] ?? 'Unknown'),
                              const Divider(),
                              _buildStatusRow('Water Level Sensor', status['waterLevel'] ?? 'Unknown'),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // UV Lamp Runtime Section
                    _buildSectionTitle('UV Lamp Runtime'),
                    StreamBuilder<int>(
                      stream: _sensorService.uvRuntimeStream,
                      builder: (context, snapshot) {
                        final totalSeconds = snapshot.data ?? 0;
                        final hours = totalSeconds / 3600.0;
                         // Assuming replacement every 9000 hours
                        final maxHours = 9000;
                        final remaining = maxHours - hours;
                        final progress = (hours / maxHours).clamp(0.0, 1.0);

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20), // 16 -> 20
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${hours.toInt()} Hours Used',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3436),
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[200],
                                color: progress > 0.9 ? Colors.red : Colors.blue,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                remaining > 0 
                                  ? 'Replace in approx. ${remaining.toStringAsFixed(0)} hours' 
                                  : 'Replacement needed immediately',
                                style: TextStyle(
                                  color: remaining > 0 ? Colors.grey[600] : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (await _verifyPassword(context)) {
                                      await _sensorService.resetUvRuntime();
                                      if (context.mounted) {
                                         NotificationPage.addLog('UV Lamp Replacement', 'User reset UV lamp runtime timer to 0.');
                                         _showSuccessDialog('UV Lamp runtime reset successfully');
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: remaining > 0 ? const Color(0xFFE8EAF6) : Colors.red,
                                    foregroundColor: remaining > 0 ? const Color(0xFF283593) : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Replace Lamp & Reset Timer'),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Filter Usage Time Section
                    _buildSectionTitle('Filter Usage Time'),
                    StreamBuilder<Map<String, int>>(
                      stream: _maintenanceStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                           return Container(
                            height: 200,
                            padding: const EdgeInsets.all(20),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.amber, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'Error loading filter data',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Show loading only if we truly have no data and no error
                        if (!snapshot.hasData) {
                          return Container(
                            height: 200,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }

                        final maintenanceData = snapshot.data!;
                        return Column(
                          children: [
                            _buildFilterUsageItem('Gravel', 'gravel', maintenanceData),
                            _buildFilterUsageItem('Sand', 'sand', maintenanceData),
                            _buildFilterUsageItem('Charcoal', 'charcoal', maintenanceData),
                            _buildFilterUsageItem('Calcite', 'calcite', maintenanceData),
                            _buildFilterUsageItem('Sediment Filter', 'sediment_filter', maintenanceData),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Calibration Options (Moved from Settings)
                    _buildSectionTitle('Calibration Options'),
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _settingsStream,
                      builder: (context, snapshot) {
                        final settings = snapshot.data ?? {};
                        final calibSettings = settings['calibration'] ?? {};
                        return _buildCalibrationOptions(calibSettings);
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedItemColor: const Color(0xFF283593),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.opacity), label: 'Water Status'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'System'), // Renamed from System Health
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const DashboardPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }

          if (index == 1) {
            Navigator.pushReplacement(context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const WaterStatusPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }

          if (index == 2) return;

          if (index == 3) {
            Navigator.pushReplacement(context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const AnalyticsPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Success!',
              style: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2D3436)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyPassword(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool? authorized = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Security Check'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please enter your password to confirm this action.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        errorText: errorMessage, // Display error here
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setState(() => errorMessage = null);
                        }
                      },
                      validator: (value) => value?.isEmpty ?? true ? 'Password required' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && user.email != null) {
                          final cred = EmailAuthProvider.credential(
                            email: user.email!, 
                            password: passwordController.text
                          );
                          await user.reauthenticateWithCredential(cred);
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          setState(() => errorMessage = 'No user authenticated');
                        }
                      } catch (e) {
                         setState(() => errorMessage = 'Incorrect Password');
                      }
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          }
        );
      },
    );
    return authorized ?? false;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3436),
        ),
      ),
    );
  }

  // --- Calibration Widgets (Copied from Settings) ---

  Widget _buildCalibrationOptions(Map<dynamic, dynamic> settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // 16 -> 20
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalibrationItem('pH Sensor', 'ph', settings),
          const Divider(),
          _buildCalibrationItem('Turbidity Sensor', 'turbidity', settings),
          const Divider(),
          // Water Level Info Row
          StreamBuilder<Map<String, String>>(
            stream: _sensorService.sensorStatusStream,
            builder: (context, snapshot) {
              final statusMap = snapshot.data ?? {};
              final status = statusMap['waterLevel'] ?? 'Unknown';
              final isOk = status == 'OK';
              final statusColor = isOk ? Colors.green : Colors.red;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Water Level Sensor', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            isOk ? 'Calibrated (Auto)' : status,
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (isOk)
                            const Text(
                                'Ultrasonic self-calibrating',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Auto', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationItem(String name, String key, Map<dynamic, dynamic> settings) {
    final lastCalibrated = settings['${key}_last_calibrated'];
    final lastDate = lastCalibrated != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastCalibrated)
        : null;
    
    final isDue = lastDate == null || DateTime.now().difference(lastDate).inDays > 30;
    final status = isDue ? 'Calibration Due' : 'Calibrated';
    final statusColor = isDue ? Colors.orange : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (lastDate != null)
                  Text(
                    'Last: ${lastDate.toString().split(' ')[0]}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showCalibrationDialog(name, key),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF283593),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Log Check'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCalibrationDialog(String name, String key) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Calibration Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Clean the sensor probe with distilled water.'),
            const SizedBox(height: 8),
            const Text('2. Place the sensor in the calibration solution.'),
            const SizedBox(height: 8),
            const Text('3. Manually adjust the sensor potentiometer until the reading matches the solution.'),
            const SizedBox(height: 8),
            const Text('4. Press "Mark as Calibrated" to reset the maintenance timer.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Ask for password before action
               if (await _verifyPassword(context)) {
                  _sensorService.updateCalibrationDate(key);
                  if (context.mounted) {
                    NotificationPage.addLog('$name Calibration', 'User marked $name sensor as calibrated.');
                    Navigator.pop(context);
                    _showSuccessDialog('$name maintenance logged');
                  }
               }
            },
            child: const Text('Mark as Calibrated'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String sensorName, String status) {
    final isOk = status == 'OK';
    final displayStatus = status.startsWith('Offline') ? 'Offline' : status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            sensorName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D3436),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isOk
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isOk ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: isOk ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  displayStatus,
                  style: TextStyle(
                    color: isOk ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterUsageItem(String name, String key, Map<String, int> data) {
    final lastReplaced = data[key];
    final lastDate = lastReplaced != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastReplaced)
        : DateTime.now().subtract(const Duration(days: 61)); // Default to expired
    
    final nextReplaceDate = lastDate.add(const Duration(days: 60));
    final daysRemaining = nextReplaceDate.difference(DateTime.now()).inDays;
    
    final isExpired = daysRemaining <= 0;
    final statusColor = isExpired ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Increased spacing
      padding: const EdgeInsets.all(20), // Increased padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // 16 -> 20
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), // Subtle shadow
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        // Removed border to match "card" look, or keep it subtle? Let's remove border for cleaner look if shadow is present
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired ? 'Replace Now' : '$daysRemaining days left',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showMaintenanceOptions(name, key),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF283593),
              backgroundColor: const Color(0xFFE8EAF6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMaintenanceOptions(String name, String key) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an action for the $name filter:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Reset Timer'),
              subtitle: const Text('Use after standard replacement'),
              onTap: () async {
                // Ask for password
                if (await _verifyPassword(context)) {
                  _sensorService.updateMaintenanceDate(key);
                  if (context.mounted) {
                    NotificationPage.addLog('$name Filter Reset', 'User reset timer for $name filter.');
                    Navigator.pop(context);
                    _showSuccessDialog('$name timer reset successfully');
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

}