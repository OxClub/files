import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'common.dart';
import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OxFilesApp());
}

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: kAccent, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0B0F14) : const Color(0xFFF4F7F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}

class OxFilesApp extends StatelessWidget {
  const OxFilesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ox Files',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const PermissionGate(),
    );
  }
}

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  bool? ok;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ok != true) _check(false);
  }

  Future<void> _check(bool ask) async {
    var m = await Permission.manageExternalStorage.status;
    var s = await Permission.storage.status;
    if (!(m.isGranted || s.isGranted) && ask) {
      m = await Permission.manageExternalStorage.request();
      if (!m.isGranted) s = await Permission.storage.request();
    }
    if (!mounted) return;
    setState(() => ok = m.isGranted || s.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    if (ok == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ok == true) return const HomePage();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OxLogo(size: 88),
                const SizedBox(height: 24),
                Text('Ox Files',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text(
                  'Ox Files needs access to your device storage so you can browse, open, zip and manage your files. Files never leave your device.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _check(true),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Allow access'),
                ),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
