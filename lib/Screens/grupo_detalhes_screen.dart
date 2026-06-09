import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../services/boss_service.dart';

class GrupoDetalhesScreen extends StatefulWidget {
  final Map<String, dynamic> grupoData;

  const GrupoDetalhesScreen({super.key, required this.grupoData});

  @override
  State<GrupoDetalhesScreen> createState() => _GrupoDetalhesScreenState();
}

class _GrupoDetalhesScreenState extends State<GrupoDetalhesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BossService _bossService = BossService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _atacando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatarTempo(int totalMinutos) {
    if (totalMinutos < 60) return '${totalMinutos}m';
    int horas = totalMinutos ~/ 60;
    int minutos = totalMinutos % 60;
    return '${horas}h ${minutos}m';
  }

  // ================= 1. SAIR OU EXCLUIR GRUPO =================
  Future<void> _gerenciarGrupo(String acao) async {
    String uid = _auth.currentUser?.uid ?? '';
    String groupId = widget.grupoData['id'] ?? '';

    try {
      if (acao == 'sair') {
        // Remove o utilizador da lista de membros
        List<dynamic> membros = widget.grupoData['membros'] ?? [];
        membros.remove(uid);
        await _db.collection('grupos').doc(groupId).update({
          'membros': membros,
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Você saiu da Party.')));
          Navigator.pop(context); // Volta para a tela anterior
        }
      } else if (acao == 'excluir') {
        // Apaga o grupo inteiro
        await _db.collection('grupos').doc(groupId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party excluída com sucesso.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Erro ao gerenciar grupo: $e");
    }
  }

  // ================= 2. CRIAR NOVO COMBINADO =================
  void _mostrarDialogNovoCombinado() {
    final TextEditingController tituloCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    final TextEditingController premioCtrl = TextEditingController();
    DateTime dataFim = DateTime.now().add(const Duration(days: 7));
    String uid = _auth.currentUser?.uid ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Novo Combinado 🤝'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome (ex: Jantar da semana)',
                      ),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Regra (ex: Quem usar menos tela não paga)',
                      ),
                    ),
                    TextField(
                      controller: premioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prêmio (ex: Jantar grátis)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Data final:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () async {
                            DateTime? escolhida = await showDatePicker(
                              context: context,
                              initialDate: dataFim,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (escolhida != null) {
                              setStateDialog(() => dataFim = escolhida);
                            }
                          },
                          child: Text(DateFormat('dd/MM/yyyy').format(dataFim)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                  ),
                  onPressed: () async {
                    if (tituloCtrl.text.isEmpty) return;

                    await _db
                        .collection('grupos')
                        .doc(widget.grupoData['id'])
                        .collection('combinados')
                        .add({
                          'titulo': tituloCtrl.text,
                          'descricao': descCtrl.text,
                          'premio': premioCtrl.text,
                          'data_fim': Timestamp.fromDate(dataFim),
                          'status': 'ativo',
                          'criador_id':
                              uid, // Grava quem criou para poder apagar depois
                          'criado_em': FieldValue.serverTimestamp(),
                        });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Criar Aposta',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= 3. COROAR O VENCEDOR =================
  Future<void> _finalizarApostaEEncontrarVencedor(String combinadoId) async {
    String groupId = widget.grupoData['id'];
    List<dynamic> membros = widget.grupoData['membros'] ?? [];

    if (membros.isEmpty) return;

    try {
      // Puxa o ranking atual de todo mundo do grupo
      QuerySnapshot snapMembros = await _db
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: membros)
          .get();

      var usuarios = snapMembros.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      // Ordena para achar quem tem o MENOR tempo de tela
      usuarios.sort(
        (a, b) => (a['minutos_hoje'] ?? 0).compareTo(b['minutos_hoje'] ?? 0),
      );

      String nomeVencedor = usuarios.isNotEmpty
          ? (usuarios.first['nome'] ?? 'Desconhecido')
          : 'Ninguém';

      // Atualiza o status da aposta para finalizado e grava o vencedor
      await _db
          .collection('grupos')
          .doc(groupId)
          .collection('combinados')
          .doc(combinadoId)
          .update({'status': 'finalizado', 'vencedor': nomeVencedor});

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('👑 Veredito Final!'),
            content: Text(
              'A aposta foi encerrada.\n\nO vencedor com o menor tempo de tela é:\n\n🏆 $nomeVencedor',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Incrível!',
                  style: TextStyle(color: Color(0xFF1D9E75)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao finalizar aposta: $e");
    }
  }

  // ================= 4. EXCLUIR APOSTA =================
  Future<void> _excluirAposta(String combinadoId) async {
    String groupId = widget.grupoData['id'];
    await _db
        .collection('grupos')
        .doc(groupId)
        .collection('combinados')
        .doc(combinadoId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    String groupId = widget.grupoData['id'] ?? '';
    List<dynamic> membros = widget.grupoData['membros'] ?? [];
    String uid = _auth.currentUser?.uid ?? '';
    bool isDonoDoGrupo = widget.grupoData['criador_id'] == uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupoData['nome'] ?? 'Detalhes do Grupo'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        actions: [
          // MENU TRÊS PONTINHOS NO TOPO
          PopupMenuButton<String>(
            onSelected: _gerenciarGrupo,
            itemBuilder: (BuildContext context) {
              return [
                if (!isDonoDoGrupo)
                  const PopupMenuItem(
                    value: 'sair',
                    child: Text('Sair da Party'),
                  ),
                if (isDonoDoGrupo)
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Text(
                      'Excluir Party',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Ranking'),
            Tab(icon: Icon(Icons.handshake), text: 'Combinados'),
            Tab(icon: Icon(Icons.local_fire_department), text: 'Boss'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogNovoCombinado,
        backgroundColor: const Color(0xFF1D9E75),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Aposta', style: TextStyle(color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ================= ABA 1: RANKING =================
          membros.isEmpty
              ? const Center(child: Text('Nenhum membro neste grupo.'))
              : FutureBuilder<QuerySnapshot>(
                  future: _db
                      .collection('usuarios')
                      .where(FieldPath.documentId, whereIn: membros)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const Center(
                        child: Text('Erro ao carregar ranking.'),
                      );

                    var usuarios = snapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList();
                    usuarios.sort(
                      (a, b) => (a['minutos_hoje'] ?? 0).compareTo(
                        b['minutos_hoje'] ?? 0,
                      ),
                    );

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: usuarios.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var user = usuarios[index];
                        int minutos = user['minutos_hoje'] ?? 0;

                        String coroa = '';
                        if (index == 0) coroa = ' 👑';
                        if (index == 1) coroa = ' 🥈';
                        if (index == 2) coroa = ' 🥉';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: index == 0
                                ? Colors.amber[100]
                                : Colors.grey[100],
                            child: Text(
                              '${index + 1}º',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: index == 0
                                    ? Colors.amber[900]
                                    : Colors.black,
                              ),
                            ),
                          ),
                          title: Text(
                            '${user['nome'] ?? 'Usuário'}$coroa',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            _formatarTempo(minutos),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: index == 0
                                  ? const Color(0xFF1D9E75)
                                  : Colors.black87,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

          // ================= ABA 2: COMBINADOS =================
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('grupos')
                .doc(groupId)
                .collection('combinados')
                .orderBy('criado_em', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum combinado ativo. Crie uma aposta! 🤝',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var combinado = doc.data() as Map<String, dynamic>;

                  String titulo = combinado['titulo'] ?? '';
                  String descricao = combinado['descricao'] ?? '';
                  String premio = combinado['premio'] ?? '';
                  String status = combinado['status'] ?? 'ativo';
                  String vencedor = combinado['vencedor'] ?? '';
                  String criadorId = combinado['criador_id'] ?? '';

                  bool podeExcluir = (criadorId == uid || isDonoDoGrupo);

                  Timestamp dataFimTs = combinado['data_fim'];
                  DateTime dataFim = dataFimTs.toDate();
                  // Zera horas/minutos para a diferença de dias ser exata
                  DateTime hoje = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  );
                  DateTime dataFinalLimpa = DateTime(
                    dataFim.year,
                    dataFim.month,
                    dataFim.day,
                  );

                  int diasRestantes = dataFinalLimpa.difference(hoje).inDays;
                  bool expirou = diasRestantes < 0;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              // Ícone de exclusão para o dono
                              if (podeExcluir)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _excluirAposta(doc.id),
                                ),

                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'ativo'
                                      ? const Color(0xFFE1F5EE)
                                      : Colors.amber[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'ativo'
                                        ? const Color(0xFF1D9E75)
                                        : Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            descricao,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // STATUS DO TEMPO
                              Row(
                                children: [
                                  Icon(
                                    status == 'finalizado'
                                        ? Icons.check_circle
                                        : Icons.timer_outlined,
                                    size: 16,
                                    color: status == 'finalizado'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status == 'finalizado'
                                        ? 'Finalizado'
                                        : (expirou
                                              ? 'Prazo Encerrado'
                                              : '$diasRestantes dias restantes'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: status == 'finalizado'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '🏆 $premio',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),

                          // AÇÃO OU RESULTADO
                          if (status == 'ativo' && expirou) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _finalizarApostaEEncontrarVencedor(doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D9E75),
                                ),
                                child: const Text(
                                  'Coroar Vencedor',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (status == 'finalizado') ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Text(
                                '👑 Vencedor: $vencedor',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // ================= ABA 3: BOSS =================
          _construirAbaBoss(groupId, uid, isDonoDoGrupo),
        ],
      ),
    );
  }

  // ================= ABA BOSS =================
  Widget _construirAbaBoss(String groupId, String uid, bool isDono) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bossService.bossStream(groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
          );
        }

        Map<String, dynamic> grupoData =
            snapshot.data!.data() as Map<String, dynamic>;
        Map<String, dynamic>? boss = grupoData['boss'] as Map<String, dynamic>?;
        int minutosHoje = 0;

        // Busca minutos do usuário atual para calcular dano
        return FutureBuilder<DocumentSnapshot>(
          future: _db.collection('usuarios').doc(uid).get(),
          builder: (context, userSnap) {
            if (userSnap.hasData && userSnap.data!.exists) {
              minutosHoje =
                  (userSnap.data!.data()
                      as Map<String, dynamic>)['minutos_hoje'] ??
                  0;
            }

            // SEM BOSS ATIVO
            if (boss == null || boss['ativo'] != true) {
              return _telaInvocarBoss(groupId, isDono, boss);
            }

            // BOSS ATIVO
            return _telaBossAtivo(groupId, uid, boss, minutosHoje);
          },
        );
      },
    );
  }

  // Tela quando não há boss ativo
  Widget _telaInvocarBoss(
    String groupId,
    bool isDono,
    Map<String, dynamic>? bossAnterior,
  ) {
    bool foiDerrotado = bossAnterior != null && bossAnterior['ativo'] == false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (foiDerrotado) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1D9E75)),
              ),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    '${bossAnterior['emoji']} ${bossAnterior['nome']} foi derrotado!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Todos ganharam +${bossAnterior['recompensa_xp']} XP e +${bossAnterior['recompensa_moedas']} moedas!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1D9E75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          const Text('⚔️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Nenhum boss ativo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Invocar um boss cria um desafio coletivo. Cada membro causa dano ficando abaixo de 3h de tela por dia. Derrotem juntos e ganhem recompensas!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          if (isDono) ...[
            const Text(
              'ESCOLHA O BOSS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ...BossService.catalogo.map((boss) {
              Color corBoss = Color(boss['cor'] as int);
              return GestureDetector(
                onTap: () async {
                  await _bossService.invocarBoss(groupId, boss);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${boss['emoji']} ${boss['nome']} foi invocado!',
                        ),
                        backgroundColor: corBoss,
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: corBoss.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: corBoss.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Text(boss['emoji'], style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              boss['nome'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: corBoss,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              boss['descricao'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _chipInfo(
                                  '❤️ ${boss['hp_maximo']} HP',
                                  corBoss,
                                ),
                                const SizedBox(width: 8),
                                _chipInfo(
                                  '✨ ${boss['recompensa_xp']} XP',
                                  corBoss,
                                ),
                                const SizedBox(width: 8),
                                _chipInfo(
                                  '🪙 ${boss['recompensa_moedas']}',
                                  corBoss,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Apenas o dono da party pode invocar um boss.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Tela com boss ativo
  Widget _telaBossAtivo(
    String groupId,
    String uid,
    Map<String, dynamic> boss,
    int minutosHoje,
  ) {
    int hpAtual = boss['hp_atual'] ?? 0;
    int hpMaximo = boss['hp_maximo'] ?? 1;
    double hpPercent = hpAtual / hpMaximo;
    Color corBoss = Color(boss['cor'] as int);

    Map<String, dynamic> ataquesDiarios = Map<String, dynamic>.from(
      boss['ataques_diarios'] ?? {},
    );
    String hoje =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    bool jaAtacouHoje = ataquesDiarios[uid] == hoje;

    Map<String, dynamic> danoPorMembro = Map<String, dynamic>.from(
      boss['dano_por_membro'] ?? {},
    );

    // Calcula dano potencial de hoje
    int danoPotencial = minutosHoje < 180
        ? (180 - minutosHoje).clamp(10, 200)
        : 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // CARD DO BOSS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: corBoss.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: corBoss.withOpacity(0.4), width: 2),
            ),
            child: Column(
              children: [
                Text(boss['emoji'], style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  boss['nome'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: corBoss,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  boss['descricao'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // BARRA DE HP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '❤️ HP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$hpAtual / $hpMaximo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: corBoss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: hpPercent),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 18,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(corBoss),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // RECOMPENSAS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chipInfo(
                      '✨ ${boss['recompensa_xp']} XP ao vencer',
                      corBoss,
                    ),
                    const SizedBox(width: 8),
                    _chipInfo('🪙 ${boss['recompensa_moedas']}', corBoss),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // BOTÃO DE ATAQUE
          if (!jaAtacouHoje)
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _atacando
                    ? null
                    : () => _executarAtaque(groupId, minutosHoje),
                style: ElevatedButton.styleFrom(
                  backgroundColor: corBoss,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _atacando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '⚔️  ATACAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '-$danoPotencial de dano hoje',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    '✅ Você já atacou hoje!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Volte amanhã para atacar novamente',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // PLACAR DE DANO DOS MEMBROS
          if (danoPorMembro.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DANO CAUSADO PELA PARTY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<QuerySnapshot>(
              future: _db
                  .collection('usuarios')
                  .where(
                    FieldPath.documentId,
                    whereIn: danoPorMembro.keys.toList(),
                  )
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                var membrosSnap = snap.data!.docs;
                membrosSnap.sort((a, b) {
                  int danoA = danoPorMembro[a.id] ?? 0;
                  int danoB = danoPorMembro[b.id] ?? 0;
                  return danoB.compareTo(danoA);
                });
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: membrosSnap.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, i) {
                      var membro =
                          membrosSnap[i].data() as Map<String, dynamic>;
                      int dano = danoPorMembro[membrosSnap[i].id] ?? 0;
                      return ListTile(
                        leading: Text(
                          i == 0 ? '🗡️' : '⚔️',
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(
                          membro['nome'] ?? 'Usuário',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          '$dano dmg',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: corBoss,
                            fontSize: 15,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executarAtaque(String groupId, int minutosHoje) async {
    setState(() => _atacando = true);

    final resultado = await _bossService.atacarBoss(
      grupoId: groupId,
      minutosHoje: minutosHoje,
    );

    if (!mounted) return;
    setState(() => _atacando = false);

    if (resultado['sucesso'] == true) {
      HapticFeedback.heavyImpact();
      try {
        await _audioPlayer.play(AssetSource('sounds/Loja.mp3'));
      } catch (_) {}

      if (resultado['derrotou'] == true) {
        // Boss derrotado!
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF111111),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💥', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                const Text(
                  'BOSS DERROTADO!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D9E75),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Todos os membros da party receberam as recompensas!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ÉPICO! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚔️ Você causou ${resultado['dano']} de dano! HP restante: ${resultado['hp_atual']}',
            ),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } else if (resultado['motivo'] == 'ja_atacou') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você já atacou hoje. Volte amanhã!')),
      );
    }
  }

  Widget _chipInfo(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
