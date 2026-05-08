import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> _abrirPermissao() async {
    // Agora isso abre a tela de configurações DE FATO quando o usuário clica no botão
    try {
      await UsageStats.grantUsagePermission();
    } catch (e) {
      // Ignora erro
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text('📵', style: TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 28),

            // Título
            const Text(
              'Scroff precisa da\nsua permissão',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // Descrição
            const Text(
              'Para monitorar seu tempo de tela e participar dos desafios com seus amigos, o Scroff precisa acessar as estatísticas de uso do seu celular.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888780),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),

            // Card de instruções
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Como liberar:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF085041),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Toque em "Permitir" abaixo',
                    style: TextStyle(color: Color(0xFF085041), fontSize: 13),
                  ),
                  Text(
                    '2. Encontre o app Scroff na lista',
                    style: TextStyle(color: Color(0xFF085041), fontSize: 13),
                  ),
                  Text(
                    '3. Ative a permissão',
                    style: TextStyle(color: Color(0xFF085041), fontSize: 13),
                  ),
                  Text(
                    '4. Volte para o app',
                    style: TextStyle(color: Color(0xFF085041), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Botão
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _abrirPermissao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Permitir acesso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Sem essa permissão o app não consegue\nmonitorar seu tempo de tela.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
            ),
          ],
        ),
      ),
    );
  }
}
