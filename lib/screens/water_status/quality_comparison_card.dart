import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QualityComparisonCard extends StatelessWidget {
  final double currentPh;
  final double currentTurbidity;

  const QualityComparisonCard({
    super.key,
    required this.currentPh,
    required this.currentTurbidity,
  });

  // WHO Standards
  static const double minPh = 6.5;
  static const double maxPh = 8.5;
  static const double maxTurbidity = 5.0; // NTU

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
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
          Text(
            'Quality Benchmark',
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparison against WHO Drinking Water Standards',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          _buildComparisonRow(
            label: 'pH Level',
            value: currentPh.toStringAsFixed(1),
            standard: '$minPh - $maxPh',
            isSafe: currentPh >= minPh && currentPh <= maxPh,
            unit: '',
          ),
          const Divider(height: 32),
          _buildComparisonRow(
            label: 'Turbidity',
            value: currentTurbidity.toStringAsFixed(1),
            standard: '< $maxTurbidity',
            isSafe: currentTurbidity <= maxTurbidity,
            unit: ' NTU',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF1E88E5), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Values within the "Standard" range are considered safe for conventional drinking sources.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String value,
    required String standard,
    required bool isSafe,
    required String unit,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Standard: $standard$unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  '$value$unit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSafe ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSafe ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isSafe ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isSafe ? 'Within Limits' : 'Action Required',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSafe ? const Color(0xFF00B894) : const Color(0xFFFF7675),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
