import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SensorDataCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color cardColor;
  final Color iconColor;
  final Color textColor;
  final Color? unitColor;

  const SensorDataCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    required this.cardColor,
    required this.iconColor,
    required this.textColor,
    this.unitColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // LEFT SIDE TEXT
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: textColor.withOpacity(0.8),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  value,
                  style: GoogleFonts.lora(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                if (unit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      unit!,
                      style: GoogleFonts.lora(
                        fontSize: 16,
                        color: unitColor ?? Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),

            // RIGHT SIDE ICON
            Icon(
              icon,
              size: 60,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
