import 'package:flutter/material.dart';
import '../../services/school_repository.dart';
import '../../core/feedback.dart';

class EmailSettingsPage extends StatefulWidget {
  const EmailSettingsPage({super.key, required this.repository});
  final SchoolRepository repository;
  @override
  State<EmailSettingsPage> createState() => _EmailSettingsPageState();
}

class _EmailSettingsPageState extends State<EmailSettingsPage> {
  final recipients = TextEditingController();
  bool busy = true, enabled = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    recipients.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final config = await widget.repository.emailSettings();
      if (mounted) {
        setState(() {
          recipients.text = (config['recipients'] as List).join('\n');
          enabled = config['enabled'];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final list = recipients.text
        .split(RegExp(r'[\n,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (list.length > 20 ||
        (enabled && list.isEmpty) ||
        list.any(
          (e) => !RegExp(r'^[^\s@,<>]+@[^\s@,<>]+\.[^\s@,<>]+$').hasMatch(e),
        )) {
      setState(() => error = 'Informe até 20 e-mails válidos, um por linha.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.configureEmail(list, enabled);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurar e-mail')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Os PDFs serão enviados somente aos destinatários abaixo. A alteração vale para todos os aparelhos.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: recipients,
            enabled: !busy,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Destinatários (um por linha)',
            ),
          ),
          SwitchListTile(
            title: const Text('Habilitar envio'),
            value: enabled,
            onChanged: busy ? null : (v) => setState(() => enabled = v),
          ),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: busy ? null : save,
            child: const Text('Salvar configuração'),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
