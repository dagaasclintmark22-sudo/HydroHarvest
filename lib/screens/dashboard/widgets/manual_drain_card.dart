import 'package:flutter/material.dart';

class ManualDrainCard extends StatelessWidget {
  final double ph;
  final double turbidity; // can be percent (0-100) or NTU

  const ManualDrainCard({super.key, required this.ph, required this.turbidity});

  @override
  Widget build(BuildContext context) {
    // pH classification
    String phClass;
    bool phAlert = false;
    if (ph < 7.0) {
      phClass = 'Acidic';
      phAlert = true;
    } else if (ph < 8.0) {
      phClass = 'Neutral';
      phAlert = false;
    } else {
      phClass = 'Alkaline';
      phAlert = true;
    }

    // Turbidity interpretation
    bool turbAlert = false;
    String turbDisplay;
    if (turbidity >= 0 && turbidity <= 100) {
      // treat as percent
      turbAlert = turbidity <= 80; // per project logic
      turbDisplay = '${turbidity.toStringAsFixed(0)}%';
    } else {
      turbAlert = turbidity > 5.0; // NTU threshold example
      turbDisplay = '${turbidity.toStringAsFixed(2)} NTU';
    }

    // Build reasons
    final reasons = <String>[];
    if (phAlert) {
      reasons.add(phClass == 'Acidic'
          ? 'pH is low (acidic) — can corrode system and harm plants'
          : 'pH is high (alkaline) — reduces nutrient availability');
    }
    if (turbAlert) {
      reasons.add('Turbidity is high — particles may clog filters and promote bacteria');
    }

    final needsDrain = reasons.isNotEmpty;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
        child: Row(
          children: [
            // Large status icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: needsDrain ? (phAlert && turbAlert ? Colors.red[600] : Colors.orange[400]) : Colors.green[400],
                shape: BoxShape.circle,
              ),
              child: Icon(
                needsDrain ? Icons.warning_amber_rounded : Icons.check,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Drain',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    needsDrain ? 'Action recommended' : 'No manual drain needed',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('pH: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('${ph.toStringAsFixed(2)} ($phClass)', style: TextStyle(color: Colors.black87)),
                      const SizedBox(width: 12),
                      Text('Turbidity: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(turbDisplay, style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                  if (needsDrain) ...[
                    const SizedBox(height: 8),
                    Text('Why this alert:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    for (final r in reasons)
                      Text('• $r', style: const TextStyle(fontSize: 13, color: Colors.black87)),
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
