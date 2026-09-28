import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color darkGreenTop = Color(0xFF0E241C);
  static const Color darkGreenMid = Color(0xFF1E4433);
  static const Color mediumGreen = Color(0xFF3E6A52);
  static const Color fieldGreen = Color(0xFF4C7A5E);
  static const Color fieldGreenLight = Color(0xFF5A8B6C);
  static const Color accentOrange = Color(0xFFF2A93B);
  static const Color accentRed = Color(0xFFE0685A);
  static const Color accentBlue = Color(0xFF6E9BD1);
  static const Color mintIcon = Color(0xFFB7E4C7);
  static const Color textWhite = Color(0xFFFAFAFA);
  static const Color textMuted = Color(0xFFCBD9CF);
  static const Color textFaint = Color(0xFF8FA69A);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkGreenTop, darkGreenMid, mediumGreen],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkGreenTop, Color(0xFF14352A)],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkGreenTop,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mediumGreen,
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleMedium: TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(color: AppColors.textMuted, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textFaint, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: AppColors.darkGreenTop,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final Widget? suffix;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.fieldGreen,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}


class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
