import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
  });
  final String id, name, role;
  final bool active;
  bool get isManager => role == 'gestor' || role == 'admin';
  bool get isAdmin => role == 'admin';
  factory UserProfile.fromJson(Map<String, dynamic> data) => UserProfile(
    id: data['id'] as String,
    name: data['nome'] as String,
    role: data['role'] as String,
    active: data['ativo'] as bool,
  );
}

abstract class AuthService {
  String? get userId;
  Stream<void> get changes;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<UserProfile> profile();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<void> get changes => client.auth.onAuthStateChange.map((_) {});
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
  @override
  Future<UserProfile> profile() async => UserProfile.fromJson(
    await client.from('profiles').select().eq('id', userId!).single(),
  );
}
