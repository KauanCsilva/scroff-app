import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'usage_service.dart';
import 'boss_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sincronizarDadosDiarios() async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      if (uid.isEmpty) return;

      int minutosTotais = await UsageService.getMinutosHoje();
      List<Map<String, dynamic>> appsUsados = await UsageService.getTopApps();

      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      int minutosDescontados = 0;
      int xpAtual = 0;
      int nivelAtual = 1;
      int moedasAtuais = 0;
      int ofensivaAtual = 1;
      String ultimaSincronizacao = "";
      List<dynamic> whitelist = [];
      List<dynamic> badgesAtuais = [];

      DateTime agora = DateTime.now();
      DateTime hoje = DateTime(agora.year, agora.month, agora.day);

      if (userDoc.exists) {
        Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
        whitelist = dados['whitelist'] ?? [];
        badgesAtuais = dados['badges'] ?? [];
        xpAtual = dados['xp'] ?? 0;
        nivelAtual = dados['nivel'] ?? 1;
        moedasAtuais = dados['moedas'] ?? 0;
        ofensivaAtual = dados['ofensiva_dias'] ?? 1;
        ultimaSincronizacao = dados['ultima_sincronizacao'] ?? "";

        for (var app in appsUsados) {
          String nomeApp = app['nome'].toString().toLowerCase();
          for (var itemAprovado in whitelist) {
            if (nomeApp.contains(itemAprovado.toString().toLowerCase())) {
              minutosDescontados += (app['minutos'] as int);
              break;
            }
          }
        }
      }

      int novaOfensiva = 1;
      bool virouODia = false;
      String dataHojeStr = "${agora.year}-${agora.month}-${agora.day}";

      if (ultimaSincronizacao.isNotEmpty) {
        List<String> partes = ultimaSincronizacao.split('-');
        if (partes.length == 3) {
          DateTime ultimaData = DateTime(
            int.parse(partes[0]),
            int.parse(partes[1]),
            int.parse(partes[2]),
          );
          int diferencaDias = hoje.difference(ultimaData).inDays;

          if (diferencaDias == 1) {
            novaOfensiva = ofensivaAtual + 1;
            virouODia = true;
          } else if (diferencaDias == 0) {
            novaOfensiva = ofensivaAtual;
          } else if (diferencaDias > 1) {
            novaOfensiva = 1;
            virouODia = true;
          }
        }
      } else {
        virouODia = true;
      }

      int minutosFinaisRanking = minutosTotais - minutosDescontados;
      if (minutosFinaisRanking < 0) minutosFinaisRanking = 0;

      int xpNecessario = nivelAtual * 1000;
      bool correcaoLevelUp = false;
      while (xpAtual >= xpNecessario) {
        xpAtual -= xpNecessario;
        nivelAtual++;
        xpNecessario = nivelAtual * 1000;
        correcaoLevelUp = true;
      }
      if (correcaoLevelUp) {
        print(
          "Corretor de Nível ativado! Usuário ajustado para o Nível $nivelAtual.",
        );
      }

      List<String> novasBadges = [];
      if (novaOfensiva >= 7 && !badgesAtuais.contains('badge_7_dias')) {
        novasBadges.add('badge_7_dias');
      }

      await userRef.set({
        'minutos_hoje': minutosFinaisRanking,
        'ultima_sincronizacao': dataHojeStr,
        'xp': xpAtual,
        'nivel': nivelAtual,
        'ofensiva_dias': novaOfensiva,
        if (novasBadges.isNotEmpty)
          'badges': FieldValue.arrayUnion(novasBadges),
      }, SetOptions(merge: true));

      if (virouODia && userDoc.exists) {
        QuerySnapshot meusDesafios = await userRef
            .collection('meus_desafios')
            .get();
        for (var doc in meusDesafios.docs) {
          Map<String, dynamic> dadosDesafio =
          doc.data() as Map<String, dynamic>;
          if (dadosDesafio['status'] == 'coletado') {
            await doc.reference.delete();
          }
        }
        print("Dia virou! Desafios coletados foram limpos.");

        try {
          BossService bossService = BossService();
          String grupoId = await bossService.getGrupoIdDoUsuario(uid);
          if (grupoId.isNotEmpty) {
            await bossService.danoSyncDiario(
              grupoId: grupoId,
              uid: uid,
              minutosHoje: minutosFinaisRanking,
            );
          }
        } catch (e) {
          print("Boss sync diário: $e");
        }
      }
    } catch (e) {
      print("Erro na sincronização diária: $e");
    }
  }

  Future<bool> adicionarRecompensa(int xpGanho, int moedasGanhas) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      if (uid.isEmpty) return false;

      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      DocumentSnapshot userSnap = await userRef.get();

      if (userSnap.exists) {
        Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
        int xpAtual = userData['xp'] ?? 0;
        int nivelAtual = userData['nivel'] ?? 1;
        int moedasAtuais = userData['moedas'] ?? 0;

        int xpNovo = xpAtual + xpGanho;
        int xpNecessario = nivelAtual * 1000;
        bool subiuDeNivel = false;

        while (xpNovo >= xpNecessario) {
          xpNovo -= xpNecessario;
          nivelAtual++;
          xpNecessario = nivelAtual * 1000;
          subiuDeNivel = true;
        }

        await userRef.update({
          'xp': xpNovo,
          'nivel': nivelAtual,
          'moedas': moedasAtuais + moedasGanhas,
        });

        return subiuDeNivel;
      }
      return false;
    } catch (e) {
      print("Erro ao adicionar recompensa: $e");
      return false;
    }
  }
}