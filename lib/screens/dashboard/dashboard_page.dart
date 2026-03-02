import 'package:flutter/material.dart';
import 'package:hydro_harvest/screens/analytics/analytics_page.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';
import 'package:hydro_harvest/services/collected_water_analytics_service.dart';
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
  final CollectedWaterAnalyticsService _analyticsService =
      CollectedWaterAnalyticsService();
  late Stream<bool> _harvestLidStream; // Changed to bool for UV status
  late Stream<int> _waterLevelStream;
  late Future<CollectedWaterAnalytics> _todayAnalyticsFuture;

  @override
  void initState() {
    super.initState();
    _harvestLidStream = _sensorService.collectingStream; // Listen to "collecting" (Solenoid) state, NOT "uvActive" (includes cooldown)
    _waterLevelStream = _sensorService.waterLevelPercentageStream;
    _refreshTodayAnalytics();
  }

  void _refreshTodayAnalytics() {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    _todayAnalyticsFuture = _analyticsService.getDailyAnalytics(date: day);
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
                
                // Nest StreamBuilder for dismissal updates to ensure red dot clears immediately
                return StreamBuilder<Map<String, DateTime>>(
                  stream: _sensorService.dismissalStream,
                  initialData: _sensorService.dismissedAlertsMap,
                  builder: (context, dismissalSnapshot) {
                    final dismissedMap = dismissalSnapshot.data ?? {};
                    // Filter out dismissed alerts ("High Severity" ones that can't be dismissed are always shown)
                    final activeVisible = alerts.where((a) {
                        return !dismissedMap.containsKey(a['type']);
                    }).toList();
                    
                    final hasActiveAlerts = activeVisible.isNotEmpty;

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
                  }
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
              StreamBuilder<Map<String, dynamic>>(
                stream: _sensorService.fullSensorDataStream,
                builder: (context, sensorSnap) {
                      
                      // 1. Get Loading State
                      if (!sensorSnap.hasData) {
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

                      // 2. Resolve Safety (Combined Logic) & Pinpoint Issues
                      final sensorData = sensorSnap.data!;
                      final double ph = sensorData['ph'];
                      final double turbidity = sensorData['turbidity'];

                      // Safety Thresholds
                      bool isPhLow = ph < 6.5;
                      bool isPhHigh = ph > 8.5;
                      bool isTurbidityHigh = turbidity > 0.5;

                      bool isRealtimeSafe = !isPhLow && !isPhHigh && !isTurbidityHigh;

                      // MASTER SAFETY FLAG
                      final isOverallSafe = isRealtimeSafe;

                      // 3. Determine Messages (Pinpoint Logic)
                      String statusTitle = isOverallSafe ? 'Safe to Drink' : 'Unsafe to Drink';
                      String statusSubtitle = 'All systems normal';
                      
                      List<String> errors = [];
                      if (isPhLow) errors.add('pH is too low (${ph.toStringAsFixed(1)})');
                      if (isPhHigh) errors.add('pH is too high (${ph.toStringAsFixed(1)})');
                      if (isTurbidityHigh) errors.add('Turbidity is too high (${turbidity.toStringAsFixed(1)})');

                      if (errors.isNotEmpty) {
                        statusSubtitle = errors.join(', ');
                      } else if (!isRealtimeSafe) {
                        // Fallback if numbers are borderline but logic failed somehow
                        statusSubtitle = 'Check sensor readings';
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOverallSafe 
                                ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                                : [const Color(0xFFE53935), const Color(0xFFEF5350)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (isOverallSafe ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Water Status',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              statusTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isOverallSafe ? Icons.check_circle : Icons.warning,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    statusSubtitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
              StreamBuilder<bool>(
                stream: _harvestLidStream,
                initialData: false,
                builder: (context, servoSnapshot) {
                  return StreamBuilder<int>(
                    stream: _waterLevelStream,
                    initialData: 0,
                    builder: (context, waterSnapshot) {
                      final isLidOpen = servoSnapshot.data ?? false; // True if Servos are open (Auto or Manual)
                      final waterLevel = waterSnapshot.data ?? 0;
                      
                      // UI Logic: Lock button if Water >= 70% (User request)
                      // Only allow opening if < 70%.
                      // If currently Open, allow Closing (so not blocked if isLidOpen is true).
                      final bool isActionBlocked = !isLidOpen && waterLevel >= 70; 

                      return Container(
                        decoration: BoxDecoration(
                          color: isActionBlocked ? Colors.grey[50] : Colors.white, 
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
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
                              color: isActionBlocked ? Colors.grey : Colors.black87, 
                            )
                          ),
                          subtitle: Text(
                            isLidOpen 
                                ? 'Open (Collecting)' 
                                : (isActionBlocked ? 'Tank is Full - Cannot Collect' : 'Closed'),
                            style: TextStyle(
                              color: isActionBlocked ? Colors.deepOrange : (isLidOpen ? Colors.green : Colors.grey[600]),
                              fontWeight: isActionBlocked ? FontWeight.w600 : FontWeight.normal,
                            )
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActionBlocked
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : (isLidOpen
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.blue.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isActionBlocked ? Icons.lock_outline : Icons.roofing, 
                              color: isActionBlocked ? Colors.grey : (isLidOpen ? Colors.green : Colors.grey)
                            ),
                          ),
                          value: isLidOpen,
                          activeThumbColor: isLidOpen ? Colors.green : Colors.blue,
                          onChanged: (value) {
                            if (value) {
                              // Trying to open (ONLY Restricted by Water Level)
                              if (waterLevel < 70) { 
                                // Show Confirmation Dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Collection'),
                                    content: const Text('Are you sure you want to open the lid to collect water?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _sensorService.setHarvestLid(true);
                                        },
                                        child: const Text('Confirm', style: TextStyle(color: Colors.green)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Show Pop-up for Full Tank
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Cannot Collect Water'),
                                    content: Text('Cannot collect anymore because the water tank is full ($waterLevel%). Limit is 70%.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else {
                              // Trying to Close - ALWAYS Allowed, NO Restrictions
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
                  StreamBuilder<int>(
                    stream: _sensorService.waterLevelPercentageStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSensorCard(
                          'Water Level',
                          '...',
                          Icons.water_drop,
                          Colors.grey,
                        );
                      }
                      final percentage = snapshot.data!;

                      Color statusColor;
                      String statusText;

                      if (percentage >= 90) {
                        statusColor = Colors.green;
                        statusText = '$percentage% (Full)';
                      } else if (percentage <= 20) {
                        statusColor = Colors.red;
                        statusText = '$percentage% (Low)';
                      } else {
                        statusColor = Colors.blue;
                        statusText = '$percentage%';
                      }

                      return _buildSensorCard(
                        'Water Level',
                        statusText,
                        Icons.water_damage,
                        statusColor,
                      );
                    },
                  ),
                  // Water Level Card
                  StreamBuilder<double>(
                    stream: _sensorService.turbidityStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSensorCard(
                          'Turbidity',
                          '...',
                          Icons.opacity,
                          Colors.grey,
                        );
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

              const SizedBox(height: 16),
              _buildDashboardAnalyticsSummaryCard(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics), label: 'Analytics'),
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

          if (index == 3) {
            Navigator.pushReplacement(
              context,
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

  Widget _buildDashboardAnalyticsSummaryCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AnalyticsPage(),
            transitionDuration: Duration.zero,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Color(0xFF283593),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Today\'s Harvest',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF5C6B73),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<CollectedWaterAnalytics>(
              future: _todayAnalyticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'Data unavailable for today',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Water Purified',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF636E72),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                data.totalCollectedLiters.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E88E5),
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Liters',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF636E72),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collection Cycles',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF636E72),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.collectionEventCount} times',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
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
