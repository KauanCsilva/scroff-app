import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BossService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Catálogo de bosses disponíveis (rotação por semana)
  static const List<Map<String, dynamic>> catalogo = [
    {
      'id': 'boss_notificacoes',
      'nome': 'Senhor das Notificações',
      'descricao':
          'Ele alimenta sua compulsão de checar o celular a cada minuto.',
      'emoji': '🔔',
      'hp_maximo': 1000,
      'recompensa_xp': 300,
      'recompensa_moedas': 100,
      'cor': 0xFFE24B4A,
    },
    {
      'id': 'boss_scrollinfinito',
      'nome': 'Espírito do Scroll Infinito',
      'descricao': 'Alimentado por reels e shorts, ele nunca deixa você parar.',
      'emoji': '📱',
      'hp_maximo': 1500,
      'recompensa_xp': 500,
      'recompensa_moedas': 150,
      'cor': 0xFF9B59B6,
    },
    {
      'id': 'boss_insonia',
      'nome': 'Demônio da Insônia Digital',
      'descricao': 'Ele te mantém na tela até de madrugada, roubando seu sono.',
      'emoji': '🌙',
      'hp_maximo': 2000,
      'recompensa_xp': 700,
      'recompensa_moedas': 200,
      'cor': 0xFF2C3E50,
    },
    {
      'id': 'boss_procrastinacao',
      'nome': 'Arquiduque da Procrastinação',
      'descricao': 'Transforma cada tarefa em horas de distração no celular.',
      'emoji': '⏳',
      'hp_maximo': 1200,
      'recompensa_xp': 400,
      'recompensa_moedas': 120,
      'cor': 0xFFEF9F27,
    },
  ];

  // Retorna stream do boss ativo do grupo
  Stream<DocumentSnapshot> bossStream(String grupoId) {
    return _db.collection('grupos').doc(grupoId).snapshots();
  }

  // Cria um novo boss para o grupo
  Future<void> invocarBoss(String grupoId, Map<String, dynamic> boss) async {
    await _db.collection('grupos').doc(grupoId).update({
      'boss': {
        'id': boss['id'],
        'nome': boss['nome'],
        'descricao': boss['descricao'],
        'emoji': boss['emoji'],
        'hp_maximo': boss['hp_maximo'],
        'hp_atual': boss['hp_maximo'],
        'recompensa_xp': boss['recompensa_xp'],
        'recompensa_moedas': boss['recompensa_moedas'],
        'cor': boss['cor'],
        'ativo': true,
        'criado_em': FieldValue.serverTimestamp(),
        'dano_por_membro': {}, // uid -> dano total causado
      },
    });
  }

  // Calcula e aplica o dano do usuário ao boss
  // Dano = quantos minutos ficou ABAIXO do limite diário (padrão: 180min = 3h)
  Future<Map<String, dynamic>> atacarBoss({
    required String grupoId,
    required int minutosHoje,
    int limiteMinutos = 180,
  }) async {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return {'sucesso': false};

    DocumentSnapshot grupoDoc = await _db
        .collection('grupos')
        .doc(grupoId)
        .get();
    Map<String, dynamic> grupoData = grupoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic>? boss = grupoData['boss'] as Map<String, dynamic>?;

    if (boss == null || boss['ativo'] != true) {
      return {'sucesso': false, 'motivo': 'sem_boss'};
    }

    // Checa se o usuário já atacou hoje
    String hoje = _hoje();
    Map<String, dynamic> ataquesDiarios = Map<String, dynamic>.from(
      boss['ataques_diarios'] ?? {},
    );
    if (ataquesDiarios[uid] == hoje) {
      return {'sucesso': false, 'motivo': 'ja_atacou'};
    }

    // Calcula dano: cada minuto abaixo do limite = 1 de dano, mínimo 10
    int dano = (minutosHoje < limiteMinutos)
        ? (limiteMinutos - minutosHoje).clamp(10, 200).toInt()
        : 10; // Mesmo acima do limite, causa dano mínimo para incentivar participação

    int hpAtual = boss['hp_atual'] ?? 0;
    int novoHp = (hpAtual - dano).clamp(0, (boss["hp_maximo"] as int)).toInt();

    // Acumula dano por membro
    Map<String, dynamic> danoPorMembro = Map<String, dynamic>.from(
      boss['dano_por_membro'] ?? {},
    );
    danoPorMembro[uid] = (danoPorMembro[uid] ?? 0) + dano;

    ataquesDiarios[uid] = hoje;

    bool derrotou = novoHp <= 0;

    await _db.collection('grupos').doc(grupoId).update({
      'boss.hp_atual': novoHp,
      'boss.dano_por_membro': danoPorMembro,
      'boss.ataques_diarios': ataquesDiarios,
      if (derrotou) 'boss.ativo': false,
    });

    // Se derrotou, distribui recompensas para todos os membros
    if (derrotou) {
      await _distribuirRecompensas(grupoId, boss, grupoData['membros'] ?? []);
    }

    return {
      'sucesso': true,
      'dano': dano,
      'hp_atual': novoHp,
      'derrotou': derrotou,
    };
  }

  // Distribui XP e moedas para todos ao derrotar o boss
  Future<void> _distribuirRecompensas(
    String grupoId,
    Map<String, dynamic> boss,
    List<dynamic> membros,
  ) async {
    int xp = boss['recompensa_xp'] ?? 200;
    int moedas = boss['recompensa_moedas'] ?? 50;

    WriteBatch batch = _db.batch();
    for (String uid in membros.cast<String>()) {
      DocumentReference userRef = _db.collection('usuarios').doc(uid);
      // Usa increment para não precisar ler o doc de cada membro
      batch.update(userRef, {
        'xp': FieldValue.increment(xp),
        'moedas': FieldValue.increment(moedas),
      });
    }
    await batch.commit();
  }

  String _hoje() {
    DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
