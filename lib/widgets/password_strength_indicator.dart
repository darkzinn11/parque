import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF669340);

enum PasswordStrength { empty, fraca, media, forte }

class PasswordRules {
  static const int minLen = 8;
  static const int maxLen = 72;

  static bool hasMinLength(String v)  => v.length >= minLen;
  static bool hasMaxLength(String v)  => v.length <= maxLen;
  static bool hasUppercase(String v)  => RegExp(r'[A-Z]').hasMatch(v);
  static bool hasNumber(String v)     => RegExp(r'[0-9]').hasMatch(v);
  static bool hasSpecial(String v)    => RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?/\\]').hasMatch(v);

  static PasswordStrength strength(String v) {
    if (v.isEmpty) return PasswordStrength.empty;
    int score = 0;
    if (hasMinLength(v)) score++;
    if (hasUppercase(v)) score++;
    if (hasNumber(v))    score++;
    if (hasSpecial(v))   score++;
    if (score <= 1) return PasswordStrength.fraca;
    if (score <= 2) return PasswordStrength.media;
    return PasswordStrength.forte;
  }

  /// Retorna null se a senha atende todas as regras, ou a mensagem do primeiro problema.
  static String? validate(String? value) {
    final v = value ?? '';
    if (v.isEmpty)           return 'Crie uma senha';
    if (!hasMinLength(v))    return 'Mínimo de $minLen caracteres';
    if (!hasMaxLength(v))    return 'Máximo de $maxLen caracteres';
    if (!hasUppercase(v))    return 'Inclua pelo menos uma letra maiúscula';
    if (!hasNumber(v))       return 'Inclua pelo menos um número';
    if (!hasSpecial(v))      return 'Inclua pelo menos um caractere especial (!@#\$%...)';
    return null;
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final s = PasswordRules.strength(password);

    final (barColor, label) = switch (s) {
      PasswordStrength.fraca  => (Colors.red.shade400,   'Fraca'),
      PasswordStrength.media  => (Colors.orange.shade400, 'Média'),
      PasswordStrength.forte  => (_green,                'Forte'),
      _                       => (Colors.transparent,    ''),
    };

    final filledSegments = switch (s) {
      PasswordStrength.fraca => 1,
      PasswordStrength.media => 2,
      PasswordStrength.forte => 4,
      _                      => 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(4, (i) {
                  final filled = i < filledSegments;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled ? barColor : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _RuleRow(
          met: PasswordRules.hasMinLength(password),
          label: 'Mínimo ${PasswordRules.minLen} caracteres',
        ),
        _RuleRow(
          met: PasswordRules.hasUppercase(password),
          label: 'Uma letra maiúscula',
        ),
        _RuleRow(
          met: PasswordRules.hasNumber(password),
          label: 'Um número',
        ),
        _RuleRow(
          met: PasswordRules.hasSpecial(password),
          label: 'Um caractere especial (!@#\$%...)',
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? _green : const Color(0xFFB0B8C1),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: met ? _green : const Color(0xFF8F959E),
            ),
          ),
        ],
      ),
    );
  }
}
