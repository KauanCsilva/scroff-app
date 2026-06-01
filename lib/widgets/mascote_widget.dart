import 'package:flutter/material.dart';

class MascoteWidget extends StatelessWidget {
  final int minutosDeTela;
  final String acessorio; // Ex: 'chapeu', 'oculos', 'coroa', 'nenhum'

  const MascoteWidget({
    super.key,
    required this.minutosDeTela,
    this.acessorio = 'nenhum',
  });

  @override
  Widget build(BuildContext context) {
    Color corCorpo = const Color(0xFF81C784); // Verde saudável
    IconData olhos = Icons.visibility; // Olhos abertos
    IconData boca = Icons.sentiment_satisfied_alt; // Sorriso

    if (minutosDeTela >= 120 && minutosDeTela < 240) {
      corCorpo = const Color(0xFFFFD54F); // Amarelo (Aviso)
      olhos = Icons.remove; // Olhos semicerrados (tédio)
      boca = Icons.sentiment_neutral; // Boca reta
    } else if (minutosDeTela >= 240) {
      corCorpo = const Color(0xFFE57373); // Vermelho (Doente/Exausto)
      olhos = Icons.close; // Olhos fechados
      boca = Icons.sentiment_very_dissatisfied; // Triste
    }

    return SizedBox(
      width: 100,
      height: 120,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // CAMADA 1: AURA (Sombras)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: corCorpo.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // CAMADA 2: O CORPO DO MASCOTE (Forma de "Pou" ou Gota)
          Container(
            width: 80,
            height: 90,
            decoration: BoxDecoration(
              color: corCorpo,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.black12, width: 2),
            ),
          ),

          // CAMADA 3: O ROSTO (Muda com o tempo de tela)
          Positioned(
            top: 25,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(olhos, size: 18, color: Colors.black87),
                    const SizedBox(width: 10),
                    Icon(olhos, size: 18, color: Colors.black87),
                  ],
                ),
                const SizedBox(height: 2),
                Icon(boca, size: 24, color: Colors.black87),
              ],
            ),
          ),

          // CAMADA 4: ACESSÓRIOS EQUIPADOS DA LOJA
          if (acessorio == 'chapeu')
            const Positioned(
              top: -20,
              child: Text('🧢', style: TextStyle(fontSize: 40)),
            ),
          if (acessorio == 'oculos')
            const Positioned(
              top: 15,
              child: Text('🕶️', style: TextStyle(fontSize: 45)),
            ),
          if (acessorio == 'coroa')
            const Positioned(
              top: -25,
              child: Text('👑', style: TextStyle(fontSize: 45)),
            ),
        ],
      ),
    );
  }
}
