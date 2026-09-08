import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/config.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.environment();
  AuthService? auth;
  if (config.isValid) {
    await Supabase.initialize(url: config.url, publishableKey: config.key);
    auth = SupabaseAuthService(Supabase.instance.client);
  }
  runApp(OcorrenciasApp(auth: auth));
}

class OcorrenciasApp extends StatelessWidget {
  const OcorrenciasApp({super.key, this.auth, this.home});
  final AuthService? auth;
  final Widget Function(UserProfile)? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ocorrências Escolares',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: auth == null
        ? const SetupPage()
        : AuthGate(
            auth: auth!,
            home:
                home ??
                (user) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Ocorrências Escolares'),
                    actions: [
                      IconButton(
                        tooltip: 'Sair',
                        onPressed: auth!.signOut,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Olá, ${user.name}.'),
                  ),
                ),
          ),
  );
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ocorrências Escolares')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E.E. João Paulo II'),
            SizedBox(height: 16),
            Text(
              'Esta instalação ainda não está conectada à escola. Solicite a versão configurada ao administrador.',
            ),
          ],
        ),
      ),
    ),
  );
}
