import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/create_wallet_screen.dart';
import 'screens/wallet_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoneyFlowApp());
}

class MoneyFlowApp extends StatelessWidget {
  const MoneyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const AppStartup(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/create-wallet': (_) => const CreateWalletScreen(),
        '/wallets': (_) => const WalletListScreen(),
      },
    );
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _checkWallets();
  }

  Future<void> _checkWallets() async {
    final wallets = await DatabaseHelper.instance.getAllWallets();

    if (!mounted) return;

    if (wallets.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateWalletScreen(isFirstWallet: true),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
