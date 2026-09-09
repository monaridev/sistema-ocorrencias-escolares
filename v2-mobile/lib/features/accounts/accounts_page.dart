import 'package:flutter/material.dart';
import '../../services/school_repository.dart';
import '../../core/feedback.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.repository});
  final SchoolRepository repository;
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final users = <Map<String, dynamic>>[];
  int page = 1;
  bool busy = false, more = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page;
      final result = await widget.repository.manageUsers({
        'action': 'list',
        'page': next,
      });
      if (!mounted) return;
      setState(() {
        if (reset) users.clear();
        users.addAll(List<Map<String, dynamic>>.from(result['users']));
        page = next + 1;
        more = result['has_more'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? user]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountForm(repository: widget.repository, user: user),
      ),
    );
    if (mounted) await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administrar contas'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: busy ? null : () => load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => edit(),
      icon: const Icon(Icons.person_add),
      label: const Text('Criar conta'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final user in users)
          ListTile(
            title: Text(user['nome'] ?? ''),
            subtitle: Text(
              '${user['email']}\n${user['role']} · ${user['ativo'] == true ? 'Ativa' : 'Inativa'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => edit(user),
          ),
        if (error != null) Text(error!),
        if (busy) const Center(child: CircularProgressIndicator()),
        if (!busy && more)
          TextButton(
            onPressed: load,
            child: Text(error == null ? 'Carregar mais' : 'Tentar novamente'),
          ),
      ],
    ),
  );
}

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, required this.repository, this.user});
  final SchoolRepository repository;
  final Map<String, dynamic>? user;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  String role = 'professor';
  bool active = true, busy = false, uncertain = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      name.text = u['nome'];
      email.text = u['email'];
      role = u['role'];
      active = u['ativo'];
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || uncertain || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.manageUsers({
        'action': widget.user == null ? 'create' : 'update',
        if (widget.user != null) 'id': widget.user!['id'],
        'nome': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'role': role,
        'ativo': active,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          uncertain = true;
          error =
              '${friendlyError(e)}\nVolte à lista e confira a conta antes de tentar novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.user == null ? 'Criar conta' : 'Alterar conta'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: name,
              enabled: !busy,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (s) =>
                  RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(s?.trim() ?? '')
                  ? null
                  : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: widget.user == null
                    ? 'Senha inicial'
                    : 'Nova senha (opcional)',
              ),
              validator: (s) =>
                  (widget.user == null || (s ?? '').isNotEmpty) &&
                      (s ?? '').length < 8
                  ? 'Use pelo menos 8 caracteres.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Papel'),
              items: [
                for (final r in ['professor', 'gestor', 'admin'])
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: busy ? null : (v) => setState(() => role = v!),
            ),
            SwitchListTile(
              title: const Text('Conta ativa'),
              value: active,
              onChanged: busy ? null : (v) => setState(() => active = v),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!),
              ),
            FilledButton(
              onPressed: busy || uncertain ? null : save,
              child: Text(busy ? 'Salvando…' : 'Salvar conta'),
            ),
          ],
        ),
      ),
    ),
  );
}
