import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrupoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // BACK-END: Função auxiliar para gerar um código aleatório de 6 dígitos
  String _gerarCodigoGrupo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  // 1. LÓGICA: Criar um grupo novo no Firestore
  Future<void> criarGrupo(String nomeGrupo) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      String codigoUnico = _gerarCodigoGrupo();

      // Cria o documento na coleção 'grupos' usando o código como ID do documento
      await _db.collection('grupos').doc(codigoUnico).set({
        'nome': nomeGrupo,
        'codigo': codigoUnico,
        'criadorId': uid,
        'membros': [uid], // O criador já entra como primeiro membro
        'data_criacao': FieldValue.serverTimestamp(),
      });

      print("Grupo criado com sucesso! Código: $codigoUnico");
    } catch (e) {
      print("Erro ao criar grupo: $e");
    }
  }

  // 2. LÓGICA: Entrar em um grupo existente usando o código de convite
  Future<bool> entrarNoGrupo(String codigo) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      // Força o código a ficar em maiúsculo para evitar erros do usuário
      String codigoLimpo = codigo.trim().toUpperCase();

      // Procura o grupo com esse ID/Código
      DocumentReference docRef = _db.collection('grupos').doc(codigoLimpo);
      DocumentSnapshot doc = await docRef.get();

      if (doc.exists) {
        // Se o grupo existe, adiciona o UID do usuário na lista de membros
        await docRef.update({
          'membros': FieldValue.arrayUnion([uid]),
        });
        print("Usuário entrou no grupo com sucesso!");
        return true;
      } else {
        print("Grupo não encontrado.");
        return false;
      }
    } catch (e) {
      print("Erro ao entrar no grupo: $e");
      return false;
    }
  }

  // 3. LÓGICA: Buscar em tempo real os grupos que o usuário participa
  Stream<QuerySnapshot> listarMeusGrupos() {
    String uid = _auth.currentUser?.uid ?? "";

    // Faz uma query buscando todos os grupos onde o array 'membros' contém o UID dele
    return _db
        .collection('grupos')
        .where('membros', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> buscarRankingDoGrupo(List<dynamic> membrosIds) {
    // Se por acaso o grupo estiver vazio, evita dar erro no Firestore
    if (membrosIds.isEmpty) {
      return _db
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: ['vazio'])
          .snapshots();
    }

    // O 'whereIn' faz o Firestore buscar apenas os usuários cujos IDs estão dentro da lista de membros do grupo.
    // O 'orderBy' organiza do menor para o maior baseado nos minutos usados hoje.
    return _db
        .collection('usuarios')
        .where(FieldPath.documentId, whereIn: membrosIds)
        .orderBy('minutos_hoje', descending: false)
        .snapshots();
  }
}
