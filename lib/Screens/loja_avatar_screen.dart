import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart'; // IMPORT DO ÁUDIO

class LojaScreen extends StatefulWidget {
  const LojaScreen({super.key});

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer(); // TOCA-DISCOS DA LOJA

  final List<Map<String, dynamic>> itensLoja = [
    {'id': 'nenhum', 'nome': 'Limpo', 'preco': 0, 'icone': '❌'},
    {'id': 'chapeu', 'nome': 'Boné Azul', 'preco': 50, 'icone': '🧢'},
    {'id': 'oculos', 'nome': 'Óculos Cool', 'preco': 150, 'icone': '🕶️'},
    {'id': 'coroa', 'nome': 'Coroa Real', 'preco': 1000, 'icone': '👑'},
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _processarCompraOuEquipar(
    String itemId,
    int preco,
    List<dynamic> inventario,
    int moedasAtuais,
    String equipado,
  ) async {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    DocumentReference userRef = _db.collection('usuarios').doc(uid);

    if (inventario.contains(itemId)) {
      await userRef.update({'acessorio_atual': itemId});
    } else {
      if (moedasAtuais >= preco) {
        inventario.add(itemId);
        await userRef.update({
          'moedas': moedasAtuais - preco,
          'inventario': inventario,
          'acessorio_atual': itemId,
        });

        // TOCA O SOM DE COMPRA 💰
        await _audioPlayer.play(AssetSource('sounds/Loja.mp3'));

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item comprado e equipado!')),
          );
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Moedas insuficientes! 💸'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Loja do Mascote'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var user = snapshot.data!.data() as Map<String, dynamic>;
          int moedas = user['moedas'] ?? 0;
          List<dynamic> meuInventario = user['inventario'] ?? ['nenhum'];
          String equipado = user['acessorio_atual'] ?? 'nenhum';

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFE1F5EE),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Suas Moedas: ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.monetization_on, color: Colors.orange),
                    Text(
                      ' $moedas',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: itensLoja.length,
                  itemBuilder: (context, index) {
                    var item = itensLoja[index];
                    bool jaTenho = meuInventario.contains(item['id']);
                    bool estaEquipado = equipado == item['id'];

                    return Card(
                      elevation: estaEquipado ? 8 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: estaEquipado
                              ? const Color(0xFF1D9E75)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['icone'],
                            style: const TextStyle(fontSize: 50),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['nome'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            jaTenho ? 'Adquirido' : '${item['preco']} moedas',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: estaEquipado
                                ? null
                                : () => _processarCompraOuEquipar(
                                    item['id'],
                                    item['preco'],
                                    meuInventario,
                                    moedas,
                                    equipado,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: estaEquipado
                                  ? Colors.grey
                                  : const Color(0xFF1D9E75),
                            ),
                            child: Text(
                              estaEquipado
                                  ? 'Equipado'
                                  : (jaTenho ? 'Equipar' : 'Comprar'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
