import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/desafio_service.dart';
import '../services/firestore_service.dart';
import '../services/usage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DesafioService _desafioService = DesafioService();
  final FirestoreService _firestoreService = FirestoreService();

  int _minutosHoje = 0;
  List<Map<String, dynamic>> _topApps = [];
  bool _carregandoUso = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosDeUso();
    _firestoreService.sincronizarDadosDiarios();
  }

  Future<void> _carregarDadosDeUso() async {
    try {
      int minutos = await UsageService.getMinutosHoje();
      List<Map<String, dynamic>> apps = await UsageService.getTopApps();

      if (mounted) {
        setState(() {
          _minutosHoje = minutos;
          _topApps = apps;
          _carregandoUso = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoUso = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fundo totalmente limpo
      appBar: AppBar(
        elevation: 0, // Tira a sombra da AppBar para ficar mais chapado/clean
        title: const Text('Scroff Dashboard'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. MINI PERFIL REATIVO (CLEAN)
          StreamBuilder<DocumentSnapshot>(
            stream: _desafioService.dadosUsuario(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();
              var user = snapshot.data!.data() as Map<String, dynamic>;

              String nome = user['nome'] ?? 'Usuário';
              int nivel = user['nivel'] ?? 1;
              int xp = user['xp'] ?? 0;
              String iconeAvatar = user['avatar_atual'] ?? '👤';

              int xpNecessario = nivel * 1000;
              double progressoBarra = xp / xpNecessario;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey!),
                  ), // Linha sutil separando o header
                ),
                child: Row(
                  children: [
                    Text(
                      iconeAvatar.length > 3 ? '🎭' : iconeAvatar,
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressoBarra,
                              backgroundColor: Colors.grey,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF1D9E75),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$xp / $xpNecessario XP',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        const Text(
                          'NÍVEL',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$nivel',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D9E75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. DADOS DE USO (VISUAL MINIMALISTA)
          Expanded(
            child: _carregandoUso
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF1D9E75),
                    onRefresh: _carregarDadosDeUso,
                    child: SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // Permite o 'puxar para atualizar'
                      child: Column(
                        children: [
                          // TEMPO DE TELA GIGANTE E CENTRALIZADO
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Text(
                                  'Tempo de Tela Hoje',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_minutosHoje}m',
                                  style: const TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D9E75),
                                    height: 1.0, // Deixa o número bem compacto
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // TÍTULO DA LISTA
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Text(
                              'Top Aplicativos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // LISTA CLEAN COM LINHAS DIVISÓRIAS FINAS
                          _topApps.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    'Nenhum dado registrado ainda.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _topApps.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                        height: 1,
                                        indent: 24,
                                        endIndent: 24,
                                        color: Color(0xFFEEEEEE),
                                      ),
                                  itemBuilder: (context, index) {
                                    var app = _topApps[index];
                                    String nomeApp =
                                        app['nome'] ?? 'Desconhecido';
                                    int minsApp = app['minutos'] ?? 0;

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 0,
                                          ),
                                      leading: Text(
                                        '${index + 1}º',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      title: Text(
                                        nomeApp,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      trailing: Text(
                                        '${minsApp}m',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D9E75),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
