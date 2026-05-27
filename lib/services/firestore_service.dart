import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scroff/services/usage_service.dart';

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

  Future<void> sincronizarDadosDiarios() async {
    try {
      String uid = _auth.currentUser?.uid ?? "";
      if (uid.isEmpty) return;

      // 1. Puxa os minutos de hoje direto do celular (Para o Ranking das Partys)
      int minutosHoje = await UsageService.getMinutosHoje();

      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      // Pega a data de hoje formatada (ex: "2023-10-25")
      DateTime agora = DateTime.now();
      String dataHojeStr = "${agora.year}-${agora.month}-${agora.day}";

      bool virouODia = false;

      // Verifica se é a primeira vez que ele abre o app hoje
      if (userDoc.exists) {
        Map<String, dynamic> dados = userDoc.data() as Map<String, dynamic>;
        String ultimaSincronizacao = dados['ultima_sincronizacao'] ?? "";

        if (ultimaSincronizacao != dataHojeStr) {
          virouODia = true; // Opa, é um novo dia!
        }
      } else {
        virouODia = true;
      }

      // 2. Atualiza os minutos atuais e carimba a data de hoje no perfil
      await userRef.set({
        'minutos_hoje': minutosHoje,
        'ultima_sincronizacao': dataHojeStr,
      }, SetOptions(merge: true));

      // 3. RESET DIÁRIO (Se virou o dia, apaga os desafios concluídos de ontem)
      if (virouODia) {
        QuerySnapshot meusDesafios = await userRef
            .collection('meus_desafios')
            .get();

        // Loop que limpa a tela, mas poupa os desafios que ele precisa concluir hoje!
        for (var doc in meusDesafios.docs) {
          Map<String, dynamic> dadosDesafio =
              doc.data() as Map<String, dynamic>;
          String status = dadosDesafio['status'] ?? '';

          // Só apaga os desafios que ele já clicou em concluir e ganhou o prêmio ('coletado')
          if (status == 'coletado') {
            await doc.reference.delete();
          }
          // Os que estão como 'aceito' continuam na tela para ele poder clicar no botão verde hoje!
        }
        print("🔄 Dia virou! Desafios coletados foram limpos da tela.");
      }

      print("✅ Sincronização concluída: $minutosHoje minutos gravados.");
    } catch (e) {
      print("Erro na sincronização diária: $e");
    }
  }
}
