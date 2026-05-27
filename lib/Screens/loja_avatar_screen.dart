import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/desafio_service.dart';
import '../services/loja_service.dart';

class LojaAvatarScreen extends StatefulWidget {
  const LojaAvatarScreen({super.key});

  @override
  State<LojaAvatarScreen> createState() => _LojaAvatarScreenState();
}

class _LojaAvatarScreenState extends State<LojaAvatarScreen> {
  final DesafioService _desafioService = DesafioService();
  final LojaService _lojaService = LojaService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja & Customização'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _desafioService.dadosUsuario(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text('Erro ao carregar perfil.'));

          var user = snapshot.data!.data() as Map<String, dynamic>;
          int moedas = user['moedas'] ?? 0;
          String avatarAtual = user['avatar_atual'] ?? '👤';
          List<dynamic> comprados = user['avatars_comprados'] ?? [];
          List<dynamic> medalhas = user['badges'] ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Painel Superior de Saldo
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            avatarAtual.length > 3 ? '🎭' : avatarAtual,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const Text(
                            'Avatar Equipado',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(
                        '🪙 $moedas Moedas',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '🛒 COMPRAR AVATARS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                // Grid de Vitrine de Itens da Loja
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _lojaService.vitrineAvatars.length,
                  itemBuilder: (context, index) {
                    var item = _lojaService.vitrineAvatars[index];
                    String id = item['id'];
                    String nome = item['nome'];
                    int preco = item['preco'];

                    bool jaPossui = comprados.contains(id);
                    bool estaEquipado = avatarAtual == id;

                    return Card(
                      color: estaEquipado
                          ? const Color(0xFFE1F5EE)
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (estaEquipado)
                              const Text(
                                'Equipado',
                                style: TextStyle(
                                  color: Color(0xFF1D9E75),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (jaPossui)
                              TextButton(
                                onPressed: () => _lojaService.equiparAvatar(id),
                                child: const Text('Equipar'),
                              )
                            else
                              ElevatedButton(
                                onPressed: moedas >= preco
                                    ? () =>
                                          _lojaService.comprarAvatar(id, preco)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                ),
                                child: Text('🪙 $preco'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '🏅 MINHAS CONQUISTAS (BADGES)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                // Lista de Medalhas Conquistadas
                medalhas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Nenhuma medalha desbloqueada ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: medalhas.length,
                        itemBuilder: (context, idx) {
                          return ListTile(
                            leading: const Icon(
                              Icons.verified,
                              color: Colors.purple,
                            ),
                            title: Text(
                              'Medalha: ${medalhas[idx].toString().replaceAll('badge_', '').toUpperCase()}',
                            ),
                            subtitle: const Text(
                              'Desbloqueado por mérito de foco.',
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
