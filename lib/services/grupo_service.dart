import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrupoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _gerarCodigoGrupo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> criarGrupo(String nomeGrupo) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      String codigoUnico = _gerarCodigoGrupo();

      await _db.collection('grupos').doc(codigoUnico).set({
        'nome': nomeGrupo,
        'codigo': codigoUnico,
        'criadorId': uid,
        'membros': [uid],
        'data_criacao': FieldValue.serverTimestamp(),
      });

      print("Grupo criado com sucesso! Código: $codigoUnico");
    } catch (e) {
      print("Erro ao criar grupo: $e");
    }
  }

  Future<bool> entrarNoGrupo(String codigo) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      String codigoLimpo = codigo.trim().toUpperCase();

      DocumentReference docRef = _db.collection('grupos').doc(codigoLimpo);
      DocumentSnapshot doc = await docRef.get();

      if (doc.exists) {
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

  Stream<QuerySnapshot> listarMeusGrupos() {
    String uid = _auth.currentUser?.uid ?? "";

    return _db
        .collection('grupos')
        .where('membros', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> buscarRankingDoGrupo(List<dynamic> membrosIds) {
    if (membrosIds.isEmpty) {
      return _db
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: ['vazio'])
          .snapshots();
    }

    return _db
        .collection('usuarios')
        .where(FieldPath.documentId, whereIn: membrosIds)
        .orderBy('minutos_hoje', descending: false)
        .snapshots();
  }
}