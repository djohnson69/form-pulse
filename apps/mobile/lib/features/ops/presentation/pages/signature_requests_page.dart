import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import '../../../documents/data/documents_provider.dart';
import '../../../dashboard/presentation/pages/signature_pad_page.dart';

class SignatureRequestsPage extends ConsumerWidget {
  const SignatureRequestsPage({super.key, this.documentId});

  final String? documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(signatureRequestsProvider(documentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Signature Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No signature requests yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final isSigned = request.status == 'signed';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(isSigned ? Icons.check_circle : Icons.edit),
                  title: Text(request.requestName ?? 'Signature request'),
                  subtitle: Text(
                    '${request.signerName ?? 'Signer'} • ${request.status.toUpperCase()}',
                  ),
                  trailing: isSigned
                      ? const Icon(Icons.verified, color: Colors.green)
                      : TextButton(
                          onPressed: () => _captureSignature(context, ref, request),
                          child: const Text('Sign'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final signerController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedDocumentId = documentId;
    bool isSaving = false;
    final docsAsync = await ref.read(documentsProvider(null).future);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create request',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Request name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: signerController,
                    decoration: const InputDecoration(
                      labelText: 'Signer name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Signer email (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedDocumentId,
                    decoration: const InputDecoration(
                      labelText: 'Document (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No document'),
                      ),
                      ...docsAsync.map((doc) {
                        return DropdownMenuItem<String?>(
                          value: doc.id,
                          child: Text(doc.title),
                        );
                      }),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedDocumentId = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty ||
                                signerController.text.trim().isEmpty) {
                              return;
                            }
                            setState(() => isSaving = true);
                            await ref
                                .read(opsRepositoryProvider)
                                .createSignatureRequest(
                                  requestName: nameController.text.trim(),
                                  signerName: signerController.text.trim(),
                                  signerEmail: emailController.text.trim().isEmpty
                                      ? null
                                      : emailController.text.trim(),
                                  documentId: selectedDocumentId,
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Create request'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    nameController.dispose();
    signerController.dispose();
    emailController.dispose();
    if (result == true) {
      ref.invalidate(signatureRequestsProvider(documentId));
    }
  }

  Future<void> _captureSignature(
    BuildContext context,
    WidgetRef ref,
    SignatureRequest request,
  ) async {
    final result = await Navigator.of(context).push<SignatureResult>(
      MaterialPageRoute(builder: (_) => const SignaturePadPage()),
    );
    if (result == null) return;
    await ref.read(opsRepositoryProvider).signSignatureRequest(
          request: request,
          signatureBytes: result.bytes,
          signerName: result.name,
        );
    ref.invalidate(signatureRequestsProvider(documentId));
  }
}
