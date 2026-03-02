import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydro_harvest/screens/dashboard/dashboard_page.dart';
import 'package:hydro_harvest/screens/profile/profile_page.dart';
import 'package:hydro_harvest/screens/system_logs/system_logs_page.dart';
import 'package:hydro_harvest/screens/water_status/water_status_page.dart';
import 'package:hydro_harvest/services/collected_water_analytics_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final CollectedWaterAnalyticsService _analyticsService =
      CollectedWaterAnalyticsService();

  late DateTime _selectedAnalyticsDate;
  late Future<_DailyBundle> _dailyBundleFuture; // single combined future
  late DateTimeRange _selectedRange;
  late Future<CollectedWaterRangeAnalytics> _rangeAnalyticsFuture;
  bool _isCustomRange = false;

  // Cache DateTime.now() per lifecycle instead of per build
  late final DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _selectedAnalyticsDate = _now;
    final rangeStart = _now.subtract(const Duration(days: 6));
    _selectedRange = DateTimeRange(
      start: DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
      end: DateTime(_now.year, _now.month, _now.day),
    );
    _refreshDailyAnalytics();
    _refreshRangeAnalytics();
  }

  void _refreshDailyAnalytics() {
    final selectedDay = DateTime(
      _selectedAnalyticsDate.year,
      _selectedAnalyticsDate.month,
      _selectedAnalyticsDate.day,
    );

    // Load daily + 7-day trend in PARALLEL via Future.wait
    _dailyBundleFuture = Future.wait([
      _analyticsService.getDailyAnalytics(date: selectedDay),
      _analyticsService.getLastSevenDaysTrend(endDate: selectedDay),
    ]).then((results) => _DailyBundle(
          analytics: results[0] as CollectedWaterAnalytics,
          trend: results[1] as List<DailyCollectedWaterPoint>,
        ));
  }

  void _refreshRangeAnalytics() {
    _rangeAnalyticsFuture = _analyticsService.getRangeAnalytics(
      startDate: _selectedRange.start,
      endDate: _selectedRange.end,
    );
  }

  Future<void> _pickAnalyticsDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAnalyticsDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: 'Select analytics date',
    );

    if (picked == null) return;

    setState(() {
      _selectedAnalyticsDate = picked;
      _refreshDailyAnalytics();
    });
  }

  void _setPresetDate(DateTime date) {
    setState(() {
      _selectedAnalyticsDate = date;
      _refreshDailyAnalytics();
    });
  }

  void _setPresetRange(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));

    setState(() {
      _isCustomRange = false;
      _selectedRange = DateTimeRange(start: start, end: end);
      _refreshRangeAnalytics();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: _selectedRange,
      helpText: 'Select analytics date range',
    );

    if (picked == null) return;

    setState(() {
      _isCustomRange = true;
      _selectedRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      _refreshRangeAnalytics();
    });
  }

  String _formatDateLabel(DateTime date) {
    if (DateUtils.isSameDay(date, DateTime.now())) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatRangeLabel(DateTimeRange range) {
    final start = DateFormat('MMM d, yyyy').format(range.start);
    final end = DateFormat('MMM d, yyyy').format(range.end);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final yesterday = _now.subtract(const Duration(days: 1));

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
                  'Analytics',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DAILY ANALYTICS SECTION ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                        const Expanded(
                          child: Text(
                            'Daily Analytics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickAnalyticsDate,
                          icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF283593)),
                          label: Text(
                            _formatDateLabel(_selectedAnalyticsDate),
                            style: const TextStyle(color: Color(0xFF283593), fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: const Color(0xFFE8EAF6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setPresetDate(now),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: DateUtils.isSameDay(_selectedAnalyticsDate, now) ? const Color(0xFF283593) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Today', style: TextStyle(
                                color: DateUtils.isSameDay(_selectedAnalyticsDate, now) ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setPresetDate(yesterday),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: DateUtils.isSameDay(_selectedAnalyticsDate, yesterday) ? const Color(0xFF283593) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Yesterday', style: TextStyle(
                                color: DateUtils.isSameDay(_selectedAnalyticsDate, yesterday) ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<_DailyBundle>(
                      future: _dailyBundleFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const _DailySectionSkeleton();
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Unable to load analytics.\n${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final bundle = snapshot.data;
                        if (bundle == null) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No analytics available yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final data = bundle.analytics;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Collected (Liters)',
                                    '${data.totalCollectedLiters.toStringAsFixed(1)} L',
                                    Icons.water_drop,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Peak Hour',
                                    data.peakCollectionHourLabel,
                                    Icons.access_time,
                                    Colors.deepPurple,
                                    subtitle: '${data.peakCollectionLiters.toStringAsFixed(1)} L',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Samples',
                                    '${data.sampleCount}',
                                    Icons.science,
                                    Colors.teal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Batch Events',
                                    '${data.collectionEventCount}',
                                    Icons.storage,
                                    Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '7-Day Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (bundle.trend.isNotEmpty)
                              RepaintBoundary(
                                child: _buildTrendChart(
                                  title: 'Collection Volume (L)',
                                  points: bundle.trend,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- RANGE ANALYTICS SECTION ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _setPresetRange(7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (!_isCustomRange && _selectedRange.duration.inDays == 6) ? const Color(0xFF283593) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('7 Days', style: TextStyle(
                                color: (!_isCustomRange && _selectedRange.duration.inDays == 6) ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _setPresetRange(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (!_isCustomRange && _selectedRange.duration.inDays == 29) ? const Color(0xFF283593) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('30 Days', style: TextStyle(
                                color: (!_isCustomRange && _selectedRange.duration.inDays == 29) ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _pickCustomRange,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isCustomRange ? const Color(0xFF283593) : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Custom', style: TextStyle(
                                color: _isCustomRange ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          _formatRangeLabel(_selectedRange),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<CollectedWaterRangeAnalytics>(
                      future: _rangeAnalyticsFuture,
                      builder: (context, rangeSnapshot) {
                        if (rangeSnapshot.connectionState == ConnectionState.waiting) {
                          return const _RangeSectionSkeleton();
                        }

                        if (rangeSnapshot.hasError || !rangeSnapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Unable to load overview analytics.\n${rangeSnapshot.error ?? ''}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final range = rangeSnapshot.data!;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Total Collected',
                                    '${range.totalCollectedLiters.toStringAsFixed(1)} L',
                                    Icons.waves,
                                    Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Peak Day',
                                    range.peakDayLabel,
                                    Icons.analytics,
                                    Colors.teal,
                                    subtitle: '${range.peakDayLiters.toStringAsFixed(1)} L',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Total Samples',
                                    '${range.sampleCount}',
                                    Icons.science_outlined,
                                    Colors.blueGrey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsMetric(
                                    'Total Events',
                                    '${range.collectionEventCount}',
                                    Icons.dashboard_outlined,
                                    Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Trend Analysis',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RepaintBoundary(
                              child: _buildTrendChart(
                                title: 'Daily Volume (L)',
                                points: range.points,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
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
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const DashboardPage(),
                transitionDuration: Duration.zero,
              ),
            );
          }

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

          if (index == 3) return;
        },
      ),
    );
  }

  Widget _buildAnalyticsMetric(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendChart({
    required String title,
    required List<DailyCollectedWaterPoint> points,
  }) {
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].totalCollectedLiters));
    }

    final maxY = points
        .map((e) => e.totalCollectedLiters)
        .fold<double>(0, (prev, item) => item > prev ? item : prev);
    final chartMaxY = maxY <= 0 ? 1.0 : (maxY * 1.3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF283593), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xFFECEFF1),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final day = DateFormat('MMM d').format(points[index].date);
                        
                        // Show fewer labels if too many points
                        if (points.length > 10 && index % (points.length ~/ 5) != 0 && index != points.length - 1 && index != 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF283593),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final item = points[index];
                        final dateStr = DateFormat('MMM d').format(item.date);
                        return LineTooltipItem(
                          '$dateStr\n${item.totalCollectedLiters.toStringAsFixed(1)} L',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    spots: spots,
                    color: const Color(0xFF5C6BC0),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeColor: const Color(0xFF5C6BC0),
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                          const Color(0xFF5C6BC0).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Combined bundle for parallel loading ---
class _DailyBundle {
  const _DailyBundle({required this.analytics, required this.trend});
  final CollectedWaterAnalytics analytics;
  final List<DailyCollectedWaterPoint> trend;
}

// --- Skeleton loaders (no external dependencies) ---

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height, this.borderRadius = 12});
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBox(width: 36, height: 36, borderRadius: 8),
              const SizedBox(width: 8),
              Expanded(child: _SkeletonBox(width: double.infinity, height: 12, borderRadius: 6)),
            ],
          ),
          const SizedBox(height: 16),
          const _SkeletonBox(width: 80, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 120, height: 14, borderRadius: 6),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final heights = [40.0, 60.0, 35.0, 80.0, 55.0, 70.0, 45.0];
                return _SkeletonBox(width: 16, height: heights[i], borderRadius: 4);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySectionSkeleton extends StatelessWidget {
  const _DailySectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(children: [
          Expanded(child: _MetricCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _MetricCardSkeleton()),
        ]),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _MetricCardSkeleton()),
        ]),
        SizedBox(height: 24),
        _ChartSkeleton(),
      ],
    );
  }
}

class _RangeSectionSkeleton extends StatelessWidget {
  const _RangeSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(children: [
          Expanded(child: _MetricCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _MetricCardSkeleton()),
        ]),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _MetricCardSkeleton()),
        ]),
        SizedBox(height: 24),
        _ChartSkeleton(),
      ],
    );
  }
}