import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DesafioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. BACK-END: Puxa o saldo atual de XP e Moedas do usuário para exibir na tela
  Stream<DocumentSnapshot> dadosUsuario() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db.collection('usuarios').doc(uid).snapshots();
  }

  // 2. BACK-END: Busca todos os desafios globais do sistema
  Stream<QuerySnapshot> listarDesafiosGlobais() {
    return _db.collection('desafios_globais').snapshots();
  }

  // 3. BACK-END: Vigia em tempo real quais desafios o usuário já interagiu
  Stream<QuerySnapshot> listarMeusDesafios() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('meus_desafios')
        .snapshots();
  }

  // 4. LÓGICA: Usuário clica em "Aceitar"
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

  // 5. LÓGICA DE VALIDAÇÃO: Bloqueia ou permite a conclusão baseado no tempo real do app
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

      // VALIDAÇÃO DO TEMPO: Procura o app alvo dentro da lista de uso do celular do usuário
      int minutosUsadosNoApp = 0;
      for (var app in topAppsUsuario) {
        if (app['nome'].toString().toLowerCase() == appAlvo.toLowerCase()) {
          minutosUsadosNoApp = app['minutos'] as int;
          break;
        }
      }

      // Se o usuário usou MAIS tempo do que o desafio permitia, ele falhou!
      if (minutosUsadosNoApp > limiteMinutos) {
        print(
          "Validação falhou: Usou $minutosUsadosNoApp min no $appAlvo, o limite era $limiteMinutos min.",
        );
        return false;
      }

      // SE PASSOU NA VALIDAÇÃO: Dá as recompensas
      // Marca o desafio como coletado para sumir/mudar na tela
      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId)
          .set({'status': 'coletado'}, SetOptions(merge: true));

      // Busca os pontos atuais para somar
      DocumentSnapshot userDoc = await _db
          .collection('usuarios')
          .doc(uid)
          .get();
      int xpAtual = 0;
      int moedasAtuais = 0;

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
        xpAtual = dados['xp'] is int ? dados['xp'] : 0;
        moedasAtuais = dados['moedas'] is int ? dados['moedas'] : 0;
      }

      // Injeta os novos valores no perfil do usuário
      await _db.collection('usuarios').doc(uid).set({
        'xp': xpAtual + xpRecompensa,
        'moedas': moedasAtuais + moedasRecompensa,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print("Erro ao concluir desafio: $e");
      return false;
    }
  }
}
