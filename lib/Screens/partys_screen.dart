import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/grupo_service.dart';
import 'grupo_detalhes_screen.dart'; // Importado para funcionar o clique do ranking

class PartysScreen extends StatefulWidget {
  const PartysScreen({super.key});

  @override
  State<PartysScreen> createState() => _PartysScreenState();
}

class _PartysScreenState extends State<PartysScreen> {
  final GrupoService _grupoService = GrupoService();
  final TextEditingController _controllerNome = TextEditingController();
  final TextEditingController _controllerCodigo = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Partys (Grupos)'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // FRONT-END: Card superior com botões de ação (Criar e Entrar)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _mostrarDialogCriar(context),
                    child: const Text('Criar Grupo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _mostrarDialogEntrar(context),
                    child: const Text('Entrar com Código'),
                  ),
                ),
              ],
            ),
          ),

          // BACK-END: StreamBuilder que escuta os grupos do usuário em tempo real
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _grupoService.listarMeusGrupos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Você não está em nenhum grupo ainda.'),
                  );
                }

                final grupos = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: grupos.length,
                  itemBuilder: (context, index) {
                    // Captura os dados do documento do grupo
                    var grupoDoc = grupos[index];
                    var grupo = grupoDoc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Text(
                          '🛡️',
                          style: TextStyle(fontSize: 24),
                        ),
                        title: Text(grupo['nome'] ?? 'Sem nome'),
                        subtitle: Text('Código de Convite: ${grupo['codigo']}'),
                        trailing: Text(
                          '${grupo['membros']?.length ?? 1} membros',
                        ),
                        // CONECTADO: Abre a tela do ranking ao clicar no grupo
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GrupoDetalhesScreen(grupoData: grupo),
                            ),
                          );
                        },
                      ),
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

  //  Caixa de texto que aparece para digitar o nome do grupo novo
  void _mostrarDialogCriar(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criar Nova Party'),
        content: TextField(
          controller: _controllerNome,
          decoration: const InputDecoration(hintText: "Nome do grupo"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (_controllerNome.text.isNotEmpty) {
                await _grupoService.criarGrupo(_controllerNome.text);
                _controllerNome.clear();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  //  Caixa de texto que aparece para digitar o código de um grupo
  void _mostrarDialogEntrar(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em uma Party'),
        content: TextField(
          controller: _controllerCodigo,
          decoration: const InputDecoration(hintText: "Código de 6 dígitos"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (_controllerCodigo.text.isNotEmpty) {
                bool entrou = await _grupoService.entrarNoGrupo(
                  _controllerCodigo.text,
                );
                _controllerCodigo.clear();
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!entrou) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Código inválido ou grupo não encontrado.',
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}
