import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/loja_service.dart';

class LojaScreen extends StatefulWidget {
  const LojaScreen({super.key});

  @override
  State<LojaScreen> createState() => _LojaScreenState();
}

class _LojaScreenState extends State<LojaScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // MOTOR DE COMPRA DINÂMICO (Avatares, Títulos e Power-Ups)
  Future<void> _processarCompra(
      ItemLoja item,
      int moedasAtuais,
      Map<String, dynamic> userData,
      ) async {
    String uid = _auth.currentUser!.uid;
    Map<String, dynamic> updates = {};

    // =========================================================
    // ROTA A: LÓGICA PARA ITENS CONSUMÍVEIS (Pode comprar vários)
    // =========================================================
    if (item.tipo == 'consumivel') {
      if (moedasAtuais >= item.preco) {
        Map<String, dynamic> consumiveis = Map<String, dynamic>.from(userData['consumiveis'] ?? {});

        // Adiciona 1 à quantidade atual (ou define como 1 se não tinha nenhum)
        consumiveis[item.id] = (consumiveis[item.id] ?? 0) + 1;

        updates['moedas'] = moedasAtuais - item.preco;
        updates['consumiveis'] = consumiveis;

        await _db.collection('usuarios').doc(uid).update(updates);
        await _audioPlayer.play(AssetSource('sounds/Loja.mp3'));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+1 ${item.nome} adquirido!'),
              backgroundColor: const Color(0xFF1D9E75),
            ),
          );
        }
      } else {
        if (mounted) _mostrarErroSaldo();
      }
      return; // Encerra a função aqui para consumíveis
    }

    // =========================================================
    // ROTA B: LÓGICA PARA AVATARES E TÍTULOS (Compra única)
    // =========================================================
    String campoInventario = item.tipo == 'titulo' ? 'inventario_titulos' : 'inventario';
    String campoAtual = item.tipo == 'titulo' ? 'titulo_atual' : 'acessorio_atual';
    List fallbackInventario = item.tipo == 'titulo' ? ['t_iniciante'] : ['avatar_basicof', 'avatar_basicom'];

    List invUsuario = List.from(userData[campoInventario] ?? fallbackInventario);
    bool jaTem = invUsuario.contains(item.id) || item.preco == 0;

    if (jaTem) {
      // EQUIPAR ITEM QUE JÁ POSSUI
      await _db.collection('usuarios').doc(uid).update({campoAtual: item.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.nome} equipado com sucesso!'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } else {
      // COMPRAR NOVO ITEM PERMANENTE
      if (moedasAtuais >= item.preco) {
        updates['moedas'] = moedasAtuais - item.preco;
        invUsuario.add(item.id);
        updates[campoInventario] = invUsuario;
        updates[campoAtual] = item.id;

        await _db.collection('usuarios').doc(uid).update(updates);
        await _audioPlayer.play(AssetSource('sounds/Loja.mp3'));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.nome} desbloqueado!'),
              backgroundColor: const Color(0xFF1D9E75),
            ),
          );
        }
      } else {
        if (mounted) _mostrarErroSaldo();
      }
    }
  }

  void _mostrarErroSaldo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moedas insuficientes!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // GERADOR DE GRADES (Adapta-se ao tipo de aba lida)
  Widget _construirGradeDeItens(String tipoDaAba, Map<String, dynamic> userData) {
    int moedas = userData['moedas'] ?? 0;
    int nivelAtual = userData['nivel'] ?? 1;

    // Leituras Dinâmicas
    String campoInventario = tipoDaAba == 'titulo' ? 'inventario_titulos' : 'inventario';
    String campoAtual = tipoDaAba == 'titulo' ? 'titulo_atual' : 'acessorio_atual';

    List invUsuario = userData[campoInventario] ?? [];
    String itemEquipado = userData[campoAtual] ?? '';
    Map<String, dynamic> consumiveis = userData['consumiveis'] ?? {};

    List<ItemLoja> itens = LojaService.getItensPorTipo(tipoDaAba);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70, // Espaço extra para mostrar o estoque dos power-ups
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itens.length,
      itemBuilder: (context, index) {
        var item = itens[index];

        bool ehConsumivel = item.tipo == 'consumivel';
        bool bloqueado = nivelAtual < item.lvl;

        // Consumíveis nunca ficam no status "equipado" ou "já tem"
        bool isEquipado = !ehConsumivel && itemEquipado == item.id;
        bool jaTem = !ehConsumivel && (invUsuario.contains(item.id) || item.preco == 0);

        int estoqueAtual = ehConsumivel ? (consumiveis[item.id] ?? 0) : 0;

        Color corFundoBotao;
        String textoBotao;
        Color corTextoBotao = Colors.black;

        if (isEquipado) {
          corFundoBotao = const Color(0xFF96D268);
          textoBotao = 'Equipado';
        } else if (bloqueado) {
          corFundoBotao = const Color(0xFFFF8C00);
          textoBotao = 'Nivel ${item.lvl}';
        } else if (jaTem) {
          corFundoBotao = Colors.grey[300]!;
          textoBotao = 'Equipar';
        } else {
          corFundoBotao = const Color(0xFF1D9E75);
          textoBotao = '${item.preco} moedas';
          corTextoBotao = Colors.white;
        }

        Widget visualDoItem;
        if (item.imagemPath != null && item.imagemPath!.isNotEmpty) {
          visualDoItem = Image.asset(
            item.imagemPath!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          );
        } else {
          visualDoItem = Icon(
            item.icone ?? Icons.star,
            size: 64,
            color: bloqueado ? Colors.grey : (ehConsumivel ? Colors.amber : const Color(0xFF1D9E75)),
          );
        }

        if (bloqueado) {
          visualDoItem = ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: visualDoItem,
          );
        }

        return GestureDetector(
          onTap: (bloqueado || isEquipado)
              ? null
              : () => _processarCompra(item, moedas, userData),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: bloqueado ? 0.4 : 1.0,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(child: visualDoItem),
                                const SizedBox(height: 8),
                                Text(
                                  item.nome,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: bloqueado ? Colors.grey : const Color(0xFF1D9E75),
                                  ),
                                ),
                                // Indicador de Estoque para Power-Ups
                                if (ehConsumivel && !bloqueado)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Em estoque: $estoqueAtual',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (bloqueado)
                            const Icon(Icons.lock, size: 32, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(color: corFundoBotao),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        textoBotao,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: corTextoBotao,
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
      length: 3, // Mudamos de 2 para 3 abas
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Loja Scroff',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Color(0xFF1D9E75),
            labelColor: Color(0xFF1D9E75),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Avatares'),
              Tab(icon: Icon(Icons.flash_on), text: 'Power-Ups'),
              Tab(icon: Icon(Icons.military_tech), text: 'Títulos'),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('usuarios').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
              );
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>;
            int moedas = userData['moedas'] ?? 0;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Exibe as 3 abas na mesma ordem definida no topo
                Expanded(
                  child: TabBarView(
                    children: [
                      _construirGradeDeItens('icone', userData),
                      _construirGradeDeItens('consumivel', userData),
                      _construirGradeDeItens('titulo', userData),
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