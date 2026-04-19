import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'vision_controller.dart';
import 'damage_painter.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {

  late VisionController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VisionController();
    _controller.startMockDetection();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {

          if (!_controller.isInitialized ||
              _controller.controller == null) {

            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Stack(
            children: [

              /// CAMERA
              Positioned.fill(
                child: CameraPreview(_controller.controller!),
              ),

              /// DAMAGE PAINTER
              if (_controller.isOverlayVisible)
                Positioned.fill(
                  child: CustomPaint(
                    painter: DamagePainter(
                      _controller.currentDetections,
                    ),
                  ),
                ),

              /// BACK BUTTON
              Positioned(
                top: 40,
                left: 20,
                child: _circleButton(
                  icon: Icons.arrow_back,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              /// RIGHT TOP BUTTONS
              Positioned(
                top: 40,
                right: 20,
                child: Column(
                  children: [

                    _circleButton(
                      icon: _controller.isFlashlightOn
                          ? Icons.flash_on
                          : Icons.flash_off,
                      onTap: () {
                        _controller.toggleFlashlight();
                      },
                    ),

                    const SizedBox(height: 10),

                    _circleButton(
                      icon: _controller.isOverlayVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      onTap: () {
                        _controller.toggleOverlay();
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}