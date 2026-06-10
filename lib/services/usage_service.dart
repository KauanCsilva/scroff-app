import 'package:flutter/foundation.dart';
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
      // Primeiro tenta a verificação nativa
      bool? concedido = await UsageStats.checkUsagePermission();

      // Se retornou false com certeza, não tem permissão
      if (concedido == false) return false;

      // Se retornou null ou true, confirma com uma query real
      // pois checkUsagePermission pode dar falso positivo em alguns dispositivos
      DateTime agora = DateTime.now();
      DateTime umDiaAtras = agora.subtract(const Duration(days: 1));
      await UsageStats.queryUsageStats(umDiaAtras, agora);

      // Se chegou aqui sem exception, tem permissão de verdade
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
            int start = appsAbertos[pacote] ?? 0;

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
        int start = appsAbertos[pacote] ?? 0;
        if (!_deveIgnorar(pacote)) {
          int inicioValido = start < inicioEpoch ? inicioEpoch : start;
          if (limite > inicioValido) {
            int duracao = limite - inicioValido;
            tempoPorApp[pacote] = (tempoPorApp[pacote] ?? 0) + duracao;
          }
        }
      }
    } catch (e) {
      debugPrint("Erro no cálculo de eventos: $e");
    }

    return tempoPorApp;
  }

  static Future<String> _buscarNomeApp(String pacote) async {
    try {
      AppInfo? appInfo = await InstalledApps.getAppInfo(pacote, null);
      final nome = appInfo?.name;
      if (nome != null && nome.isNotEmpty) {
        return nome;
      }
      // Fallback: usa a última parte do package name
      final partes = pacote.split('.');
      final ultimoNome = partes.last;
      if (ultimoNome.isNotEmpty) {
        return ultimoNome.substring(0, 1).toUpperCase() +
            ultimoNome.substring(1).toLowerCase();
      }
    } catch (_) {}
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

      final pacotesComUso = tempoPorApp.entries
          .where((e) => e.value ~/ 60000 > 0)
          .toList();

      final nomes = await Future.wait(
        pacotesComUso.map((e) => _buscarNomeApp(e.key)),
      );

      List<Map<String, dynamic>> listaApps = List.generate(
        pacotesComUso.length,
        (i) => {'nome': nomes[i], 'minutos': pacotesComUso[i].value ~/ 60000},
      );

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

      final pacotesComUso = tempoPorApp.entries
          .where((e) => e.value ~/ 60000 > 0)
          .toList();

      final nomes = await Future.wait(
        pacotesComUso.map((e) => _buscarNomeApp(e.key)),
      );

      List<Map<String, dynamic>> listaApps = List.generate(
        pacotesComUso.length,
        (i) => {'nome': nomes[i], 'minutos': pacotesComUso[i].value ~/ 60000},
      );

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

      final pacotesComUso = tempoPorApp.entries
          .where((e) => e.value ~/ 60000 > 0)
          .toList();

      final nomes = await Future.wait(
        pacotesComUso.map((e) => _buscarNomeApp(e.key)),
      );

      List<Map<String, dynamic>> listaApps = List.generate(
        pacotesComUso.length,
        (i) => {'nome': nomes[i], 'minutos': pacotesComUso[i].value ~/ 60000},
      );

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

      final pacotesComUso = tempoPorApp.entries
          .where((e) => e.value ~/ 60000 > 0)
          .toList();

      final nomes = await Future.wait(
        pacotesComUso.map((e) => _buscarNomeApp(e.key)),
      );

      return List.generate(
        pacotesComUso.length,
        (i) => {'nome': nomes[i], 'minutos': pacotesComUso[i].value ~/ 60000},
      );
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
            int start = appsAbertos[pacote] ?? 0;
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
