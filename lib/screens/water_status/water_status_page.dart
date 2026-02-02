import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hydro_harvest/screens/dashboard/dashboard_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Water Status',
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3436),
                    ),
                  ),
                  GestureDetector(
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
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                    color: (isSafe ? Colors.green : Colors.red).withOpacity(0.3),
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
                    const Text(
                      'Filtration Stage Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Media should be changed every 2 months',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Filtration Status List
                    StreamBuilder<Map<String, int>>(
                      stream: _sensorService.maintenanceStream,
                      builder: (context, snapshot) {
                        final maintenanceData = snapshot.data ?? {};
                        
                        return Column(
                          children: [
                            _buildFilterStatusItem('Gravel', 'gravel', maintenanceData),
                            _buildFilterStatusItem('Sand', 'sand', maintenanceData),
                            _buildFilterStatusItem('Charcoal', 'charcoal', maintenanceData),
                            _buildFilterStatusItem('Calcite', 'calcite', maintenanceData),
                            _buildFilterStatusItem('Sediment Filter', 'sediment_filter', maintenanceData),
                          ],
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
      // If safe, score is between 80-100 based on optimality
      double deviation = (ph - 7.0).abs();
      // Max deviation is 1.5. 1.5 * 13 = 19.5, Score ~80
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
            color: Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.1),
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

  Widget _buildFilterStatusItem(String name, String key, Map<String, int> data) {
    final lastReplaced = data[key];
    // Default to 60 days ago if never set, so it shows as expired/needs replacement initially
    final lastDate = lastReplaced != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastReplaced)
        : DateTime.now().subtract(const Duration(days: 61));
    
    final nextReplaceDate = lastDate.add(const Duration(days: 60));
    final daysRemaining = nextReplaceDate.difference(DateTime.now()).inDays;
    
    final isExpired = daysRemaining <= 0;
    final statusColor = isExpired ? Colors.red : Colors.green;
    final statusText = isExpired ? 'Needs Attention' : 'Good';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
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
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
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
}
