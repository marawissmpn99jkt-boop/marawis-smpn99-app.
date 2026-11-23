import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:material_ui/material_ui.dart';

final hauntedNightStart = DateTime(2026, 11, 23);
final hauntedNightEndExclusive = DateTime(2026, 12, 1);

bool isHauntedNightActive(DateTime now) =>
    !now.isBefore(hauntedNightStart) && now.isBefore(hauntedNightEndExclusive);

ThemeData buildMarawisTheme(bool hauntedNight) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF167D68)),
  scaffoldBackgroundColor: const Color(0xFFF7F9F7),
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(color: Color(0xFF172A25), fontSize: 18, fontWeight: FontWeight.w800),
    iconTheme: IconThemeData(color: Color(0xFF263B34)),
  ),
);

/// A transparent app shell: event graphics are scoped to the event landing page.
class HauntedNightExperience extends StatelessWidget {
  const HauntedNightExperience({super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) => child;
}

class HauntedNightLanding extends StatefulWidget {
  const HauntedNightLanding({super.key, required this.onLogin});
  final VoidCallback onLogin;

  @override
  State<HauntedNightLanding> createState() => _HauntedNightLandingState();
}

class _HauntedNightLandingState extends State<HauntedNightLanding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this, duration: const Duration(seconds: 18),
  )..repeat();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _motion.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _explore() => _scroll.animateTo(
    _scroll.position.maxScrollExtent,
    duration: const Duration(milliseconds: 850),
    curve: Curves.easeInOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      backgroundColor: const Color(0xFF080A13),
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(
          animation: _motion,
          builder: (_, __) => CustomPaint(painter: _NightBackdropPainter(_motion.value)),
        )),
        SafeArea(child: Column(children: [
          _NightHeader(onLogin: widget.onLogin),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 16, compact ? 16 : 28, 52),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _hero(compact),
                const SizedBox(height: 26),
                const _EventTicker(),
                const SizedBox(height: 52),
                const _SectionHeading(
                  eyebrow: 'ENTER THE EXPERIENCE',
                  title: 'Bukan sekadar tampilan baru.',
                  subtitle: 'Masuk ke dunia event spesial Marawis dengan kejutan, permainan, dan atmosfer yang berbeda.',
                ),
                const SizedBox(height: 22),
                _cards(),
                const SizedBox(height: 48),
                _cta(),
                const SizedBox(height: 34),
                const Center(child: Text(
                  'MARAWIS SMPN 99 JAKARTA  •  2026/2027',
                  style: TextStyle(color: Color(0xFF77738A), fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w800),
                )),
              ]),
            ),
          ))),
        ])),
      ]),
    );
  }

  Widget _hero(bool compact) => AnimatedBuilder(
    animation: _motion,
    builder: (_, __) {
      final drift = math.sin(_motion.value * math.pi * 2) * 8;
      return Container(
        constraints: const BoxConstraints(minHeight: 430),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF47315D)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF211633), Color(0xFF121323), Color(0xFF10101B)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x552D164B), blurRadius: 50, offset: Offset(0, 22))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(children: [
            Positioned(right: compact ? -80 : 80, top: -120 + drift, child: const _GlowOrb(size: 380)),
            Positioned(left: -110, bottom: -190, child: Container(
              width: 330, height: 330,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6B35A0).withValues(alpha: 0.13)),
            )),
            Padding(
              padding: EdgeInsets.all(compact ? 22 : 42),
              child: compact
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _heroCopy(compact),
                      const SizedBox(height: 8),
                      Center(child: Transform.translate(offset: Offset(0, drift), child: _mascot(235))),
                    ])
                  : Row(children: [
                      Expanded(flex: 6, child: _heroCopy(compact)),
                      const SizedBox(width: 12),
                      Expanded(flex: 5, child: Transform.translate(offset: Offset(0, drift), child: _mascot(370))),
                    ]),
            ),
            const Positioned(right: 20, top: 20, child: _LivePill()),
          ]),
        ),
      );
    },
  );

  Widget _heroCopy(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x26FF9B45), borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0x66FF9B45)),
        ),
        child: const Text('✦  LIMITED EVENT  •  23—30 NOV 2026',
          style: TextStyle(color: Color(0xFFFFBD79), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      ),
      const SizedBox(height: 25),
      Text('THE NIGHT\nHAS A', style: TextStyle(
        color: Colors.white, fontSize: compact ? 43 : 62, height: .98,
        letterSpacing: -2.4, fontWeight: FontWeight.w900,
      )),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFFD08A), Color(0xFFFF853B), Color(0xFFB77BFF)],
        ).createShader(bounds),
        child: Text('RHYTHM.', style: TextStyle(
          color: Colors.white, fontSize: compact ? 49 : 72, height: 1.05,
          letterSpacing: -2.5, fontWeight: FontWeight.w900,
        )),
      ),
      const SizedBox(height: 16),
      const Text('MARAWIS HAUNTED NIGHT 2026',
        style: TextStyle(color: Color(0xFFE9DDF8), fontSize: 12, letterSpacing: 2.1, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Text(
        'Satu event spesial. Nuansa baru. Kejutan di setiap sudut. Siap menjelajahi malam bersama Marawis?',
        style: TextStyle(color: Color(0xFFB7B0C7), height: 1.65, fontSize: 13),
      ),
      const SizedBox(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(
          onPressed: _explore,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF963F), foregroundColor: const Color(0xFF1B1023),
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          icon: const Icon(Icons.explore_rounded, size: 18), label: const Text('Jelajahi event'),
        ),
        OutlinedButton.icon(
          onPressed: widget.onLogin,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF716080)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          icon: const Icon(Icons.login_rounded, size: 17), label: const Text('Masuk akun'),
        ),
      ]),
    ],
  );

  Widget _mascot(double height) => SizedBox(
    height: height,
    child: Hero(tag: 'marawis-haunted-mascot', child: Image.asset(
      'assets/images/marwi.webp', fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.nightlight_round, size: 150, color: Color(0xFFFFB15C)),
    )),
  );

  Widget _cards() => LayoutBuilder(builder: (context, constraints) {
    final cols = constraints.maxWidth >= 760 ? 3 : 1;
    final data = [
      _ExperienceData('01', Icons.auto_awesome_rounded, 'A different world',
        'Nikmati atmosfer visual spesial yang hadir selama event berlangsung.',
        const Color(0xFFFFA34F), () => _showInfo('A different world',
          'Nuansa Haunted Night hadir sebagai pengalaman event sementara. Fitur organisasi tetap tersedia seperti biasa.')),
      _ExperienceData('02', Icons.toys_rounded, 'Mystery Pumpkin',
        'Pilih labu misterius dan temukan kejutan tersembunyi di dalamnya.',
        const Color(0xFFB78AFF), _openPumpkin),
      _ExperienceData('03', Icons.groups_rounded, 'One Marawis family',
        'Masuk ke ruang digital untuk terhubung dengan seluruh aktivitas Marawis.',
        const Color(0xFF68D9C0), widget.onLogin),
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, crossAxisSpacing: 15, mainAxisSpacing: 15, mainAxisExtent: 205,
      ),
      itemBuilder: (_, i) => _ExperienceCard(data: data[i]),
    );
  });

  Widget _cta() => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [Color(0xFF3A2051), Color(0xFF1D1A31), Color(0xFF192A35)]),
      border: Border.all(color: const Color(0xFF58406C)),
    ),
    child: LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      const copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR NEXT MOVE?', style: TextStyle(color: Color(0xFFFFB56E), letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900)),
        SizedBox(height: 9),
        Text('The night is yours to explore.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('Jangan lewatkan pengalaman spesial Marawis Haunted Night 2026.',
          style: TextStyle(color: Color(0xFFC1B9CF), fontSize: 12, height: 1.5)),
      ]);
      final button = FilledButton.icon(
        onPressed: widget.onLogin,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF963F), foregroundColor: const Color(0xFF211329)),
        icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Masuk ke Marawis'),
      );
      return compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 18), button])
          : Row(children: [const Expanded(child: copy), const SizedBox(width: 18), button]);
    }),
  );

  void _showInfo(String title, String detail) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF211B30),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(detail, style: const TextStyle(color: Color(0xFFD1C9DC), height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    ),
  );

  void _openPumpkin() => showDialog<void>(
    context: context, builder: (_) => const _MysteryPumpkinDialog(),
  );
}

class _NightHeader extends StatelessWidget {
  const _NightHeader({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1180),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Row(children: [
        Container(
          width: 39, height: 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFB15C), Color(0xFF9B65D5)]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF17101F), size: 22),
        ),
        const SizedBox(width: 11),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MARAWIS SMPN 99', style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
          SizedBox(height: 2),
          Text('DIGITAL EXPERIENCE', style: TextStyle(color: Color(0xFF8F879F), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        ])),
        TextButton.icon(
          onPressed: onLogin, style: TextButton.styleFrom(foregroundColor: const Color(0xFFE9E0F3)),
          icon: const Icon(Icons.account_circle_outlined, size: 18), label: const Text('Masuk'),
        ),
      ]),
    ),
  ));
}

class _LivePill extends StatelessWidget {
  const _LivePill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xCC151322), borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xFF6D4D79)),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      _PulsingDot(), SizedBox(width: 7),
      Text('EVENT LIVE', style: TextStyle(color: Color(0xFFFFC17C), fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .35, end: 1).animate(_controller),
    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFFA04C), shape: BoxShape.circle)),
  );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
      const Color(0xFF9C5BD4).withValues(alpha: .25),
      const Color(0xFFFF934A).withValues(alpha: .08),
      Colors.transparent,
    ])),
  );
}

class _EventTicker extends StatelessWidget {
  const _EventTicker();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17),
    decoration: BoxDecoration(
      color: const Color(0xFF171523), borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFF30263E)),
    ),
    child: const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _TickerItem(Icons.auto_awesome, 'SPECIAL ATMOSPHERE'),
      _TickerItem(Icons.sports_esports, 'INTERACTIVE FUN'),
      _TickerItem(Icons.music_note, 'ONE MARAWIS FAMILY'),
    ]),
  );
}
class _TickerItem extends StatelessWidget {
  const _TickerItem(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Flexible(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFFFFB56E), size: 19),
      const SizedBox(height: 7),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(
        color: Color(0xFFBDB5CB), fontSize: 8, letterSpacing: .7, fontWeight: FontWeight.w800,
      )),
    ]),
  ));
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title, required this.subtitle});
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(eyebrow, style: const TextStyle(color: Color(0xFFFFA65A), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.7)),
    const SizedBox(height: 8),
    Text(subtitle, style: const TextStyle(color: Color(0xFFA9A2B8), fontSize: 13, height: 1.6)),
  ]);
}

class _ExperienceData {
  const _ExperienceData(this.number, this.icon, this.title, this.detail, this.accent, this.onTap);
  final String number, title, detail;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}
class _ExperienceCard extends StatefulWidget {
  const _ExperienceCard({required this.data});
  final _ExperienceData data;
  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}
class _ExperienceCardState extends State<_ExperienceCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF262036) : const Color(0xFF191725),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hovered ? d.accent.withValues(alpha: .8) : const Color(0xFF342B42)),
          boxShadow: _hovered ? [BoxShadow(color: d.accent.withValues(alpha: .12), blurRadius: 24)] : const [],
        ),
        child: Material(color: Colors.transparent, child: InkWell(
          onTap: d.onTap, borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 43, height: 43, decoration: BoxDecoration(
                  color: d.accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(13),
                ), child: Icon(d.icon, color: d.accent, size: 22)),
                const Spacer(),
                Text(d.number, style: const TextStyle(color: Color(0xFF777086), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ]),
              const Spacer(),
              Text(d.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(d.detail, style: const TextStyle(color: Color(0xFFAFA7BE), fontSize: 11, height: 1.55)),
              const SizedBox(height: 12),
              Row(children: [
                Text('EXPLORE', style: TextStyle(color: d.accent, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                const SizedBox(width: 7), Icon(Icons.arrow_forward_rounded, color: d.accent, size: 14),
              ]),
            ],
          )),
        )),
      ),
    );
  }
}

class _MysteryPumpkinDialog extends StatefulWidget {
  const _MysteryPumpkinDialog();
  @override
  State<_MysteryPumpkinDialog> createState() => _MysteryPumpkinDialogState();
}
class _MysteryPumpkinDialogState extends State<_MysteryPumpkinDialog> {
  late final int _prize = DateTime.now().microsecondsSinceEpoch % 3;
  int? _selected;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF211B30),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(padding: const EdgeInsets.all(23), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        const Text('🎃', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 9),
        const Text('MYSTERY PUMPKIN', style: TextStyle(
          color: Color(0xFFFFB66E), fontWeight: FontWeight.w900, letterSpacing: 1.7, fontSize: 15,
        )),
        const SizedBox(height: 9),
        Text(_revealed ? 'Kamu berhasil menemukan kejutan rahasia!' : 'Satu labu menyimpan kejutan. Pilih satu dan lihat apa yang kamu temukan.',
          textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD0C8DA), height: 1.5, fontSize: 12)),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(3, (i) {
          final selected = _selected == i;
          return InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: _revealed ? null : () => setState(() { _selected = i; _revealed = i == _prize; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220), width: 68, height: 78,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF53356D) : const Color(0xFF30273D),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? const Color(0xFFFFB66E) : const Color(0xFF554765), width: selected ? 1.7 : 1),
              ),
              child: Center(child: Text(_revealed && selected ? '✨' : '🎃', style: const TextStyle(fontSize: 30))),
            ),
          );
        })),
        if (_selected != null && !_revealed) ...[
          const SizedBox(height: 13),
          const Text('Belum ketemu. Coba labu yang lain!', style: TextStyle(color: Color(0xFFFFBD83), fontSize: 11)),
        ],
        if (_revealed) ...[
          const SizedBox(height: 13),
          const Text('UNLOCKED: PUMPKIN EXPLORER', style: TextStyle(color: Color(0xFF8DE1C6), fontWeight: FontWeight.w900, letterSpacing: .8, fontSize: 10)),
        ],
        const SizedBox(height: 20),
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: () { if (_revealed) { Navigator.pop(context); } else { setState(() => _selected = null); } },
          child: Text(_revealed ? 'Selesai' : 'Ulangi'),
        )),
      ],
    )),
  );
}

class HauntedNightDashboardCard extends StatelessWidget {
  const HauntedNightDashboardCard({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (!isHauntedNightActive(DateTime.now())) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Material(
      color: const Color(0xFF211832), borderRadius: BorderRadius.circular(19),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFF60466F)),
            gradient: const LinearGradient(colors: [Color(0xFF2A1B3A), Color(0xFF181B2B)]),
          ),
          child: const Row(children: [
            Text('🎃', style: TextStyle(fontSize: 30)), SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MARAWIS HAUNTED NIGHT 2026', style: TextStyle(
                color: Color(0xFFFFBD79), fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w900,
              )),
              SizedBox(height: 5),
              Text('Event spesial sedang berlangsung — jelajahi sekarang.',
                style: TextStyle(color: Colors.white, fontSize: 11, height: 1.4)),
            ])),
            Icon(Icons.arrow_forward_rounded, color: Color(0xFFFFB66E)),
          ]),
        ),
      ),
    ));
  }
}

class _NightBackdropPainter extends CustomPainter {
  _NightBackdropPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFB89BDB).withValues(alpha: .055)..strokeWidth = .7;
    for (double x = 0; x < size.width; x += 46) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid); }
    for (double y = 0; y < size.height; y += 46) { canvas.drawLine(Offset(0, y), Offset(size.width, y), grid); }
    final particle = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 42; i++) {
      final x = (i * 83.0) % size.width;
      final baseY = (i * 137.0) % size.height;
      final y = (baseY - progress * 90 * (1 + (i % 3) * .25)) % size.height;
      final pulse = (.35 + .45 * math.sin(progress * math.pi * 2 + i)).abs() * .55;
      particle.color = (i % 4 == 0 ? const Color(0xFFFFB36C) : const Color(0xFF9E83D4)).withValues(alpha: pulse);
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 2 : 1.1, particle);
    }
  }

  @override
  bool shouldRepaint(covariant _NightBackdropPainter old) => old.progress != progress;
}
