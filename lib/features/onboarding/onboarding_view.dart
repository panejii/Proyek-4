import 'package:flutter/material.dart';
import 'package:logbook_app_020/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int step = 1;

  void _nextStep() {
    if (step >= 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    } else {
      setState(() {
        step++;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              _getImage(),
              height: 240,
            ),

            const SizedBox(height: 32),

            Text(
              _getTitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _getDescription(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        )

      ),
    );
  }

  // ===== Mapping berdasarkan step =====

  String _getImage() {
    switch (step) {
      case 1:
        return 'assets/image/onboarding1.png'; // Jam Gadang
      case 2:
        return 'assets/image/onboarding2.png'; // Rumah Makan Padang
      case 3:
        return 'assets/image/onboarding3.png'; // Tari Piring
      default:
        return '';
    }
  }

  String _getTitle() {
    switch (step) {
      case 1:
        return 'Jam Gadang';
      case 2:
        return 'Rumah Makan Padang';
      case 3:
        return 'Baju Tradisional Minangkabau';
      default:
        return '';
    }
  }

  String _getDescription() {
    switch (step) {
      case 1:
        return 'Ikon bersejarah Minangkabau yang menjadi saksi perjalanan waktu dan identitas masyarakat Bukittinggi';
      case 2:
        return 'Cita rasa kaya rempah yang menggambarkan kehangatan, kebersamaan, dan kekayaan kuliner Nusantara';
      case 3:
        return 'Busana adat penuh makna yang mencerminkan martabat, adat, dan filosofi hidup masyarakat Minangkabau';
      default:
        return '';
    }
  }

  Color _getBackgroundColor() {
    switch (step) {
      case 1:
        return Colors.blue.shade700;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.green.shade700;
      default:
        return Colors.white;
    }
  }
}
