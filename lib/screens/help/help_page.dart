import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          'Help & About',
          style: GoogleFonts.lora(
            color: const Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            title: 'How HydroHarvest Works',
            icon: Icons.water_drop_outlined,
            content: _buildHowItWorksContent(),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Water Safety Explanation',
            icon: Icons.health_and_safety_outlined,
            content: _buildWaterSafetyContent(),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Maintenance Guide',
            icon: Icons.build_circle_outlined,
            content: _buildMaintenanceContent(),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Disclaimer',
            icon: Icons.warning_amber_rounded,
            content: _buildDisclaimerContent(),
            isExpanded: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
    bool isExpanded = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF283593)),
        ),
        title: Text(
          title,
          style: GoogleFonts.lora(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3436),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksContent() {
    final steps = [
      {'title': 'Collection', 'desc': 'Valve opens when user press the Harvest System Lid to collect water.'},
      {'title': 'Filtration', 'desc': 'Water passes through physical filters to remove debris and particles.'},
      {'title': 'Purification', 'desc': 'UV light activates to kill bacteria and pathogens.'},
      {'title': 'Monitoring', 'desc': 'Sensors continuously check pH and turbidity levels.'},
      {'title': 'Ready', 'desc': 'Safe water is stored and ready for use.'},
    ];

    return Column(
      children: [
        // Simple diagram representation using Icons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            Icon(Icons.cloud, color: Colors.blue),
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            Icon(Icons.filter_alt, color: Colors.blueGrey),
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            Icon(Icons.light_mode, color: Colors.orange),
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF283593),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        step['desc']!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWaterSafetyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSafetyItem(
          'pH Level',
          'Indicates acidity or alkalinity. Water outside the safe range can taste bitter or corrode pipes.',
          'Safe Range: 6.5 - 8.5',
          Icons.science,
          Colors.purple,
        ),
        const SizedBox(height: 16),
        _buildSafetyItem(
          'Turbidity',
          'Measures cloudiness. High turbidity can shield bacteria from UV light, making purification less effective.',
          'Safe Limit: < 0.5 NTU (Clear)',
          Icons.opacity,
          Colors.brown,
        ),
        const SizedBox(height: 16),
        _buildSafetyItem(
          'UV Sterilization',
          'Ultraviolet light neutralizes harmful pathogens and bacteria that filters might miss.',
          'Status: Must be Active',
          Icons.light_mode,
          Colors.orange,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_user_outlined, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Real-time sensors continuously monitor water quality. Always check the dashboard status to ensure water is safe.',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyItem(String title, String desc, String range, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                range,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceContent() {
    final tasks = [
      {'task': 'Clean Tank', 'freq': 'Every 6 months', 'desc': 'Drain and scrub the tank to remove sediment.'},
      {'task': 'Replace Filters', 'freq': 'Every 3 months', 'desc': 'Change physical filters when flow reduces.'},
      {'task': 'Check UV Lamp', 'freq': 'Monthly', 'desc': 'Ensure the UV light is functioning correctly.'},
      {'task': 'Calibrate Sensors', 'freq': 'Monthly', 'desc': 'Use buffer solutions to recalibrate pH sensors.'},
    ];

    return Column(
      children: tasks.map((task) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(task['task']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task['freq']!,
                            style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      task['desc']!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDisclaimerContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Safety Warning',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Do not drink untreated water. Always check the dashboard for "Safe" status before consumption. Regular maintenance is essential to ensure water quality.',
            style: TextStyle(color: Colors.red[900], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
