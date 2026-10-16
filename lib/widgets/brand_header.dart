import 'package:flutter/material.dart';

const brandGradient = LinearGradient(
  colors: [Color(0xff1e3a5f), Color(0xff2563eb)],
);

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle = 'Novos Convertidos'});
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.church, color: Colors.white),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'IEADPE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ],
  );
}
