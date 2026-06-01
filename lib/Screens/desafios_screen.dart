import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import '../services/usage_service.dart';
import '../services/firestore_service.dart';
import 'package:audioplayers/audioplayers.dart';

class DesafiosScreen extends StatefulWidget {
  const DesafiosScreen({super.key});

  @override
  State<DesafiosScreen> createState() => _DesafiosScreenState();
}

class _DesafiosScreenState extends State<DesafiosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _usoHoje = [];
  bool _carregandoUso = true;

  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _carregarUsoEmTempoReal();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _testarConfeteELevelUp() {
    _confettiController.play();
    _audioPlayer.play(AssetSource('sounds/levelup.mp3'));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎊 LEVEL UP! 🎊'),
        content: const Text(
          'Incrível! Você subiu de nível!\n\n+500 XP\n+100 Moedas',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Coletar MEGA Recompensa',
              style: TextStyle(
                color: Color(0xFF1D9E75),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarUsoEmTempoReal() async {
    try {
      var uso = await UsageService.getTopApps();
      if (mounted) {
        setState(() {
          _usoHoje = uso;
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

  Future<void> _aceitarDesafio(
    String desafioId,
    Map<String, dynamic> dadosGlobais,
  ) async {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('meus_desafios')
        .doc(desafioId)
        .set({
          'status': 'aceito',
          'aceito_em': FieldValue.serverTimestamp(),
          'titulo': dadosGlobais['titulo'] ?? 'Desafio',
          'app_alvo': dadosGlobais['app_alvo'] ?? '',
          'limite_minutos': dadosGlobais['limite_minutos'] ?? 0,
          'xp_recompensa': dadosGlobais['xp_recompensa'] ?? 0,
          'moedas_recompensa': dadosGlobais['moedas_recompensa'] ?? 0,
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desafio aceite! Foco total hoje.'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    }
  }

  Future<void> _reprovarDesafioImediatamente(String desafioId) async {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('meus_desafios')
        .doc(desafioId)
        .update({'status': 'falhou'});
  }

  Future<void> _concluirDesafio(
    String desafioId,
    Map<String, dynamic> meuDesafio,
  ) async {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    String appAlvo = meuDesafio['app_alvo'] ?? '';
    int limite = meuDesafio['limite_minutos'] ?? 0;
    int xpGanho = meuDesafio['xp_recompensa'] ?? 0;
    int moedasGanhas = meuDesafio['moedas_recompensa'] ?? 0;

    List<Map<String, dynamic>> appsOntem = await UsageService.getTopAppsOntem();

    int minutosUsadosOntem = 0;
    for (var app in appsOntem) {
      if (app['nome'].toString().toLowerCase().contains(
        appAlvo.toLowerCase(),
      )) {
        minutosUsadosOntem = app['minutos'];
        break;
      }
    }

    if (minutosUsadosOntem <= limite) {
      final FirestoreService firestoreService = FirestoreService();
      bool subiuDeNivel = await firestoreService.adicionarRecompensa(
        xpGanho,
        moedasGanhas,
      );

      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId)
          .update({'status': 'coletado'});

      // DISPARA OS CONFETES! 🎉
      _confettiController.play();

      if (subiuDeNivel) {
        await _audioPlayer.play(AssetSource('sounds/levelup.mp3'));
      } else {
        await _audioPlayer.play(AssetSource('sounds/sucesso.mp3'));
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(subiuDeNivel ? '🎊 LEVEL UP! 🎊' : '🎉 Sucesso!'),
            content: Text(
              subiuDeNivel
                  ? 'Incrível! Você subiu de nível!\n\n+$xpGanho XP\n+$moedasGanhas Moedas'
                  : 'Você cumpriu a meta do $appAlvo ontem!\n\n+$xpGanho XP\n+$moedasGanhas Moedas',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Coletar',
                  style: TextStyle(color: Color(0xFF1D9E75)),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId)
          .update({'status': 'falhou'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falhou! O uso ontem foi de $minutosUsadosOntem min.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser?.uid ?? '';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Seus desafios'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1D9E75),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _carregarUsoEmTempoReal,
                tooltip: 'Atualizar progresso',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: Colors.grey[200], height: 1.0),
            ),
          ),

          // 👇 ADICIONE ESTE BLOCO AQUI 👇
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _testarConfeteELevelUp,
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text(
              'Testar Trailer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 👆 ATE AQUI 👆
          body: _carregandoUso
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('desafios_globais').snapshots(),
                  builder: (context, globaisSnapshot) {
                    if (!globaisSnapshot.hasData) return const SizedBox();

                    return StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('usuarios')
                          .doc(uid)
                          .collection('meus_desafios')
                          .snapshots(),
                      builder: (context, meusSnapshot) {
                        if (!meusSnapshot.hasData) return const SizedBox();

                        List<DocumentSnapshot> globais =
                            globaisSnapshot.data!.docs;
                        Map<String, Map<String, dynamic>> meusDesafiosMap = {};

                        for (var doc in meusSnapshot.data!.docs) {
                          meusDesafiosMap[doc.id] =
                              doc.data() as Map<String, dynamic>;
                        }

                        List<Map<String, dynamic>> emAndamento = [];
                        List<Map<String, dynamic>> disponiveis = [];

                        for (var docGlobal in globais) {
                          String id = docGlobal.id;
                          Map<String, dynamic> dadosGlobais =
                              docGlobal.data() as Map<String, dynamic>;
                          dadosGlobais['id'] = id;

                          if (meusDesafiosMap.containsKey(id)) {
                            var meuProgresso = meusDesafiosMap[id]!;
                            if (meuProgresso['status'] == 'aceito' ||
                                meuProgresso['status'] == 'falhou') {
                              dadosGlobais['meu_status'] =
                                  meuProgresso['status'];
                              dadosGlobais['aceito_em'] =
                                  meuProgresso['aceito_em'];
                              emAndamento.add(dadosGlobais);
                            }
                          } else {
                            disponiveis.add(dadosGlobais);
                          }
                        }

                        return RefreshIndicator(
                          onRefresh: _carregarUsoEmTempoReal,
                          color: const Color(0xFF1D9E75),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (emAndamento.isNotEmpty) ...[
                                  const Text(
                                    'EM ANDAMENTO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...emAndamento.map((desafio) {
                                    String appAlvo = desafio['app_alvo'] ?? '';
                                    int limite = desafio['limite_minutos'] ?? 1;
                                    bool falhouDb =
                                        desafio['meu_status'] == 'falhou';

                                    bool aceitoHoje = false;
                                    Timestamp? ts =
                                        desafio['aceito_em'] as Timestamp?;
                                    if (ts != null) {
                                      DateTime dataAceite = ts.toDate();
                                      DateTime hoje = DateTime.now();
                                      if (dataAceite.year == hoje.year &&
                                          dataAceite.month == hoje.month &&
                                          dataAceite.day == hoje.day) {
                                        aceitoHoje = true;
                                      }
                                    }

                                    int minutosUsadosHoje = 0;
                                    for (var app in _usoHoje) {
                                      if (app['nome']
                                          .toString()
                                          .toLowerCase()
                                          .contains(appAlvo.toLowerCase())) {
                                        minutosUsadosHoje = app['minutos'];
                                        break;
                                      }
                                    }

                                    double porcentagemRisco =
                                        minutosUsadosHoje / limite;
                                    if (porcentagemRisco > 1.0)
                                      porcentagemRisco = 1.0;

                                    bool estourouLimiteAgora =
                                        minutosUsadosHoje > limite;
                                    bool estaFalhado =
                                        falhouDb || estourouLimiteAgora;

                                    if (estourouLimiteAgora && !falhouDb) {
                                      _reprovarDesafioImediatamente(
                                        desafio['id'],
                                      );
                                    }

                                    Color corBarra = const Color(0xFF1D9E75);
                                    if (porcentagemRisco >= 0.8)
                                      corBarra = Colors.orange;
                                    if (estaFalhado) corBarra = Colors.red;

                                    bool botaoBloqueado =
                                        estaFalhado || aceitoHoje;

                                    return Card(
                                      elevation: 0,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: estaFalhado
                                                      ? const Color(0xFFFDECEE)
                                                      : const Color(0xFFE1F5EE),
                                                  child: Icon(
                                                    estaFalhado
                                                        ? Icons.block
                                                        : Icons.timer,
                                                    color: estaFalhado
                                                        ? Colors.red
                                                        : const Color(
                                                            0xFF1D9E75,
                                                          ),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        desafio['titulo'] ?? '',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Limite: $limite min | Usado: $minutosUsadosHoje min',
                                                        style: TextStyle(
                                                          color: estaFalhado
                                                              ? Colors.red
                                                              : Colors.grey,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              estaFalhado
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: porcentagemRisco,
                                                backgroundColor:
                                                    Colors.grey[200],
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      corBarra,
                                                    ),
                                                minHeight: 8,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  estaFalhado
                                                      ? 'Desafio reprovado.'
                                                      : 'Em progresso...',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: estaFalhado
                                                        ? Colors.red
                                                        : Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  '${(porcentagemRisco * 100).toInt()}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: corBarra,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: botaoBloqueado
                                                    ? null
                                                    : () => _concluirDesafio(
                                                        desafio['id'],
                                                        desafio,
                                                      ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF1D9E75,
                                                  ),
                                                  disabledBackgroundColor:
                                                      Colors.grey[300],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  estaFalhado
                                                      ? 'Bloqueado (Limite excedido)'
                                                      : aceitoHoje
                                                      ? 'Em análise (Volte amanhã)'
                                                      : 'Concluir Desafio',
                                                  style: TextStyle(
                                                    color: botaoBloqueado
                                                        ? Colors.grey[600]
                                                        : Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 24),
                                ],

                                const Text(
                                  'DISPONÍVEIS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (disponiveis.isEmpty)
                                  const Text(
                                    'Nenhum desafio novo disponível no momento.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ...disponiveis.map((desafio) {
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor:
                                                    Colors.grey[100],
                                                child: const Icon(
                                                  Icons.star_border,
                                                  color: Colors.orange,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      desafio['titulo'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Troque o tempo no ${desafio['app_alvo']} por ${desafio['xp_recompensa']} XP',
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              onPressed: () => _aceitarDesafio(
                                                desafio['id'],
                                                desafio,
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: BorderSide(
                                                  color: Colors.grey[300]!,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Aceitar desafio',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}
