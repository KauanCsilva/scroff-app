import 'package:flutter/material.dart';
import '../services/loja_service.dart';

class PerfilAvatarWidget extends StatelessWidget {
  final int minutosDeTela;
  final String iconeId;

  const PerfilAvatarWidget({
    super.key,
    required this.minutosDeTela,
    this.iconeId = 'avatar_basicof',
  });

  @override
  Widget build(BuildContext context) {
    Color corAura = const Color(0xFF1D9E75);
    if (minutosDeTela >= 120 && minutosDeTela < 240) corAura = Colors.orange;
    if (minutosDeTela >= 240) corAura = Colors.redAccent;

    ItemLoja? itemAtual;
    try {
      itemAtual = LojaService.catalogo.firstWhere((item) => item.id == iconeId);
    } catch (e) {
      itemAtual = null;
    }

    Widget visualAvatar;

    if (itemAtual != null && itemAtual.imagemPath != null && itemAtual.imagemPath!.isNotEmpty) {
      visualAvatar = ClipRRect(
        borderRadius: BorderRadius.circular(16), // Arredondamento interno ajustado para o novo tamanho
        child: Image.asset(
          itemAtual.imagemPath!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      );
    } else {
      visualAvatar = Icon(
        itemAtual?.icone ?? Icons.person,
        size: 48, // Ícone de fallback aumentado proporcionalmente
        color: Colors.black87,
      );
    }

    return Container(
      width: 90,
      height: 155,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Arredondamento externo ajustado
        border: Border.all(color: corAura.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: corAura.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: visualAvatar,
    );
  }
}