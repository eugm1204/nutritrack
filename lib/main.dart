import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/splash/splash_gate.dart';
import 'services/error_reporter.dart';

final updateAvailableNotifier = ValueNotifier<bool>(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    authStatusNotifier.value = Supabase.instance.client.auth.currentSession != null;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      authStatusNotifier.value = data.session != null;
    });
  } else {
    authStatusNotifier.value = false;
  }

  _watchForUpdates();
  _setupErrorTelemetry();

  runApp(const ProviderScope(child: NutriTrackApp()));
}

void _setupErrorTelemetry() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    try {
      ErrorReporter(Supabase.instance.client).report(
        action: 'flutter_error',
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
      );
    } catch (_) {}
  };

  if (kIsWeb) return;
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      ErrorReporter(Supabase.instance.client).report(
        action: 'platform_error',
        message: error.toString(),
        stack: stack.toString(),
      );
    } catch (_) {}
    return true;
  };
}

void _watchForUpdates() {
  if (!kIsWeb) return;
  try {
    final sw = web.window.navigator.serviceWorker;
    sw.getRegistrations().toDart.then((regs) {
      for (final reg in regs.toDart) {
        reg.addEventListener('updatefound', (web.Event _) {
          final newWorker = reg.installing;
          if (newWorker == null) return;
          newWorker.addEventListener('statechange', (web.Event _) {
            if (newWorker.state == 'installed' && sw.controller != null) {
              updateAvailableNotifier.value = true;
            }
          }.toJS);
        }.toJS);
      }
    });
  } catch (_) {
    // O service worker pode não estar disponível — ignora.
  }
}

class NutriTrackApp extends StatelessWidget {
  const NutriTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NutriTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        return SplashGate(
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: updateAvailableNotifier,
                builder: (context, show, _) {
                  if (!show) return const SizedBox.shrink();
                  final scheme = Theme.of(context).colorScheme;
                  return Material(
                    color: scheme.inverseSurface,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Nova versão disponível!',
                                style: TextStyle(
                                  color: scheme.onInverseSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => web.window.location.reload(),
                              child: const Text('Atualizar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }
}