import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // VIBRAÇÃO
import 'package:audioplayers/audioplayers.dart'; // ÁUDIO
import 'package:confetti/confetti.dart'; // CONFETES
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/desafio_service.dart';
import '../services/firestore_service.dart';
import '../services/usage_service.dart';
import 'modo_foco_screen.dart';
import 'configuracoes_screen.dart';
import '../widgets/perfil_avatar_widget.dart';

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
  List<double> _usoPorHora = List.filled(24, 0.0);

  // CORES EDITÁVEIS DO GRÁFICO DE DONUT
  final List<Color> _coresDonut = [
    const Color(0xFF246815), // 1º Lugar
    const Color(0xFF30931D), // 2º Lugar
    const Color(0xEA3FCA23), // 3º Lugar
  ];

  // 👇 SISTEMA GLOBAL DE LEVEL UP 👇
  int _nivelAnterior = 0;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _carregarDadosDeUso();
    _firestoreService.sincronizarDadosDiarios();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosDeUso() async {
    try {
      int minutos = await UsageService.getMinutosHoje();
      List<Map<String, dynamic>> apps = await UsageService.getTopApps();
      List<double> usoHora = await UsageService.getUsoPorHora();

      if (mounted) {
        setState(() {
          _minutosHoje = minutos;
          _topApps = apps;
          _usoPorHora = usoHora;
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

  // Exibe detalhes completos
  void _mostrarDetalhesTodosApps() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Todos os Aplicativos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: UsageService.getTodosApps(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1D9E75),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('Nenhum dado registrado hoje.'),
                      );
                    }

                    final todosApps = snapshot.data!;

                    return ListView.separated(
                      itemCount: todosApps.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 24,
                        endIndent: 24,
                        color: Color(0xFFEEEEEE),
                      ),
                      itemBuilder: (context, index) {
                        var app = todosApps[index];
                        String nomeApp = app['nome'] ?? 'Desconhecido';
                        int minsApp = app['minutos'] ?? 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
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
                            _formatarTempo(minsApp),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 🏆 TELA GLOBAL DE LEVEL UP ÉPICA
  // =========================================================================
  void _dispararLevelUpGlobal(int novoNivel) async {
    _confettiController.play();
    HapticFeedback.heavyImpact();
    try {
      await _audioPlayer.play(AssetSource('sounds/levelup.mp3'));
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          border: Border(top: BorderSide(color: Color(0xFF1D9E75), width: 4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎊', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 10),
            const Text(
              'LEVEL UP!',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D9E75),
                letterSpacing: 3,
                shadows: [Shadow(color: Color(0xFF1D9E75), blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'A sua disciplina atingiu um novo patamar.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1D9E75).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'BEM-VINDO AO',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'NÍVEL $novoNivel',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D9E75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            SizedBox(
              width: 250,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: const Text(
                  'CONTINUAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfiguracoesScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ModoFocoScreen()),
        ),
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
      body: Stack(
        children: [
          Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _desafioService.dadosUsuario(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists)
                    return const SizedBox();
                  var user = snapshot.data!.data() as Map<String, dynamic>;

                  String nome = user['nome'] ?? 'Usuário';
                  int nivelAtual = user['nivel'] ?? 1;
                  int xp = user['xp'] ?? 0;
                  String acessorioAtual = user['acessorio_atual'] ?? 'padrao';
                  String tituloAtual = user['titulo_atual'] ?? 't_iniciante';

                  int xpNecessario = nivelAtual * 1000;
                  double progressoBarra = xp / xpNecessario;

                  // 👇 O GATILHO MÁGICO DO LEVEL UP 👇
                  if (_nivelAnterior > 0 && nivelAtual > _nivelAnterior) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _dispararLevelUpGlobal(nivelAtual);
                    });
                  }
                  _nivelAnterior = nivelAtual; // Atualiza a memória
                  // 👆 ---------------------------- 👆

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        PerfilAvatarWidget(
                          minutosDeTela: _minutosHoje,
                          iconeId: acessorioAtual,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                      tituloAtual == 't_zen'
                                          ? 'MESTRE ZEN'
                                          : tituloAtual == 't_intocavel'
                                          ? 'INTOCÁVEL'
                                          : tituloAtual == 't_maquina'
                                          ? 'MÁQUINA'
                                          : 'INICIANTE',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D9E75),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0,
                                  end: progressoBarra,
                                ),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: value,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF1D9E75),
                                      ),
                                      minHeight: 8,
                                    ),
                                  );
                                },
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
                              '$nivelAtual',
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

              Expanded(
                child: _carregandoUso
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1D9E75),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF1D9E75),
                        onRefresh: _carregarDadosDeUso,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
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

                              // GRÁFICO 1 - COLUNAS HORÁRIAS
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SizedBox(
                                  height: 150,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: 60,
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 20,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: Colors.grey.withOpacity(
                                              0.15,
                                            ),
                                            strokeWidth: 1,
                                          );
                                        },
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.withOpacity(0.3),
                                            width: 1,
                                          ),
                                          left: BorderSide.none,
                                          right: BorderSide.none,
                                          top: BorderSide.none,
                                        ),
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: 20,
                                            getTitlesWidget: (value, meta) {
                                              if (value == 0)
                                                return const SizedBox.shrink();
                                              return Text(
                                                '${value.toInt()} m',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              int hora = value.toInt();
                                              if (hora == 0 ||
                                                  hora == 6 ||
                                                  hora == 12 ||
                                                  hora == 18 ||
                                                  hora == 23) {
                                                String texto = hora == 23
                                                    ? '23'
                                                    : hora.toString();
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    texto,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                      ),
                                      barGroups: List.generate(24, (index) {
                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: _usoPorHora[index],
                                              color: const Color(0xFF1D9E75),
                                              width: 5,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(3),
                                                  ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),

                              // GRÁFICO 2 - DONUT CHART
                              if (_topApps.isNotEmpty) ...[
                                const SizedBox(height: 40),
                                Center(
                                  child: SizedBox(
                                    height: 140,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 45,
                                        startDegreeOffset: 270,
                                        sections: List.generate(
                                          _topApps.length,
                                          (index) {
                                            final app = _topApps[index];
                                            final double minutos =
                                                (app['minutos'] as int)
                                                    .toDouble();
                                            final corSegura =
                                                _coresDonut[index %
                                                    _coresDonut.length];

                                            return PieChartSectionData(
                                              color: corSegura,
                                              value: minutos,
                                              title: '${minutos.toInt()}m',
                                              radius: 18,
                                              titleStyle: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 40),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
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

                              // LISTA DOS APPS COM CORES ASSOCIAIS AO DONUT
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
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                                        final corItem =
                                            _coresDonut[index %
                                                _coresDonut.length];

                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 0,
                                              ),
                                          leading: Text(
                                            '${index + 1}º',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: corItem,
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
                                            _formatarTempo(minsApp),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: corItem,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                              const SizedBox(height: 16),

                              // BOTÃO DE DETALHES
                              if (_topApps.isNotEmpty)
                                Center(
                                  child: TextButton(
                                    onPressed: _mostrarDetalhesTodosApps,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF5700),
                                    ),
                                    child: const Text(
                                      'Ver Detalhes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          // Confetes explodem por cima de tudo na Home
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              gravity: 0.2,
              colors: const [Color(0xFF1D9E75), Colors.amber, Colors.white],
            ),
          ),
        ],
      ),
    );
  }
}
