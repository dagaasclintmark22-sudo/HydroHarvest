import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/screens/system_logs/system_logs_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RealtimeSensorService _sensorService = RealtimeSensorService();
  // ignore: unused_field
  final Set<String> _dismissedAlerts = {}; // Keeping for backward compatibility if needed

  // State
  List<Map<String, dynamic>> _activeAlerts = [];
  StreamSubscription? _alertSubscription;

  // Static history buffer to persist resolved alerts during the app session
  static final List<Map<String, dynamic>> _resolvedHistoryBuffer = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startListening();
  }

  void _startListening() {
    _alertSubscription = _sensorService.alertsStream.listen((newAlerts) {
      _processAlertUpdates(newAlerts);
    });
  }

  void _processAlertUpdates(List<Map<String, dynamic>> newAlerts) {
    // 1. Identify alerts that were active but are no longer in the new list
    final newTypes = newAlerts.map((a) => a['type']).toSet();
    
    for (final oldAlert in _activeAlerts) {
      if (!newTypes.contains(oldAlert['type'])) {
        // This alert has been resolved
        final resolvedAlert = Map<String, dynamic>.from(oldAlert);
        resolvedAlert['status'] = 'resolved';
        resolvedAlert['severity'] = 'resolved'; // Change color to green/grey
        resolvedAlert['message'] = 'Issue resolved automatically.';
        resolvedAlert['timestamp'] = _getCurrentTime();
        
        // Add to history (at the top)
        _resolvedHistoryBuffer.insert(0, resolvedAlert);
      }
    }

    if (mounted) {
      setState(() {
        _activeAlerts = newAlerts;
      });
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _tabController.dispose();
    _alertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out dismissed alerts from the live feed
    final visibleActiveAlerts = _activeAlerts.where((a) => !_dismissedAlerts.contains(a['type'])).toList();

    // Categorize alerts for tabs
    final criticalAlerts = visibleActiveAlerts.where((a) => a['severity'] == 'critical').toList();
    final warningAlerts = visibleActiveAlerts.where((a) => a['severity'] == 'warning' || a['severity'] == 'info').toList();
    
    // Combine active alerts + history for "All Alerts", but history for "Resolved"
    final allDisplayList = [...visibleActiveAlerts, ..._resolvedHistoryBuffer];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Alerts & Notifications',
          style: GoogleFonts.lora(
            color: const Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF283593),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF283593),
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Alerts'),
            Tab(text: 'Critical'),
            Tab(text: 'Warnings'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertList(allDisplayList),
          _buildAlertList(criticalAlerts),
          _buildAlertList(warningAlerts),
          _buildAlertList(_resolvedHistoryBuffer),
        ],
      ),
    );
  }

  Widget _buildAlertList(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Clear!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your system is running smoothly.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemLogsPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF283593),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View System Status'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String;
    final type = alert['type'] as String;
    final message = alert['message'] as String;
    final timestamp = alert['timestamp'] as String; // Assuming ISO string or formatted
    final isResolved = alert['status'] == 'resolved';

    Color cardColor;
    Color iconColor;
    IconData iconData;

    switch (severity) {
      case 'critical':
        cardColor = Colors.red.shade50;
        iconColor = Colors.red;
        iconData = Icons.warning_rounded;
        break;
      case 'warning':
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        iconData = Icons.info_outline;
        break;
      default:
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        iconData = Icons.info;
    }

    if (isResolved) {
      cardColor = Colors.grey.shade100;
      iconColor = Colors.grey;
      iconData = Icons.check_circle_outline;
    }

    // Determine Contextual Action
    Widget? actionButton;
    if (!isResolved) {
      if (type.contains('Unsafe Water') || type.contains('Turbidity')) {
        actionButton = ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WaterStatusPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Check Quality'),
        );
      } else if (type.contains('Sensor') || type.contains('System')) {
        actionButton = ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SystemLogsPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Check System'),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: iconColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isResolved ? Colors.grey[700] : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                  if (!isResolved) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (actionButton != null) ...[
                          actionButton,
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _dismissedAlerts.add(type);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Alert dismissed')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
