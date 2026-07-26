import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tg_proxy/core/components/app_theme.dart';
import 'package:tg_proxy/core/components/theme.dart';

class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.suffixIcon,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    );

    return TextFormField(
      controller: controller,
      style: AppText.regular_18a.copyWith(fontSize: 14, color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.regular_18a.copyWith(
          fontSize: 13,
          color: colors.text.withValues(alpha: 0.62),
        ),
        errorStyle: AppText.regular_18a.copyWith(
          fontSize: 12,
          color: colors.error,
        ),
        filled: true,
        fillColor: colors.bg,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        suffixIcon: suffixIcon,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
    );
  }
}
