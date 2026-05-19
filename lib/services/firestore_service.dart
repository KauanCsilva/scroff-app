import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Função para salvar ou atualizar os dados do usuário atual
  // Atualize a sua função salvarTempoDeTela no seu firestore_service.dart:
  Future<void> salvarTempoDeTela(int minutosUsados) async {
    try {
      String? uid = _auth.currentUser?.uid;
      String? email = _auth.currentUser?.email;

      if (uid != null && email != null) {
        // GARANTIA TOTAL: Quebramos o texto e pegamos o primeiro item
        // convertendo explicitamente para String comum.
        final List<String> partesEmail = email.split('@');
        final String nomePadrao = partesEmail.first.toString();

        await _db.collection('usuarios').doc(uid).set({
          'email': email,
          'minutos_hoje': minutosUsados,
          'ultima_atualizacao': FieldValue.serverTimestamp(),
          // O merge: true impede que essa linha apague o nome
          // caso o usuário já tenha criado um nome personalizado antes
          'nome': nomePadrao,
        }, SetOptions(merge: true));

        print("Dados salvos com o nome padrão: $nomePadrao");
      }
    } catch (e) {
      print("Erro ao salvar no Firestore: $e");
    }
  }

  // Função para buscar os dados do usuário (ex: para mostrar no perfil)
  Stream<DocumentSnapshot> getDadosUsuario() {
    String uid = _auth.currentUser?.uid ?? "";
    return _db.collection('usuarios').doc(uid).snapshots();
  }

  Future<void> atualizarNomeUsuario(String novoNome) async {
    try {
      String? uid = _auth.currentUser?.uid;

      if (uid != null) {
        // Atualiza apenas o campo 'nome' dentro do documento do usuário
        await _db.collection('usuarios').doc(uid).update({
          'nome': novoNome.trim(),
        });
        print("Nome do usuário atualizado para: $novoNome");
      }
    } catch (e) {
      print("Erro ao atualizar nome: $e");
    }
  }

  Future<void> adicionarXP(int quantidade) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";

      // O 'increment' do Firestore é ótimo porque evita erro de cálculo se a internet oscilar
      await _db.collection('usuarios').doc(uid).update({
        'xp': FieldValue.increment(quantidade),
      });

      // Aqui você poderia colocar uma lógica de:
      // "Se XP > 1000, nivel = nivel + 1"
    } catch (e) {
      print("Erro ao adicionar XP: $e");
    }
  }
}
