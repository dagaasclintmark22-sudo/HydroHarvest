import 'package:flutter/material.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';
import 'package:hydro_harvest/screens/system_logs/system_logs_page.dart';
import 'package:hydro_harvest/screens/profile/profile_page.dart';
import 'package:hydro_harvest/screens/notification/notification_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final RealtimeSensorService _sensorService = RealtimeSensorService();
  late Stream<int> _harvestLidStream;
  late Stream<int> _waterLevelStream;

  @override
  void initState() {
    super.initState();
    _harvestLidStream = _sensorService.harvestLidStream;
    _waterLevelStream = _sensorService.waterLevelPercentageStream;
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
              height: 40,
              width: 40,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HydroHarvest',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283593),
                  ),
                ),
                Text(
                  'Smart Purification',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
            // Notification Button
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _sensorService.alertsStream,
              builder: (context, snapshot) {
                final alerts = snapshot.data ?? [];
                final hasActiveAlerts = alerts.isNotEmpty;
                
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Color(0xFF283593)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationPage()),
                        );
                      },
                    ),
                    if (hasActiveAlerts)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 8,
                            minHeight: 8,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  ProfilePage()),
                  );
                },
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF283593),
                  ),
                ),
              ),
            ),
          ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Water Safety Card
              StreamBuilder<bool>(
                stream: _sensorService.isWaterSafeStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      width: double.infinity,
                      height: 140,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  final isSafe = snapshot.data!;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSafe 
                            ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                            : [const Color(0xFFE53935), const Color(0xFFEF5350)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (isSafe ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Water Status',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isSafe ? 'Safe to Drink' : 'Unsafe to Drink',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              isSafe ? Icons.check_circle : Icons.warning,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSafe ? 'All systems normal' : 'Check filtration system',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              
              const Text(
                'Control Panel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 16),
              
              // Lid Control
              StreamBuilder<int>(
                stream: _harvestLidStream,
                initialData: 0,
                builder: (context, servoSnapshot) {
                  return StreamBuilder<int>(
                    stream: _waterLevelStream,
                    initialData: 0,
                    builder: (context, waterSnapshot) {
                      final angle = servoSnapshot.data ?? 0;
                      final isLidOpen = angle == 90;
                      final waterLevel = waterSnapshot.data ?? 0;
                      
                      // UI Logic: Check if action is blocked
                      final bool isActionBlocked = !isLidOpen && waterLevel >= 55; // Cannot open if closed and water >= 55%

                      return Container(
                        decoration: BoxDecoration(
                          color: isActionBlocked ? Colors.grey[50] : Colors.white, // Slightly greyer background if blocked
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Harvest System Lid', 
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isActionBlocked ? Colors.grey : Colors.black87, // Grey text if blocked
                            )
                          ),
                          subtitle: Text(
                            isLidOpen 
                                ? 'Open' 
                                : (isActionBlocked ? 'Disabled (Risk of Overflow)' : 'Closed'),
                            style: TextStyle(
                              color: isActionBlocked ? Colors.deepOrange : Colors.grey[600],
                              fontWeight: isActionBlocked ? FontWeight.w600 : FontWeight.normal,
                            )
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActionBlocked ? Colors.grey.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isActionBlocked ? Icons.lock_outline : Icons.roofing, // Lock icon if blocked
                              color: isActionBlocked ? Colors.grey : (isLidOpen ? Colors.blue : Colors.grey)
                            ),
                          ),
                          value: isLidOpen,
                          activeThumbColor: Colors.blue,
                          onChanged: (value) {
                            if (value) {
                              // Trying to open
                              // Safety Buffer: Only allow opening if we have at least 5% capacity before auto-close (at 60%)
                              if (waterLevel < 55) {
                                _sensorService.setHarvestLid(true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot open lid: Water level too high (> 55%). Buffer required to prevent overflow.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                              // Trying to close - always allowed
                              _sensorService.setHarvestLid(false);
                            }
                          },
                        ),
                      );
                    }
                  );
                }
              ),

              const SizedBox(height: 24),

              const Text(
                'Sensor Readings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 16),

              // Grid for sensors
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // pH Card
                  StreamBuilder<double>(
                    stream: _sensorService.phStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSensorCard('pH Level', '...', Icons.science, Colors.grey);
                      }
                      final ph = snapshot.data!;
                      
                      String status;
                      if (ph < 6.5) {
                        status = 'Acidic';
                      } else if (ph < 7.0) {
                        status = 'Slightly Acidic';
                      } else if (ph <= 7.5) {
                        status = 'Neutral';
                      } else if (ph <= 8.5) {
                        status = 'Slightly Alkaline';
                      } else {
                        status = 'Alkaline';
                      }

                      return _buildSensorCard(
                        'pH Level',
                        ph.toStringAsFixed(1),
                        Icons.science,
                        Colors.purple,
                        statusText: status,
                      );
                    },
                  ),
                  // Turbidity Card
                  StreamBuilder<double>(
                    stream: _sensorService.turbidityStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSensorCard('Turbidity', '...', Icons.opacity, Colors.grey);
                      }
                      final turb = snapshot.data!;
                      final isClear = turb < 0.5;
                      return _buildSensorCard(
                        'Turbidity',
                        isClear ? 'Clear' : 'Dirty',
                        Icons.opacity,
                        isClear ? Colors.blue : Colors.red,
                      );
                    },
                  ),
                  // Water Level Card
                  StreamBuilder<int>(
                    stream: _sensorService.waterLevelPercentageStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSensorCard('Water Level', '...', Icons.water_drop, Colors.grey);
                      }
                      final percentage = snapshot.data!;
                      
                      Color statusColor;
                      String statusText;
                      
                      if (percentage >= 90) {
                        statusColor = Colors.green;
                        statusText = "$percentage% (Full)";
                      } else if (percentage <= 20) {
                        statusColor = Colors.red;
                        statusText = "$percentage% (Low)";
                      } else {
                        statusColor = Colors.blue;
                        statusText = "$percentage%";
                      }

                      return _buildSensorCard(
                        'Water Level',
                        statusText,
                        Icons.water_damage,
                        statusColor,
                      );
                    },
                  ),
                  // UV Sterilizer
                  StreamBuilder<bool>(
                    stream: _sensorService.uvActiveStream,
                    builder: (context, snapshot) {
                      final isActive = snapshot.data ?? false;
                      return _buildSensorCard(
                        'UV Sterilizer',
                        isActive ? 'Active' : 'Inactive',
                        Icons.light_mode,
                        isActive ? Colors.amber : Colors.grey,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: const Color(0xFF283593),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.opacity), label: 'Water Status'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'System'),
        ],
        onTap: (index) {
          if (index == 0) return;

          if (index == 1) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const WaterStatusPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }

          if (index == 2) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SystemLogsPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color, {String? statusText}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              if (statusText != null) ...[
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
