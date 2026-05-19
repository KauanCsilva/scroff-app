import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/firestore_service.dart'; // Import do Firestore
import '../services/auth_service.dart'; // Import do Authentication

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _minutosTotais = 0;
  int _minutosOntem = 0;
  List<Map<String, dynamic>> _topApps = [];
  bool _carregando = true;

  // Instanciando o serviço do Firestore
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _iniciarAtualizacaoAutomatica();
  }

  Future<void> _carregarDados() async {
    final minutos = await UsageService.getMinutosHoje();
    final minutosOntem = await UsageService.getMinutosOntem();
    final apps = await UsageService.getTopApps();

    if (mounted) {
      setState(() {
        _minutosTotais = minutos;
        _minutosOntem = minutosOntem;
        _topApps = apps;
        _carregando = false;
      });

      // Salva os minutos atuais na nuvem automaticamente
      _firestoreService.salvarTempoDeTela(minutos);
    }
  }

  void _iniciarAtualizacaoAutomatica() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60));
      if (mounted) {
        await _carregarDados();
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final horas = _minutosTotais ~/ 60;
    final minutos = _minutosTotais % 60;
    final progresso = (_minutosTotais / 480).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header com título à esquerda e botão de Logout à direita
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Scroff',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D9E75),
                        ),
                      ),
                      Text(
                        'Bom dia!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888780),
                        ),
                      ),
                    ],
                  ),
                  // Botão de Logout adicionado aqui
                  IconButton(
                    icon: const Icon(Icons.logout, color: Color(0xFF888780)),
                    tooltip: 'Sair da conta',
                    onPressed: () async {
                      await AuthService().sair();
                    },
                  ),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1D9E75),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _cardTempoTela(horas, minutos, progresso),
                        const SizedBox(height: 12),
                        _cardApps(),
                        const SizedBox(height: 12),
                        _cardDesafio(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTempoTela(int horas, int minutos, double progresso) {
    String textoComparacao = "Sem dados de ontem";
    Color corFundo = const Color(0xFFF5F5F5);
    Color corTexto = const Color(0xFF888780);

    if (_minutosOntem > 0) {
      int diferenca = _minutosTotais - _minutosOntem;

      if (diferenca > 0) {
        textoComparacao = '▲ $diferenca min a mais que ontem';
        corFundo = const Color(0xFFFFEBEE);
        corTexto = const Color(0xFFC62828);
      } else if (diferenca < 0) {
        textoComparacao = '▼ ${diferenca.abs()} min a menos que ontem';
        corFundo = const Color(0xFFE1F5EE);
        corTexto = const Color(0xFF085041);
      } else {
        textoComparacao = 'Tempo igual ao de ontem';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEMPO DE TELA HOJE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888780),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 7,
                      color: Color(0xFFE1F5EE),
                    ),
                    CircularProgressIndicator(
                      value: progresso,
                      strokeWidth: 7,
                      color: const Color(0xFF1D9E75),
                    ),
                    Text(
                      '${(progresso * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${horas}h ${minutos}m',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'tempo de tela hoje',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: corFundo,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textoComparacao,
                      style: TextStyle(
                        fontSize: 11,
                        color: corTexto,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardApps() {
    final cores = [
      const Color(0xFFE24B4A),
      const Color(0xFFBA7517),
      const Color(0xFF1D9E75),
    ];
    final maxMinutos = _topApps.isEmpty ? 1 : _topApps.first['minutos'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPS PRINCIPAIS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888780),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (_topApps.isEmpty)
            const Text(
              'Nenhum dado ainda.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
            )
          else
            ...List.generate(_topApps.length, (i) {
              final app = _topApps[i];
              final mins = app['minutos'] as int;
              final progresso = mins / maxMinutos;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < _topApps.length - 1 ? 10 : 0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          app['nome'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888780),
                          ),
                        ),
                        Text(
                          '${mins}m',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progresso,
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE0E0E0),
                        valueColor: AlwaysStoppedAnimation(cores[i]),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _cardDesafio() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESAFIO ATIVO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888780),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('📵', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semana sem TikTok',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '5 de 7 dias concluídos',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
              value: 0.71,
              minHeight: 6,
              backgroundColor: Color(0xFFE1F5EE),
              valueColor: AlwaysStoppedAnimation(Color(0xFF1D9E75)),
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5 de 7 dias',
                style: TextStyle(fontSize: 10, color: Color(0xFF888780)),
              ),
              Text(
                '71%',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF1D9E75),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
