import 'package:flutter/material.dart';

class WaterPurityIndicator extends StatelessWidget {
  final double purity;

  const WaterPurityIndicator({super.key, required this.purity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: purity),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                strokeAlign: 7,
                backgroundColor: Colors.indigo.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF283593)),
              );
            },
          ),
          Text(
            '${(purity * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF283593),
            ),
          ),
        ],
      ),
    );
  }
}
