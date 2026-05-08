import 'package:usage_stats/usage_stats.dart';

class UsageService {
  // Agora ele APENAS checa a permissão, sem forçar a tela de configurações!
  static Future<bool> temPermissao() async {
    try {
      bool? isGranted = await UsageStats.checkUsagePermission();
      return isGranted ?? false;
    } catch (e) {
      return false;
    }
  }

  // Retorna o total de minutos de tela hoje
  static Future<int> getMinutosHoje() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);

      final dados = await UsageStats.queryUsageStats(inicio, agora);
      int totalMillis = 0;

      for (final app in dados) {
        totalMillis += int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
      }
      return totalMillis ~/ 60000; // Converte Milissegundos para Minutos
    } catch (e) {
      return 0;
    }
  }

  // Retorna o total de minutos de tela de ontem
  static Future<int> getMinutosOntem() async {
    try {
      final agora = DateTime.now();
      final hojeInicio = DateTime(agora.year, agora.month, agora.day);
      final ontemInicio = hojeInicio.subtract(const Duration(days: 1));

      final dados = await UsageStats.queryUsageStats(ontemInicio, hojeInicio);

      int totalMillis = 0;
      for (final app in dados) {
        totalMillis += int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
      }
      return totalMillis ~/ 60000;
    } catch (e) {
      return 0;
    }
  }

  // Retorna os top 3 apps mais usados hoje
  static Future<List<Map<String, dynamic>>> getTopApps() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);
      final dados = await UsageStats.queryUsageStats(inicio, agora);

      List<Map<String, dynamic>> listaApps = [];

      for (final app in dados) {
        int millis = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
        int minutos = millis ~/ 60000;

        if (minutos > 0 && app.packageName != null) {
          final nome = app.packageName!.split('.').last;
          final nomeFormatado = nome.toUpperCase() + nome.substring(1);
          listaApps.add({'nome': nomeFormatado, 'minutos': minutos});
        }
      }

      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );
      return listaApps.take(3).toList();
    } catch (e) {
      return [];
    }
  }
}
