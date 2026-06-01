import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final TextEditingController _nomeController = TextEditingController();
  List<dynamic> _whitelistAtuais = [];
  bool _carregando = true;

  // Lista de apps produtivos sugeridos pelo GDD para o MVP
  final List<Map<String, String>> _appsProdutivos = [
    {'id': 'gmail', 'nome': 'Gmail 📧'},
    {'id': 'slack', 'nome': 'Slack 💬'},
    {'id': 'linkedin', 'nome': 'LinkedIn 💼'},
    {'id': 'notion', 'nome': 'Notion 📝'},
    {'id': 'kindle', 'nome': 'Kindle 📚'},
  ];

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isNotEmpty) {
      var doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (doc.exists) {
        setState(() {
          _nomeController.text = doc.data()?['nome'] ?? '';
          _whitelistAtuais = doc.data()?['whitelist'] ?? [];
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarConfiguracoes() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'nome': _nomeController.text.trim(),
        'whitelist': _whitelistAtuais,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _toggleAppList(String appId, bool isChecked) {
    setState(() {
      if (isChecked) {
        _whitelistAtuais.add(appId);
      } else {
        _whitelistAtuais.remove(appId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar Perfil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Seu Nickname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Modo Trabalho (Whitelist)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Selecione os apps que não devem penalizar o seu ranking.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),

            // Lista de Switches para o Modo Trabalho
            ..._appsProdutivos.map((app) {
              bool ativo = _whitelistAtuais.contains(app['id']);
              return SwitchListTile(
                title: Text(app['nome']!),
                value: ativo,
                activeColor: const Color(0xFF1D9E75),
                onChanged: (bool value) => _toggleAppList(app['id']!, value),
              );
            }),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarConfiguracoes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Salvar Alterações',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
