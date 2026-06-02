import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import '../services/firestore_service.dart';

class ModoFocoScreen extends StatefulWidget {
  const ModoFocoScreen({super.key});

  @override
  State<ModoFocoScreen> createState() => _ModoFocoScreenState();
}

class _ModoFocoScreenState extends State<ModoFocoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  int _segundosRestantes = 1500; // 25 minutos
  Timer? _timer;
  bool _estaRodando = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _musicaTocando = false;
  late ConfettiController _confettiController;

  // LOGICA DO COMPLEMENTO (CAFÉ)
  bool _cafeAtivadoNoFoco = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _alternarMusica() async {
    try {
      if (_musicaTocando) {
        await _audioPlayer.pause();
        setState(() => _musicaTocando = false);
      } else {
        await _audioPlayer.play(AssetSource('sounds/Lofi.mpeg'));
        setState(() => _musicaTocando = true);
      }
    } catch (e) {
      debugPrint("Erro ao tocar Lo-Fi: $e");
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

      // 👇 LINHA CORRIGIDA: Inicia o som automaticamente ao habilitar o cronômetro 👇
      if (!_musicaTocando) {
        try {
          await _audioPlayer.play(AssetSource('sounds/Lofi.mp3'));
          _musicaTocando = true;
        } catch (e) {
          debugPrint("Erro ao iniciar áudio: $e");
        }
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

  // GASTA O CAFÉ E ATIVA O MULTIPLICADOR
  Future<void> _usarCafe(Map<String, dynamic> consumiveis) async {
    if (_cafeAtivadoNoFoco || (consumiveis['cafe'] ?? 0) <= 0) return;

    String uid = _auth.currentUser!.uid;
    int qtd = consumiveis['cafe'];
    consumiveis['cafe'] = qtd - 1;

    await _db.collection('usuarios').doc(uid).update({
      'consumiveis': consumiveis,
    });
    setState(() {
      _cafeAtivadoNoFoco = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('☕ Café Expresso Ativado! Recompensas duplicadas.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  // ENVIA OS DADOS REAIS DE RECOMPENSA PRO FIREBASE
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
      try {
        await AudioPlayer().play(AssetSource('sounds/levelup.mp3'));
      } catch (_) {}
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(subiuDeNivel ? '🎊 LEVEL UP! 🎊' : '🎯 Foco Concluído!'),
          content: Text(
            'Excelente trabalho!\n\n+$xpBase XP\n+$moedasBase Moedas ${_cafeAtivadoNoFoco ? "(Bônus de Café! ☕)" : ""}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Excelente!',
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

    setState(() {
      _segundosRestantes = 1500;
      _cafeAtivadoNoFoco = false;
    });
  }

  void _cancelarFoco() {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _segundosRestantes = 1500;
      _estaRodando = false;
      _musicaTocando = false;
      _cafeAtivadoNoFoco = false;
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
                    const SizedBox(height: 30),

                    Text(
                      _formatarTempo(),
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_estaRodando && !_cafeAtivadoNoFoco)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: OutlinedButton.icon(
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
                      ),
                    if (_cafeAtivadoNoFoco)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          '🚀 Multiplicador de XP 2x Ativo',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    GestureDetector(
                      onTap: _alternarCronometro,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _estaRodando
                              ? Colors.amber
                              : const Color(0xFF1D9E75),
                        ),
                        child: Icon(
                          _estaRodando ? Icons.pause : Icons.play_arrow,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    if (_estaRodando) ...[
                      const SizedBox(height: 30),
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
            // CONFETE DE LEVEL UP — flutua por cima do Scaffold
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.2,
                emissionFrequency: 0.05,
                colors: const [
                  Color(0xFF1D9E75),
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
