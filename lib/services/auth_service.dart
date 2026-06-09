import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Criar conta com E-mail e Senha
  Future<User?> cadastrar(String email, String senha, String nome) async {
    try {
      UserCredential resultado = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      User? user = resultado.user;

      // Cria o documento inicial do usuário no Firestore com todos os campos
      if (user != null) {
        await _db.collection('usuarios').doc(user.uid).set({
          'nome': nome.trim().isEmpty ? 'Usuário' : nome.trim(),
          'email': email,
          'xp': 0,
          'nivel': 1,
          'moedas': 0,
          'minutos_hoje': 0,
          'ultima_sincronizacao': '',
          'acessorio_atual': 'avatar_basicof',
          'titulo_atual': 't_iniciante',
          'inventario': ['avatar_basicof', 'avatar_basicom'],
          'inventario_titulos': ['t_iniciante'],
          'consumiveis': {},
          'whitelist': [],
          'mostrar_graficos': true,
          'criado_em': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } catch (e) {
      print("Erro no cadastro: ${e.toString()}");
      return null;
    }
  }

  // 2. Fazer Login
  Future<User?> login(String email, String senha) async {
    try {
      UserCredential resultado = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      return resultado.user;
    } catch (e) {
      print("Erro no login: ${e.toString()}");
      return null;
    }
  }

  // 3. Sair (Logout)
  Future<void> sair() async {
    await _auth.signOut();
  }

  // 4. Verificar se o usuário já está logado
  Stream<User?> get usuarioLogado => _auth.authStateChanges();
}
