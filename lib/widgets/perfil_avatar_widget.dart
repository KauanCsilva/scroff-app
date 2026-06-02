import 'package:flutter/material.dart';

class PerfilAvatarWidget extends StatelessWidget {
  final int minutosDeTela;
  final String iconeId;

  const PerfilAvatarWidget({
    super.key,
    required this.minutosDeTela,
    this.iconeId = 'padrao',
  });

  IconData _obterIcone() {
    switch (iconeId) {
      case 'foguete':
        return Icons.rocket_launch;
      case 'ninja':
        return Icons.sports_martial_arts;
      case 'coroa':
        return Icons.workspace_premium;
      case 'diamante':
        return Icons.diamond;
      case 'cerebro':
        return Icons.psychology;
      case 'meditacao':
        return Icons.self_improvement;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color corAura = const Color(0xFF1D9E75); // Focado
    if (minutosDeTela >= 120 && minutosDeTela < 240) corAura = Colors.orange;
    if (minutosDeTela >= 240) corAura = Colors.redAccent;

    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: corAura.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: corAura.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Icon(_obterIcone(), size: 32, color: Colors.black87),
    );
  }
}
