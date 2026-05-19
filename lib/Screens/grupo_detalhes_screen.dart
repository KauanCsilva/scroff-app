import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/grupo_service.dart';

class GrupoDetalhesScreen extends StatelessWidget {
  final Map<String, dynamic> grupoData;

  // Recebe os dados do grupo que foi clicado (incluindo a lista de membros)
  const GrupoDetalhesScreen({super.key, required this.grupoData});

  @override
  Widget build(BuildContext context) {
    final GrupoService grupoService = GrupoService();
    final List<dynamic> membros = grupoData['membros'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(grupoData['nome'] ?? 'Detalhes do Grupo'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Informações do Grupo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Código de convite: ${grupoData['codigo']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          const Text(
            '🏆 RANKING DA PARTY 🏆',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // BACK-END: StreamBuilder que monta o ranking puxando os dados da coleção 'usuarios'
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: grupoService.buscarRankingDoGrupo(membros),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhum dado de membro encontrado.'),
                  );
                }

                final rankingDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: rankingDocs.length,
                  itemBuilder: (context, index) {
                    var usuario =
                        rankingDocs[index].data() as Map<String, dynamic>;

                    // LÓGICA DOS NOMES: Se houver o campo 'nome' salvo no cadastro ele usa,
                    // se não, ele exibe o e-mail (para não ficar o ID feio).
                    String identificador =
                        usuario['nome'] ??
                        usuario['email'] ??
                        'Usuário Anônimo';
                    int minutos = usuario['minutos_hoje'] ?? 0;

                    // Posição no ranking (1º, 2º, 3º...)
                    int posicao = index + 1;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: posicao == 1
                            ? Colors.amber
                            : Colors.grey,
                        child: Text(
                          '$posicaoº',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        identificador,
                      ), // O NOME OU E-MAIL APARECE AQUI!
                      trailing: Text(
                        '$minutos min',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
}
