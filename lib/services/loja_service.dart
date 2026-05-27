import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LojaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // BACK-END: Vitrine fixa controlada pelo servidor. O front-end lê isso para desenhar a loja.
  final List<Map<String, dynamic>> vitrineAvatars = [
    {'id': 'avatar_guerreiro', 'nome': '🛡️ Guerreiro Focado', 'preco': 100},
    {'id': 'avatar_mago', 'nome': '🔮 Mago do Tempo', 'preco': 250},
    {'id': 'avatar_ninja', 'nome': '🥷 Ninja Offline', 'preco': 500},
    {
      'id': 'avatar_astronauta',
      'nome': '👨‍🚀 Astronauta Produtivo',
      'preco': 1000,
    },
  ];

  Future<bool> comprarAvatar(String avatarId, int preco) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      if (uid.isEmpty) return false;

      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) return false;
      Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;

      int moedasAtuais = dados['moedas'] ?? 0;
      List<dynamic> comprados = dados['avatars_comprados'] ?? [];

      // Validações de segurança de back-end
      if (comprados.contains(avatarId)) return false; // Já possui
      if (moedasAtuais < preco) return false; // Sem saldo

      // Executa a transação financeira dentro do documento do usuário
      await userRef.update({
        'moedas': FieldValue.increment(-preco), // Remove as moedas
        'avatars_comprados': FieldValue.arrayUnion([
          avatarId,
        ]), // Adiciona ao inventário
        'avatar_atual': avatarId, // Equipa o novo automaticamente
      });

      return true;
    } catch (e) {
      print("Erro ao comprar avatar: $e");
      return false;
    }
  }

  // LÓGICA: Altera o avatar ativo do usuário
  Future<void> equiparAvatar(String avatarId) async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      await _db.collection('usuarios').doc(uid).update({
        'avatar_atual': avatarId,
      });
    } catch (e) {
      print("Erro ao equipar: $e");
    }
  }
}
