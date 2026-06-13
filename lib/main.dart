import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'Screens/permission_screen.dart';
import 'Screens/login_screen.dart';
import 'services/usage_service.dart';
import 'services/auth_service.dart';
import 'Screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        colorSchemeSeed: const Color(0xFF246815),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: AuthService().usuarioLogado,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const AppRoot();
          }
          return const LoginScreen();
        },
      ),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_permissaoConcedida) {
      _verificarPermissao();
    }
  }

  Future<void> _verificarPermissao() async {
    final temPermissao = await UsageService.temPermissao();
    if (mounted) {
      setState(() {
        _permissaoConcedida = temPermissao;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissaoConcedida) {
      return const DashboardPage();
    } else {
      return const PermissionScreen();
    }
  }
}