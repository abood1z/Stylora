import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// فئة إدارة مظهر التطبيق (App Theme Management - Midnight Luxury Edition)
class AppTheme {
  // لوحة الألوان الفاخرة (Midnight Luxury Palette)
  static const primaryColor = Color(0xFFD4AF37); // ذهبي ملكي ناعم (Royal Gold)
  static const secondaryColor = Color(0xFF1F1B15); // بني أونيكس عميق (Onyx Brown)
  static const accentColor = Color(0xFFC5A358); // ذهبي فاتح للتألق
  static const errorColor = Color(0xFFD32F2F); // أحمر كلاسيكي للتنبيهات
  
  // ألوان المظهر الفاتح (Light Theme Palette)
  static const lightSurface = Color(0xFFFAFAFA); // خلفية عاجية فاتحة جداً
  static const textPrimaryLight = Color(0xFF1A1A1A); // نصوص أساسية داكنة
  static const textSecondaryLight = Color(0xFF757575); // نصوص ثانوية باهتة

  // ألوان المظهر الداكن (Dark Theme Palette - Midnight Premium)
  static const darkSurface = Color(0xFF0A0A0A); // أسود منتصف الليل لشاشات OLED
  static const darkCard = Color(0xFF161618); // رمادي غامق جداً للبطاقات
  static const textPrimaryDark = Color(0xFFFFFFFF); // أبيض ناصع
  static const textSecondaryDark = Color(0xFFBDBDBD); // رمادي فضي أنيق

  // استرجاع إعدادات المظهر الفاتح
  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  // استرجاع إعدادات المظهر الداكن
  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  // دالة بناء المظهر الموحد مع تخصيصات Midnight Luxury
  static ThemeData _buildTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: isDark ? darkSurface : Colors.white,
        onSurface: isDark ? textPrimaryDark : textPrimaryLight,
        error: errorColor,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark ? darkSurface : lightSurface,
      
      // تخصيص الخطوط باستخدام Google Fonts (Outfit) للتعبير عن الرقي
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: isDark ? textPrimaryDark : textPrimaryLight,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        displaySmall: GoogleFonts.outfit(
          color: isDark ? textPrimaryDark : textPrimaryLight,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: GoogleFonts.outfit(
          color: isDark ? textPrimaryDark : textPrimaryLight,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: isDark ? textPrimaryDark : textPrimaryLight, 
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: isDark ? textSecondaryDark : textSecondaryLight, 
          fontSize: 14,
        ),
      ),
      
      // تخصيص الأزرار Elevated Button بتصميم ذهبي فخم
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 2;
            return 0; 
          }),
        ),
      ),
      
      // تخصيص شكل البطاقات (Cards)
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)
          ),
        ),
        color: isDark ? darkCard : Colors.white,
      ),
      
      // تخصيص حقول الإدخال (Input Decoration)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      
      // تخصيص شريط التنقل (Navigation Bar)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : Colors.white,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 28);
          }
          return IconThemeData(color: isDark ? textSecondaryDark : textSecondaryLight, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return GoogleFonts.outfit(color: isDark ? textSecondaryDark : textSecondaryLight, fontSize: 11);
        }),
      ),
    );
  }
}
