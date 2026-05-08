import 'package:flutter/material.dart';
import 'Screens/home_screen.dart';
import 'Screens/permission_screen.dart';
import 'services/usage_service.dart';

void main() {
  runApp(const ScroffApp());
}

class ScroffApp extends StatelessWidget {
  const ScroffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scroff',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1D9E75),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _permissaoConcedida = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarPermissao();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Verifica permissão toda vez que o app volta ao primeiro plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarPermissao();
    }
  }

  Future<void> _verificarPermissao() async {
    final temPermissao = await UsageService.temPermissao();
    setState(() {
      _permissaoConcedida = temPermissao;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_permissaoConcedida) {
      return const HomeScreen();
    } else {
      return const PermissionScreen();
    }
  }
}
