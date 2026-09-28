import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'browser_page.dart';
import 'common.dart';

class CategoryPage extends StatefulWidget {
  /// null = global search over all indexed files
  final Cat? cat;
  const CategoryPage({super.key, required this.cat});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  String q = '';
  late bool searching = widget.cat == null;
  SortMode sort = SortMode.date;

  Future<void> _open(FileInfo f) async {
    final r = await OpenFilex.open(f.path);
    if (r.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No app found to open this file')));
    }
  }

  void _showInFolder(FileInfo f) {
    final parent = f.path.substring(0, f.path.lastIndexOf('/'));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserPage(path: parent, root: volumeRootOf(f.path)),
      ),
    );
  }

  Future<void> _delete(FileInfo f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(f.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      File(f.path).deleteSync();
      Scanner.remove(f.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
  }

  void _menu(FileInfo f) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${fmtSize(f.size)} • ${fmtDate(f.modified)}'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open'),
              onTap: () { Navigator.pop(c); _open(f); },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Show in folder'),
              onTap: () { Navigator.pop(c); _showInFolder(f); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Delete'),
              onTap: () { Navigator.pop(c); _delete(f); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<FileInfo> list) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final f = list[i];
        return GestureDetector(
          onTap: () => _open(f),
          onLongPress: () => _menu(f),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(f.path),
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Container(
                color: catInfo[Cat.images]!.color.withAlpha(40),
                child: const Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _list(List<FileInfo> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) {
        final f = list[i];
        return ListTile(
          leading: FileThumb(f.path),
          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${fmtSize(f.size)} • ${fmtDate(f.modified)}'),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _menu(f),
          ),
          onTap: () => _open(f),
          onLongPress: () => _menu(f),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final cs = Theme.of(context).colorScheme;
    final title = cat == null ? 'Search' : catInfo[cat]!.label;

    return Scaffold(
      appBar: AppBar(
        title: searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: cat == null ? 'Search files…' : 'Search in $title…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
              )
            : Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (cat != null)
            IconButton(
              icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () => setState(() {
                searching = !searching;
                if (!searching) q = '';
              }),
            ),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortMode.date, child: Text('Newest first')),
              PopupMenuItem(value: SortMode.size, child: Text('Largest first')),
              PopupMenuItem(value: SortMode.name, child: Text('Name')),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<List<FileInfo>?>(
        valueListenable: Scanner.files,
        builder: (context, all, _) {
          if (all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cat == null && q.isEmpty) {
            return Center(
              child: Text('Search photos, videos, audio, documents, archives and APKs',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }
          final list = all
              .where((f) =>
                  (cat == null || f.cat == cat) &&
                  (q.isEmpty || f.name.toLowerCase().contains(q)))
              .toList();
          switch (sort) {
            case SortMode.date:
              list.sort((a, b) => b.modified.compareTo(a.modified));
              break;
            case SortMode.size:
              list.sort((a, b) => b.size.compareTo(a.size));
              break;
            case SortMode.name:
              list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              break;
          }
          if (list.isEmpty) {
            return Center(
              child: Text('No files found', style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }
          return cat == Cat.images ? _grid(list) : _list(list);
        },
      ),
    );
  }
}
