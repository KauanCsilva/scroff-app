import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();
  final _authService = AuthService();

  bool _carregando = false;
  bool _modoLogin = true;

  void _processarAcao() async {
    setState(() => _carregando = true);

    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();
    final nome = _nomeController.text.trim();

    if (email.isEmpty || senha.isEmpty || (!_modoLogin && nome.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos!")),
      );
      setState(() => _carregando = false);
      return;
    }

    final user = _modoLogin
        ? await _authService.login(email, senha)
        : await _authService.cadastrar(email, senha, nome);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _modoLogin
                  ? "E-mail ou senha incorretos."
                  : "Erro ao criar conta. Tente novamente.",
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _carregando = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo/scroff.png',
                  height: 420,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _modoLogin ? "Bem-vindo de volta" : "Crie sua conta",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                if (!_modoLogin) ...[
                  _campo(
                    controller: _nomeController,
                    label: "Seu nickname",
                    icone: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                ],

                _campo(
                  controller: _emailController,
                  label: "E-mail",
                  icone: Icons.email_outlined,
                  teclado: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                _campo(
                  controller: _senhaController,
                  label: "Senha",
                  icone: Icons.lock_outline,
                  senha: true,
                ),
                const SizedBox(height: 28),

                if (_carregando)
                  const CircularProgressIndicator(color: Color(0xFF246815))
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _processarAcao,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF246815),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _modoLogin ? "ENTRAR" : "CRIAR CONTA",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _modoLogin = !_modoLogin;
                      _nomeController.clear();
                    });
                  },
                  child: Text(
                    _modoLogin
                        ? "Não tem conta? Cadastre-se"
                        : "Já tem conta? Entrar",
                    style: const TextStyle(
                      color: Color(0xFF246815),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    bool senha = false,
    TextInputType teclado = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: senha,
      keyboardType: teclado,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icone, color: Colors.black38, size: 20),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF246815), width: 1.5),
        ),
      ),
    );
  }
}