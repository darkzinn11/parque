import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF669340);
const _dark = Color(0xFF32384A);

class EventRequestSuccessScreen extends StatelessWidget {
  const EventRequestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              Text(
                'Solicitação\nenviada!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _green,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 40),

              Image.asset(
                'assets/images/calendario.png',
                width: 260,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 40),

              Text(
                'Sua solicitação foi enviada.\nAguarde a aprovação do gestor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: _dark,
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.go('/tabs/user/meus-pedidos-evento'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.event_note_outlined,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Ver minhas solicitações',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
