import 'package:usage_stats/usage_stats.dart';
import 'package:device_apps/device_apps.dart';

class UsageService {
  // 1. FILTRO: Ignora processos do motor do Android, Launchers e o app Scroff
  static bool _deveIgnorar(String? packageName) {
    if (packageName == null) {
      return true;
    }

    final p = packageName.toLowerCase();

    if (p == 'android' ||
        p == 'com.android.systemui' ||
        p == 'com.android.settings') {
      return true;
    }
    if (p.contains('launcher') ||
        p.contains('miui.home') ||
        p.contains('sec.android.app')) {
      return true;
    }
    if (p.startsWith('com.android.providers')) {
      return true;
    }
    if (p.contains('scroff')) {
      return true;
    }

    return false;
  }

  // Checa permissão silenciosamente
  static Future<bool> temPermissao() async {
    try {
      // Em vez de perguntar se tem permissão, vamos tentar USAR a permissão.
      // Se ele conseguir pegar o tempo de tela do último minuto, é porque está liberado!
      DateTime agora = DateTime.now();
      DateTime umMinutoAtras = agora.subtract(const Duration(minutes: 1));

      List<UsageInfo> stats = await UsageStats.queryUsageStats(
        umMinutoAtras,
        agora,
      );

      // Se a lista não estiver vazia, o Android deixou ler -> Permissão OK!
      return stats.isNotEmpty;
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
        if (_deveIgnorar(app.packageName)) continue;
        totalMillis += int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
      }
      return totalMillis ~/ 60000;
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
        if (_deveIgnorar(app.packageName)) continue;
        totalMillis += int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
      }
      return totalMillis ~/ 60000;
    } catch (e) {
      return 0;
    }
  }

  // Retorna os top 3 apps mais usados hoje com seus NOMES REAIS
  static Future<List<Map<String, dynamic>>> getTopApps() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);
      final dados = await UsageStats.queryUsageStats(inicio, agora);

      List<Map<String, dynamic>> listaApps = [];

      for (final app in dados) {
        if (_deveIgnorar(app.packageName)) continue;

        int millis = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
        int minutos = millis ~/ 60000;

        if (minutos > 0 && app.packageName != null) {
          String nomeReal = 'Desconhecido';

          // ==========================================
          // MÁGICA AQUI: Pede o nome verdadeiro do app
          // ==========================================
          try {
            // Removidos os argumentos extras. O pacote já faz a busca padrão!
            Application? appInfo = await DeviceApps.getApp(app.packageName!);

            if (appInfo != null) {
              nomeReal = appInfo.appName;
            } else {
              // Fallback de segurança com o bug das letras corrigido
              final partes = app.packageName!.split('.');
              final ultimoNome = partes.last;
              if (ultimoNome.isNotEmpty) {
                nomeReal =
                    ultimoNome.substring(0, 1).toUpperCase() +
                    ultimoNome.substring(1).toLowerCase();
              }
            }
          } catch (e) {
            // Se der erro na busca, mantém 'Desconhecido'
          }
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }

      // Ordena do maior para o menor
      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );

      return listaApps.take(3).toList();
    } catch (e) {
      return [];
    }
  }

  // Retorna todos os apps instalados no dispositivo (excluindo sistema)
  static Future<List<Map<String, dynamic>>> getAppsInstalados() async {
    try {
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      List<Map<String, dynamic>> lista = apps
          .where((app) => !_deveIgnorar(app.packageName))
          .map((app) => {'id': app.packageName, 'nome': app.appName})
          .toList();

      lista.sort(
        (a, b) => (a['nome'] as String).compareTo(b['nome'] as String),
      );

      return lista;
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTopAppsOntem() async {
    try {
      final agora = DateTime.now();
      final hojeInicio = DateTime(agora.year, agora.month, agora.day);
      final ontemInicio = hojeInicio.subtract(const Duration(days: 1));

      final dados = await UsageStats.queryUsageStats(ontemInicio, hojeInicio);

      List<Map<String, dynamic>> listaApps = [];

      for (final app in dados) {
        if (_deveIgnorar(app.packageName)) continue;

        int millis = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
        int minutos = millis ~/ 60000;

        if (minutos > 0 && app.packageName != null) {
          String nomeReal = 'Desconhecido';

          try {
            Application? appInfo = await DeviceApps.getApp(app.packageName!);
            if (appInfo != null) {
              nomeReal = appInfo.appName;
            } else {
              final partes = app.packageName!.split('.');
              final ultimoNome = partes.last;
              if (ultimoNome.isNotEmpty) {
                nomeReal =
                    ultimoNome.substring(0, 1).toUpperCase() +
                    ultimoNome.substring(1).toLowerCase();
              }
            }
          } catch (e) {}
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }

      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );
      return listaApps
          .take(10)
          .toList(); // Traz os 10 mais usados para garantir
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAppsNoHorario(
    DateTime inicio,
    DateTime fim,
  ) async {
    try {
      final dados = await UsageStats.queryUsageStats(inicio, fim);
      List<Map<String, dynamic>> listaApps = [];

      for (final app in dados) {
        if (_deveIgnorar(app.packageName)) continue;

        int millis = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;
        int minutos = millis ~/ 60000;

        if (minutos > 0 && app.packageName != null) {
          String nomeReal = 'Desconhecido';
          try {
            Application? appInfo = await DeviceApps.getApp(app.packageName!);
            if (appInfo != null) {
              nomeReal = appInfo.appName;
            } else {
              final partes = app.packageName!.split('.');
              final ultimoNome = partes.last;
              if (ultimoNome.isNotEmpty) {
                nomeReal =
                    ultimoNome.substring(0, 1).toUpperCase() +
                    ultimoNome.substring(1).toLowerCase();
              }
            }
          } catch (e) {}
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }
      return listaApps;
    } catch (e) {
      return [];
    }
  }

  static Future<List<double>> getUsoPorHora() async {
    List<double> usoPorHora = List.filled(24, 0.0);

    DateTime agora = DateTime.now();
    DateTime inicioDoDia = DateTime(agora.year, agora.month, agora.day);

    try {
      List<EventUsageInfo> eventos = await UsageStats.queryEvents(
        inicioDoDia,
        agora,
      );
      Map<String, int> appsAbertos = {};

      for (var evento in eventos) {
        String? pacote = evento.packageName;

        if (_deveIgnorar(pacote)) continue;

        String tipo = evento.eventType ?? '';
        int timestamp = int.tryParse(evento.timeStamp ?? '0') ?? 0;

        if (timestamp == 0) continue;

        if (tipo == '1') {
          appsAbertos[pacote!] = timestamp;
        } else if (tipo == '2') {
          if (appsAbertos.containsKey(pacote)) {
            int inicio = appsAbertos[pacote!]!;
            int fim = timestamp;

            double minutosDeUso = (fim - inicio) / 60000.0;

            DateTime horaDoEvento = DateTime.fromMillisecondsSinceEpoch(inicio);
            int hora = horaDoEvento.hour;

            if (minutosDeUso > 0 && hora >= 0 && hora < 24) {
              usoPorHora[hora] += minutosDeUso;
            }

            appsAbertos.remove(pacote);
          }
        }
      }
    } catch (e) {
      // Retorna a lista vazia se houver erro
    }

    return usoPorHora;
  }

  // NOVO: Retorna TODOS os apps usados hoje, ordenados por tempo (Trazido da sua versão)
  static Future<List<Map<String, dynamic>>> getTodosApps() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);
      final dados = await UsageStats.queryUsageStats(inicio, agora);

      // 1. Agrupar e somar os milissegundos
      Map<String, int> tempoPorApp = {};

      for (final app in dados) {
        if (_deveIgnorar(app.packageName)) continue;

        String pacote = app.packageName!;
        int millis = int.tryParse(app.totalTimeInForeground ?? '0') ?? 0;

        if (tempoPorApp.containsKey(pacote)) {
          tempoPorApp[pacote] = tempoPorApp[pacote]! + millis;
        } else {
          tempoPorApp[pacote] = millis;
        }
      }

      List<Map<String, dynamic>> listaApps = [];

      // 2. Processar a lista agrupada
      for (String pacote in tempoPorApp.keys) {
        int minutos = tempoPorApp[pacote]! ~/ 60000;

        if (minutos > 0) {
          String nomeReal = 'Desconhecido';

          try {
            Application? appInfo = await DeviceApps.getApp(pacote);
            if (appInfo != null) {
              nomeReal = appInfo.appName;
            } else {
              final partes = pacote.split('.');
              final ultimoNome = partes.last;
              if (ultimoNome.isNotEmpty) {
                nomeReal =
                    ultimoNome.substring(0, 1).toUpperCase() +
                    ultimoNome.substring(1).toLowerCase();
              }
            }
          } catch (e) {}
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }

      // Ordena do maior para o menor
      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );

      return listaApps;
    } catch (e) {
      return [];
    }
  }
}
