import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyError(Object error) {
  if (error is PostgrestException && error.code == '23505') {
    return 'Já existe um cadastro com esse identificador. Confira o RA/matrícula.';
  }
  if (error is PostgrestException && error.code == 'P0001') {
    return error.message;
  }
  if (error is FunctionException &&
      error.details is Map &&
      error.details['error'] is String) {
    return error.details['error'] as String;
  }
  return 'Não foi possível concluir. Confira a conexão e tente novamente.';
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
}

Future<String?> askReason(BuildContext context, String title) async {
  final input = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Justificativa obrigatória',
            errorText: error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isEmpty) {
                setState(() => error = 'Informe a justificativa.');
                return;
              }
              Navigator.pop(context, input.text.trim());
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ),
  );
  // O diálogo encerra sua animação antes de o controlador ser descartado.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  input.dispose();
  return result;
}
