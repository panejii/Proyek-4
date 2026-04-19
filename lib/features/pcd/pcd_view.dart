import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PcdView extends StatefulWidget {
  const PcdView({super.key});

  @override
  State<PcdView> createState() => _PcdViewState();
}

class _PcdViewState extends State<PcdView> {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  String _activeOp = '';
  bool _isProcessing = false;

  // Parameter kontrol sederhana
  double _brightness = 50; 
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource src) async {
    final xfile = await _picker.pickImage(source: src, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _originalBytes = bytes;
      _processedBytes = null;
      _activeOp = '';
    });
  }

  void _reset() => setState(() {
        _processedBytes = null;
        _activeOp = '';
      });

  Future<_RawImage> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _RawImage(
      pixels: Uint8List.fromList(byteData!.buffer.asUint8List()),
      width: img.width,
      height: img.height,
    );
  }

  Future<Uint8List> _encode(_RawImage raw) async {
    final completer = Completer<Uint8List>();
    ui.decodeImageFromPixels(
      raw.pixels,
      raw.width,
      raw.height,
      ui.PixelFormat.rgba8888,
      (image) async {
        final bd = await image.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(bd!.buffer.asUint8List());
      },
    );
    return completer.future;
  }

  // ── PROCESSING FUNCTIONS ──────────────────────────────────────────────────

  Future<Uint8List> _applyGrayscale(Uint8List src) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    for (int i = 0; i < p.length; i += 4) {
      final g = ((p[i] + p[i + 1] + p[i + 2]) ~/ 3).clamp(0, 255);
      p[i] = p[i + 1] = p[i + 2] = g;
    }
    return _encode(raw);
  }

  Future<Uint8List> _applyBiner(Uint8List src) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    for (int i = 0; i < p.length; i += 4) {
      final g = (p[i] + p[i + 1] + p[i + 2]) ~/ 3;
      final bin = g >= 128 ? 255 : 0;
      p[i] = p[i + 1] = p[i + 2] = bin;
    }
    return _encode(raw);
  }

  Future<Uint8List> _applyBrightness(Uint8List src, int delta) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    for (int i = 0; i < p.length; i += 4) {
      p[i] = (p[i] + delta).clamp(0, 255);
      p[i + 1] = (p[i + 1] + delta).clamp(0, 255);
      p[i + 2] = (p[i + 2] + delta).clamp(0, 255);
    }
    return _encode(raw);
  }

  Future<Uint8List> _applyInverse(Uint8List src) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    for (int i = 0; i < p.length; i += 4) {
      p[i] = 255 - p[i];
      p[i + 1] = 255 - p[i + 1];
      p[i + 2] = 255 - p[i + 2];
    }
    return _encode(raw);
  }

  Future<Uint8List> _applyHistEq(Uint8List src) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    final total = raw.width * raw.height;

    final hist = List<int>.filled(256, 0);
    for (int i = 0; i < p.length; i += 4) {
      final g = ((p[i] + p[i + 1] + p[i + 2]) ~/ 3).clamp(0, 255);
      hist[g]++;
    }

    final cdf = List<int>.filled(256, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < 256; i++) cdf[i] = cdf[i - 1] + hist[i];

    final cdfMin = cdf.firstWhere((v) => v > 0);
    final lut = List<int>.generate(256, (i) {
      return ((cdf[i] - cdfMin) / (total - cdfMin) * 255).round().clamp(0, 255);
    });

    for (int i = 0; i < p.length; i += 4) {
      final g = ((p[i] + p[i + 1] + p[i + 2]) ~/ 3).clamp(0, 255);
      p[i] = p[i + 1] = p[i + 2] = lut[g];
    }
    return _encode(raw);
  }

  Future<Uint8List> _applyMeanBlur(Uint8List src) async {
    final raw = await _decode(src);
    final p = raw.pixels;
    final w = raw.width;
    final h = raw.height;
    final out = Uint8List.fromList(p);

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        for (int c = 0; c < 3; c++) {
          int sum = 0;
          // Kernel 3x3
          for (int ky = -1; ky <= 1; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              sum += p[((y + ky) * w + (x + kx)) * 4 + c];
            }
          }
          out[(y * w + x) * 4 + c] = (sum ~/ 9).clamp(0, 255);
        }
      }
    }
    raw.pixels.setAll(0, out);
    return _encode(raw);
  }

  Future<void> _run(String op) async {
    if (_originalBytes == null) return;
    setState(() {
      _isProcessing = true;
      _activeOp = op;
    });

    try {
      Uint8List result;
      switch (op) {
        case 'Grayscale': result = await _applyGrayscale(_originalBytes!); break;
        case 'Biner': result = await _applyBiner(_originalBytes!); break;
        case 'Brightness': result = await _applyBrightness(_originalBytes!, (_brightness - 50).round()); break;
        case 'Inverse': result = await _applyInverse(_originalBytes!); break;
        case 'Histogram Eq': result = await _applyHistEq(_originalBytes!); break;
        case 'Mean Blur': result = await _applyMeanBlur(_originalBytes!); break;
        default: result = _originalBytes!;
      }
      setState(() => _processedBytes = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operasi PCD'),
        actions: [_processedBytes != null ? IconButton(icon: const Icon(Icons.restart_alt), onPressed: _reset) : const SizedBox()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('Kamera'), onPressed: () => _pickImage(ImageSource.camera))),
              ],
            ),
          ),
          if (_originalBytes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: _ImageCard(label: 'Asli', bytes: _originalBytes!)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isProcessing
                        ? const Center(child: CircularProgressIndicator())
                        : _processedBytes != null
                            ? _ImageCard(label: 'Hasil: $_activeOp', bytes: _processedBytes!, highlight: true)
                            : const Center(child: Text('Pilih operasi')),
                  ),
                ],
              ),
            ),
          if (_originalBytes != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('Operasi Dasar', style: TextStyle(fontWeight: FontWeight.bold)),
                  _ChipRow(chips: const ['Grayscale', 'Biner', 'Inverse'], active: _activeOp, onTap: _run),
                  
                  const Text('Tingkat Kecerahan', style: TextStyle(fontWeight: FontWeight.bold)),
                  _SliderRow(
                    label: 'Level:', value: _brightness, min: 0, max: 100, divisions: 100,
                    displayValue: '${(_brightness - 50).round()}',
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                  _RunButton(label: 'Terapkan Brightness', onTap: () => _run('Brightness')),

                  const Text('Perbaikan Citra', style: TextStyle(fontWeight: FontWeight.bold)),
                  _ChipRow(chips: const ['Histogram Eq', 'Mean Blur'], active: _activeOp, onTap: _run),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Widget pembantu tetap sama seperti sebelumnya namun disederhanakan
class _RawImage {
  final Uint8List pixels;
  final int width;
  final int height;
  _RawImage({required this.pixels, required this.width, required this.height});
}

class _ImageCard extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  final bool highlight;
  const _ImageCard({required this.label, required this.bytes, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(border: Border.all(color: highlight ? Colors.indigo : Colors.grey)),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> chips;
  final String active;
  final Function(String) onTap;
  const _ChipRow({required this.chips, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: chips.map((c) => ActionChip(label: Text(c), onPressed: () => onTap(c))).toList(),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.displayValue, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label),
        Expanded(child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged)),
        Text(displayValue),
      ]);
}

class _RunButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RunButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(onPressed: onTap, child: Text(label));
}