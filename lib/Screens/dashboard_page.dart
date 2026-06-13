import 'package:flutter/material.dart';
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
  int _abaAtual = 0;

  final List<Widget> _telas = [
    const HomeScreen(),
    const DesafiosScreen(),
    const PartysScreen(),
    const LojaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_abaAtual],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: const Color(0xFFFF5700),
        unselectedItemColor: const Color(0xFFFFFFFF),
        backgroundColor:  const Color(0xFF246815),

        onTap: (index) {
          setState(() {
            _abaAtual = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Desafios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Partys',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Loja',
          ),
        ],
      ),
    );
  }
}