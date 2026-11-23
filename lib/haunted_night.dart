import 'package:material_ui/material_ui.dart';

const hauntedNightStart = DateTime(2026, 11, 23);
const hauntedNightEndExclusive = DateTime(2026, 12, 1);

bool isHauntedNightActive(DateTime now) =>
    !now.isBefore(hauntedNightStart) && now.isBefore(hauntedNightEndExclusive);

ThemeData buildMarawisTheme(bool hauntedNight) {
  const normalSeed = Color(0xFF167D68);
  final seed = hauntedNight ? const Color(0xFFFF8A32) : normalSeed;
  final background = hauntedNight ? const Color(0xFF100D1D) : const Color(0xFFF7F9F7);
  final surface = hauntedNight ? const Color(0xFF1C1730) : Colors.white;
  final border = hauntedNight ? const Color(0xFF3A2D50) : const Color(0xFFE4EBE7);
  final foreground = hauntedNight ? const Color(0xFFF7F0FF) : const Color(0xFF172A25);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: hauntedNight ? Brightness.dark : Brightness.light,
      surface: hauntedNight ? surface : background,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: hauntedNight ? const Color(0xFF171226) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(
        color: hauntedNight ? const Color(0xFFFFB45C) : const Color(0xFF263B34),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: seed, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: hauntedNight ? const Color(0xFF211329) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    dividerColor: hauntedNight ? const Color(0xFF392B4D) : const Color(0xFFE8EEEA),
  );
}

class HauntedNightExperience extends StatefulWidget {
  const HauntedNightExperience({super.key, required this.child});

  final Widget child;

  @override
  State<HauntedNightExperience> createState() => _HauntedNightExperienceState();
}

class _HauntedNightExperienceState extends State<HauntedNightExperience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isHauntedNightActive(DateTime.now())) return widget.child;

    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _floatController,
            builder: (context, _) {
              final offset = (_floatController.value - 0.5) * 10;
              return Stack(
                children: [
                  Positioned(
                    top: topInset + 66 + offset,
                    left: 13,
                    child: Opacity(
                      opacity: 0.32,
                      child: const Text('🦇', style: TextStyle(fontSize: 25)),
                    ),
                  ),
                  Positioned(
                    top: topInset + 88 - offset,
                    right: 16,
                    child: Opacity(
                      opacity: 0.34,
                      child: const Text('✨', style: TextStyle(fontSize: 19)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF7C35B5),
                            Color(0xFFFF8A32),
                            Color(0xFF7C35B5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 14,
          bottom: 92,
          child: Tooltip(
            message: 'Mystery Pumpkin',
            child: Material(
              color: const Color(0xFF2A1B40),
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xFFFFA34D), width: 1.5),
              ),
              elevation: 8,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _MysteryPumpkinDialog(),
                ),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Text('🎃', style: TextStyle(fontSize: 25)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MysteryPumpkinDialog extends StatefulWidget {
  const _MysteryPumpkinDialog();

  @override
  State<_MysteryPumpkinDialog> createState() => _MysteryPumpkinDialogState();
}

class _MysteryPumpkinDialogState extends State<_MysteryPumpkinDialog> {
  late final int _surpriseIndex =
      DateTime.now().millisecondsSinceEpoch % 3;
  bool _found = false;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF211832),
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Mystery Pumpkin',
        style: TextStyle(color: Color(0xFFFFB45C), fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _found
                ? 'Kamu menemukan kejutan rahasia Haunted Night!'
                : 'Satu labu menyimpan kejutan. Pilih satu untuk membukanya!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF2EAFB), height: 1.45),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final selected = _selected == index;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _found
                    ? null
                    : () => setState(() {
                          _selected = index;
                          _found = index == _surpriseIndex;
                        }),
                child: Container(
                  width: 66,
                  height: 72,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF593477)
                        : const Color(0xFF302342),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB45C)
                          : const Color(0xFF59456D),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _found && selected ? '👻' : '🎃',
                      style: const TextStyle(fontSize: 29),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_selected != null && !_found) ...[
            const SizedBox(height: 12),
            const Text(
              'Belum ketemu! Coba labu yang lain.',
              style: TextStyle(color: Color(0xFFFFC28A), fontSize: 12),
            ),
          ],
          if (_found) ...[
            const SizedBox(height: 12),
            const Text(
              '🎉 Pumpkin Explorer',
              style: TextStyle(
                color: Color(0xFFFFC46B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_found)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keren!'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: const Text('Ulangi'),
          ),
      ],
    );
  }
}
