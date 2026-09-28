import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const FileZipApp());

class FileZipApp extends StatelessWidget {
  const FileZipApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FileZip',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const HomePage(),
      );
}

// ---- background jobs (run in a separate isolate so UI doesn't freeze) ----
Future<void> _extractJob(List<String> a) async {
  await extractFileToDisk(a[0], a[1]);
}

Future<void> _zipJob(List<String> a) async {
  final enc = ZipFileEncoder();
  enc.create(a[0]);
  for (final p in a.skip(1)) {
    if (FileSystemEntity.isDirectorySync(p)) {
      await enc.addDirectory(Directory(p));
    } else {
      await enc.addFile(File(p));
    }
  }
  enc.close();
}

const _root = '/storage/emulated/0';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Directory dir = Directory(_root);
  List<FileSystemEntity> items = [];
  final Set<String> selected = {};
  bool granted = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    var s = await Permission.manageExternalStorage.request();
    if (!s.isGranted) s = await Permission.storage.request();
    setState(() => granted = s.isGranted);
    if (granted) _load();
  }

  String _name(FileSystemEntity e) => e.path.split('/').last;

  bool _isArchive(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.zip') ||
        l.endsWith('.tar') ||
        l.endsWith('.tar.gz') ||
        l.endsWith('.tgz') ||
        l.endsWith('.tar.bz2');
  }

  String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  void _load() {
    try {
      final l = dir.listSync()
        ..sort((a, b) {
          final ad = a is Directory, bd = b is Directory;
          if (ad != bd) return ad ? -1 : 1;
          return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
        });
      setState(() => items = l);
    } catch (e) {
      _msg('Cannot open folder: $e');
    }
  }

  void _open(Directory d) {
    dir = d;
    selected.clear();
    _load();
  }

  void _back() {
    if (selected.isNotEmpty) {
      setState(() => selected.clear());
    } else if (dir.path != _root) {
      _open(dir.parent);
    }
  }

  Future<void> _extract(File f) async {
    final base = _name(f).replaceAll(RegExp(r'(\.tar)?\.[^.]+$'), '');
    final out = Directory('${f.parent.path}/$base');
    setState(() => busy = true);
    try {
      await out.create(recursive: true);
      await compute(_extractJob, [f.path, out.path]);
      _msg('Extracted to "$base"');
    } catch (e) {
      _msg('Extract failed: $e');
    }
    setState(() => busy = false);
    _load();
  }

  Future<void> _zipSelected() async {
    final target =
        '${dir.path}/archive_${DateTime.now().millisecondsSinceEpoch}.zip';
    final paths = selected.toList();
    setState(() {
      busy = true;
      selected.clear();
    });
    try {
      await compute(_zipJob, [target, ...paths]);
      _msg('Created ${target.split('/').last}');
    } catch (e) {
      _msg('Zip failed: $e');
    }
    setState(() => busy = false);
    _load();
  }

  Future<void> _deleteSelected() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('${selected.length} item(s) will be deleted permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    for (final p in selected) {
      try {
        if (FileSystemEntity.isDirectorySync(p)) {
          Directory(p).deleteSync(recursive: true);
        } else {
          File(p).deleteSync();
        }
      } catch (e) {
        _msg('Delete failed: $e');
      }
    }
    selected.clear();
    _load();
  }

  Future<void> _tap(FileSystemEntity e) async {
    if (selected.isNotEmpty) {
      setState(() {
        selected.contains(e.path)
            ? selected.remove(e.path)
            : selected.add(e.path);
      });
      return;
    }
    if (e is Directory) {
      _open(e);
    } else if (e is File && _isArchive(_name(e))) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Extract here?'),
          content: Text(_name(e)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Extract')),
          ],
        ),
      );
      if (ok == true) _extract(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = selected.isNotEmpty;
    return PopScope(
      canPop: dir.path == _root && !sel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(sel ? '${selected.length} selected' : dir.path
              .replaceFirst(_root, 'Internal storage')),
          leading: sel
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(selected.clear))
              : (dir.path != _root
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back), onPressed: _back)
                  : null),
          actions: sel
              ? [
                  IconButton(
                      tooltip: 'Zip',
                      icon: const Icon(Icons.folder_zip),
                      onPressed: _zipSelected),
                  IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete),
                      onPressed: _deleteSelected),
                ]
              : [
                  IconButton(
                      icon: const Icon(Icons.refresh), onPressed: _load)
                ],
        ),
        body: !granted
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Storage permission needed'),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () async {
                          await openAppSettings();
                          _init();
                        },
                        child: const Text('Grant access')),
                  ],
                ),
              )
            : Stack(
                children: [
                  ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final e = items[i];
                      final n = _name(e);
                      final isDir = e is Directory;
                      final isSel = selected.contains(e.path);
                      String sub = '';
                      if (e is File) {
                        try {
                          sub = _size(e.lengthSync());
                        } catch (_) {}
                      }
                      return ListTile(
                        selected: isSel,
                        leading: Icon(isDir
                            ? Icons.folder
                            : (_isArchive(n)
                                ? Icons.folder_zip_outlined
                                : Icons.insert_drive_file_outlined)),
                        title: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: sub.isEmpty ? null : Text(sub),
                        trailing: isSel ? const Icon(Icons.check_circle) : null,
                        onTap: () => _tap(e),
                        onLongPress: () =>
                            setState(() => selected.add(e.path)),
                      );
                    },
                  ),
                  if (busy)
                    Container(
                      color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
