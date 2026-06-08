import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                    backgroundColor: const Color(0xFF246815),
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
                  style: TextStyle(color: Color(0xFF246815)),
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
        backgroundColor: const Color(0xFF246815),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogNovoCombinado,
        backgroundColor: const Color(0xFF246815),
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
                                  ? const Color(0xFF246815)
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
                                        ? const Color(0xFF246815)
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
                                  backgroundColor: const Color(0xFF246815),
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
        ],
      ),
    );
  }
}
