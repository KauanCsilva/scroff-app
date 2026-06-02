import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class LojaScreen extends StatefulWidget {
  const LojaScreen({super.key});

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // CATÁLOGO COMPLETO DA LOJA (Separado por categorias)
  final List<Map<String, dynamic>> itensLoja = [
    // --- ÍCONES (tipo: icone) ---
    {
      'id': 'padrao',
      'tipo': 'icone',
      'nome': 'Básico',
      'preco': 0,
      'lvl': 1,
      'icone': Icons.person,
    },
    {
      'id': 'foguete',
      'tipo': 'icone',
      'nome': 'Foguete',
      'preco': 100,
      'lvl': 3,
      'icone': Icons.rocket_launch,
    },
    {
      'id': 'cerebro',
      'tipo': 'icone',
      'nome': 'Gênio',
      'preco': 400,
      'lvl': 8,
      'icone': Icons.psychology,
    },
    {
      'id': 'ninja',
      'tipo': 'icone',
      'nome': 'Ninja',
      'preco': 800,
      'lvl': 15,
      'icone': Icons.sports_martial_arts,
    },
    {
      'id': 'coroa',
      'tipo': 'icone',
      'nome': 'Realeza',
      'preco': 2000,
      'lvl': 25,
      'icone': Icons.workspace_premium,
    },

    // --- POWER-UPS (tipo: consumivel) ---
    {
      'id': 'cafe',
      'tipo': 'consumivel',
      'nome': 'Café Expresso',
      'desc': 'Dobra XP no próximo foco',
      'preco': 150,
      'lvl': 1,
      'icone': Icons.local_cafe,
    },
    {
      'id': 'escudo',
      'tipo': 'consumivel',
      'nome': 'Escudo de Foco',
      'desc': 'Salva sua ofensiva se falhar',
      'preco': 300,
      'lvl': 2,
      'icone': Icons.security,
    },
    {
      'id': 'ticket',
      'tipo': 'consumivel',
      'nome': 'Ticket VIP',
      'desc': 'Aposta tripla nas Partys',
      'preco': 500,
      'lvl': 5,
      'icone': Icons.local_activity,
    },

    // --- TÍTULOS (tipo: titulo) ---
    {
      'id': 't_iniciante',
      'tipo': 'titulo',
      'nome': 'O Iniciante',
      'preco': 0,
      'lvl': 1,
      'icone': Icons.badge,
    },
    {
      'id': 't_zen',
      'tipo': 'titulo',
      'nome': 'Mestre Zen',
      'preco': 500,
      'lvl': 5,
      'icone': Icons.self_improvement,
    },
    {
      'id': 't_intocavel',
      'tipo': 'titulo',
      'nome': 'O Intocável',
      'preco': 2500,
      'lvl': 15,
      'icone': Icons.shield,
    },
    {
      'id': 't_maquina',
      'tipo': 'titulo',
      'nome': 'Máquina',
      'preco': 5000,
      'lvl': 30,
      'icone': Icons.precision_manufacturing,
    },

    // --- TEMAS (tipo: tema) ---
    {
      'id': 'tema_light',
      'tipo': 'tema',
      'nome': 'Claro (Padrão)',
      'preco': 0,
      'lvl': 1,
      'icone': Icons.light_mode,
    },
    {
      'id': 'tema_papel',
      'tipo': 'tema',
      'nome': 'Papel Antigo',
      'preco': 1000,
      'lvl': 5,
      'icone': Icons.menu_book,
    },
    {
      'id': 'tema_hacker',
      'tipo': 'tema',
      'nome': 'Terminal',
      'preco': 1500,
      'lvl': 10,
      'icone': Icons.terminal,
    },
    {
      'id': 'tema_dark',
      'tipo': 'tema',
      'nome': 'Crepúsculo',
      'preco': 2000,
      'lvl': 15,
      'icone': Icons.dark_mode,
    },
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _processarCompra(
    Map<String, dynamic> item,
    int moedasAtuais,
    Map<String, dynamic> userData,
  ) async {
    String uid = _auth.currentUser!.uid;
    String id = item['id'];
    String tipo = item['tipo'];
    int preco = item['preco'];

    // PREPARA OS DADOS DO FIREBASE
    List invIcones = userData['inventario'] ?? ['padrao'];
    List invTitulos = userData['inventario_titulos'] ?? ['t_iniciante'];
    List invTemas = userData['inventario_temas'] ?? ['tema_light'];
    Map consumiveis = userData['consumiveis'] ?? {};

    // VERIFICA SE JÁ TEM O ITEM (Para itens permanentes)
    bool jaTem = false;
    if (tipo == 'icone') jaTem = invIcones.contains(id);
    if (tipo == 'titulo') jaTem = invTitulos.contains(id);
    if (tipo == 'tema') jaTem = invTemas.contains(id);

    Map<String, dynamic> updates = {};

    if (jaTem && tipo != 'consumivel') {
      // APENAS EQUIPAR
      if (tipo == 'icone') updates['acessorio_atual'] = id;
      if (tipo == 'titulo') updates['titulo_atual'] = id;
      if (tipo == 'tema') updates['tema_atual'] = id;

      await _db.collection('usuarios').doc(uid).update(updates);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['nome']} equipado!'),
            backgroundColor: const Color(0xFF1D9E75),
          ),
        );
      return;
    }

    // TENTAR COMPRAR
    if (moedasAtuais >= preco) {
      updates['moedas'] = moedasAtuais - preco;

      if (tipo == 'icone') {
        invIcones.add(id);
        updates['inventario'] = invIcones;
        updates['acessorio_atual'] = id;
      } else if (tipo == 'titulo') {
        invTitulos.add(id);
        updates['inventario_titulos'] = invTitulos;
        updates['titulo_atual'] = id;
      } else if (tipo == 'tema') {
        invTemas.add(id);
        updates['inventario_temas'] = invTemas;
        updates['tema_atual'] = id;
      } else if (tipo == 'consumivel') {
        int qtdAtual = consumiveis[id] ?? 0;
        consumiveis[id] = qtdAtual + 1;
        updates['consumiveis'] = consumiveis;
      }

      await _db.collection('usuarios').doc(uid).update(updates);
      await _audioPlayer.play(AssetSource('sounds/compra.mp3'));

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compra realizada com sucesso!'),
            backgroundColor: const Color(0xFF1D9E75),
          ),
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

  // WIDGET PARA MONTAR CADA ABA DA LOJA
  Widget _construirAba(String tipoFiltro, Map<String, dynamic> userData) {
    int moedas = userData['moedas'] ?? 0;
    int nivel = userData['nivel'] ?? 1;

    List invIcones = userData['inventario'] ?? ['padrao'];
    List invTitulos = userData['inventario_titulos'] ?? ['t_iniciante'];
    List invTemas = userData['inventario_temas'] ?? ['tema_light'];
    Map consumiveis = userData['consumiveis'] ?? {};

    String equipadoIcone = userData['acessorio_atual'] ?? 'padrao';
    String equipadoTitulo = userData['titulo_atual'] ?? 't_iniciante';
    String equipadoTema = userData['tema_atual'] ?? 'tema_light';

    var itensFiltrados = itensLoja
        .where((item) => item['tipo'] == tipoFiltro)
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itensFiltrados.length,
      itemBuilder: (context, index) {
        var item = itensFiltrados[index];
        bool bloqueado = nivel < item['lvl'];

        bool jaTem = false;
        bool isEquipado = false;
        int quantidade = 0;

        if (tipoFiltro == 'icone') {
          jaTem = invIcones.contains(item['id']);
          isEquipado = equipadoIcone == item['id'];
        }
        if (tipoFiltro == 'titulo') {
          jaTem = invTitulos.contains(item['id']);
          isEquipado = equipadoTitulo == item['id'];
        }
        if (tipoFiltro == 'tema') {
          jaTem = invTemas.contains(item['id']);
          isEquipado = equipadoTema == item['id'];
        }
        if (tipoFiltro == 'consumivel') {
          quantidade = consumiveis[item['id']] ?? 0;
        }

        return Opacity(
          opacity: bloqueado ? 0.6 : 1.0,
          child: Card(
            elevation: isEquipado ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isEquipado ? const Color(0xFF1D9E75) : Colors.grey[200]!,
                width: isEquipado ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    bloqueado ? Icons.lock : item['icone'],
                    size: 36,
                    color: bloqueado ? Colors.grey : Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['nome'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  if (tipoFiltro == 'consumivel')
                    Text(
                      item['desc'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),

                  const Spacer(),
                  Text(
                    bloqueado
                        ? 'Requer Lvl ${item['lvl']}'
                        : (tipoFiltro == 'consumivel'
                              ? 'Tem: $quantidade'
                              : (jaTem
                                    ? 'Desbloqueado'
                                    : '${item['preco']} 🪙')),
                    style: TextStyle(
                      fontSize: 12,
                      color: bloqueado ? Colors.red : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: bloqueado
                          ? null
                          : () => _processarCompra(item, moedas, userData),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEquipado
                            ? Colors.grey[200]
                            : (jaTem && tipoFiltro != 'consumivel'
                                  ? Colors.black87
                                  : const Color(0xFF1D9E75)),
                        foregroundColor: isEquipado
                            ? Colors.grey
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isEquipado
                            ? 'Em Uso'
                            : (jaTem && tipoFiltro != 'consumivel'
                                  ? 'Usar'
                                  : 'Comprar'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser!.uid;

    return DefaultTabController(
      length: 4, // 4 Abas agora!
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Loja de Prestígio',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF1D9E75),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1D9E75),
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Ícones'),
              Tab(icon: Icon(Icons.bolt), text: 'Power-Ups'),
              Tab(icon: Icon(Icons.workspace_premium), text: 'Títulos'),
              Tab(icon: Icon(Icons.palette), text: 'Temas'),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('usuarios').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
              );
            var userData = snapshot.data!.data() as Map<String, dynamic>;
            int moedas = userData['moedas'] ?? 0;

            return Column(
              children: [
                // SALDO FIXO NO TOPO
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Saldo: ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$moedas',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange,
                        ),
                      ),
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                // AS ABAS
                Expanded(
                  child: TabBarView(
                    children: [
                      _construirAba('icone', userData),
                      _construirAba('consumivel', userData),
                      _construirAba('titulo', userData),
                      _construirAba('tema', userData),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
