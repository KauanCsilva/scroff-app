import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'usage_service.dart';
import 'boss_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SINCRO DIÁRIA + CORRETOR AUTOMÁTICO DE NÍVEL DE SEGURANÇA
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
      String ultimaSincronizacao = "";
      List<dynamic> whitelist = [];

      if (userDoc.exists) {
        Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
        whitelist = dados['whitelist'] ?? [];
        xpAtual = dados['xp'] ?? 0;
        nivelAtual = dados['nivel'] ?? 1;
        moedasAtuais = dados['moedas'] ?? 0;
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

      int minutosFinaisRanking = minutosTotais - minutosDescontados;
      if (minutosFinaisRanking < 0) minutosFinaisRanking = 0;

      // --- TRAVA DE SEGURANÇA (Resolve o seu problema de 1050XP) ---
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
          "🛠️ Corretor de Nível ativado! Usuário ajustado para o Nível $nivelAtual.",
        );
      }
      // -------------------------------------------------------------

      DateTime agora = DateTime.now();
      String dataHojeStr = "${agora.year}-${agora.month}-${agora.day}";
      bool virouODia = ultimaSincronizacao != dataHojeStr;

      await userRef.set({
        'minutos_hoje': minutosFinaisRanking,
        'ultima_sincronizacao': dataHojeStr,
        'xp': xpAtual,
        'nivel': nivelAtual,
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
        print("🔄 Dia virou! Desafios coletados foram limpos.");

        // Dano automático diário ao boss do grupo (se houver)
        try {
          BossService bossService = BossService();
          String grupoId = await bossService.getGrupoIdDoUsuario(uid);
          if (grupoId.isNotEmpty) {
            final resultado = await bossService.danoSyncDiario(
              grupoId: grupoId,
              uid: uid,
              minutosHoje: minutosFinaisRanking,
            );
            if (resultado['sucesso'] == true) {
              print(
                "⚔️ Dano diário ao boss: ${resultado['dano']} (HP: ${resultado['hp_atual']})",
              );
            }
          }
        } catch (e) {
          print("Boss sync diário: $e");
        }
      }
    } catch (e) {
      print("Erro na sincronização diária: $e");
    }
  }

  // 2. FUNÇÃO MESTRE CENTRALIZADA DE RECOMPENSA E LEVEL UP
  // Qualquer parte do app que der pontos vai chamar essa função única!
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

        // Processa o Level Up acumulativo
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

        return subiuDeNivel; // Retorna true se passou de nível para a tela soltar confetes
      }
      return false;
    } catch (e) {
      print("Erro ao adicionar recompensa: $e");
      return false;
    }
  }
}
