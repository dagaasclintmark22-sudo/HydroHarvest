import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hydro_harvest/services/realtime_sensor_service.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/screens/system_logs/system_logs_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  // Global history buffer accessible from other pages
  static final List<Map<String, dynamic>> resolvedHistoryBuffer = [];

  static void addLog(String type, String message) {
    resolvedHistoryBuffer.insert(0, {
      'type': type,
      'message': message,
      'severity': 'resolved',
      'status': 'resolved',
      'timestamp': DateFormat('MMM dd, HH:mm').format(DateTime.now()),
      'isMaintenance': true, // Use this to filter out from main alerts tab
    });
  }

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RealtimeSensorService _sensorService = RealtimeSensorService();
  
  // State
  List<Map<String, dynamic>> _activeAlerts = [];
  StreamSubscription? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    NotificationPage.resolvedHistoryBuffer.removeWhere(_isTdsAlert);
    _startListening();
  }

  void _startListening() {
    // Listen to the alerts stream from the service
    _alertSubscription = _sensorService.alertsStream.listen((newAlerts) {
      _processAlertUpdates(newAlerts);
    });
  }

  void _processAlertUpdates(List<Map<String, dynamic>> newAlerts) {
    final filteredNewAlerts = newAlerts.where((a) => !_isTdsAlert(a)).toList();

    // 1. Identify alerts that were active but are no longer in the new list (Auto-Resolved)
    final newTypes = filteredNewAlerts.map((a) => a['type']).toSet();
    
    for (final oldAlert in _activeAlerts) {
      if (!newTypes.contains(oldAlert['type'])) {
        // This alert has been resolved automatically
        final resolvedAlert = Map<String, dynamic>.from(oldAlert);
        resolvedAlert['status'] = 'resolved';
        resolvedAlert['severity'] = 'resolved';
        resolvedAlert['message'] = 'Issue resolved automatically.';
        resolvedAlert['timestamp'] = _getCurrentTime();
        
        // Add to history (at the top)
        NotificationPage.resolvedHistoryBuffer.insert(0, resolvedAlert);
      }
    }

    if (mounted) {
      setState(() {
        _activeAlerts = filteredNewAlerts;
      });
    }
  }

  bool _isTdsAlert(Map<String, dynamic> alert) {
    final type = alert['type']?.toString().toLowerCase() ?? '';
    final message = alert['message']?.toString().toLowerCase() ?? '';
    return type.contains('tds') || message.contains('tds');
  }

  String _getCurrentTime() {
    return DateFormat('MMM dd, HH:mm').format(DateTime.now());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _alertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to dismissal changes to trigger rebuilds and hide dismissed alerts
    return StreamBuilder<Map<String, DateTime>>(
      stream: _sensorService.dismissalStream,
      initialData: _sensorService.dismissedAlertsMap,
      builder: (context, snapshot) {
        final dismissedMap = snapshot.data ?? {};
        
        // Filter out dismissed alerts from the live feed for display
        final visibleActiveAlerts = _activeAlerts
          .where((a) => !_isTdsAlert(a))
          .where((a) => !dismissedMap.containsKey(a['type']))
          .toList();

        // Categorize alerts for tabs
        final criticalAlerts = visibleActiveAlerts.where((a) => a['severity'] == 'critical').toList();
        final warningAlerts = visibleActiveAlerts.where((a) => a['severity'] == 'warning' || a['severity'] == 'info').toList();
        
        // Filter out maintenance logs from "All Alerts" tab - keeping only Active Alerts + System Alert History
        // Explicitly exclude maintenance items from the main overview
        final systemResolvedHistory = NotificationPage.resolvedHistoryBuffer
          .where((a) => !_isTdsAlert(a))
          .where((a) => a['isMaintenance'] != true)
          .toList();
        
        // "All Alerts" shows active alerts + history of system alerts (not user maintenance logs)
        final allDisplayList = [...visibleActiveAlerts, ...systemResolvedHistory];

        // "Resolved & Logs" shows everything in history (System + Maintenance)
        final fullHistoryList = NotificationPage.resolvedHistoryBuffer
          .where((a) => !_isTdsAlert(a))
          .toList();

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
                Tab(text: 'Resolved & Logs'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAlertList(allDisplayList),
              _buildAlertList(criticalAlerts),
              _buildAlertList(warningAlerts),
              _buildAlertList(fullHistoryList),
            ],
          ),
        );
      }
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
                color: Colors.green.withValues(alpha: 0.1),
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
              'No alerts to display.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
             const SizedBox(height: 32),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        // Unique Key for Dismissible (using type + timestamp)
        final uniqueKey = "${alert['type']}_${alert['timestamp']}_$index";
        final severity = alert['severity'];
        final isCriticalOrWarning = severity == 'critical' || severity == 'warning';
        final isResolved = alert['status'] == 'resolved';

        // Critical/Warning alerts CANNOT be dismissed. Resolved can always be removed from list if needed.
        // Info alerts (like Tank Full) can be dismissed.
        final canDismiss = (!isCriticalOrWarning && !isResolved); 
        
        return Dismissible(
          key: Key(uniqueKey),
          direction: canDismiss ? DismissDirection.endToStart : DismissDirection.none,
          onDismissed: (direction) {
            if (canDismiss) {
              _handleDismissal(alert);
            }
          },
          background: canDismiss ? Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ) : Container(), 
          child: _buildAlertCard(alert, canDismiss),
        );
      },
    );
  }

  void _handleDismissal(Map<String, dynamic> alert) {
      final type = alert['type'];
      _sensorService.dismissAlert(type);
      
      // Special behavior for Tank Full (Log history, NO SnackBar)
      if (type == 'Tank Full') {
          // Add to Resolved History specifically
          final logAlert = Map<String, dynamic>.from(alert);
          logAlert['status'] = 'resolved'; 
          logAlert['severity'] = 'resolved';
          logAlert['message'] = 'Tank Full event acknowledged.';
          logAlert['timestamp'] = _getCurrentTime();
          NotificationPage.resolvedHistoryBuffer.insert(0, logAlert);
          // Silent - no snackbar
      } else {
          // Default behavior: Show SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$type dismissed (will reappear only if the issue clears and happens again)'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  _sensorService.undoDismissAlert(type);
                },
              ),
            ),
          );
      }
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, bool canDismiss) {
    final severity = alert['severity'] as String;
    final type = alert['type'] as String;
    String message = alert['message'] as String;
    final timestamp = alert['timestamp'] as String; 
    final isResolved = alert['status'] == 'resolved';

    // Parse Issues Chips if present
    List<String> issuesList = [];
    if (message.startsWith('Issues:')) {
      final rawIssues = message.replaceAll('Issues: ', '').split('. ').first; 
      issuesList = rawIssues.split(', ');
    }

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
        side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
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
                  
                  if (issuesList.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: issuesList.map((issue) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            issue,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: iconColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                       "Recommendation: Check water source and filter status immediately.",
                       style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ] else ...[
                     Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ],

                  if (!isResolved && (actionButton != null || canDismiss)) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (actionButton != null) ...[
                          actionButton,
                          const SizedBox(width: 8),
                        ],
                        if (canDismiss)
                          OutlinedButton(
                            onPressed: () => _handleDismissal(alert),
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
