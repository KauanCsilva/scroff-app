import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'grupo_detalhes_screen.dart';
import 'configuracoes_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class PartysScreen extends StatefulWidget {
  const PartysScreen({super.key});

  @override
  State<PartysScreen> createState() => _PartysScreenState();
}

class _PartysScreenState extends State<PartysScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _criarGrupo() {
    TextEditingController nomeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criar nova Party'),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(
            hintText: 'Nome do Grupo (ex: Galera da Facul)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF246815),
            ),
            onPressed: () async {
              if (nomeCtrl.text.isEmpty) {
                return;
              }
              String uid = _auth.currentUser!.uid;
              String codigo = (Random().nextInt(900000) + 100000).toString();

              await _db.collection('grupos').add({
                'nome': nomeCtrl.text,
                'codigo': codigo,
                'criador_id': uid,
                'membros': [uid],
                'criado_em': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _entrarGrupo() {
    TextEditingController codigoCtrl = TextEditingController();
    final AudioPlayer audioPlayerLocal = AudioPlayer();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar numa Party'),
        content: TextField(
          controller: codigoCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Código de 6 dígitos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF246815),
            ),
            onPressed: () async {
              if (codigoCtrl.text.isEmpty) return;
              String uid = _auth.currentUser!.uid;

              var query = await _db
                  .collection('grupos')
                  .where('codigo', isEqualTo: codigoCtrl.text)
                  .get();

              if (query.docs.isNotEmpty) {
                var docGrupo = query.docs.first;
                List<dynamic> membros = docGrupo['membros'] ?? [];

                if (!membros.contains(uid)) {
                  membros.add(uid);
                  await docGrupo.reference.update({'membros': membros});

                  await audioPlayerLocal.play(
                    AssetSource('sounds/User Party.mp3'),
                  );
                }
                if (mounted) Navigator.pop(context);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Grupo não encontrado!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Entrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Parties',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF246815) ,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracoesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('grupos')
            .where('membros', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF246815)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Você não está em nenhuma Party.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar ou Entrar em Grupo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF246815),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.group_add),
                              title: const Text('Criar Nova Party'),
                              onTap: () {
                                Navigator.pop(context);
                                _criarGrupo();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.login),
                              title: const Text('Entrar com Código'),
                              onTap: () {
                                Navigator.pop(context);
                                _entrarGrupo();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var document = snapshot.data!.docs[index];
              var grupoData = document.data() as Map<String, dynamic>;
              grupoData['id'] = document.id;

              List<dynamic> membros = grupoData['membros'] ?? [];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey[200]!,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GrupoDetalhesScreen(grupoData: grupoData),
                      ),
                    );
                  },
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE1F5EE),
                    child: Icon(Icons.group, color: Color(0xFF246815), size: 20),
                  ),
                  title: Text(
                    grupoData['nome'] ?? 'Grupo Sem Nome',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${membros.length} membros • Código: ${grupoData['codigo']}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Criar Nova Party'),
                  onTap: () {
                    Navigator.pop(context);
                    _criarGrupo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Entrar com Código'),
                  onTap: () {
                    Navigator.pop(context);
                    _entrarGrupo();
                  },
                ),
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFF246815),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}