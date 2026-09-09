import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../services/occurrence_pdf.dart';
import '../../core/models.dart';
import '../../core/feedback.dart';
import '../../services/school_repository.dart';
import '../auth/auth_service.dart';
import 'occurrence_form.dart';

class OccurrenceDetail extends StatefulWidget {
  const OccurrenceDetail({
    super.key,
    required this.repository,
    required this.id,
    required this.user,
  });
  final SchoolRepository repository;
  final String id;
  final UserProfile user;
  @override
  State<OccurrenceDetail> createState() => _OccurrenceDetailState();
}

class _OccurrenceDetailState extends State<OccurrenceDetail> {
  late Future<Occurrence> record;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    record = widget.repository.occurrence(widget.id);
  }

  void reload() {
    setState(() {
      record = widget.repository.occurrence(widget.id);
    });
  }

  Future<void> cancel(Occurrence o) async {
    final reason = await askReason(context, 'Cancelar ocorrência');
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repository.cancel(o, reason);
      if (mounted) reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendEmail(Occurrence o) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final config = await widget.repository.emailSettings();
      if (!mounted) return;
      if (config['enabled'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O admin precisa habilitar e configurar o envio.'),
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enviar PDF por e-mail?'),
          content: Text(
            'Destinatários:\n${(config['recipients'] as List).join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await widget.repository.sendEmail(o);
      if (!mounted) return;
      final text = result['status'] == 'sent'
          ? 'Envio confirmado pelo Gmail.'
          : 'Envio pendente ou resultado incerto. Peça ao admin para conferir o Gmail antes de reenviar.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printRecord() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final fresh = await widget.repository.occurrence(widget.id);
      final bytes = await occurrencePdf(fresh);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'ocorrencia-${fresh.id}.pdf',
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ocorrência')),
    body: FutureBuilder<Occurrence>(
      future: record,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível abrir este registro.'),
                TextButton(
                  onPressed: reload,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        final o = snapshot.data!;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (o.cancelled)
                  const Chip(
                    label: Text('Cancelada'),
                    avatar: Icon(Icons.cancel_outlined),
                  ),
                Text(
                  o.student?.label ?? 'Aluno',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Professor: ${o.professor}'),
                Text('Data da ocorrência: ${formatDate(o.date)}'),
                const SizedBox(height: 24),
                Text('Motivos', style: Theme.of(context).textTheme.titleMedium),
                Text(o.reasons.join('\n')),
                const SizedBox(height: 24),
                Text('Relato', style: Theme.of(context).textTheme.titleMedium),
                Text(o.report.isEmpty ? 'Não informado' : o.report),
                const SizedBox(height: 24),
                Text(
                  'Providências',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  o.actions.isEmpty ? 'Não informadas' : o.actions.join('\n'),
                ),
                if (o.cancelled) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Justificativa do cancelamento: ${o.data['change_reason'] ?? ''}',
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: busy ? null : printRecord,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gerar / imprimir PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => sendEmail(o),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Enviar PDF por e-mail'),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.repository.emailDeliveries(o.id),
                  builder: (context, deliverySnapshot) {
                    if (deliverySnapshot.hasError) {
                      return const Text(
                        'Não foi possível consultar os envios.',
                      );
                    }
                    final deliveries = deliverySnapshot.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final d in deliveries)
                          Text(
                            'E-mail versão ${d['occurrence_version']}: ${{'sent': 'Enviado', 'failed': 'Falhou', 'processing': 'Aguardando confirmação - consulte o admin', 'unknown': 'Resultado incerto - consulte o admin'}[d['status']] ?? d['status']}',
                          ),
                      ],
                    );
                  },
                ),
                if (widget.user.isManager) ...[
                  const SizedBox(height: 24),
                  if (!o.cancelled)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OccurrenceForm(
                                        repository: widget.repository,
                                        existing: o,
                                      ),
                                    ),
                                  );
                                  if (changed == true && mounted) reload();
                                },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Corrigir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => cancel(o),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar ocorrência'),
                        ),
                      ],
                    ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AuditPage(repository: widget.repository, id: o.id),
                      ),
                    ),
                    child: const Text('Histórico de alterações'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.repository, required this.id});
  final SchoolRepository repository;
  final String id;
  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  late Future<List<Map<String, dynamic>>> entries;
  @override
  void initState() {
    super.initState();
    entries = widget.repository.audit(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico de alterações')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: entries,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                entries = widget.repository.audit(widget.id);
              }),
              child: const Text('Falha ao carregar. Tentar novamente'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma alteração registrada.'));
        }
        return ListView(
          children: snapshot.data!
              .map(
                (e) => ExpansionTile(
                  title: Text(e['reason']),
                  subtitle: Text(
                    '${e['profiles']?['nome'] ?? e['changed_by']} · ${DateTime.parse(e['changed_at']).toLocal()}',
                  ),
                  children: [
                    for (final field in [
                      'student_id',
                      'occurrence_date',
                      'motivos',
                      'relato',
                      'providencias',
                      'status',
                    ])
                      if (e['old_values'][field].toString() !=
                          e['new_values'][field].toString())
                        ListTile(
                          title: Text(
                            {
                              'student_id': 'Aluno (ID)',
                              'occurrence_date': 'Data',
                              'motivos': 'Motivos',
                              'relato': 'Relato',
                              'providencias': 'Providências',
                              'status': 'Situação',
                            }[field]!,
                          ),
                          subtitle: Text(
                            'Antes: ${e['old_values'][field]}\nDepois: ${e['new_values'][field]}',
                          ),
                        ),
                  ],
                ),
              )
              .toList(),
        );
      },
    ),
  );
}
