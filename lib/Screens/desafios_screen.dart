import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/desafio_service.dart';
import '../services/usage_service.dart';

class DesafiosScreen extends StatefulWidget {
  const DesafiosScreen({super.key});

  @override
  State<DesafiosScreen> createState() => _DesafiosScreenState();
}

class _DesafiosScreenState extends State<DesafiosScreen> {
  final DesafioService _desafioService = DesafioService();
  List<Map<String, dynamic>> _appsDoUsuario = [];

  @override
  void initState() {
    super.initState();
    _carregarAppsDoAparelho();
  }

  // Pega o uso real do celular para podermos validar os minutos
  Future<void> _carregarAppsDoAparelho() async {
    final apps = await UsageService.getTopApps();
    if (mounted) {
      setState(() {
        _appsDoUsuario = apps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desafios & Missões'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. RECOMPENSAS EXIBIDAS NA TELA: Mostrador de pontos em tempo real
          StreamBuilder<DocumentSnapshot>(
            stream: _desafioService.dadosUsuario(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              var dados = snapshot.data!.data() as Map<String, dynamic>;
              int xp = dados['xp'] ?? 0;
              int moedas = dados['moedas'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      '✨ XP: $xp',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      '🪙 Moedas: $moedas',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),

          // 2. LISTA DE DESAFIOS EVOLUÍDA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _desafioService.listarDesafiosGlobais(),
              builder: (context, snapshotGlobais) {
                if (snapshotGlobais.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshotGlobais.hasData ||
                    snapshotGlobais.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum desafio ativo.'));
                }

                // AQUI ESTAVA O ERRO! Agora tem apenas um "stream" chamando a função correta.
                return StreamBuilder<QuerySnapshot>(
                  stream: _desafioService.listarMeusDesafios(),
                  builder: (context, snapshotMeus) {
                    final globais = snapshotGlobais.data!.docs;

                    // Mapeia todos os dados do desafio do usuário (incluindo a data de início)
                    Map<String, Map<String, dynamic>> meusDesafiosDados = {};
                    if (snapshotMeus.hasData) {
                      for (var doc in snapshotMeus.data!.docs) {
                        meusDesafiosDados[doc.id] =
                            doc.data() as Map<String, dynamic>;
                      }
                    }

                    // Filtra a lista para SUMIR os desafios já 'coletados'
                    final desafiosVisiveis = globais.where((doc) {
                      return meusDesafiosDados[doc.id]?['status'] != 'coletado';
                    }).toList();

                    if (desafiosVisiveis.isEmpty) {
                      return const Center(
                        child: Text(
                          '🎉 Parabéns! Você completou todos os desafios disponíveis.',
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: desafiosVisiveis.length,
                      itemBuilder: (context, index) {
                        var doc = desafiosVisiveis[index];
                        var desafio = doc.data() as Map<String, dynamic>;

                        String id = doc.id;
                        String titulo = desafio['titulo'] ?? 'Sem título';
                        int xpPremo = desafio['xp_recompensa'] ?? 0;
                        int moedasPremio = desafio['moedas_recompensa'] ?? 0;
                        String appAlvo = desafio['app_alvo'] ?? '';
                        int limiteMinutos = desafio['limite_minutos'] ?? 0;

                        // Puxa os dados do usuário para esse desafio
                        var meuDesafio = meusDesafiosDados[id];
                        String statusAtual =
                            meuDesafio?['status'] ?? 'nao_aceito';

                        // LÓGICA DA BRECHA (EXPLOIT) - DESATIVADA TEMPORARIAMENTE PARA TESTES!
                        bool bloqueadoPorTempo = false;

                        /* === CÓDIGO COMENTADO PARA VOCÊ PODER TESTAR IMEDIATAMENTE ===
                        Timestamp? dataInicioTs = meuDesafio?['data_inicio'];
                        if (statusAtual == 'aceito' && dataInicioTs != null) {
                          DateTime dataInicio = dataInicioTs.toDate();
                          DateTime hoje = DateTime.now();

                          if (dataInicio.day == hoje.day &&
                              dataInicio.month == hoje.month &&
                              dataInicio.year == hoje.year) {
                            bloqueadoPorTempo = true;
                          }
                        }
                        ============================================================= */

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const Text(
                              '🎯',
                              style: TextStyle(fontSize: 24),
                            ),
                            title: Text(titulo),
                            subtitle: Text(
                              'Prêmio: $xpPremo XP | 🪙 $moedasPremio\nFoco: $appAlvo (Máx: $limiteMinutos min)',
                            ),

                            // O BOTÃO DINÂMICO
                            trailing: statusAtual == 'nao_aceito'
                                ? ElevatedButton(
                                    onPressed: () =>
                                        _desafioService.aceitarDesafio(id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    child: const Text(
                                      'Aceitar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  )
                                : bloqueadoPorTempo
                                // Se estiver bloqueado (mesmo dia), mostra o botão cinza inativo
                                ? const ElevatedButton(
                                    onPressed: null,
                                    child: Text('Em andamento...'),
                                  )
                                // Se já for o dia seguinte (ou no nosso caso de teste, liberado direto), pode concluir!
                                : ElevatedButton(
                                    onPressed: () async {
                                      bool sucesso = await _desafioService
                                          .verificarEConcluir(
                                            id,
                                            appAlvo,
                                            limiteMinutos,
                                            xpPremo,
                                            moedasPremio,
                                            _appsDoUsuario,
                                          );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              sucesso
                                                  ? 'Sucesso! Recompensa injetada na conta!'
                                                  : 'Falha! Você estourou o limite de tempo do app.',
                                            ),
                                            backgroundColor: sucesso
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D9E75),
                                    ),
                                    child: const Text(
                                      'Concluir',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
