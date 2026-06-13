import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _DesafiosScreenState extends State<DesafiosScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;

  List<Map<String, dynamic>> _usoHoje = [];
  bool _carregandoUso = true;

  late AnimationController _xpAnimController;
  late Animation<double> _xpOpacity;
  late Animation<double> _xpPosition;
  String _textoXpFlutuante = "";
  bool _mostrarXpFlutuante = false;

  @override
  void initState() {
    super.initState();
    _carregarUsoEmTempoReal();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _xpAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _xpOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _xpAnimController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _xpPosition = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(parent: _xpAnimController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _confettiController.dispose();
    _xpAnimController.dispose();
    super.dispose();
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
      if (mounted) setState(() => _carregandoUso = false);
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
      'tipo': dadosGlobais['tipo'] ?? 'diario',
      'hora_inicio': dadosGlobais['hora_inicio'] ?? 0,
      'hora_fim': dadosGlobais['hora_fim'] ?? 23,
      'limite_minutos': dadosGlobais['limite_minutos'] ?? 0,
      'xp_recompensa': dadosGlobais['xp_recompensa'] ?? 0,
      'moedas_recompensa': dadosGlobais['moedas_recompensa'] ?? 0,
    });

    HapticFeedback.lightImpact();
    _carregarUsoEmTempoReal();
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
    String tipo = meuDesafio['tipo'] ?? 'diario';

    Timestamp? ts = meuDesafio['aceito_em'] as Timestamp?;
    if (ts == null) return;
    DateTime dataAceite = ts.toDate();
    DateTime agora = DateTime.now();

    DateTime inicioJanela;
    DateTime fimJanela;

    if (tipo == 'horario') {
      int horaInicio = meuDesafio['hora_inicio'] ?? 18;
      int horaFim = meuDesafio['hora_fim'] ?? 23;
      inicioJanela = DateTime(
        dataAceite.year,
        dataAceite.month,
        dataAceite.day,
        horaInicio,
        0,
      );
      fimJanela = DateTime(
        dataAceite.year,
        dataAceite.month,
        dataAceite.day,
        horaFim,
        59,
      );
    } else {
      inicioJanela = DateTime(
        dataAceite.year,
        dataAceite.month,
        dataAceite.day,
        0,
        0,
      );
      fimJanela = DateTime(
        dataAceite.year,
        dataAceite.month,
        dataAceite.day,
        23,
        59,
        59,
      );
    }

    if (agora.isBefore(fimJanela)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O período do desafio ainda não acabou!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    int minutosUsadosNaJanela = 0;
    List<Map<String, dynamic>> appsJanela = await UsageService.getAppsNoHorario(
      inicioJanela,
      fimJanela,
    );

    for (var app in appsJanela) {
      if (app['nome'].toString().toLowerCase().contains(
        appAlvo.toLowerCase(),
      )) {
        minutosUsadosNaJanela = app['minutos'];
        break;
      }
    }

    if (minutosUsadosNaJanela <= limite) {
      final FirestoreService firestoreService = FirestoreService();
      bool subiuDeNivel = await firestoreService.adicionarRecompensa(
        xpGanho,
        moedasGanhas,
      );

      if (subiuDeNivel) {
        _confettiController.play();
        HapticFeedback.heavyImpact();
        try {
          await AudioPlayer().play(AssetSource('sounds/levelup.mp3'));
        } catch (_) {}
      }

      var desafiosColetados = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .where('status', isEqualTo: 'coletado')
          .limit(1)
          .get();

      if (desafiosColetados.docs.isEmpty) {
        await _db.collection('usuarios').doc(uid).update({
          'badges': FieldValue.arrayUnion(['badge_primeiro_desafio']),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selo Desbloqueado: O inicio!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      await _db
          .collection('usuarios')
          .doc(uid)
          .collection('meus_desafios')
          .doc(desafioId)
          .update({'status': 'coletado'});

      try {
        await _audioPlayer.play(AssetSource('sounds/sucesso.mp3'));
      } catch (_) {}
      HapticFeedback.mediumImpact();

      setState(() {
        _textoXpFlutuante = "+$xpGanho XP";
        _mostrarXpFlutuante = true;
      });
      _xpAnimController.forward(from: 0).then((_) {
        if (mounted) setState(() => _mostrarXpFlutuante = false);
      });
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
              'Falhou! O uso na janela foi de $minutosUsadosNaJanela min.',
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
            title: const Text(
              'Seus Desafios',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF246815),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _carregarUsoEmTempoReal,
              ),
            ],
          ),
          body: _carregandoUso
              ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF246815)),
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
                      String status = meuProgresso['status'] ?? '';

                      bool aceitoHoje = false;
                      Timestamp? ts =
                      meuProgresso['aceito_em'] as Timestamp?;
                      if (ts != null) {
                        DateTime dataAceite = ts.toDate();
                        DateTime hoje = DateTime.now();
                        if (dataAceite.year == hoje.year &&
                            dataAceite.month == hoje.month &&
                            dataAceite.day == hoje.day) {
                          aceitoHoje = true;
                        }
                      }

                      dadosGlobais['meu_status'] = status;
                      dadosGlobais['aceito_hoje'] = aceitoHoje;
                      dadosGlobais['aceito_em'] =
                      meuProgresso['aceito_em'];

                      if (status == 'aceito') {
                        emAndamento.add(dadosGlobais);
                      } else if (status == 'falhou' && aceitoHoje) {
                        emAndamento.add(dadosGlobais);
                      } else if (status == 'coletado' && aceitoHoje) {
                      } else {
                        disponiveis.add(dadosGlobais);
                      }
                    } else {
                      disponiveis.add(dadosGlobais);
                    }
                  }

                  return RefreshIndicator(
                    onRefresh: _carregarUsoEmTempoReal,
                    color: const Color(0xFF246815),
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
                              String tipo = desafio['tipo'] ?? 'diario';
                              bool aceitoHoje =
                                  desafio['aceito_hoje'] ?? false;
                              int horaFim = desafio['hora_fim'] ?? 23;

                              bool podeValidarHoje = false;
                              if (tipo == 'horario' && aceitoHoje) {
                                if (DateTime.now().hour > horaFim) {
                                  podeValidarHoje = true;
                                }
                              }

                              bool bloqueadoPeloTempo =
                                  aceitoHoje && !podeValidarHoje;

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
                                  minutosUsadosHoje > limite &&
                                      tipo == 'diario';
                              bool estaFalhado =
                                  falhouDb ||
                                      (aceitoHoje && estourouLimiteAgora);

                              if (aceitoHoje &&
                                  estourouLimiteAgora &&
                                  !falhouDb) {
                                _reprovarDesafioImediatamente(
                                  desafio['id'],
                                );
                              }

                              bool botaoBloqueado =
                                  bloqueadoPeloTempo || estaFalhado;
                              Color corBarra = estaFalhado
                                  ? Colors.red
                                  : (porcentagemRisco >= 0.8
                                  ? Colors.orange
                                  : const Color(0xFF246815));

                              String textoBotao;
                              if (estaFalhado) {
                                textoBotao =
                                'Reprovado (Limite excedido)';
                              } else if (bloqueadoPeloTempo) {
                                textoBotao = (tipo == 'horario')
                                    ? 'Em análise (Aguarde passar das ${horaFim}h)'
                                    : 'Em análise (Volte amanhã)';
                              } else {
                                textoBotao = 'Validar Recompensa';
                              }

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
                                                  : (tipo == 'horario'
                                                  ? Icons.dark_mode
                                                  : Icons.timer),
                                              color: estaFalhado
                                                  ? Colors.red
                                                  : const Color(
                                                0xFF246815,
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
                                                  tipo == 'horario'
                                                      ? 'Janela: ${desafio['hora_inicio']}h até ${desafio['hora_fim']}h | Limite: $limite min'
                                                      : 'Limite diário: $limite min | Usado: $minutosUsadosHoje min',
                                                  style: TextStyle(
                                                    color: estaFalhado
                                                        ? Colors.red
                                                        : Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (tipo != 'horario') ...[
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
                                      ],
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
                                          ),
                                          child: Text(
                                            textoBotao,
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
                            bool ehHorario = desafio['tipo'] == 'horario';
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
                                          child: Icon(
                                            ehHorario
                                                ? Icons.nights_stay
                                                : Icons.star_border,
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
                                                ehHorario
                                                    ? 'Usar max ${desafio['limite_minutos']} min do ${desafio['app_alvo']} das ${desafio['hora_inicio']}h às ${desafio['hora_fim']}h'
                                                    : 'Troque tempo no ${desafio['app_alvo']} por ${desafio['xp_recompensa']} XP',
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

        if (_mostrarXpFlutuante)
          Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _xpAnimController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _xpPosition.value),
                  child: Opacity(
                    opacity: _xpOpacity.value,
                    child: Text(
                      _textoXpFlutuante,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF246815),
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.2,
            colors: const [
              Color(0xFF246815),
              Colors.amber,
              Colors.white,
              Colors.orange,
            ],
          ),
        ),
      ],
    );
  }
}