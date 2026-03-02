import 'package:flutter/material.dart';

import 'package:hydro_harvest/screens/dashboard/dashboard_page.dart';
import 'package:hydro_harvest/screens/analytics/analytics_page.dart';
import 'package:hydro_harvest/screens/system_logs/system_logs_page.dart';
import 'package:hydro_harvest/screens/profile/profile_page.dart';
import 'package:hydro_harvest/screens/water_status/quality_comparison_card.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';


class WaterStatusPage extends StatefulWidget {
  const WaterStatusPage({super.key});

  @override
  State<WaterStatusPage> createState() => _WaterStatusPageState();
}

class _WaterStatusPageState extends State<WaterStatusPage> {
  final RealtimeSensorService _sensorService = RealtimeSensorService();
  late final Stream<Map<String, int>> _maintenanceStream;

  @override
  void initState() {
    super.initState();
    _maintenanceStream = _sensorService.maintenanceStream;
    // We can init others if used 
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
                  'Water Status',
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
                    // Overall Water Quality Score
                    StreamBuilder<double>(
                      stream: _sensorService.phStream,
                      builder: (context, phSnap) {
                        if (!phSnap.hasData) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        final ph = phSnap.data!;
                        return StreamBuilder<double>(
                          stream: _sensorService.turbidityStream,
                          builder: (context, turbSnap) {
                            if (!turbSnap.hasData) {
                               return Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }
                            final turb = turbSnap.data!;
                                
                            // Calculate Score with params
                            final score = _calculateQualityScore(ph, turb);
                                final isSafe = score >= 80;

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
                                        color: (isSafe ? Colors.green : Colors.red)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Overall Water Quality Score',
                                        style: TextStyle(color: Colors.white70, fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${score.toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isSafe ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isSafe ? 'Safe to Drink' : 'Unsafe to Drink',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    
                    // pH Level
                    StreamBuilder<double>(
                      stream: _sensorService.phStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                           return _buildDetailCard('pH Level', '...', 'Loading...', Icons.science, Colors.grey);
                        }
                        final ph = snapshot.data!;
                        String interpretation;
                        Color color;
                        if (ph < 6.5) {
                          interpretation = 'Acidic';
                          color = Colors.orange;
                        } else if (ph > 8.5) {
                          interpretation = 'Alkaline';
                          color = Colors.purple;
                        } else {
                          interpretation = 'Neutral (Optimal)';
                          color = Colors.green;
                        }

                        return _buildDetailCard(
                          'pH Level',
                          ph.toStringAsFixed(2),
                          interpretation,
                          Icons.science,
                          color,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Turbidity
                    StreamBuilder<double>(
                      stream: _sensorService.turbidityStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                           return _buildDetailCard('Turbidity', '...', 'Loading...', Icons.opacity, Colors.grey);
                        }
                        final turb = snapshot.data!;
                        final isClear = turb < 0.5;
                        final status = isClear ? 'Clear' : 'Dirty';

                        return _buildDetailCard(
                          'Turbidity',
                          status, // Display Clear/Dirty instead of NTU value
                          'Status',
                          Icons.opacity,
                          isClear ? Colors.blue : Colors.red,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Manual TDS Input
                    // const ManualTdsCard(),

                    const SizedBox(height: 16),

                    // Water Level
                    StreamBuilder<int>(
                      stream: _sensorService.waterLevelPercentageStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                           return _buildDetailCard('Tank Capacity', '...', 'Loading...', Icons.water_damage, Colors.grey);
                        }
                        final percentage = snapshot.data!;
                        String interpretation;
                        Color color;
                        
                        if (percentage >= 90) {
                          interpretation = 'Full';
                          color = Colors.green;
                        } else if (percentage <= 20) {
                          interpretation = 'Low (Filling)';
                          color = Colors.red;
                        } else {
                          interpretation = 'Normal';
                          color = Colors.blue;
                        }

                        return _buildDetailCard(
                          'Tank Capacity',
                          '$percentage%',
                          interpretation,
                          Icons.water_damage,
                          color,
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    
                    // Filtration Summary (Replaces detailed list)
                    _buildSectionTitle('Filtration System Status'),
                    StreamBuilder<Map<String, int>>(
                      stream: _maintenanceStream,
                      builder: (context, snapshot) {
                        final maintenanceData = snapshot.data ?? {};

                        final filterLabels = {
                          'gravel': 'Gravel',
                          'sand': 'Sand',
                          'charcoal': 'Charcoal',
                          'calcite': 'Calcite',
                          'sediment_filter': 'Sediment Filter',
                        };

                        final expiredFilters = <String>[];

                        for (final key in filterLabels.keys) {
                          final lastReplaced = maintenanceData[key];
                          final lastDate = lastReplaced != null 
                              ? DateTime.fromMillisecondsSinceEpoch(lastReplaced)
                              : DateTime.now().subtract(const Duration(days: 61));
                          
                          final nextReplaceDate = lastDate.add(const Duration(days: 60));
                          if (DateTime.now().isAfter(nextReplaceDate)) {
                            expiredFilters.add(filterLabels[key]!);
                          }
                        }

                        final expiredCount = expiredFilters.length;
                        final bool isHealthy = expiredCount == 0;
                        final statusLine = isHealthy
                          ? 'All filters are in good condition.'
                          : 'Needs replacement: ${expiredFilters.join(', ')}';
                        
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isHealthy 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.orange.withValues(alpha: 0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: isHealthy 
                                ? Colors.green.withValues(alpha: 0.2) 
                                : Colors.orange.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isHealthy 
                                        ? Colors.green.withValues(alpha: 0.1) 
                                        : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                      color: isHealthy ? Colors.green : Colors.orange,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isHealthy ? 'System Nominal' : 'Maintenance Needed',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D3436),
                                          ),
                                        ),
                                        Text(
                                          statusLine,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Navigate to System Logs Page
                                    Navigator.pushReplacement(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) => const SystemLogsPage(),
                                        transitionDuration: Duration.zero,
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF283593),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: Color(0xFFC5CAE9)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('View Detailed Status'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    
                    // Quality Comparison
                    StreamBuilder<double>(
                      stream: _sensorService.phStream,
                      builder: (context, phSnap) {
                        final ph = phSnap.data ?? 7.0;
                        return StreamBuilder<double>(
                          stream: _sensorService.turbidityStream,
                          builder: (context, turbSnap) {
                            final turb = turbSnap.data ?? 0.0;
                            return QualityComparisonCard(
                              currentPh: ph,
                              currentTurbidity: turb,
                            );
                          },
                        );
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

      // NAV BAR
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        selectedItemColor: const Color(0xFF283593),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.opacity), label: 'Water Status'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'System'),
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

          if (index == 1) return;

          if (index == 2) {
            Navigator.pushReplacement(context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SystemLogsPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }

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

  double _calculateQualityScore(double ph, double turbidity) {
    double score = 100.0;
    
    // pH Calculation (Safe Zone: 6.5 - 8.5)
    if (ph < 6.5 || ph > 8.5) {
      // If unsafe, max score is 60 and drops from there
      score = 60.0;
      double deviation = (ph < 6.5) ? (6.5 - ph) : (ph - 8.5);
      score -= (deviation * 20); // Sharp penalty for further deviation
    } else {
      // If safe, score is between 80-100 based on optimality (7.0 is best)
      double deviation = (ph - 7.0).abs();
      score -= (deviation * 13);
    }

    // Turbidity Penalty
    // If dirty (> 0.5), heavy penalty
    if (turbidity > 0.5) {
      score -= 40;
    }

    if (score < 0) score = 0;
    if (score > 100) score = 100;
    return score;
  }

  Widget _buildDetailCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}
