import 'package:flutter/material.dart';

class ItemLoja {
  final String id;
  final String tipo;
  final String nome;
  final int preco;
  final int lvl;
  final String? imagemPath;
  final IconData? icone;
  final String? descricao; // NOVO: Instrucoes de como desbloquear

  ItemLoja({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.preco,
    required this.lvl,
    this.imagemPath,
    this.icone,
    this.descricao,
  });
}

class LojaService {
  static final List<ItemLoja> catalogo = [
    // ==========================================
    // Categoria: AVATARES (tipo: 'icone')
    //
    // --- AVATARES INICIAIS ---
    ItemLoja(
      id: 'avatar_basicof',
      tipo: 'icone',
      nome: 'Mulher',
      preco: 0,
      lvl: 1,
      imagemPath: 'assets/avatars/basic_f.png', // Aponta para a pasta do app
    ),
    ItemLoja(
      id: 'avatar_basicom',
      tipo: 'icone',
      nome: 'Homem',
      preco: 0,
      lvl: 1,
      imagemPath: 'assets/avatars/basic_m.jpg',
    ),

    // --- AVATARES COMPRÁVEIS COM MOEDAS E NÍVEL ---
    ItemLoja(
      id: 'avatar_ninjaF',
      tipo: 'icone',
      nome: 'Ninja F',
      preco: 150,
      lvl: 5,
      imagemPath: 'assets/avatars/ninja_f.png',
    ),
    ItemLoja(
      id: 'avatar_ninjaM',
      tipo: 'icone',
      nome: 'Ninja M',
      preco: 150,
      lvl: 5,
      imagemPath: 'assets/avatars/ninja_m.png',
    ),
    ItemLoja(
      id: 'avatar_astronautaF',
      tipo: 'icone',
      nome: 'Austronauta F',
      preco: 300,
      lvl: 10,
      imagemPath: 'assets/avatars/astronauta_f.png',
    ),
    ItemLoja(
      id: 'avatar_astronautaM',
      tipo: 'icone',
      nome: 'Austronauta M',
      preco: 300,
      lvl: 10,
      imagemPath: 'assets/avatars/astronauta_m.png',
    ),
    ItemLoja(
      id: 'avatar_brasilF',
      tipo: 'icone',
      nome: 'Brasil F',
      preco: 50,
      lvl: 2,
      imagemPath: 'assets/avatars/brasil_f.png',
    ),
    ItemLoja(
      id: 'avatar_brasilM',
      tipo: 'icone',
      nome: 'Brasil M',
      preco: 50,
      lvl: 2,
      imagemPath: 'assets/avatars/brasil_m.png',
    ),

    // ==========================================
    // Categoria: POWER-UPS (tipo: 'consumivel')
    // ==========================================
    ItemLoja(
      id: 'cafe',
      tipo: 'consumivel',
      nome: 'Café Expresso',
      preco: 50,
      lvl: 1,
      icone: Icons.local_cafe,
    ),
    ItemLoja(
      id: 'escudo',
      tipo: 'consumivel',
      nome: 'Escudo Protetor',
      preco: 150,
      lvl: 5,
      icone: Icons.shield,
    ),
    ItemLoja(
      id: 'ticket',
      tipo: 'consumivel',
      nome: 'Ticket VIP',
      preco: 500,
      lvl: 10,
      icone: Icons.confirmation_num,
    ),

    // ==========================================
    // Categoria: TÍTULOS (tipo: 'titulo')
    // ==========================================
    ItemLoja(
      id: 't_iniciante',
      tipo: 'titulo',
      nome: 'INICIANTE',
      preco: 0,
      lvl: 1,
      icone: Icons.military_tech,
    ),
    ItemLoja(
      id: 't_zen',
      tipo: 'titulo',
      nome: 'MESTRE ZEN',
      preco: 500,
      lvl: 5,
      icone: Icons.self_improvement,
    ),
    ItemLoja(
      id: 't_intocavel',
      tipo: 'titulo',
      nome: 'INTOCÁVEL',
      preco: 1000,
      lvl: 10,
      icone: Icons.shield,
    ),
    ItemLoja(
      id: 't_maquina',
      tipo: 'titulo',
      nome: 'MÁQUINA',
      preco: 2000,
      lvl: 15,
      icone: Icons.precision_manufacturing,
    ),

    // ==========================================
    // Categoria: SELOS / BADGES (tipo: 'selo')
    // ==========================================
    ItemLoja(
      id: 'badge_tiktok_week', // O ID que sua logica de desafios vai salvar no banco
      tipo: 'selo',
      nome: 'Semana Sem tiktok',
      preco: 0,
      lvl: 1,
      imagemPath: 'assets/badges/tiktok_week.png', // Coloque a imagem na sua pasta de assets
      icone: Icons.wb_sunny, // Fallback caso a imagem de erro
      descricao: 'Fique 7 dias consecutivos usando o TikTok por menos de 1 hora.',
    ),
    ItemLoja(
      id: 'badge_lvl_10',
      tipo: 'selo',
      nome: 'Nivel 10 Alcançado',
      preco: 0,
      lvl: 1,
      icone: Icons.star,
      descricao: 'Atingido automaticamente ao chegar no nível 10 de disciplina.',
    ),
  ];

  static List<ItemLoja> getItensPorTipo(String tipo) {
    return catalogo.where((item) => item.tipo == tipo).toList();
  }
}