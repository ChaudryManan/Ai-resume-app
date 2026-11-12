import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'resume_processing_service.dart';
import 'user_insights_controller.dart';
import 'user_job_service.dart';

/// The two things a candidate can do from more than one tab:
/// upload / replace the resume and apply for a job.
/// The logic is the same as before; it just lives here so Home and Jobs share it.
class UserActions {
  UserActions(this._insights);

  final UserInsightsController _insights;
  final UserJobService _jobService = UserJobService();

  /// True while the resume uploads and the AI analyses it.
  final ValueNotifier<bool> uploading = ValueNotifier<bool>(false);

  void dispose() => uploading.dispose();

  void _snack(BuildContext context, String message, {Color? color}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // Upload or replace the candidate's resume.
  Future<void> pickAndUploadResume(BuildContext context) async {
    if (uploading.value) return;

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null || !context.mounted) return;

      final fileSize = await file.length();

      if (!context.mounted) return;

      if (fileSize == null || fileSize > 5 * 1024 * 1024) {
        _snack(
          context,
          'Resume must not exceed 5 MB or file size could not be read.',
          color: Colors.red,
        );
        return;
      }

      final bytes = await file.readAsBytes();

      if (!context.mounted) return;

      if (bytes.isEmpty) {
        _snack(context, 'The selected file is empty.', color: Colors.red);
        return;
      }

      uploading.value = true;

      _snack(context, 'Uploading your resume...');

      await _jobService.uploadOrReplaceResume(
        resumeBytes: bytes,
        resumeFileName: file.name,
      );

      _snack(
        context,
        'Resume uploaded. Analysing it with AI, this can take up to a minute...',
      );

      try {
        final chunksStored = await ResumeProcessingService().processResume();

        _snack(
          context,
          'Resume uploaded and indexed in $chunksStored sections.',
          color: Colors.green,
        );
      } catch (processingError) {
        debugPrint('RESUME PROCESSING ERROR: $processingError');

        _snack(
          context,
          'Resume uploaded, but processing failed: $processingError',
          color: Colors.red,
        );
      }

      // The profile was rebuilt from the new resume, so reload it.
      _insights.load(silent: true);
    } catch (e) {
      debugPrint('RESUME UPLOAD ERROR: $e');

      _snack(context, 'Resume upload failed: $e', color: Colors.red);
    } finally {
      uploading.value = false;
    }
  }

  // Apply for a job using the already-uploaded resume.
  Future<void> applyForJob(
    BuildContext context,
    String jobId,
    String jobTitle,
  ) async {
    try {
      await _jobService.applyForJob(jobId: jobId, jobTitle: jobTitle);

      _snack(
        context,
        'Application submitted successfully!',
        color: Colors.green,
      );
    } catch (e) {
      debugPrint('APPLICATION ERROR: $e');

      String message;

      if (e.toString().contains('already applied')) {
        message = 'You have already applied for this job.';
      } else if (e.toString().contains('upload your resume')) {
        message = 'Please upload your resume before applying.';
      } else {
        message = 'Application failed: $e';
      }

      _snack(context, message, color: Colors.red);
    }
  }
}
