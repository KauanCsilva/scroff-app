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
      DateTime agora = DateTime.now();
      DateTime umMinutoAtras = agora.subtract(const Duration(minutes: 1));

      List<UsageInfo> stats = await UsageStats.queryUsageStats(
        umMinutoAtras,
        agora,
      );
      return stats.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 🛠️ MOTOR CORRIGIDO: Calcula o tempo exato e ignora bugs do Android
  // =========================================================================
  static Future<Map<String, int>> _calcularTempoExatoPorApp(
    DateTime inicio,
    DateTime fim,
  ) async {
    Map<String, int> tempoPorApp = {};
    Map<String, int> appsAbertos = {};
    Set<String> appsJaVistos = {}; // Filtro Anti-Eventos Fantasmas

    try {
      List<EventUsageInfo> eventos = await UsageStats.queryEvents(inicio, fim);

      for (var evento in eventos) {
        String? pacote = evento.packageName;
        if (_deveIgnorar(pacote)) continue;

        String tipo = evento.eventType ?? '';
        int timestamp = int.tryParse(evento.timeStamp ?? '0') ?? 0;
        if (timestamp == 0) continue;

        if (tipo == '1') {
          // App abriu (foi para o primeiro plano)
          appsAbertos[pacote!] = timestamp;
          appsJaVistos.add(pacote);
        } else if (tipo == '2') {
          // App fechou (foi para o segundo plano)
          if (appsAbertos.containsKey(pacote)) {
            // Fluxo Normal: Sabemos quando abriu, calculamos a diferença
            int start = appsAbertos[pacote!]!;
            int duracao = timestamp - start;
            if (duracao > 0)
              tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
            appsAbertos.remove(pacote);
          } else {
            // Fluxo de Exceção: O app fechou, mas não vimos ele abrir.
            // Isso acontece se ele estava aberto desde antes da meia-noite.
            // MAS só fazemos isso se for a PRIMEIRA vez que vemos ele hoje.
            if (!appsJaVistos.contains(pacote!)) {
              int start = inicio.millisecondsSinceEpoch;
              int duracao = timestamp - start;
              if (duracao > 0)
                tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
              appsJaVistos.add(pacote);
            }
          }
        }
      }

      // Finaliza a conta dos apps que ainda estão abertos neste exato segundo
      int tempoFim = fim.millisecondsSinceEpoch;
      int agora = DateTime.now().millisecondsSinceEpoch;
      int limite = tempoFim < agora ? tempoFim : agora;

      for (var pacote in appsAbertos.keys) {
        int start = appsAbertos[pacote]!;
        if (limite > start) {
          int duracao = limite - start;
          tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
        }
      }
    } catch (e) {
      print("Erro no cálculo de eventos: $e");
    }

    return tempoPorApp;
  }

  static Future<String> _buscarNomeApp(String pacote) async {
    try {
      Application? appInfo = await DeviceApps.getApp(pacote);
      if (appInfo != null) {
        return appInfo.appName;
      } else {
        final partes = pacote.split('.');
        final ultimoNome = partes.last;
        if (ultimoNome.isNotEmpty) {
          return ultimoNome.substring(0, 1).toUpperCase() +
              ultimoNome.substring(1).toLowerCase();
        }
      }
    } catch (e) {}
    return 'Desconhecido';
  }

  static Future<int> getMinutosHoje() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);

      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        inicio,
        agora,
      );

      int totalMillis = 0;
      for (var millis in tempoPorApp.values) {
        totalMillis += millis;
      }

      return totalMillis ~/ 60000;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getMinutosOntem() async {
    try {
      final agora = DateTime.now();
      final hojeInicio = DateTime(agora.year, agora.month, agora.day);
      final ontemInicio = hojeInicio.subtract(const Duration(days: 1));

      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        ontemInicio,
        hojeInicio,
      );

      int totalMillis = 0;
      for (var millis in tempoPorApp.values) {
        totalMillis += millis;
      }
      return totalMillis ~/ 60000;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getTopApps() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);

      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        inicio,
        agora,
      );
      List<Map<String, dynamic>> listaApps = [];

      for (String pacote in tempoPorApp.keys) {
        int minutos = tempoPorApp[pacote]! ~/ 60000;
        if (minutos > 0) {
          String nomeReal = await _buscarNomeApp(pacote);
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
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

  static Future<List<Map<String, dynamic>>> getTodosApps() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);

      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        inicio,
        agora,
      );
      List<Map<String, dynamic>> listaApps = [];

      for (String pacote in tempoPorApp.keys) {
        int minutos = tempoPorApp[pacote]! ~/ 60000;
        if (minutos > 0) {
          String nomeReal = await _buscarNomeApp(pacote);
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }

      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );
      return listaApps;
    } catch (e) {
      return [];
    }
  }

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

      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        ontemInicio,
        hojeInicio,
      );
      List<Map<String, dynamic>> listaApps = [];

      for (String pacote in tempoPorApp.keys) {
        int minutos = tempoPorApp[pacote]! ~/ 60000;
        if (minutos > 0) {
          String nomeReal = await _buscarNomeApp(pacote);
          listaApps.add({'nome': nomeReal, 'minutos': minutos});
        }
      }

      listaApps.sort(
        (a, b) => (b['minutos'] as int).compareTo(a['minutos'] as int),
      );
      return listaApps.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAppsNoHorario(
    DateTime inicio,
    DateTime fim,
  ) async {
    try {
      Map<String, int> tempoPorApp = await _calcularTempoExatoPorApp(
        inicio,
        fim,
      );
      List<Map<String, dynamic>> listaApps = [];

      for (String pacote in tempoPorApp.keys) {
        int minutos = tempoPorApp[pacote]! ~/ 60000;
        if (minutos > 0) {
          String nomeReal = await _buscarNomeApp(pacote);
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
          int start = appsAbertos.containsKey(pacote)
              ? appsAbertos[pacote!]!
              : inicioDoDia.millisecondsSinceEpoch;

          if (timestamp > start) {
            _distribuirTempoPorHora(start, timestamp, usoPorHora);
          }
          appsAbertos.remove(pacote);
        }
      }

      int limite = agora.millisecondsSinceEpoch;
      for (var pacote in appsAbertos.keys) {
        int start = appsAbertos[pacote]!;
        if (limite > start) {
          _distribuirTempoPorHora(start, limite, usoPorHora);
        }
      }
    } catch (e) {}

    return usoPorHora;
  }

  static void _distribuirTempoPorHora(
    int startEpoch,
    int endEpoch,
    List<double> usoPorHora,
  ) {
    DateTime dtStart = DateTime.fromMillisecondsSinceEpoch(
      startEpoch,
      isUtc: true,
    ).toLocal();
    DateTime dtEnd = DateTime.fromMillisecondsSinceEpoch(
      endEpoch,
      isUtc: true,
    ).toLocal();

    DateTime atual = dtStart;

    while (atual.isBefore(dtEnd)) {
      DateTime proximaHora = DateTime(
        atual.year,
        atual.month,
        atual.day,
        atual.hour + 1,
      );

      if (proximaHora.isAfter(dtEnd)) {
        double minutos = dtEnd.difference(atual).inMilliseconds / 60000.0;
        if (atual.hour >= 0 && atual.hour < 24 && minutos > 0) {
          usoPorHora[atual.hour] += minutos;
        }
        break;
      } else {
        double minutos = proximaHora.difference(atual).inMilliseconds / 60000.0;
        if (atual.hour >= 0 && atual.hour < 24 && minutos > 0) {
          usoPorHora[atual.hour] += minutos;
        }
        atual = proximaHora;
      }
    }
  }
}
