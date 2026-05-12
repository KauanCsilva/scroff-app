import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

class PermissionScreen extends StatelessWidget {
  // Removi o callback daqui para simplificar e evitar o conflito
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📵', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text(
              'Acesso Necessário',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ative o Scroff na tela que vai abrir para podermos contar seu tempo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Apenas abre a configuração.
                  // O Android cuida do resto e o AppRoot detecta quando você voltar.
                  UsageStats.grantUsagePermission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                ),
                child: const Text('ABRIR CONFIGURAÇÕES'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
