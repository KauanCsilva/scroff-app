import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/firestore_service.dart';

class ModoFocoScreen extends StatefulWidget {
  const ModoFocoScreen({super.key});

  @override
  State<ModoFocoScreen> createState() => _ModoFocoScreenState();
}

class _ModoFocoScreenState extends State<ModoFocoScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final int _tempoTotal = 1500;
  late int _segundosRestantes;
  Timer? _timer;
  bool _estaRodando = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _musicaTocando = false;
  bool _cafeAtivadoNoFoco = false;
  late ConfettiController _confettiController;

  late AnimationController _xpAnimController;
  late Animation<double> _xpOpacity;
  late Animation<double> _xpPosition;
  String _textoXpFlutuante = "";
  bool _mostrarXpFlutuante = false;

  @override
  void initState() {
    super.initState();
    _segundosRestantes = _tempoTotal;
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
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
    _timer?.cancel();
    _audioPlayer.dispose();
    _confettiController.dispose();
    _xpAnimController.dispose();
    super.dispose();
  }

  Future<void> _alternarMusica() async {
    try {
      if (_musicaTocando) {
        await _audioPlayer.pause();
        setState(() => _musicaTocando = false);
      } else {
        await _audioPlayer.play(AssetSource('sounds/Lofi.mp3'));
        setState(() => _musicaTocando = true);
      }
    } catch (e) {
      debugPrint("Erro ao tocar Lo-Fi");
    }
  }

  void _alternarCronometro() async {
    if (_estaRodando) {
      _timer?.cancel();
      await _audioPlayer.pause();
      setState(() {
        _estaRodando = false;
        _musicaTocando = false;
      });
    } else {
      _estaRodando = true;

      if (!_musicaTocando) {
        try {
          await _audioPlayer.play(AssetSource('sounds/Lofi.mpeg'));
          _musicaTocando = true;
        } catch (_) {}
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_segundosRestantes > 0) {
          setState(() {
            _segundosRestantes--;
          });
        } else {
          _timer?.cancel();
          _audioPlayer.stop();
          setState(() {
            _estaRodando = false;
            _musicaTocando = false;
          });
          _concluirFocoReal();
        }
      });
      setState(() {});
    }
  }

  Future<void> _usarCafe(Map<String, dynamic> consumiveis) async {
    if (_cafeAtivadoNoFoco || (consumiveis['cafe'] ?? 0) <= 0) return;

    String uid = _auth.currentUser!.uid;
    int qtd = consumiveis['cafe'];
    consumiveis['cafe'] = qtd - 1;

    await _db.collection('usuarios').doc(uid).update({
      'consumiveis': consumiveis,
    });
    setState(() => _cafeAtivadoNoFoco = true);
    HapticFeedback.lightImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('☕ Café Expresso Ativado!'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  Future<void> _concluirFocoReal() async {
    int xpBase = 150;
    int moedasBase = 3;

    if (_cafeAtivadoNoFoco) {
      xpBase *= 2;
      moedasBase *= 2;
    }

    bool subiuDeNivel = await _firestoreService.adicionarRecompensa(
      xpBase,
      moedasBase,
    );

    if (subiuDeNivel) {
      _confettiController.play();
      HapticFeedback.heavyImpact();
      try {
        await AudioPlayer().play(AssetSource('sounds/levelup.mp3'));
      } catch (_) {}
    }

    try {
      await _audioPlayer.play(AssetSource('sounds/sucesso.mp3'));
    } catch (_) {}
    HapticFeedback.mediumImpact();

    setState(() {
      _textoXpFlutuante = "+$xpBase XP";
      _mostrarXpFlutuante = true;
    });

    _xpAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _mostrarXpFlutuante = false);
    });

    setState(() {
      _segundosRestantes = _tempoTotal;
      _cafeAtivadoNoFoco = false;
    });
  }

  void _cancelarFoco() {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _segundosRestantes = _tempoTotal;
      _estaRodando = false;
      _musicaTocando = false;
      _cafeAtivadoNoFoco = false;
      _mostrarXpFlutuante = false;
    });
  }

  String _formatarTempo() {
    int minutos = _segundosRestantes ~/ 60;
    int segundos = _segundosRestantes % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser!.uid;
    double progresso = 1 - (_segundosRestantes / _tempoTotal);

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> consumiveis = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          var dados = snapshot.data!.data() as Map<String, dynamic>;
          consumiveis = dados['consumiveis'] ?? {};
        }

        int quantCafes = consumiveis['cafe'] ?? 0;

        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF111111),
              appBar: AppBar(
                title: const Text('Modo Foco'),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(
                      _musicaTocando ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                    ),
                    onPressed: _estaRodando ? _alternarMusica : null,
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _estaRodando
                          ? (_cafeAtivadoNoFoco
                          ? '☕ Foco Turbinado com Café!'
                          : '🧘🏽‍♂️ Focando com Lo-Fi...')
                          : 'Pronto para começar?',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 50),

                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CircularProgressIndicator(
                            value: progresso,
                            strokeWidth: 14,
                            backgroundColor: Colors.white12,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _cafeAtivadoNoFoco
                                  ? Colors.amber
                                  : const Color(0xFF1D9E75),
                            ),
                          ),
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatarTempo(),
                              style: const TextStyle(
                                fontSize: 70,
                                fontWeight: FontWeight.w200,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _alternarCronometro,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _estaRodando
                                      ? Colors.white12
                                      : (_cafeAtivadoNoFoco
                                      ? Colors.amber
                                      : const Color(0xFF1D9E75)),
                                ),
                                child: Icon(
                                  _estaRodando ? Icons.pause : Icons.play_arrow,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_mostrarXpFlutuante)
                          AnimatedBuilder(
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
                                      color: Color(0xFF1D9E75),
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    if (_estaRodando && !_cafeAtivadoNoFoco)
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.local_cafe,
                          color: Colors.amber,
                          size: 18,
                        ),
                        label: Text(
                          'Ativar Café Expresso (Tem: $quantCafes)',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: quantCafes > 0
                            ? () => _usarCafe(consumiveis)
                            : null,
                      ),

                    if (_estaRodando) ...[
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _cancelarFoco,
                        child: const Text(
                          'Desistir',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
      },
    );
  }
}