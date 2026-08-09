import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

TextTheme _txt(Color body, Color sub) => TextTheme(
      displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w800, color: body),
      displayMedium: GoogleFonts.inter(
          fontSize: 26, fontWeight: FontWeight.w700, color: body),
      displaySmall: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700, color: body),
      headlineLarge: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: body),
      headlineMedium: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: body),
      headlineSmall: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: body),
      titleLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: body),
      titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: body),
      titleSmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: sub),
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w400, color: body),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: body),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: sub),
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: body),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: sub),
      labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500, color: sub),
    );

InputDecorationTheme _inp(Color fill, Color border, Color hint) =>
    InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.inter(color: hint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.green, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.err, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.err, width: 2)),
      prefixIconColor: hint,
      suffixIconColor: hint,
    );

ElevatedButtonThemeData _btn() => ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: C.green,
    secondary: C.greenDark,
    surface: C.surfL,
    error: C.err,
    onPrimary: Colors.white,
    onSurface: C.textL,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: C.bgL,
  textTheme: _txt(C.textL, C.subL),
  iconTheme: const IconThemeData(color: C.iconL),
  inputDecorationTheme: _inp(C.inputL, C.borderL, C.subL),
  elevatedButtonTheme: _btn(),
  dividerTheme: const DividerThemeData(color: C.borderL, thickness: 1),
  appBarTheme: AppBarTheme(
    backgroundColor: C.bgL,
    elevation: 0,
    centerTitle: true,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    iconTheme: const IconThemeData(color: C.iconL),
    titleTextStyle: GoogleFonts.inter(
        color: C.textL, fontSize: 18, fontWeight: FontWeight.w700),
  ),
  tabBarTheme: const TabBarThemeData(
    // Changed from TabBarTheme to TabBarThemeData
    labelColor: C.green,
    unselectedLabelColor: C.subL,
    indicatorColor: C.green,
    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? C.green : C.surf2L),
    checkColor: WidgetStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: C.bgL,
    selectedItemColor: C.green,
    unselectedItemColor: C.subL,
    showSelectedLabels: true,
    showUnselectedLabels: true,
  ),
);

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: C.green,
    secondary: C.greenLight,
    surface: C.surfD,
    error: C.err,
    onPrimary: Colors.white,
    onSurface: C.textD,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: C.bgD,
  textTheme: _txt(C.textD, C.subD),
  iconTheme: const IconThemeData(color: C.iconD),
  inputDecorationTheme: _inp(C.inputD, C.borderD, C.subD),
  elevatedButtonTheme: _btn(),
  dividerTheme: const DividerThemeData(color: C.borderD, thickness: 1),
  appBarTheme: AppBarTheme(
    backgroundColor: C.bgD,
    elevation: 0,
    centerTitle: true,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    iconTheme: const IconThemeData(color: C.iconD),
    titleTextStyle: GoogleFonts.inter(
        color: C.textD, fontSize: 18, fontWeight: FontWeight.w700),
  ),
  tabBarTheme: const TabBarThemeData(
    // Changed from TabBarTheme to TabBarThemeData
    labelColor: C.green,
    unselectedLabelColor: C.subD,
    indicatorColor: C.green,
    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? C.green : C.surf2D),
    checkColor: WidgetStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: C.surfD,
    selectedItemColor: C.green,
    unselectedItemColor: C.subD,
    showSelectedLabels: true,
    showUnselectedLabels: true,
  ),
);
