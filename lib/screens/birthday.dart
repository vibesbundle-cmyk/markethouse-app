import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'account_type.dart'; // ← goes to account type now, not verify directly

class Birthday extends StatefulWidget {
  final String name, email, password;
  const Birthday({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });
  @override
  State<Birthday> createState() => _BirthdayState();
}

class _BirthdayState extends State<Birthday> {
  String _month = 'November', _day = '26', _year = '2000', _gender = 'Male';
  final _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  void _next() {
    final monthIdx = (_months.indexOf(_month) + 1).toString().padLeft(2, '0');
    final dayFormatted = _day.padLeft(2, '0');
    final isoDate = '$_year-$monthIdx-$dayFormatted';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountType(     // ← now goes to AccountType
          name: widget.name,
          email: widget.email,
          password: widget.password,
          dob: isoDate,
          gender: _gender,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  Steps(total: 4, current: 1),   // ← now 4 steps total
                  MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 28),
              Slide(
                delay: 100,
                child: Text(
                  "Your date of birth — even for a business account, this won't be shown publicly.",
                  style: txt.bodyLarge?.copyWith(height: 1.55),
                ),
              ),
              const SizedBox(height: 28),
              Slide(
                delay: 200,
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Drop(
                      value: _month,
                      items: _months,
                      onChange: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Drop(
                      value: _day,
                      items: List.generate(31, (i) => '${i + 1}'),
                      onChange: (v) => setState(() => _day = v ?? _day),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Drop(
                      value: _year,
                      items: List.generate(
                          100, (i) => '${DateTime.now().year - i}'),
                      onChange: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              Slide(
                delay: 300,
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  GenderPill(
                    label: 'Male',
                    selected: _gender == 'Male',
                    onTap: () => setState(() => _gender = 'Male'),
                  ),
                  GenderPill(
                    label: 'Female',
                    selected: _gender == 'Female',
                    onTap: () => setState(() => _gender = 'Female'),
                  ),
                  GenderPill(
                    label: 'Custom',
                    selected: _gender == 'Custom',
                    onTap: () => setState(() => _gender = 'Custom'),
                  ),
                ]),
              ),
              const Spacer(),
              Slide(delay: 400, child: Btn(label: 'Next', onTap: _next)),
              const SizedBox(height: 16),
              Slide(
                delay: 500,
                child: Center(child: BackRow(onTap: () => Navigator.pop(context))),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
