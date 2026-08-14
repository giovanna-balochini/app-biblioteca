import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  final String label;
  final String? value;

  const InfoTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final valorValido = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              valorValido ? value! : 'Não informado',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF2A2A38)),
            ),
          ),
        ],
      ),
    );
  }
}
