import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'sync.dart';

class Photo extends StatefulWidget {
  const Photo({super.key});
  @override
  State<Photo> createState() => _PhotoState();
}

class _PhotoState extends State<Photo> {
  bool _picked = false;
  bool _busy = false;
  XFile? _file;

  Future<void> _pick() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      setState(() {
        _picked = true;
        _file = img;
      });
    }
  }

  Future<void> _upload() async {
    if (_file == null) {
      _next();
      return;
    }
    setState(() => _busy = true);
    final url = await Api.uploadProfilePhoto(_file!);
    if (url != null && mounted) {
      context.read<AppState>().setAvatar(url);
    }
    if (mounted) {
      setState(() => _busy = false);
      _next();
    }
  }

  void _next() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Sync()));

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _next,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: C.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
              const Spacer(),
              GestureDetector(
                onTap: _pick,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.green.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _picked ? C.green : C.green.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: C.green.withValues(alpha: 0.2),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Icon(
                        _picked
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        color: C.green,
                        size: 70,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.green,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 20),
              Text(
                'Add profile picture',
                style: txt.headlineMedium,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 10),
              Text(
                'Choose a photo that represents you.\nMake sure it\'s clear, recent, and recognizable',
                textAlign: TextAlign.center,
                style: txt.bodyMedium?.copyWith(height: 1.5),
              ).animate().fadeIn(delay: 250.ms),
              const Spacer(),
              Btn(
                label: _picked ? 'Continue' : 'Upload Photo',
                loading: _busy,
                onTap: _picked ? _upload : _pick,
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 12),
              Btn(
                label: 'Skip for now',
                outlined: true,
                onTap: _next,
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
