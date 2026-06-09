import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BossService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Dano bônus fixo por completar um desafio
  static const int danoPorDesafioConcluido = 80;

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

  Stream<DocumentSnapshot> bossStream(String grupoId) {
    return _db.collection('grupos').doc(grupoId).snapshots();
  }

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
        'dano_por_membro': {},
        'ataques_diarios': {},
      },
    });
  }

  // =========================================================
  // DANO MANUAL — botão Atacar na tela do boss (1x por dia)
  // =========================================================
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
    if (!grupoDoc.exists) return {'sucesso': false};
    Map<String, dynamic> grupoData = grupoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic>? boss = grupoData['boss'] as Map<String, dynamic>?;
    if (boss == null || boss['ativo'] != true)
      return {'sucesso': false, 'motivo': 'sem_boss'};

    // Trava diária
    String hoje = _hoje();
    Map<String, dynamic> ataquesDiarios = Map<String, dynamic>.from(
      boss['ataques_diarios'] ?? {},
    );
    if (ataquesDiarios[uid] == hoje)
      return {'sucesso': false, 'motivo': 'ja_atacou'};

    int dano = (minutosHoje < limiteMinutos)
        ? (limiteMinutos - minutosHoje).clamp(10, 200).toInt()
        : 10;

    ataquesDiarios[uid] = hoje;
    await _db.collection('grupos').doc(grupoId).update({
      'boss.ataques_diarios': ataquesDiarios,
    });

    return await _aplicarDano(
      grupoId: grupoId,
      uid: uid,
      dano: dano,
      boss: boss,
      grupoData: grupoData,
    );
  }

  // =========================================================
  // DANO AUTOMÁTICO DIÁRIO — chamado pelo sync ao virar o dia
  // =========================================================
  Future<Map<String, dynamic>> danoSyncDiario({
    required String grupoId,
    required String uid,
    required int minutosHoje,
    int limiteMinutos = 180,
  }) async {
    if (uid.isEmpty) return {'sucesso': false};

    DocumentSnapshot grupoDoc = await _db
        .collection('grupos')
        .doc(grupoId)
        .get();
    if (!grupoDoc.exists) return {'sucesso': false};
    Map<String, dynamic> grupoData = grupoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic>? boss = grupoData['boss'] as Map<String, dynamic>?;
    if (boss == null || boss['ativo'] != true)
      return {'sucesso': false, 'motivo': 'sem_boss'};

    int dano = minutosHoje < limiteMinutos
        ? (limiteMinutos - minutosHoje).clamp(5, 150).toInt()
        : 5;

    return await _aplicarDano(
      grupoId: grupoId,
      uid: uid,
      dano: dano,
      boss: boss,
      grupoData: grupoData,
    );
  }

  // =========================================================
  // DANO BÔNUS POR DESAFIO — chamado ao coletar desafio
  // =========================================================
  Future<Map<String, dynamic>> danoPorDesafio({
    required String grupoId,
    required String uid,
  }) async {
    if (uid.isEmpty || grupoId.isEmpty) return {'sucesso': false};

    DocumentSnapshot grupoDoc = await _db
        .collection('grupos')
        .doc(grupoId)
        .get();
    if (!grupoDoc.exists) return {'sucesso': false};
    Map<String, dynamic> grupoData = grupoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic>? boss = grupoData['boss'] as Map<String, dynamic>?;
    if (boss == null || boss['ativo'] != true)
      return {'sucesso': false, 'motivo': 'sem_boss'};

    return await _aplicarDano(
      grupoId: grupoId,
      uid: uid,
      dano: danoPorDesafioConcluido,
      boss: boss,
      grupoData: grupoData,
    );
  }

  // =========================================================
  // NÚCLEO: aplica dano, verifica derrota, distribui recompensas
  // =========================================================
  Future<Map<String, dynamic>> _aplicarDano({
    required String grupoId,
    required String uid,
    required int dano,
    required Map<String, dynamic> boss,
    required Map<String, dynamic> grupoData,
  }) async {
    int hpAtual = boss['hp_atual'] ?? 0;
    int novoHp = (hpAtual - dano).clamp(0, (boss['hp_maximo'] as int)).toInt();

    Map<String, dynamic> danoPorMembro = Map<String, dynamic>.from(
      boss['dano_por_membro'] ?? {},
    );
    danoPorMembro[uid] = (danoPorMembro[uid] ?? 0) + dano;

    bool derrotou = novoHp <= 0;

    await _db.collection('grupos').doc(grupoId).update({
      'boss.hp_atual': novoHp,
      'boss.dano_por_membro': danoPorMembro,
      if (derrotou) 'boss.ativo': false,
    });

    if (derrotou) {
      await _distribuirRecompensas(
        boss,
        grupoData['membros'] ?? [],
        danoPorMembro,
      );
    }

    return {
      'sucesso': true,
      'dano': dano,
      'hp_atual': novoHp,
      'derrotou': derrotou,
    };
  }

  // =========================================================
  // DISTRIBUIÇÃO PROPORCIONAL AO DANO CAUSADO
  // =========================================================
  Future<void> _distribuirRecompensas(
    Map<String, dynamic> boss,
    List<dynamic> membros,
    Map<String, dynamic> danoPorMembro,
  ) async {
    int xpTotal = boss['recompensa_xp'] ?? 200;
    int moedasTotal = boss['recompensa_moedas'] ?? 50;

    int danoTotalGrupo = danoPorMembro.values.fold(
      0,
      (soma, dano) => soma + (dano as int),
    );

    WriteBatch batch = _db.batch();
    for (String uid in membros.cast<String>()) {
      int danoCausado = danoPorMembro[uid] ?? 0;
      int xpFinal;
      int moedasFinal;

      if (danoTotalGrupo == 0 || danoCausado == 0) {
        // Não participou — consolação de 10%
        xpFinal = (xpTotal * 0.1).round();
        moedasFinal = (moedasTotal * 0.1).round();
      } else {
        double proporcao = danoCausado / danoTotalGrupo;
        xpFinal = (xpTotal * proporcao).round();
        moedasFinal = (moedasTotal * proporcao).round();
      }

      batch.update(_db.collection('usuarios').doc(uid), {
        'xp': FieldValue.increment(xpFinal),
        'moedas': FieldValue.increment(moedasFinal),
      });
    }
    await batch.commit();
  }

  // Busca o grupoId do grupo ao qual o usuário pertence
  Future<String> getGrupoIdDoUsuario(String uid) async {
    QuerySnapshot snap = await _db
        .collection('grupos')
        .where('membros', arrayContains: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return '';
    return snap.docs.first.id;
  }

  String _hoje() {
    DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
