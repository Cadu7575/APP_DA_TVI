import 'package:flutter/material.dart';

class AppTheme {
  // Cores primárias (estilo Globo Play)
  static const Color bgPrimary = Color(0xFF0F0F0F);
  static const Color bgSecondary = Color(0xFF1A1A1A);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color cardColorAlt = Color(0xFF242424);

  // Cores de destaque (gradiente TVI: azul, laranja, roxo)
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color accentRed = Color(0xFFE30613);
  static const Color accentBlue = Color(0xFF1E63C8);
  static const Color accentPurple = Color(0xFF6B2CB3);

  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF616161);

  // Shimmer
  static const Color shimmerBase = Color(0xFF2A2A2A);
  static const Color shimmerHighlight = Color(0xFF3A3A3A);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, accentOrange, accentPurple],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentOrange, accentRed],
  );
}
