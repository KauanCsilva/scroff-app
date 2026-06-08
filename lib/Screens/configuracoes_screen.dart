import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/usage_service.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _buscaController = TextEditingController();

  List<dynamic> _whitelistAtuais = [];
  Set<String> _packageNamesInstalados = {};
  bool _carregando = true;

  // =====================================================
  // LISTA CURADA DE APPS PRODUTIVOS (por categoria)
  // package name = ID real do Android para comparar com UsageStats
  // =====================================================
  static const List<Map<String, dynamic>> _appsCurados = [
    // TRABALHO
    {
      'categoria': 'Trabalho',
      'apps': [
        {'id': 'com.google.android.gm', 'nome': 'Gmail', 'icone': '📧'},
        {
          'id': 'com.microsoft.office.outlook',
          'nome': 'Outlook',
          'icone': '📨',
        },
        {'id': 'com.Slack', 'nome': 'Slack', 'icone': '💬'},
        {'id': 'com.microsoft.teams', 'nome': 'Microsoft Teams', 'icone': '🤝'},
        {'id': 'us.zoom.videomeetings', 'nome': 'Zoom', 'icone': '📹'},
        {
          'id': 'com.google.android.apps.meetings',
          'nome': 'Google Meet',
          'icone': '🎥',
        },
        {'id': 'com.linkedin.android', 'nome': 'LinkedIn', 'icone': '💼'},
        {'id': 'com.microsoft.office.word', 'nome': 'Word', 'icone': '📝'},
        {'id': 'com.microsoft.office.excel', 'nome': 'Excel', 'icone': '📊'},
        {
          'id': 'com.microsoft.office.powerpoint',
          'nome': 'PowerPoint',
          'icone': '📑',
        },
        {
          'id': 'com.google.android.apps.docs',
          'nome': 'Google Docs',
          'icone': '📄',
        },
        {
          'id': 'com.google.android.apps.sheets',
          'nome': 'Google Sheets',
          'icone': '🗂️',
        },
        {'id': 'com.notion.id', 'nome': 'Notion', 'icone': '🗒️'},
        {'id': 'com.todoist.android.Todoist', 'nome': 'Todoist', 'icone': '✅'},
        {'id': 'com.trello', 'nome': 'Trello', 'icone': '📋'},
        {'id': 'com.github.android', 'nome': 'GitHub', 'icone': '🐙'},
      ],
    },
    // ESTUDO
    {
      'categoria': 'Estudo',
      'apps': [
        {'id': 'com.duolingo', 'nome': 'Duolingo', 'icone': '🦉'},
        {'id': 'com.brainscape.android', 'nome': 'Anki', 'icone': '🧠'},
        {'id': 'com.ankidroid.anki', 'nome': 'AnkiDroid', 'icone': '🃏'},
        {
          'id': 'org.khanacademy.android',
          'nome': 'Khan Academy',
          'icone': '🎓',
        },
        {'id': 'com.coursera.android', 'nome': 'Coursera', 'icone': '📚'},
        {'id': 'com.udemy.android', 'nome': 'Udemy', 'icone': '🖥️'},
        {
          'id': 'com.google.android.apps.classroom',
          'nome': 'Google Classroom',
          'icone': '🏫',
        },
        {
          'id': 'com.wolfram.android.alpha',
          'nome': 'Wolfram Alpha',
          'icone': '🔢',
        },
        {
          'id': 'com.microsoft.teams.education',
          'nome': 'Teams Educação',
          'icone': '🏫',
        },
      ],
    },
    // LEITURA
    {
      'categoria': 'Leitura',
      'apps': [
        {'id': 'com.amazon.kindle', 'nome': 'Kindle', 'icone': '📖'},
        {
          'id': 'com.google.android.apps.books',
          'nome': 'Google Play Livros',
          'icone': '📗',
        },
        {'id': 'com.scribd.app.reader0', 'nome': 'Scribd', 'icone': '📜'},
        {'id': 'com.apple.ibooks', 'nome': 'Apple Books', 'icone': '📘'},
        {'id': 'com.nytimes.android', 'nome': 'NY Times', 'icone': '🗞️'},
        {'id': 'flipboard.app', 'nome': 'Flipboard', 'icone': '📰'},
        {'id': 'com.medium.reader', 'nome': 'Medium', 'icone': '✍️'},
        {'id': 'com.getpocket.android', 'nome': 'Pocket', 'icone': '🔖'},
      ],
    },
    // SAÚDE & FOCO
    {
      'categoria': 'Saúde & Foco',
      'apps': [
        {'id': 'com.headspace.android', 'nome': 'Headspace', 'icone': '🧘'},
        {'id': 'com.calm.android', 'nome': 'Calm', 'icone': '🌊'},
        {'id': 'com.noisli', 'nome': 'Noisli', 'icone': '🎵'},
        {
          'id': 'com.google.android.apps.fitness',
          'nome': 'Google Fit',
          'icone': '🏃',
        },
        {
          'id': 'com.samsung.android.shealth',
          'nome': 'Samsung Health',
          'icone': '❤️',
        },
        {'id': 'com.strava', 'nome': 'Strava', 'icone': '🚴'},
        {'id': 'com.nike.plusgps', 'nome': 'Nike Run Club', 'icone': '👟'},
        {
          'id': 'com.myfitnesspal.android',
          'nome': 'MyFitnessPal',
          'icone': '🥗',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarInstalados();
    _buscaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      var doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (doc.exists) {
        setState(() {
          _nomeController.text = doc.data()?['nome'] ?? '';
          _whitelistAtuais = List<dynamic>.from(doc.data()?['whitelist'] ?? []);
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarConfiguracoes() async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'nome': _nomeController.text.trim(),
        'whitelist': _whitelistAtuais,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _toggleApp(String packageName, bool isChecked) {
    setState(() {
      if (isChecked) {
        if (!_whitelistAtuais.contains(packageName)) {
          _whitelistAtuais.add(packageName);
        }
      } else {
        _whitelistAtuais.remove(packageName);
      }
    });
  }

  // Abre dialog para o usuário sugerir um app à equipe
  void _mostrarDialogSugestao() {
    final TextEditingController sugestaoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sugerir App 💡'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qual app produtivo você quer ver na lista? A equipe vai avaliar e adicionar se fizer sentido.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sugestaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do app',
                hintText: 'Ex: Obsidian, Linear, Figma...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
            ),
            onPressed: () async {
              if (sugestaoCtrl.text.trim().isEmpty) return;

              String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              await FirebaseFirestore.instance
                  .collection('sugestoes_apps')
                  .add({
                    'app': sugestaoCtrl.text.trim(),
                    'usuario_id': uid,
                    'enviado_em': FieldValue.serverTimestamp(),
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sugestão enviada! Obrigado 🙌'),
                    backgroundColor: Color(0xFF246815),
                  ),
                );
              }
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarInstalados() async {
    final apps = await UsageService.getAppsInstalados();
    if (mounted) {
      setState(() {
        _packageNamesInstalados = apps.map((a) => a['id'] as String).toSet();
      });
    }
  }

  // Filtra: só apps da lista curada que estão instalados E batem com a busca
  List<Map<String, dynamic>> _categoriasFiltradas() {
    final termo = _buscaController.text.toLowerCase();

    return _appsCurados
        .map((cat) {
          final appsFiltrados = (cat['apps'] as List).where((a) {
            final instalado =
                _packageNamesInstalados.isEmpty ||
                _packageNamesInstalados.contains(a['id']);
            final bateBusca =
                termo.isEmpty ||
                (a['nome'] as String).toLowerCase().contains(termo);
            return instalado && bateBusca;
          }).toList();
          if (appsFiltrados.isEmpty) return null;
          return {'categoria': cat['categoria'], 'apps': appsFiltrados};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categorias = _categoriasFiltradas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: const Color(0xFF246815),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SEÇÃO: PERFIL
                  const Text(
                    'Editar Perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Seu Nickname',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // SEÇÃO: MODO TRABALHO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Modo Trabalho',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_whitelistAtuais.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE1F5EE),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${_whitelistAtuais.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF246815),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // BOTÃO SUGERIR APP
                      TextButton.icon(
                        onPressed: _mostrarDialogSugestao,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Color(0xFF246815),
                        ),
                        label: const Text(
                          'Sugerir app',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF246815),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Apps selecionados não contam no seu ranking.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // CAMPO DE BUSCA
                  TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar na lista...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscaController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscaController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // LISTA POR CATEGORIA
                  if (_packageNamesInstalados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF246815)),
                            SizedBox(height: 12),
                            Text(
                              'Verificando apps instalados...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (categorias.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              'Nenhum app da lista está instalado.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Seu app produtivo não está aqui?',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _mostrarDialogSugestao,
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                color: Color(0xFF246815),
                              ),
                              label: const Text(
                                'Sugerir para a equipe',
                                style: TextStyle(color: Color(0xFF246815)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...categorias.map((cat) {
                      final apps = cat['apps'] as List<Map<String, dynamic>>;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              cat['categoria'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: apps.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade100,
                              ),
                              itemBuilder: (context, index) {
                                final app = apps[index];
                                final ativo = _whitelistAtuais.contains(
                                  app['id'],
                                );
                                return SwitchListTile(
                                  title: Text(
                                    '${app['icone']}  ${app['nome']}',
                                    style: TextStyle(
                                      fontWeight: ativo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                  value: ativo,
                                  activeColor: const Color(0xFF246815),
                                  onChanged: (val) =>
                                      _toggleApp(app['id'], val),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),

                  // RODAPÉ COM LINK PARA SUGESTÃO
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _mostrarDialogSugestao,
                      icon: const Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      label: const Text(
                        'Não encontrou seu app? Sugira para a equipe',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // BOTÃO FIXO NO FUNDO
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvarConfiguracoes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF246815),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Salvar Alterações',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
