import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // IMPORT DO ÁUDIO
import 'dart:async';

class ModoFocoScreen extends StatefulWidget {
  const ModoFocoScreen({super.key});

  @override
  State<ModoFocoScreen> createState() => _ModoFocoScreenState();
}

class _ModoFocoScreenState extends State<ModoFocoScreen> {
  // CONTROLADORES DO CRONÔMETRO
  int _segundosRestantes = 1500; // 25 minutos padrão (Pomodoro)
  Timer? _timer;
  bool _estaRodando = false;

  // CONTROLADORES DA MÚSICA LO-FI 🎵
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _musicaTocando = false;

  @override
  void initState() {
    super.initState();
    _configurarMusica();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose(); // Limpa o player da memória ao sair da tela
    super.dispose();
  }

  // CONFIGURA O LOOP INFINITO DA MÚSICA
  Future<void> _configurarMusica() async {
    _audioPlayer.setReleaseMode(
      ReleaseMode.loop,
    ); // Define para repetir para sempre
  }

  // FUNÇÃO PARA LIGAR/DESLIGAR A MÚSICA (BOTÃO DE MUDO)
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
      debugPrint(
        "Erro ao carregar o Lo-Fi (verifique se o arquivo está em assets/sounds/Lofi.mpeg): $e",
      );
    }
  }

  void _alternarCronometro() {
    if (_estaRodando) {
      // PAUSAR
      _timer?.cancel();
      _audioPlayer.pause(); // Pausa a música junto com o cronômetro
      setState(() {
        _estaRodando = false;
        _musicaTocando = false;
      });
    } else {
      // INICIAR / RETOMAR
      _estaRodando = true;

      // Inicia a música automaticamente ao dar "Play" no foco 🎧
      if (!_musicaTocando) {
        _audioPlayer.play(AssetSource('sounds/Lofi.mpeg'));
        _musicaTocando = true;
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_segundosRestantes > 0) {
          setState(() {
            _segundosRestantes--;
          });
        } else {
          _timer?.cancel();
          _audioPlayer.stop(); // Para a música quando o tempo acabar
          setState(() {
            _estaRodando = false;
            _musicaTocando = false;
          });
          _mostrarDialogFocoConcluido();
        }
      });
      setState(() {});
    }
  }

  void _cancelarFoco() {
    _timer?.cancel();
    _audioPlayer.stop(); // Para a música se desistir
    setState(() {
      _segundosRestantes = 1500;
      _estaRodando = false;
      _musicaTocando = false;
    });
  }

  String _formatarTempo() {
    int minutos = _segundosRestantes ~/ 60;
    int segundos = _segundosRestantes % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  void _mostrarDialogFocoConcluido() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 Foco Concluído!'),
        content: const Text(
          'Excelente trabalho! Você completou o seu tempo de foco.\n\n+150 XP\n+30 Moedas',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF111111,
      ), // Fundo escuro imersivo para economizar bateria e focar
      appBar: AppBar(
        title: const Text('Modo Foco'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 🎧 BOTÃO DINÂMICO DE MUDO NA APPBAR
          IconButton(
            icon: Icon(
              _musicaTocando ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            tooltip: _musicaTocando ? 'Mutar Lo-Fi' : 'Tocar Lo-Fi',
            onPressed: _estaRodando
                ? _alternarMusica
                : null, // Só deixa mexer na música se o foco estiver rodando
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // EFEITO VISUAL DA VIBE RELAXANTE DO JOGO
            Text(
              _estaRodando ? 'Modo foco ativado...' : 'Pronto para começar?',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 30),

            // O CRONÔMETRO GIGANTE
            Text(
              _formatarTempo(),
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 60),

            // BOTÃO DE PLAY / PAUSE GAMIFICADO
            GestureDetector(
              onTap: _alternarCronometro,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _estaRodando ? Colors.amber : const Color(0xFF1D9E75),
                  boxShadow: [
                    BoxShadow(
                      color: _estaRodando
                          ? Colors.amber.withValues(alpha: 0.4)
                          : const Color(0xFF1D9E75).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _estaRodando ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

            // BOTÃO DISCRETO PARA CANCELAR
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
    );
  }
}
