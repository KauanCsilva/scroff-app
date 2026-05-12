import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Criar conta com E-mail e Senha
  Future<User?> cadastrar(String email, String senha) async {
    try {
      UserCredential resultado = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      return resultado.user;
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
