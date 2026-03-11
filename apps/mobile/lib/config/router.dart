import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/feed/tab_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/etf_detail/etf_detail_screen.dart';
import '../features/etf_detail/etf_report_screen.dart';
import '../features/etf_detail/company_etfs_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/tracking/screen_observer.dart';

/// Application router with screen tracking observer.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [ScreenObserver()],
  routes: [
    // Splash
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ),

    // Home — uses TabShell built by Feed developer
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const TabShell(),
    ),

    // ETF Report — slide from right (must come before /etf/:ticker)
    GoRoute(
      path: '/etf/:ticker/report',
      name: 'etf_report',
      pageBuilder: (context, state) {
        final ticker = state.pathParameters['ticker'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: EtfReportScreen(ticker: ticker),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
      },
    ),

    // ETF Detail — slide from right
    GoRoute(
      path: '/etf/:ticker',
      name: 'etf_detail',
      pageBuilder: (context, state) {
        final ticker = state.pathParameters['ticker'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: EtfDetailScreen(ticker: ticker),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
      },
    ),

    // Company ETFs — slide from right
    GoRoute(
      path: '/company/:ticker',
      name: 'company_etfs',
      pageBuilder: (context, state) {
        final ticker = state.pathParameters['ticker'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: CompanyEtfsScreen(companyTicker: ticker),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
      },
    ),

    // Settings (standalone, outside tab shell) — slide from right
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ),
  ],
);
