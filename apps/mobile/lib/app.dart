import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/router.dart';

class PortfiqApp extends StatelessWidget {
  const PortfiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Portfiq',
        debugShowCheckedModeBanner: false,
        theme: PortfiqTheme.darkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
