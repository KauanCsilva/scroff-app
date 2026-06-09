import 'package:flutter/material.dart';
// IMPORTAÇÃO DAS 4 TELAS QUE CONECTAREMOS ÀS ABAS
import 'home_screen.dart';
import 'desafios_screen.dart';
import 'partys_screen.dart';
import 'loja_avatar_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // BACK-END: Variável que guarda o índice da aba ativa no momento (começa na 0 = Home)
  int _abaAtual = 0;

  // BACK-END: Lista que organiza a ordem das telas.
  // Se mudar a ordem aqui, muda a ordem das abas lá embaixo.
  final List<Widget> _telas = [
    const HomeScreen(), // Índice 0
    const DesafiosScreen(), // Índice 1
    const PartysScreen(), // Índice 2
    const LojaScreen(), // Índice 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // BACK-END: O corpo da página muda dinamicamente baseado no índice da _abaAtual
      body: _telas[_abaAtual],

      // FRONT-END: Menu de navegação inferior. Cores, fontes e tamanhos podem ser mudados aqui.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            _abaAtual, // Diz ao Flutter qual ícone deve ficar aceso/marcado
        type: BottomNavigationBarType
            .fixed, // Mantém os 4 botões fixos e visíveis na tela

        //Front-End
        selectedItemColor: const Color(0xFFFF5700), // Cor do ícone ativo
        unselectedItemColor: const Color(0xFFFFFFFF), // Cor dos ícones inativos
        backgroundColor:  const Color(0xFF246815), // Cor de fundo da barra de abas
        // BACK-END: Função que detecta o clique do usuário e muda o estado da tela
        onTap: (index) {
          setState(() {
            _abaAtual =
                index; // Atualiza o índice, forçando o Flutter a trocar a tela do 'body'
          });
        },

        // FRONT-END/DESIGNER: Aqui a pessoa muda os textos, ícones ou adiciona animações
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Home', // Aba 0
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt), // Ícone temporário de raio/missão
            label: 'Desafios', // Aba 1
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Partys', // Aba 2
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store), // Ícone de loja/sacola
            label: 'Loja', // Aba 3
          ),
        ],
      ),
    );
  }
}
