import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/desafio_service.dart';
import '../services/firestore_service.dart';
import '../services/usage_service.dart';
import 'modo_foco_screen.dart';
import '../widgets/mascote_widget.dart';
import 'configuracoes_screen.dart';

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
        title: const Text('Scroff Dashboard'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
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
        icon: const Icon(Icons.timer, color: Colors.white),
        label: const Text(
          'Focar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // MINI PERFIL REATIVO
          StreamBuilder<DocumentSnapshot>(
            stream: _desafioService.dadosUsuario(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();
              var user = snapshot.data!.data() as Map<String, dynamic>;

              String nome = user['nome'] ?? 'Usuário';
              int nivel = user['nivel'] ?? 1;
              int xp = user['xp'] ?? 0;
              // AGORA PEGA DO FIREBASE O ACESSÓRIO
              String acessorioAtual = user['acessorio_atual'] ?? 'nenhum';

              int xpNecessario = nivel * 1000;
              double progressoBarra = xp / xpNecessario;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    // O MASCOTE VIVO E SINCRONIZADO!
                    MascoteWidget(
                      minutosDeTela: _minutosHoje,
                      acessorio: acessorioAtual,
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
                              backgroundColor: Colors.grey[200],
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
                                  'Tempo de Tela Hoje',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatarTempo(_minutosHoje),
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D9E75),
                                    height: 1.0,
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
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

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
                                        app['nome'] ?? 'Desconhecido',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      trailing: Text(
                                        _formatarTempo(minsApp),
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
