import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hydro_harvest/services/manual_sensor_service.dart';

class ManualTdsCard extends StatelessWidget {
  const ManualTdsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ManualSensorService _service = ManualSensorService();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _service.latestTdsStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final double? value = data != null ? (data['value'] as num).toDouble() : null;
        
        // Parse timestamp (supports int milliseconds or String ISO8601)
        DateTime? ts;
        if (data != null && data['timestamp'] != null) {
           final raw = data['timestamp'];
           if (raw is int) {
             ts = DateTime.fromMillisecondsSinceEpoch(raw);
           } else if (raw is String) {
             ts = DateTime.tryParse(raw);
           }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
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
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.water_drop, color: Color(0xFF2196F3)),
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        'Total Dissolved Solids',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2196F3)),
                    tooltip: 'Log New Reading',
                    onPressed: () => _showEntryDialog(context, _service),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value != null ? value.toStringAsFixed(0) : '--',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'ppm',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF636E72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Timestamp Display with Stale Check
              Builder(
                builder: (context) {
                  if (ts == null) return const Text('No reading recorded yet', style: TextStyle(fontSize: 12, color: Colors.grey));
                  
                  final daysOld = DateTime.now().difference(ts).inDays;
                  final isStale = daysOld > 7;
                  
                  return Row(
                    children: [
                      Text(
                        'Last updated: ${DateFormat.yMMMd().add_jm().format(ts)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isStale ? Colors.red : const Color(0xFFAAB0B3),
                          fontWeight: isStale ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isStale) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text(
                          '(Update required)',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
                        ),
                      ]
                    ],
                  );
                }
              ),

              if (value != null) ...[
                const SizedBox(height: 15),
                _buildStatusIndicator(value, ts),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(double tds, DateTime? timestamp) {
    // Check if stale
    bool isStale = false;
    if (timestamp != null) {
       if (DateTime.now().difference(timestamp).inDays > 7) {
         isStale = true;
       }
    }

    if (isStale) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Data Expired - Please Measure Again',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    // Basic TDS guidelines:
    // < 300: Excellent
    // 300 - 600: Good
    // 600 - 900: Fair
    // > 1200: Unacceptable
    
    Color color;
    String label;
    
    if (tds < 300) {
      color = Colors.green;
      label = 'Excellent';
    } else if (tds < 600) {
      color = Colors.blue;
      label = 'Good';
    } else if (tds < 900) {
      color = Colors.orange;
      label = 'Fair';
    } else {
      color = Colors.red;
      label = 'Poor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showEntryDialog(BuildContext context, ManualSensorService service) {
    final TextEditingController _controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log TDS Reading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the value shown on your handheld TDS meter.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'TDS Value (ppm)',
                border: OutlineInputBorder(),
                suffixText: 'ppm',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_controller.text);
              if (val != null) {
                if(val < 0 || val > 5000) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Please enter a valid TDS value (0-5000 ppm)'))
                   );
                   return;
                }
                service.logTdsReading(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
