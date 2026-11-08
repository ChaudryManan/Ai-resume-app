import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;

  /// Keyboard action key (Next / Done) and what Enter does.
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Lets the phone's password manager offer to fill this field.
  final Iterable<String>? autofillHints;

  /// Turn off for email and password so the keyboard does not "correct" them.
  final bool autocorrect;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.autocorrect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: autocorrect,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: const Color(0xFF64748B),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
