import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.home});
  final AuthService auth;
  final Widget Function(UserProfile) home;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  StreamSubscription<void>? subscription;
  Future<UserProfile>? profile;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
    subscription = widget.auth.changes.listen((_) => reload());
  }

  void reload() {
    if (mounted) {
      final next = widget.auth.userId == null ? null : widget.auth.profile();
      setState(() {
        profile = next;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  @override
  void dispose() {
    subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) return LoginPage(auth: widget.auth);
    return FutureBuilder<UserProfile>(
      future: profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.active) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso à escola')),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.hasError
                            ? 'Não foi possível verificar seu acesso. Confira a conexão.'
                            : 'Sua conta está desativada. Procure o administrador.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: reload,
                        child: const Text('Tentar novamente'),
                      ),
                      TextButton(
                        onPressed: widget.auth.signOut,
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final user = snapshot.data!;
        // Este Navigator é descartado com a sessão/perfil; telas privadas não sobrevivem ao logout.
        return Navigator(
          key: ValueKey('${user.id}:${user.role}'),
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => widget.home(user)),
        );
      },
    );
  }
}
