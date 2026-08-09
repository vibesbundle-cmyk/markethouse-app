import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// ── Buttons ─────────────────────────────────────────────────────────────────
class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading, outlined;
  final Color? color;
  final Widget? icon;
  const Btn(
      {super.key,
      required this.label,
      this.onTap,
      this.loading = false,
      this.outlined = false,
      this.color,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? C.green;
    return SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: outlined ? Colors.transparent : bg,
            foregroundColor: outlined ? bg : Colors.white,
            side: outlined ? BorderSide(color: bg, width: 2) : BorderSide.none,
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: outlined ? 0 : 2,
            shadowColor: bg.withValues(alpha: .3),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: outlined ? bg : Colors.white)),
                ]),
        ));
  }
}

class DarkBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  const DarkBtn({super.key, required this.label, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) =>
      Btn(label: label, onTap: onTap, color: C.blk, icon: icon);
}

// ── Text Field ───────────────────────────────────────────────────────────────
class Field extends StatefulWidget {
  final String hint;
  final Widget? prefix;
  final bool pwd;
  final TextEditingController? ctrl;
  final TextInputType? kb;
  final String? Function(String?)? validator;
  final void Function(String)? onChange;
  final TextInputAction? action;
  final FocusNode? focus;
  const Field(
      {super.key,
      required this.hint,
      this.prefix,
      this.pwd = false,
      this.ctrl,
      this.kb,
      this.validator,
      this.onChange,
      this.action,
      this.focus});
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  bool _hide = true;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.ctrl,
        keyboardType: widget.kb,
        validator: widget.validator,
        onChanged: widget.onChange,
        textInputAction: widget.action,
        focusNode: widget.focus,
        obscureText: widget.pwd ? _hide : false,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: widget.prefix,
          suffixIcon: widget.pwd
              ? IconButton(
                  icon: Icon(
                      _hide
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20),
                  onPressed: () => setState(() => _hide = !_hide),
                )
              : null,
        ),
      );
}

// ── Reusables ────────────────────────────────────────────────────────────────
class OrLine extends StatelessWidget {
  const OrLine({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ]);
}

class FbBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const FbBtn({super.key, this.onTap});
  @override
  Widget build(BuildContext context) => DarkBtn(
        label: 'Continue with Facebook',
        onTap: onTap,
        icon: const Icon(Icons.facebook_rounded, color: C.fb, size: 20),
      );
}

class BackRow extends StatelessWidget {
  final VoidCallback onTap;
  const BackRow({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_back,
            size: 16, color: Theme.of(context).iconTheme.color),
        const SizedBox(width: 4),
        Text('Go back', style: Theme.of(context).textTheme.bodyMedium),
      ]));
}

class Steps extends StatelessWidget {
  final int total, current;
  const Steps({super.key, required this.total, required this.current});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final on = i <= current;
        return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: on ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
                color: on ? C.green : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(4)));
      }));
}

class MoonBtn extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const MoonBtn({super.key, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isDark ? C.surf2D : C.surfL, shape: BoxShape.circle),
        child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 20, color: isDark ? C.greenLight : C.greenDark),
      ));
}

class Terms extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool?> onChange;
  const Terms({super.key, required this.checked, required this.onChange});
  @override
  Widget build(BuildContext context) => Row(children: [
        Checkbox(value: checked, onChanged: onChange),
        const SizedBox(width: 4),
        Expanded(
            child: RichText(
                text: TextSpan(
          style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color),
          children: [
            const TextSpan(
                text: 'By continuing you have read and agree to our '),
            TextSpan(
                text: 'Terms',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: C.green,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: C.green)),
            const TextSpan(text: ' and '),
            TextSpan(
                text: 'Privacy Policy',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: C.green,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: C.green)),
          ],
        ))),
      ]);
}

class GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const GenderPill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? C.green.withValues(alpha: .12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? C.green : Theme.of(context).dividerColor,
              width: selected ? 2 : 1.2),
        ),
        child: Row(children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? C.green
                      : Theme.of(context).textTheme.bodyMedium?.color)),
          const SizedBox(width: 8),
          AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          selected ? C.green : Theme.of(context).dividerColor,
                      width: 2)),
              child: selected
                  ? Center(
                      child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: C.green)))
                  : null),
        ]),
      ));
}

class Drop extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChange;
  const Drop(
      {super.key,
      required this.value,
      required this.items,
      required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Theme.of(context).dividerColor, width: 1.2)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color),
          dropdownColor: Theme.of(context).colorScheme.surface,
          onChanged: onChange,
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color))))
              .toList(),
        )),
      );
}

// ── Slide-in entrance animation ───────────────────────────────────────────────
class Slide extends StatelessWidget {
  final Widget child;
  final int delay;
  const Slide({super.key, required this.child, this.delay = 0});
  @override
  Widget build(BuildContext context) => child
      .animate(delay: Duration(milliseconds: delay))
      .fadeIn(duration: 500.ms, curve: Curves.easeOut)
      .slideY(begin: .24, end: 0, duration: 500.ms, curve: Curves.easeOut);
}

// ── Profile grid ─────────────────────────────────────────────────────────────
class Grid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  const Grid({super.key, required this.count, this.crossAxisCount = 3});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        color: isDark ? C.surf2D : C.surfL,
        child: Center(
            child: Icon(Icons.image_outlined,
                color: C.green.withValues(alpha: .4), size: 28)),
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 100});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                    color: Theme.of(context).dividerColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: C.green.withValues(alpha: .2), blurRadius: 24)
                ]),
            child: ClipOval(
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.storefront_outlined,
                        size: size * .45,
                        color: C.green)))),
        const SizedBox(height: 12),
        RichText(
            text: TextSpan(children: [
          TextSpan(
              text: 'Market',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: C.green)),
          TextSpan(
              text: 'House',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 26, fontWeight: FontWeight.w700, color: C.green)),
        ])),
      ]);
}

// ── Country dial-code phone field (shared) ────────────────────────────────
// Used anywhere a phone number needs a WhatsApp-style country-code picker
// in front of it (business profile editing in profile.dart and settings.dart).
class Country {
  final String name, flag, dialCode;
  const Country(this.name, this.flag, this.dialCode);
}

const kCountryCodes = [
  Country('Nigeria', '🇳🇬', '+234'),
  Country('Ghana', '🇬🇭', '+233'),
  Country('Kenya', '🇰🇪', '+254'),
  Country('South Africa', '🇿🇦', '+27'),
  Country('Egypt', '🇪🇬', '+20'),
  Country('Ethiopia', '🇪🇹', '+251'),
  Country('Tanzania', '🇹🇿', '+255'),
  Country('Uganda', '🇺🇬', '+256'),
  Country('Cameroon', '🇨🇲', '+237'),
  Country('Senegal', '🇸🇳', '+221'),
  Country('Côte d\'Ivoire', '🇨🇮', '+225'),
  Country('Morocco', '🇲🇦', '+212'),
  Country('Algeria', '🇩🇿', '+213'),
  Country('Rwanda', '🇷🇼', '+250'),
  Country('Zambia', '🇿🇲', '+260'),
  Country('Zimbabwe', '🇿🇼', '+263'),
  Country('United States', '🇺🇸', '+1'),
  Country('Canada', '🇨🇦', '+1'),
  Country('United Kingdom', '🇬🇧', '+44'),
  Country('Ireland', '🇮🇪', '+353'),
  Country('Germany', '🇩🇪', '+49'),
  Country('France', '🇫🇷', '+33'),
  Country('Spain', '🇪🇸', '+34'),
  Country('Italy', '🇮🇹', '+39'),
  Country('Netherlands', '🇳🇱', '+31'),
  Country('Belgium', '🇧🇪', '+32'),
  Country('Portugal', '🇵🇹', '+351'),
  Country('Switzerland', '🇨🇭', '+41'),
  Country('Sweden', '🇸🇪', '+46'),
  Country('Norway', '🇳🇴', '+47'),
  Country('Poland', '🇵🇱', '+48'),
  Country('Turkey', '🇹🇷', '+90'),
  Country('UAE', '🇦🇪', '+971'),
  Country('Saudi Arabia', '🇸🇦', '+966'),
  Country('Qatar', '🇶🇦', '+974'),
  Country('India', '🇮🇳', '+91'),
  Country('Pakistan', '🇵🇰', '+92'),
  Country('Bangladesh', '🇧🇩', '+880'),
  Country('China', '🇨🇳', '+86'),
  Country('Japan', '🇯🇵', '+81'),
  Country('South Korea', '🇰🇷', '+82'),
  Country('Philippines', '🇵🇭', '+63'),
  Country('Indonesia', '🇮🇩', '+62'),
  Country('Malaysia', '🇲🇾', '+60'),
  Country('Singapore', '🇸🇬', '+65'),
  Country('Thailand', '🇹🇭', '+66'),
  Country('Vietnam', '🇻🇳', '+84'),
  Country('Australia', '🇦🇺', '+61'),
  Country('New Zealand', '🇳🇿', '+64'),
  Country('Brazil', '🇧🇷', '+55'),
  Country('Mexico', '🇲🇽', '+52'),
  Country('Argentina', '🇦🇷', '+54'),
  Country('Jamaica', '🇯🇲', '+1876'),
];

/// Splits a saved phone number like "+2348012345678" into a dial code
/// (matched against [kCountryCodes]) and the local number, so an edit
/// field can show the country code as a chip instead of running it
/// straight into the digits. Falls back to dialCode "+234" / the raw
/// string untouched if nothing matches or the number has no "+" prefix.
(String dialCode, String localNumber) splitPhoneForEditing(String? savedPhone) {
  final phone = savedPhone ?? '';
  if (phone.startsWith('+')) {
    final match = kCountryCodes.where((c) => phone.startsWith(c.dialCode)).toList()
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    if (match.isNotEmpty) {
      return (match.first.dialCode, phone.substring(match.first.dialCode.length).trim());
    }
    return ('+234', phone);
  }
  return ('+234', phone);
}

class CountryCodePhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool dk;
  final String dialCode;
  final ValueChanged<String> onCodeChanged;
  const CountryCodePhoneField(
      {super.key, required this.controller, required this.dk, required this.dialCode, required this.onCodeChanged});

  void _openPicker(BuildContext context) {
    final searchCtl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, ss) {
        var query = searchCtl.text.toLowerCase();
        final filtered = kCountryCodes.where((c) =>
            c.name.toLowerCase().contains(query) || c.dialCode.contains(query)).toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4, expand: false,
          builder: (_, scrollCtl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(children: [
              Text('Select country code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtl,
                onChanged: (v) => ss(() => query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true, fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(c.name, style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL)),
                      trailing: Text(c.dialCode, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dk ? C.subD : C.subL)),
                      onTap: () { onCodeChanged(c.dialCode); Navigator.pop(ctx); },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flag = kCountryCodes.firstWhere((c) => c.dialCode == dialCode,
        orElse: () => const Country('Nigeria', '🇳🇬', '+234')).flag;
    return Row(children: [
      GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: dk ? C.surf2D : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(dialCode, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: dk ? C.subD : C.subL),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '801 234 5678',
            hintStyle: TextStyle(color: dk ? C.subD : C.subL),
            filled: true, fillColor: dk ? C.surf2D : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL),
        ),
      ),
    ]);
  }
}
