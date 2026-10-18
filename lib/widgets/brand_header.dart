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
      Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 10),
        decoration: const BoxDecoration(
          color: Color(0x33ffffff),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const ExcludeSemantics(
          child: Icon(Icons.church, color: Colors.white, size: 20),
        ),
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
                fontSize: 18,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xffdbeafe), fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}
