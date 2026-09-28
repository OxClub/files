import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'browser_page.dart';
import 'category_page.dart';
import 'common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Volume> volumes = [];
  final Map<String, Usage> usage = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final v = getVolumes();
    if (!mounted) return;
    setState(() => volumes = v);
    Scanner.scan(v.map((e) => e.path).toList());
    for (final vol in v) {
      diskUsage(vol.path).then((u) {
        if (u != null && mounted) setState(() => usage[vol.path] = u);
      });
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _refresh();
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _storageCard(Volume v) {
    final cs = Theme.of(context).colorScheme;
    final u = usage[v.path];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _push(BrowserPage(path: v.path, root: v.path)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kAccent.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    v.removable ? Icons.sd_card_rounded : Icons.smartphone_rounded,
                    color: kAccent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        u == null
                            ? 'Tap to browse'
                            : '${fmtSize(u.used)} used of ${fmtSize(u.total)}',
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                      if (u != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: u.frac,
                            minHeight: 6,
                            backgroundColor: cs.onSurface.withAlpha(25),
                            color: u.frac > 0.9 ? Colors.redAccent : kAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _catTile(Cat c, List<FileInfo>? all) {
    final info = catInfo[c]!;
    final count = all?.where((f) => f.cat == c).length;
    return Material(
      color: info.color.withAlpha(30),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _push(CategoryPage(cat: c)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: info.color.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(count == null ? 'Scanning…' : '$count files',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAccess() {
    const items = [
      ['Downloads', 'Download', 'download'],
      ['Camera', 'DCIM', 'camera'],
      ['Pictures', 'Pictures', 'pictures'],
      ['Documents', 'Documents', 'documents'],
      ['Movies', 'Movies', 'movies'],
      ['Music', 'Music', 'music'],
    ];
    const icons = {
      'download': Icons.download_rounded,
      'camera': Icons.photo_camera_rounded,
      'pictures': Icons.photo_library_rounded,
      'documents': Icons.article_rounded,
      'movies': Icons.movie_rounded,
      'music': Icons.library_music_rounded,
    };
    final chips = <Widget>[];
    for (final it in items) {
      final p = '$kInternalRoot/${it[1]}';
      if (!Directory(p).existsSync()) continue;
      chips.add(ActionChip(
        avatar: Icon(icons[it[2]], size: 18, color: kAccent),
        label: Text(it[0]),
        onPressed: () => _push(BrowserPage(path: p, root: kInternalRoot)),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Quick access'),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _recent(List<FileInfo>? all) {
    if (all == null || all.isEmpty) return const SizedBox.shrink();
    final l = [...all]..sort((a, b) => b.modified.compareTo(a.modified));
    final top = l.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Recent files'),
        for (final f in top)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: FileThumb(f.path),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${fmtSize(f.size)} • ${fmtDate(f.modified)}'),
            onTap: () => OpenFilex.open(f.path),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            OxLogo(size: 34),
            SizedBox(width: 10),
            Text('Ox Files',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _push(const CategoryPage(cat: null)),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ValueListenableBuilder<List<FileInfo>?>(
          valueListenable: Scanner.files,
          builder: (context, all, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _section('Storage'),
                for (final v in volumes) _storageCard(v),
                _section('Categories'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [for (final c in Cat.values) _catTile(c, all)],
                ),
                _quickAccess(),
                _recent(all),
              ],
            );
          },
        ),
      ),
    );
  }
}
