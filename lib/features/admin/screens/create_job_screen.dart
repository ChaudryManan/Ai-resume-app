
import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/job_embedding_service.dart';
class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _skillsController = TextEditingController();
  final _salaryController = TextEditingController();

  String _jobType = 'Full Time';
  String _experience = '1-2 Years';
  String _education = "Bachelor's Degree";

  final Color blue = const Color(0xFF4F6EF7);
  final Color navy = const Color(0xFF172554);

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _responsibilitiesController.dispose();
    _skillsController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Widget buildInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter $label';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFBFE),
            contentPadding: const EdgeInsets.all(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: blue, width: 1.5),
            ),
          ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                option,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFBFE),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: blue, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
            children: [
              first,
              const SizedBox(height: 18),
              second,
            ],
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

  void clearForm() {
    _formKey.currentState?.reset();

    _titleController.clear();
    _departmentController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _responsibilitiesController.clear();
    _skillsController.clear();
    _salaryController.clear();

    setState(() {
      _jobType = 'Full Time';
      _experience = '1-2 Years';
      _education = "Bachelor's Degree";
    });
  }

  
Future<void> createJob() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

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
      skills: _skillsController.text,
    );

    if (!mounted) return;

    clearForm();

    // The job is already saved. Embedding failure must not undo that.
        String? embeddingError;
    try {
      await JobEmbeddingService().generateJobEmbeddings(jobId);
    } catch (e, stackTrace) {
      embeddingError = e.toString();
      debugPrint('[JobEmbedding] FAILED for job $jobId: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          embeddingError == null
              ? 'Job created. Matching with candidate resumes has started. ID: $jobId'
              : 'Job created, but embedding failed: $embeddingError',
        ),
        backgroundColor:
            embeddingError == null ? Colors.green : Colors.orange,
      ),
    );
  } catch (e,stackTrace) {
    debugPrint('[CreateJob] FAILED: $e');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to create job: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a New Job',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172554),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Define the role and qualifications to find your ideal candidate.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 25),

                  buildSection(
                    title: 'Job Information',
                    subtitle: 'Basic details about this position',
                    icon: Icons.work_outline,
                    children: [
                      buildInput(
                        label: 'Job Title',
                        hint: 'e.g. Junior AI Engineer',
                        controller: _titleController,
                      ),
                      const SizedBox(height: 18),
                      buildResponsiveRow(
                        buildInput(
                          label: 'Department',
                          hint: 'e.g. Artificial Intelligence',
                          controller: _departmentController,
                        ),
                        buildInput(
                          label: 'Job Location',
                          hint: 'e.g. Lahore, Pakistan',
                          controller: _locationController,
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildResponsiveRow(
                        buildDropdown(
                          label: 'Employment Type',
                          value: _jobType,
                          options: [
                            'Full Time',
                            'Part Time',
                            'Internship',
                            'Contract',
                            'Remote',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _jobType = value);
                            }
                          },
                        ),
                        buildInput(
                          label: 'Salary / Salary Range',
                          hint: 'e.g. PKR 80,000 - 120,000',
                          controller: _salaryController,
                          required: false,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  buildSection(
                    title: 'Job Description',
                    subtitle: 'Explain the position to applicants',
                    icon: Icons.description_outlined,
                    children: [
                      buildInput(
                        label: 'Job Overview',
                        hint: 'Describe the role, goals and what the candidate will do...',
                        controller: _descriptionController,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 18),
                      buildInput(
                        label: 'Responsibilities',
                        hint: 'Describe the main responsibilities of this position...',
                        controller: _responsibilitiesController,
                        maxLines: 4,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  buildSection(
                    title: 'Candidate Requirements',
                    subtitle: 'Set the qualifications for your ideal candidate',
                    icon: Icons.school_outlined,
                    children: [
                      buildResponsiveRow(
                        buildDropdown(
                          label: 'Minimum Education',
                          value: _education,
                          options: [
                            'Intermediate',
                            'Diploma',
                            "Bachelor's Degree",
                            "Master's Degree",
                            'PhD',
                            'Any Education Level',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _education = value);
                            }
                          },
                        ),
                        buildDropdown(
                          label: 'Required Experience',
                          value: _experience,
                          options: [
                            'Fresh Graduate',
                            'Less than 1 Year',
                            '1-2 Years',
                            '3-5 Years',
                            '5+ Years',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _experience = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildInput(
                        label: 'Required Skills',
                        hint: 'e.g. Python, Flutter, Machine Learning, SQL',
                        controller: _skillsController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Separate skills with commas. These skills will later be used for resume matching.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: clearForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            foregroundColor: navy,
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Clear Form'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: createJob,
                          icon: const Icon(Icons.add, size: 19),
                          label: const Text('Create Job'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
