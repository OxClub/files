import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'common.dart';

enum SortMode { name, date, size }

class BrowserPage extends StatefulWidget {
  final String path;
  final String root;
  const BrowserPage({super.key, required this.path, required this.root});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late Directory dir;
  List<FileSystemEntity> items = [];
  final Map<String, FileStat> stats = {};
  final Set<String> sel = {};
  bool busy = false;
  bool showHidden = false;
  SortMode sort = SortMode.name;

  @override
  void initState() {
    super.initState();
    dir = Directory(widget.path);
    _load();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void _load() {
    try {
      final l = dir
          .listSync()
          .where((e) => showHidden || !nameOf(e.path).startsWith('.'))
          .toList();
      stats.clear();
      for (final e in l) {
        try {
          stats[e.path] = e.statSync();
        } catch (_) {}
      }
      l.sort((a, b) {
        final ad = a is Directory, bd = b is Directory;
        if (ad != bd) return ad ? -1 : 1;
        final sa = stats[a.path], sb = stats[b.path];
        switch (sort) {
          case SortMode.date:
            if (sa != null && sb != null) return sb.modified.compareTo(sa.modified);
            break;
          case SortMode.size:
            if (sa != null && sb != null) return sb.size.compareTo(sa.size);
            break;
          case SortMode.name:
            break;
        }
        return nameOf(a.path).toLowerCase().compareTo(nameOf(b.path).toLowerCase());
      });
      setState(() => items = l);
    } catch (e) {
      _msg('Cannot open folder');
    }
  }

  void _go(Directory d) {
    dir = d;
    sel.clear();
    _load();
  }

  Future<void> _run(List<String> args, String okMsg) async {
    setState(() => busy = true);
    try {
      await compute(fileJob, args);
      _msg(okMsg);
    } catch (e) {
      _msg('Failed: $e');
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      sel.clear();
    });
    _load();
  }

  // ── actions ──

  Future<void> _tap(FileSystemEntity e) async {
    if (sel.isNotEmpty) {
      setState(() => sel.contains(e.path) ? sel.remove(e.path) : sel.add(e.path));
      return;
    }
    if (e is Directory) {
      _go(e);
      return;
    }
    if (canExtract(e.path)) {
      final base = nameOf(e.path).replaceAll(RegExp(r'(\.tar)?\.[^.]+$'), '');
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.unarchive_rounded),
                title: const Text('Extract to folder'),
                subtitle: Text('$base/'),
                onTap: () => Navigator.pop(c, 'folder'),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_rounded),
                title: const Text('Extract here'),
                onTap: () => Navigator.pop(c, 'here'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open with…'),
                onTap: () => Navigator.pop(c, 'open'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'open') {
        OpenFilex.open(e.path);
      } else if (choice == 'here') {
        _run(['extract', dir.path, e.path], 'Extracted');
      } else if (choice == 'folder') {
        final out = uniquePath('${dir.path}/$base');
        await Directory(out).create(recursive: true);
        _run(['extract', out, e.path], 'Extracted to ${nameOf(out)}');
      }
      return;
    }
    final r = await OpenFilex.open(e.path);
    if (r.type != ResultType.done) _msg('No app found to open this file');
  }

  void _zip() {
    final out = uniquePath('${dir.path}/OxFiles_archive.zip');
    _run(['zip', out, ...sel], 'Created ${nameOf(out)}');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('${sel.length} item(s) will be deleted permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) _run(['delete', '', ...sel], 'Deleted');
  }

  void _copyOrCut(bool move) {
    setState(() {
      FileClip.paths = sel.toList();
      FileClip.move = move;
      sel.clear();
    });
    _msg(move ? 'Ready to move – open target folder and tap Paste' : 'Ready to copy – open target folder and tap Paste');
  }

  Future<void> _paste() async {
    final mode = FileClip.move ? 'move' : 'copy';
    final paths = List<String>.from(FileClip.paths);
    await _run([mode, dir.path, ...paths], FileClip.move ? 'Moved' : 'Copied');
    if (mode == 'move') setState(() => FileClip.paths = []);
  }

  Future<String?> _askName(String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _rename() async {
    final p = sel.first;
    final n = await _askName('Rename', nameOf(p));
    if (n == null || n.isEmpty || n.contains('/')) return;
    try {
      final target = '${dir.path}/$n';
      if (FileSystemEntity.isDirectorySync(p)) {
        Directory(p).renameSync(target);
      } else {
        File(p).renameSync(target);
      }
    } catch (e) {
      _msg('Rename failed');
    }
    setState(sel.clear);
    _load();
  }

  Future<void> _newFolder() async {
    final n = await _askName('New folder', '');
    if (n == null || n.isEmpty || n.contains('/')) return;
    try {
      Directory('${dir.path}/$n').createSync();
    } catch (e) {
      _msg('Could not create folder');
    }
    _load();
  }

  // ── UI ──

  Widget _action(IconData i, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(i, size: 22),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );

  Widget? _bottomBar() {
    final cs = Theme.of(context).colorScheme;
    if (sel.isNotEmpty) {
      return Material(
        color: cs.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _action(Icons.copy_rounded, 'Copy', () => _copyOrCut(false)),
              _action(Icons.drive_file_move_rounded, 'Move', () => _copyOrCut(true)),
              _action(Icons.folder_zip_rounded, 'Zip', _zip),
              if (sel.length == 1) _action(Icons.edit_rounded, 'Rename', _rename),
              _action(Icons.delete_rounded, 'Delete', _delete),
            ],
          ),
        ),
      );
    }
    if (FileClip.paths.isNotEmpty) {
      return Material(
        color: cs.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${FileClip.paths.length} item(s) to ${FileClip.move ? 'move' : 'copy'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => FileClip.paths = []),
                  child: const Text('Cancel'),
                ),
                FilledButton(onPressed: _paste, child: const Text('Paste here')),
              ],
            ),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final atRoot = dir.path == widget.root;
    final selecting = sel.isNotEmpty;
    final rel = dir.path.replaceFirst(widget.root, '');

    return PopScope(
      canPop: !selecting && atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          setState(sel.clear);
        } else {
          _go(dir.parent);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selecting
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(sel.clear))
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => atRoot ? Navigator.pop(context) : _go(dir.parent),
                ),
          title: selecting
              ? Text('${sel.length} selected')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(atRoot ? volumeName(widget.root) : nameOf(dir.path),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(rel.isEmpty ? '/' : rel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ],
                ),
          actions: selecting
              ? [
                  IconButton(
                    tooltip: 'Select all',
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: () => setState(() => sel.addAll(items.map((e) => e.path))),
                  ),
                ]
              : [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) {
                      if (v == 'hidden') {
                        showHidden = !showHidden;
                      } else {
                        sort = SortMode.values.firstWhere((s) => s.name == v);
                      }
                      _load();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'name', child: Text('Sort by name')),
                      const PopupMenuItem(value: 'date', child: Text('Sort by date')),
                      const PopupMenuItem(value: 'size', child: Text('Sort by size')),
                      PopupMenuItem(
                          value: 'hidden',
                          child: Text(showHidden ? 'Hide hidden files' : 'Show hidden files')),
                    ],
                  ),
                ],
        ),
        floatingActionButton: selecting
            ? null
            : FloatingActionButton(
                onPressed: _newFolder,
                tooltip: 'New folder',
                child: const Icon(Icons.create_new_folder_rounded),
              ),
        bottomNavigationBar: _bottomBar(),
        body: Stack(
          children: [
            items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: cs.onSurfaceVariant.withAlpha(120)),
                        const SizedBox(height: 8),
                        Text('This folder is empty', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final e = items[i];
                      final isDir = e is Directory;
                      final st = stats[e.path];
                      final isSel = sel.contains(e.path);
                      final sub = st == null
                          ? ''
                          : isDir
                              ? fmtDate(st.modified)
                              : '${fmtSize(st.size)} • ${fmtDate(st.modified)}';
                      return ListTile(
                        selected: isSel,
                        selectedTileColor: kAccent.withAlpha(30),
                        leading: FileThumb(e.path, dir: isDir),
                        title: Text(nameOf(e.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: sub.isEmpty ? null : Text(sub),
                        trailing: isSel ? const Icon(Icons.check_circle_rounded, color: kAccent) : null,
                        onTap: () => _tap(e),
                        onLongPress: () => setState(() => sel.add(e.path)),
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
