import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 import
import 'package:go_router/go_router.dart';

const kGreen = Color(0xFF669340);
const kDark  = Color(0xFF32384A);

class RegisterSuccessScreen extends StatelessWidget {
  const RegisterSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Agora usando SVG
              SizedBox(
                height: 180,
                child: SvgPicture.asset(
                  'assets/images/success.svg', // 👈 troquei para svg
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "Conta criada com sucesso!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Agora você já pode explorar os parques, eventos e fazer reservas.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kDark,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    context.go('/tabs/home');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Ir para a Home",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
