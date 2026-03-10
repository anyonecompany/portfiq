import 'package:flutter/material.dart';

/// Portfiq Design System — Dark mode only
class PortfiqTheme {
  PortfiqTheme._();

  // ─── Key Colors ─────────────────────────────────────────────
  static const Color accent = Color(0xFF6366F1); // Electric Indigo
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentDark = Color(0xFF4F46E5);

  // ─── Backgrounds ────────────────────────────────────────────
  static const Color primaryBg = Color(0xFF0D0E14);
  static const Color secondaryBg = Color(0xFF16181F); // cards
  static const Color tertiaryBg = Color(0xFF1E2028);
  static const Color surface = Color(0xFF1E2028); // interactive

  // ─── Surface / Glass ──────────────────────────────────────────
  static const Color surfaceCard = Color(0xFF16181F); // @ 70% opacity for glass

  // ─── Impact ─────────────────────────────────────────────────
  static const Color impactHigh = Color(0xFFEF4444);
  static const Color impactHighDark = Color(0xFFDC2626);
  static const Color impactMedium = Color(0xFFF59E0B);
  static const Color impactMediumDark = Color(0xFFD97706);
  static const Color impactLow = Color(0xFF6B7280);

  // ─── Semantic ───────────────────────────────────────────────
  static const Color positive = Color(0xFF10B981);
  static const Color negative = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);

  // ─── Text ───────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  // ─── Divider / Border ─────────────────────────────────────────
  static const Color divider = Color(0xFF2D2F3A);

  // ─── Radius ─────────────────────────────────────────────────
  static const double radiusCard = 16.0;
  static const double radiusButton = 10.0;
  static const double radiusChip = 8.0;
  static const double radiusPill = 24.0;

  // ─── Animation ──────────────────────────────────────────────
  static const Duration screenTransition = Duration(milliseconds: 250);
  static const Duration microInteraction = Duration(milliseconds: 150);

  // ─── Splash ─────────────────────────────────────────────────
  static const Color splashCenter = Color(0xFF1A1B2E);

  // ─── ThemeData ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: textPrimary,
      secondary: accentLight,
      onSecondary: textPrimary,
      surface: secondaryBg,
      onSurface: textPrimary,
      error: negative,
      onError: textPrimary,
      outline: divider,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: primaryBg,
      colorScheme: colorScheme,

      // ─── Text Theme ───────────────────────────────────────
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.2,
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        // Heading
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        // Title
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        // Body — min 14px
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        // Label / Caption
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.3,
          fontFamily: 'Inter',
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          height: 1.2,
          letterSpacing: 1.2,
          fontFamily: 'Inter',
        ),
      ),

      // ─── AppBar ───────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // ─── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: secondaryBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      // ─── ElevatedButton ───────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          disabledBackgroundColor: accent.withAlpha(77),
          disabledForegroundColor: textPrimary.withAlpha(102),
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── TextButton ───────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ─── OutlinedButton ───────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Chip ─────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withAlpha(51),
        disabledColor: surface.withAlpha(128),
        labelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: accent,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),

      // ─── BottomSheet ──────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: secondaryBg,
        modalBackgroundColor: secondaryBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: divider,
      ),

      // ─── BottomNavigationBar ──────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primaryBg,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ─── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // ─── Input Decoration ─────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tertiaryBg,
        hintStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: accent, width: 1),
        ),
      ),

      // ─── Icon ─────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),

      // ─── Splash / Ink ─────────────────────────────────────
      splashColor: accent.withAlpha(31),
      highlightColor: accent.withAlpha(20),
    );
  }
}

/// MASTER.md Typography Scale
class PortfiqTypography {
  PortfiqTypography._();

  static const display = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: PortfiqTheme.textPrimary,
  );

  static const title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
    color: PortfiqTheme.textPrimary,
  );

  static const subtitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: PortfiqTheme.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: PortfiqTheme.textPrimary,
  );

  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: PortfiqTheme.textSecondary,
  );

  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.2,
    color: PortfiqTheme.textSecondary,
  );
}

/// MASTER.md Gradient Definitions
class PortfiqGradients {
  PortfiqGradients._();

  /// Indigo accent gradient
  static const indigo = LinearGradient(
    colors: [PortfiqTheme.accent, PortfiqTheme.accentLight],
  );

  /// Morning briefing border gradient (Indigo)
  static const morning = LinearGradient(
    colors: [PortfiqTheme.accent, PortfiqTheme.accentLight],
  );

  /// Night briefing border gradient (Amber)
  static const night = LinearGradient(
    colors: [PortfiqTheme.warning, PortfiqTheme.warningLight],
  );

  /// High impact accent bar gradient (top to bottom)
  static const highImpact = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PortfiqTheme.impactHigh, PortfiqTheme.impactHighDark],
  );

  /// Medium impact accent bar gradient (top to bottom)
  static const mediumImpact = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PortfiqTheme.impactMedium, PortfiqTheme.impactMediumDark],
  );

  /// Splash screen radial gradient
  static const splash = RadialGradient(
    center: Alignment.center,
    radius: 1.2,
    colors: [PortfiqTheme.splashCenter, PortfiqTheme.primaryBg],
  );
}

/// MASTER.md Shadow Definitions
class PortfiqShadows {
  PortfiqShadows._();

  /// Subtle lift shadow
  static const sm = BoxShadow(
    color: Color(0x4D000000), // rgba(0,0,0,0.3)
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  /// Standard card shadow
  static const md = BoxShadow(
    color: Color(0x66000000), // rgba(0,0,0,0.4)
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  /// Modal / dropdown shadow
  static const lg = BoxShadow(
    color: Color(0x80000000), // rgba(0,0,0,0.5)
    blurRadius: 16,
    offset: Offset(0, 8),
  );

  /// Indigo glow for selected/active elements
  static const glow = BoxShadow(
    color: Color(0x4D6366F1), // rgba(99,102,241,0.3)
    blurRadius: 12,
    spreadRadius: 0,
  );

  /// Glass card inner shadow
  static const glassCard = BoxShadow(
    color: Color(0x33000000), // rgba(0,0,0,0.2)
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  /// Selected tab glow
  static const tabGlow = BoxShadow(
    color: Color(0x666366F1), // rgba(99,102,241,0.4)
    blurRadius: 12,
    spreadRadius: 2,
  );
}

/// MASTER.md Spacing Rhythm (4px unit system)
class PortfiqSpacing {
  PortfiqSpacing._();

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;
}

/// MASTER.md Animation Tokens
class PortfiqAnimations {
  PortfiqAnimations._();

  /// Press feedback, toggle, chip tap
  static const Duration fast = Duration(milliseconds: 100);

  /// Tab switch, chip appear, state change
  static const Duration normal = Duration(milliseconds: 200);

  /// Screen transition, modal open/close
  static const Duration slow = Duration(milliseconds: 300);

  /// Shimmer cycle duration
  static const Duration shimmer = Duration(milliseconds: 1500);

  /// Splash fade-in
  static const Duration splashFadeIn = Duration(milliseconds: 600);

  /// Card release duration
  static const Duration cardRelease = Duration(milliseconds: 150);

  /// Standard easing curve
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Subtle bounce for added items
  static const Curve bounceCurve = Curves.elasticOut;
}
