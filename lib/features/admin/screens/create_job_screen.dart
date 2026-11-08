import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/job_embedding_service.dart';

const Color _navy = Color(0xFF172554);
const Color _blue = Color(0xFF4F6EF7);
const Color _green = Color(0xFF059669);
const Color _amber = Color(0xFFD97706);
const Color _red = Color(0xFFDC6262);
const Color _muted = Color(0xFF64748B);
const Color _faint = Color(0xFF94A3B8);
const Color _border = Color(0xFFE9EDF5);
const Color _fieldBorder = Color(0xFFE2E8F0);

/// Keeps a half-written job when the admin taps another tab by accident
/// (the page is rebuilt each time it is opened).
class _JobDraft {
  static String title = '';
  static String department = '';
  static String location = '';
  static String salary = '';
  static String description = '';
  static String responsibilities = '';
  static String jobType = 'Full Time';
  static String experience = '1-2 Years';
  static String education = "Bachelor's Degree";
  static List<String> skills = [];

  static void clear() {
    title = '';
    department = '';
    location = '';
    salary = '';
    description = '';
    responsibilities = '';
    jobType = 'Full Time';
    experience = '1-2 Years';
    education = "Bachelor's Degree";
    skills = [];
  }
}

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key, this.onViewCandidates, this.onViewJobs});

  /// Opens the Candidates page with the new job selected.
  final ValueChanged<String>? onViewCandidates;

  /// Opens the Manage Jobs page.
  final VoidCallback? onViewJobs;

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  static const List<String> _jobTypes = [
    'Full Time',
    'Part Time',
    'Internship',
    'Contract',
    'Remote',
  ];
  static const List<String> _experiences = [
    'Fresh Graduate',
    'Less than 1 Year',
    '1-2 Years',
    '3-5 Years',
    '5+ Years',
  ];
  static const List<String> _educations = [
    'Intermediate',
    'Diploma',
    "Bachelor's Degree",
    "Master's Degree",
    'PhD',
    'Any Education Level',
  ];
  static const List<String> _skillSuggestions = [
    'Python',
    'JavaScript',
    'Flutter',
    'React',
    'Node.js',
    'SQL',
    'Machine Learning',
    'Git',
    'Docker',
    'REST APIs',
    'HTML',
    'CSS',
  ];

  final _formKey = GlobalKey<FormState>();
  final GlobalKey _infoKey = GlobalKey();
  final GlobalKey _descriptionKey = GlobalKey();
  final GlobalKey _requirementsKey = GlobalKey();

  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillInput = TextEditingController();
  final _skillFocus = FocusNode();

  final List<String> _skills = [];
  String? _skillsError;

  String _jobType = 'Full Time';
  String _experience = '1-2 Years';
  String _education = "Bachelor's Degree";

  bool _submitting = false;
  String _stage = '';

  bool get _isPhone => MediaQuery.sizeOf(context).width < 600;

  @override
  void initState() {
    super.initState();

    _titleController.text = _JobDraft.title;
    _departmentController.text = _JobDraft.department;
    _locationController.text = _JobDraft.location;
    _salaryController.text = _JobDraft.salary;
    _descriptionController.text = _JobDraft.description;
    _responsibilitiesController.text = _JobDraft.responsibilities;
    _jobType = _JobDraft.jobType;
    _experience = _JobDraft.experience;
    _education = _JobDraft.education;
    _skills.addAll(_JobDraft.skills);
  }

  @override
  void dispose() {
    _JobDraft.title = _titleController.text;
    _JobDraft.department = _departmentController.text;
    _JobDraft.location = _locationController.text;
    _JobDraft.salary = _salaryController.text;
    _JobDraft.description = _descriptionController.text;
    _JobDraft.responsibilities = _responsibilitiesController.text;
    _JobDraft.jobType = _jobType;
    _JobDraft.experience = _experience;
    _JobDraft.education = _education;
    _JobDraft.skills = List<String>.from(_skills);

    _titleController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _responsibilitiesController.dispose();
    _salaryController.dispose();
    _skillInput.dispose();
    _skillFocus.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- skills

  void _addSkill(String skill) {
    final cleaned = skill.trim();
    if (cleaned.isEmpty) return;

    final exists =
        _skills.any((item) => item.toLowerCase() == cleaned.toLowerCase());
    if (exists) return;

    setState(() {
      _skills.add(cleaned);
      _skillsError = null;
    });
  }

  // Accepts one skill or several separated by commas.
  void _addSkillsFromInput() {
    final parts = _skillInput.text.split(RegExp(r'[,;\n]'));
    _skillInput.clear();

    for (final part in parts) {
      _addSkill(part);
    }
  }

  // ------------------------------------------------------------------ form

  void clearForm() {
    _formKey.currentState?.reset();

    _titleController.clear();
    _departmentController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _responsibilitiesController.clear();
    _salaryController.clear();
    _skillInput.clear();

    setState(() {
      _jobType = 'Full Time';
      _experience = '1-2 Years';
      _education = "Bachelor's Degree";
      _skills.clear();
      _skillsError = null;
    });
  }

  void _scrollToSection(GlobalKey key) {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;

    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.02,
    );
  }

  Future<void> createJob() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();
    _addSkillsFromInput(); // a skill typed but not yet added still counts

    final formOk = _formKey.currentState!.validate();
    final skillsOk = _skills.isNotEmpty;

    if (!skillsOk) {
      setState(() => _skillsError = 'Add at least one required skill.');
    }

    if (!formOk || !skillsOk) {
      final infoMissing = _titleController.text.trim().isEmpty ||
          _departmentController.text.trim().isEmpty ||
          _locationController.text.trim().isEmpty;
      final descriptionMissing =
          _descriptionController.text.trim().isEmpty ||
              _responsibilitiesController.text.trim().isEmpty;

      _scrollToSection(
        infoMissing
            ? _infoKey
            : descriptionMissing
                ? _descriptionKey
                : _requirementsKey,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _stage = 'Saving job...';
    });

    try {
      final jobId = await AdminService().createJob(
        title: _titleController.text,
        department: _departmentController.text,
        location: _locationController.text,
        jobType: _jobType,
        salary: _salaryController.text,
        description: _descriptionController.text,
        responsibilities: _responsibilitiesController.text,
        education: _education,
        experience: _experience,
        skills: _skills.join(', '),
      );

      if (!mounted) {
        // The admin left the page while saving: still prepare the AI part.
        _JobDraft.clear();
        JobEmbeddingService()
            .generateJobEmbeddings(jobId)
            .catchError((Object _) => 0);
        return;
      }

      setState(() => _stage = 'Starting AI matching...');

      // The job is already saved. An embedding failure must not undo that.
      String? embeddingError;
      try {
        await JobEmbeddingService().generateJobEmbeddings(jobId);
      } catch (e, stackTrace) {
        embeddingError = e.toString().replaceFirst('Bad state: ', '');
        debugPrint('[JobEmbedding] FAILED for job $jobId: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) {
        _JobDraft.clear();
        return;
      }

      final title = _titleController.text.trim();
      clearForm();
      setState(() => _submitting = false);

      await _showSuccess(jobId, title, embeddingError);
    } catch (e, stackTrace) {
      debugPrint('[CreateJob] FAILED: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSuccess(
    String jobId,
    String title,
    String? embeddingError,
  ) {
    final failed = embeddingError != null;
    final color = failed ? _amber : _green;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    failed ? Icons.warning_amber_rounded : Icons.check_rounded,
                    color: color,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed ? 'Job saved' : 'Job created',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  failed
                      ? 'AI matching could not start: $embeddingError\n'
                          'You can run it again from the Candidates page.'
                      : 'The AI is matching this job with every screened '
                          'resume. The ranked candidates appear on the '
                          'Candidates page in about a minute.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                if (widget.onViewCandidates != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onViewCandidates!(jobId);
                      },
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('View candidates'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (widget.onViewJobs != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            widget.onViewJobs!();
                          },
                          style: _outlinedStyle(),
                          child: const Text('Back to jobs'),
                        ),
                      ),
                    if (widget.onViewJobs != null) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: _outlinedStyle(),
                        child: const Text('Create another'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _outlinedStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _navy,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ------------------------------------------------------------------ pieces

  InputDecoration _decoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: _faint),
      filled: true,
      fillColor: const Color(0xFFFAFBFE),
      contentPadding: const EdgeInsets.all(15),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget buildInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    bool required = true,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          textCapitalization: capitalization,
          textInputAction:
              maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter $label';
                  }
                  return null;
                }
              : null,
          decoration: _decoration(hint: hint),
        ),
      ],
    );
  }

  // Short options read better as tappable chips than as a dropdown.
  Widget buildChoice({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: option == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(option),
                backgroundColor: const Color(0xFFFAFBFE),
                selectedColor: _blue,
                side: BorderSide(
                  color: option == value ? _blue : _fieldBorder,
                ),
                labelStyle: TextStyle(
                  color: option == value ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          // A new key makes the field follow the value after "Clear".
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFBFE),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSection({
    required GlobalKey sectionKey,
    required int number,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final phone = _isPhone;

    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: EdgeInsets.all(phone ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172554),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _blue, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _faint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'STEP $number/3',
                style: const TextStyle(
                  color: _faint,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: phone ? 18 : 22),
          ...children,
        ],
      ),
    );
  }

  Widget buildResponsiveRow(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 550) {
          return Column(
            children: [first, const SizedBox(height: 18), second],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _skillsField() {
    final available = _skillSuggestions
        .where(
          (suggestion) => !_skills.any(
            (skill) => skill.toLowerCase() == suggestion.toLowerCase(),
          ),
        )
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Required Skills'),
        TextField(
          controller: _skillInput,
          focusNode: _skillFocus,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            if (value.contains(',')) _addSkillsFromInput();
          },
          onSubmitted: (_) {
            _addSkillsFromInput();
            _skillFocus.requestFocus();
          },
          decoration: _decoration(
            hint: 'Type a skill, then tap Add',
            suffixIcon: IconButton(
              tooltip: 'Add skill',
              onPressed: _addSkillsFromInput,
              icon: const Icon(Icons.add_circle, color: _blue),
            ),
          ),
        ),
        if (_skillsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _skillsError!,
              style: const TextStyle(color: _red, fontSize: 12),
            ),
          ),
        if (_skills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in _skills)
                  InputChip(
                    label: Text(skill),
                    onDeleted: () => setState(() => _skills.remove(skill)),
                    deleteIconColor: _blue,
                    backgroundColor: _blue.withValues(alpha: 0.10),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Quick add',
            style: TextStyle(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in available)
                ActionChip(
                  label: Text('+ $suggestion'),
                  onPressed: () => _addSkill(suggestion),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _fieldBorder),
                  labelStyle: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Each skill is saved on its own, so the AI can check it against '
          'every resume.',
          style: TextStyle(color: _faint, fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }

  Widget _createButton() {
    return FilledButton.icon(
      onPressed: _submitting ? null : createJob,
      icon: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_rounded, size: 20),
      label: Text(
        _submitting ? _stage : 'Create job',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: _blue,
        disabledBackgroundColor: _blue.withValues(alpha: 0.65),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Phone: always visible, so the admin never has to scroll to submit.
  Widget _phoneActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _submitting ? null : clearForm,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          Expanded(child: _createButton()),
        ],
      ),
    );
  }

  Widget _wideActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : clearForm,
            style: _outlinedStyle().copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 17),
              ),
            ),
            child: const Text('Clear form'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _createButton()),
      ],
    );
  }

  Widget _intro(bool phone) {
    if (!phone) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a New Job',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Define the role and qualifications to find your ideal candidate.',
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: _blue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Describe the role. When you create the job, the AI matches it '
              'with every screened resume automatically.',
              style: TextStyle(color: _navy, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final phone = _isPhone;

    final form = Form(
      key: _formKey,
      child: AbsorbPointer(
        // Nothing can be edited (or tapped twice) while the job is saving.
        absorbing: _submitting,
        child: Opacity(
          opacity: _submitting ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _intro(phone),
              SizedBox(height: phone ? 16 : 25),
              buildSection(
                sectionKey: _infoKey,
                number: 1,
                title: 'Job information',
                subtitle: 'Basic details about this position',
                icon: Icons.work_outline,
                children: [
                  buildInput(
                    label: 'Job Title',
                    hint: 'e.g. Junior AI Engineer',
                    controller: _titleController,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 18),
                  buildResponsiveRow(
                    buildInput(
                      label: 'Department',
                      hint: 'e.g. Artificial Intelligence',
                      controller: _departmentController,
                      capitalization: TextCapitalization.words,
                    ),
                    buildInput(
                      label: 'Job Location',
                      hint: 'e.g. Lahore, Pakistan',
                      controller: _locationController,
                      capitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildChoice(
                    label: 'Employment Type',
                    value: _jobType,
                    options: _jobTypes,
                    onChanged: (value) => setState(() => _jobType = value),
                  ),
                  const SizedBox(height: 18),
                  buildInput(
                    label: 'Salary / Salary Range (optional)',
                    hint: 'e.g. PKR 80,000 - 120,000',
                    controller: _salaryController,
                    required: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSection(
                sectionKey: _descriptionKey,
                number: 2,
                title: 'Job description',
                subtitle: 'Explain the position to applicants',
                icon: Icons.description_outlined,
                children: [
                  buildInput(
                    label: 'Job Overview',
                    hint:
                        'Describe the role, goals and what the candidate will do...',
                    controller: _descriptionController,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 18),
                  buildInput(
                    label: 'Responsibilities',
                    hint:
                        'List the main responsibilities, one per line...',
                    controller: _responsibilitiesController,
                    maxLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSection(
                sectionKey: _requirementsKey,
                number: 3,
                title: 'Candidate requirements',
                subtitle: 'Set the qualifications for your ideal candidate',
                icon: Icons.school_outlined,
                children: [
                  buildDropdown(
                    label: 'Minimum Education',
                    value: _education,
                    options: _educations,
                    onChanged: (value) {
                      if (value != null) setState(() => _education = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  buildChoice(
                    label: 'Required Experience',
                    value: _experience,
                    options: _experiences,
                    onChanged: (value) => setState(() => _experience = value),
                  ),
                  const SizedBox(height: 18),
                  _skillsField(),
                ],
              ),
              SizedBox(height: phone ? 16 : 25),
              if (!phone) _wideActions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    return Container(
      color: const Color(0xFFF5F7FC),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(phone ? 16 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: form,
                ),
              ),
            ),
          ),
          if (phone) _phoneActionBar(),
        ],
      ),
    );
  }
}
