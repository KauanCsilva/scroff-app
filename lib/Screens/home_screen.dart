import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/desafio_service.dart';
import '../services/firestore_service.dart';
import '../services/usage_service.dart';
import 'modo_foco_screen.dart';
import 'configuracoes_screen.dart';
import '../widgets/perfil_avatar_widget.dart'; // IMPORT DO NOVO ÍCONE PROFISSIONAL

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
      if (mounted) setState(() => _carregandoUso = false);
    }
  }

  String _formatarTempo(int totalMinutos) {
    if (totalMinutos < 60) return '${totalMinutos}m';
    int horas = totalMinutos ~/ 60;
    int minutos = totalMinutos % 60;
    return '${horas}h ${minutos}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Scroff Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracoesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ModoFocoScreen()),
          );
        },
        backgroundColor: const Color(0xFF1D9E75),
        elevation: 4,
        icon: const Icon(Icons.timer, color: Colors.white),
        label: const Text(
          'Focar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: Column(
        children: [
          // MINI PERFIL REATIVO COM DESIGN CLEAN
          StreamBuilder<DocumentSnapshot>(
            stream: _desafioService.dadosUsuario(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();
              var user = snapshot.data!.data() as Map<String, dynamic>;

              String nome = user['nome'] ?? 'Usuário';
              int nivel = user['nivel'] ?? 1;
              int xp = user['xp'] ?? 0;
              String acessorioAtual = user['acessorio_atual'] ?? 'padrao';

              int xpNecessario = nivel * 1000;
              double progressoBarra = xp / xpNecessario;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    // NOVO AVATAR DE ÍCONE
                    PerfilAvatarWidget(
                      minutosDeTela: _minutosHoje,
                      iconeId: acessorioAtual,
                    ),

                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F5EE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user['titulo_atual'] == 't_zen'
                                  ? 'MESTRE ZEN'
                                  : user['titulo_atual'] == 't_intocavel'
                                  ? 'INTOCÁVEL'
                                  : user['titulo_atual'] == 't_maquina'
                                  ? 'MÁQUINA'
                                  : 'INICIANTE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressoBarra,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF1D9E75),
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$xp / $xpNecessario XP',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        const Text(
                          'LEVEL',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '$nivel',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
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

          // TEMPO DE TELA E TOP APPS
          Expanded(
            child: _carregandoUso
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF1D9E75),
                    onRefresh: _carregarDadosDeUso,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Text(
                                  'TEMPO DE TELA HOJE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatarTempo(_minutosHoje),
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D9E75),
                                    height: 1.0,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Text(
                              'Top Aplicativos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _topApps.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    'Nenhum dado registrado.',
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
                                    int minsApp = app['minutos'] ?? 0;

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 4,
                                          ),
                                      leading: Text(
                                        '${index + 1}º',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black38,
                                        ),
                                      ),
                                      title: Text(
                                        app['nome'] ?? 'Desconhecido',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      trailing: Text(
                                        _formatarTempo(minsApp),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
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
