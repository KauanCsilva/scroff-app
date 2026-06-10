import 'package:usage_stats/usage_stats.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class UsageService {
  // 1. FILTRO: Ignora processos do motor do Android, Launchers e o app Scroff
  static bool _deveIgnorar(String? packageName) {
    if (packageName == null) return true;

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

  static Future<bool> temPermissao() async {
    try {
      // Usa uma janela de 1 hora — mais confiável que 1 minuto
      // pois logo após desbloquear o celular a janela de 1min pode estar vazia
      DateTime agora = DateTime.now();
      DateTime umaHoraAtras = agora.subtract(const Duration(hours: 1));

      List<UsageInfo> stats = await UsageStats.queryUsageStats(
        umaHoraAtras,
        agora,
      );

      // Se retornou qualquer dado (mesmo vazio mas sem exception) = tem permissão
      // A exception é o que indica falta de permissão no Android
      return true;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 🛠️ MOTOR CORRIGIDO: Calcula o tempo exato e ignora bugs do Android
  // NOVO MOTOR: Consulta o passado para evitar uso fantasma em viradas de dia e snapshots
  // =========================================================================
  static Future<Map<String, int>> _calcularTempoExatoPorApp(
    DateTime inicio,
    DateTime fim,
  ) async {
    Map<String, int> tempoPorApp = {};
    Map<String, int> appsAbertos = {};

    try {
      // Puxa eventos desde 24h ANTES do início solicitado para achar a verdadeira origem da sessão
      DateTime queryStart = inicio.subtract(const Duration(days: 1));
      List<EventUsageInfo> eventos = await UsageStats.queryEvents(
        queryStart,
        fim,
      );

      int inicioEpoch = inicio.millisecondsSinceEpoch;
      int fimEpoch = fim.millisecondsSinceEpoch;

      for (var evento in eventos) {
        String pacote = evento.packageName ?? '';
        String tipo = evento.eventType ?? '';
        int timestamp = int.tryParse(evento.timeStamp ?? '0') ?? 0;
        if (timestamp == 0) continue;

        // GATILHO GLOBAL: TELA APAGADA (Evento 16) - Corta o tempo fantasma de bolso
        if (tipo == '16') {
          for (var openApp in appsAbertos.keys.toList()) {
            int start = appsAbertos[openApp]!;
            if (timestamp > start && !_deveIgnorar(openApp)) {
              int inicioValido = start < inicioEpoch ? inicioEpoch : start;
              int fimValido = timestamp > fimEpoch ? fimEpoch : timestamp;

              // Só contabiliza o que ocorreu estritamente dentro da janela de hoje
              if (fimValido > inicioValido) {
                int duracao = fimValido - inicioValido;
                tempoPorApp[openApp] = (tempoPorApp[openApp] ?? 0) + duracao;
              }
            }
            appsAbertos.remove(openApp);
          }
          continue;
        }

        if (_deveIgnorar(pacote)) continue;

        if (tipo == '1') {
          // ACTIVITY_RESUMED
          appsAbertos[pacote] = timestamp;
        } else if (tipo == '2' || tipo == '23') {
          // ACTIVITY_PAUSED / STOPPED
          // Só calcula se temos CERTEZA de que o app estava aberto (ignora os eventos orfaos do OS)
          if (appsAbertos.containsKey(pacote)) {
            int start = appsAbertos[pacote]!;

            int inicioValido = start < inicioEpoch ? inicioEpoch : start;
            int fimValido = timestamp > fimEpoch ? fimEpoch : timestamp;

            if (fimValido > inicioValido) {
              int duracao = fimValido - inicioValido;
              tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
            }
            appsAbertos.remove(pacote);
          }
        }
      }

      int agoraEpoch = DateTime.now().millisecondsSinceEpoch;
      int limite = fimEpoch < agoraEpoch ? fimEpoch : agoraEpoch;

      for (var pacote in appsAbertos.keys) {
        int start = appsAbertos[pacote]!;
        if (!_deveIgnorar(pacote)) {
          int inicioValido = start < inicioEpoch ? inicioEpoch : start;
          if (limite > inicioValido) {
            int duracao = limite - inicioValido;
            tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
          }
        }
      }
    } catch (e) {
      print("Erro no cálculo de eventos: $e");
    }

    return tempoPorApp;
  }

  static Future<String> _buscarNomeApp(String pacote) async {
    try {
      // 👇 FIX AQUI: Passamos 'null' para o BuiltWith?
      AppInfo? appInfo = await InstalledApps.getAppInfo(pacote, null);
      if (appInfo != null && appInfo.name != null && appInfo.name!.isNotEmpty) {
        return appInfo.name!;
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
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        true,
        false,
        "",
      );

      List<Map<String, dynamic>> lista = apps
          .where((app) => !_deveIgnorar(app.packageName))
          .map(
            (app) => {
              'id': app.packageName,
              'nome': app.name ?? app.packageName,
            },
          )
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
      DateTime queryStart = inicioDoDia.subtract(const Duration(days: 1));
      List<EventUsageInfo> eventos = await UsageStats.queryEvents(
        queryStart,
        agora,
      );

      Map<String, int> appsAbertos = {};
      int inicioEpoch = inicioDoDia.millisecondsSinceEpoch;

      for (var evento in eventos) {
        String pacote = evento.packageName ?? '';
        String tipo = evento.eventType ?? '';
        int timestamp = int.tryParse(evento.timeStamp ?? '0') ?? 0;
        if (timestamp == 0) continue;

        if (tipo == '16') {
          for (var openApp in appsAbertos.keys.toList()) {
            int start = appsAbertos[openApp]!;
            if (timestamp > start && !_deveIgnorar(openApp)) {
              int inicioValido = start < inicioEpoch ? inicioEpoch : start;
              if (timestamp > inicioValido) {
                _distribuirTempoPorHora(inicioValido, timestamp, usoPorHora);
              }
            }
            appsAbertos.remove(openApp);
          }
          continue;
        }

        if (_deveIgnorar(pacote)) continue;

        if (tipo == '1') {
          appsAbertos[pacote] = timestamp;
        } else if (tipo == '2' || tipo == '23') {
          if (appsAbertos.containsKey(pacote)) {
            int start = appsAbertos[pacote]!;
            int inicioValido = start < inicioEpoch ? inicioEpoch : start;

            if (timestamp > inicioValido) {
              _distribuirTempoPorHora(inicioValido, timestamp, usoPorHora);
            }
            appsAbertos.remove(pacote);
          }
        }
      }

      int limite = agora.millisecondsSinceEpoch;
      for (var openApp in appsAbertos.keys) {
        int start = appsAbertos[openApp]!;
        if (limite > start && !_deveIgnorar(openApp)) {
          int inicioValido = start < inicioEpoch ? inicioEpoch : start;
          if (limite > inicioValido) {
            _distribuirTempoPorHora(inicioValido, limite, usoPorHora);
          }
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
