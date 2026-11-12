import 'package:flutter/material.dart';

import '../services/offer_service.dart';

class GenerateOfferDialog extends StatefulWidget {
  const GenerateOfferDialog({super.key, required this.candidateId, required this.candidateName, required this.candidateEmail, required this.jobId});
  final String candidateId;
  final String candidateName;
  final String? candidateEmail;
  final String jobId;
  @override
  State<GenerateOfferDialog> createState() => _GenerateOfferDialogState();
}

class _GenerateOfferDialogState extends State<GenerateOfferDialog> {
  final _service = OfferService();
  final _salary = TextEditingController();
  final _benefits = TextEditingController();
  final _hours = TextEditingController();
  final _joining = TextEditingController();
  final _terms = TextEditingController();
  GeneratedOffer? _offer;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _salary.dispose(); _benefits.dispose(); _hours.dispose(); _joining.dispose(); _terms.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_salary.text.trim().isEmpty) { setState(() => _error = 'Enter the salary package.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final offer = await _service.generate(
        candidateId: widget.candidateId, jobId: widget.jobId,
        salary: _salary.text.trim(),
        benefits: _benefits.text.split(RegExp(r'[,\n]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
        workingHours: _hours.text.trim().isEmpty ? null : _hours.text.trim(),
        joiningDate: _joining.text.trim().isEmpty ? null : _joining.text.trim(),
        additionalTerms: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
      );
      if (mounted) setState(() => _offer = offer);
    } catch (error) { if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _approveAndSend() async {
    final offer = _offer;
    if (offer == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve and send offer?'),
        content: Text('This will email the approved offer to ${offer.candidateEmail}. This action cannot be undone from this screen.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Review again')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve and send'))],
      ),
    );
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _service.approveAndSend(offer.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _field(TextEditingController controller, String label, {int maxLines = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true)),
  );

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    return AlertDialog(
      title: Row(children: [const Expanded(child: Text('AI job offer')), IconButton(onPressed: _busy ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close))]),
      content: SizedBox(width: 520, child: SingleChildScrollView(
        child: offer == null ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Candidate: ${widget.candidateName}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4), Text('Email: ${widget.candidateEmail ?? 'Not available'}'),
          const SizedBox(height: 16),
          _field(_salary, 'Salary package *', hint: 'e.g. PKR 150,000 per month'),
          _field(_benefits, 'Benefits', maxLines: 3, hint: 'Medical insurance, paid leave, bonus (comma or new line separated)'),
          _field(_hours, 'Working hours', hint: 'e.g. Monday–Friday, 9 AM–5 PM'),
          _field(_joining, 'Expected joining date', hint: 'e.g. 1 December 2026'),
          _field(_terms, 'Additional terms and conditions', maxLines: 3),
          const Text('The AI will prepare a draft. Nothing is emailed until you review and approve it.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ] : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Chip(avatar: Icon(Icons.edit_note, size: 18), label: Text('Draft — admin review required')),
          Text('To: ${offer.candidateEmail}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12), const Text('Subject', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4), SelectableText(offer.subject),
          const SizedBox(height: 14), const Text('Email body', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4), SelectableText(offer.body),
          const SizedBox(height: 12), const Text('Check the salary, benefits, dates and wording before sending.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      )),
      actions: [
        if (offer != null) TextButton(onPressed: _busy ? null : () => setState(() { _offer = null; _error = null; }), child: const Text('Edit details')),
        if (offer == null) FilledButton.icon(onPressed: _busy ? null : _generate, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(_busy ? 'Generating...' : 'Generate draft'))
        else FilledButton.icon(onPressed: _busy ? null : _approveAndSend, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), label: Text(_busy ? 'Sending...' : 'Approve & send email')),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}