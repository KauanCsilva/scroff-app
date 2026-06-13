import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'boss_service.dart';

class DesafioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> dadosUsuario() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db.collection('usuarios').doc(uid).snapshots();
  }

  Stream<QuerySnapshot> listarDesafiosGlobais() {
    return _db.collection('desafios_globais').snapshots();
  }

  Stream<QuerySnapshot> listarMeusDesafios() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('meus_desafios')
        .snapshots();
  }

  Future<void> aceitarDesafio(String desafioId) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId)
          .set({
        'status': 'aceito',
        'data_inicio': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Erro ao aceitar: $e");
    }
  }

  Future<bool> verificarEConcluir(
      String desafioId,
      String appAlvo,
      int limiteMinutos,
      int xpRecompensa,
      int moedasRecompensa,
      List<Map<String, dynamic>> topAppsUsuario,
      ) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      if (uid.isEmpty) return false;

      DocumentReference desafioRef = _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId);

      DocumentSnapshot desafioDoc = await desafioRef.get();
      if (desafioDoc.exists) {
        Map<String, dynamic> dadosDesafio =
        desafioDoc.data() as Map<String, dynamic>;
        if (dadosDesafio['status'] == 'coletado') {
          print("Desafio $desafioId já foi coletado. Ignorando.");
          return false;
        }
      }

      int minutosUsadosNoApp = 0;
      for (var app in topAppsUsuario) {
        if (app['nome'].toString().toLowerCase() == appAlvo.toLowerCase()) {
          minutosUsadosNoApp = app['minutos'] as int;
          break;
        }
      }

      if (minutosUsadosNoApp > limiteMinutos) return false;

      await desafioRef.set({'status': 'coletado'}, SetOptions(merge: true));

      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      int xpAtual = 0;
      int moedasAtuais = 0;
      int nivelAtual = 1;

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
        xpAtual = dados['xp'] ?? 0;
        moedasAtuais = dados['moedas'] ?? 0;
        nivelAtual = dados['nivel'] ?? 1;
      }

      int novoXp = xpAtual + xpRecompensa;
      int novoNivel = nivelAtual;
      List<String> novasBadges = [];

      int xpNecessario = novoNivel * 1000;
      while (novoXp >= xpNecessario) {
        novoXp -= xpNecessario;
        novoNivel++;
        novasBadges.add('badge_lvl_$novoNivel');
        xpNecessario = novoNivel * 1000;
      }

      await userRef.set({
        'xp': novoXp,
        'moedas': moedasAtuais + moedasRecompensa,
        'nivel': novoNivel,
        if (novasBadges.isNotEmpty)
          'badges': FieldValue.arrayUnion(novasBadges),
      }, SetOptions(merge: true));

      try {
        BossService bossService = BossService();
        String grupoId = await bossService.getGrupoIdDoUsuario(uid);
        if (grupoId.isNotEmpty) {
          await bossService.danoPorDesafio(grupoId: grupoId, uid: uid);
        }
      } catch (e) {
        print("Boss dano por desafio: $e");
      }

      return true;
    } catch (e) {
      print("Erro ao validar conclusão: $e");
      return false;
    }
  }
}