import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const kAccent = Color(0xFF00E676);
const kAccent2 = Color(0xFF22D3EE);
const kFolder = Color(0xFFFFB300);
const kInternalRoot = '/storage/emulated/0';

// ───────────────────────── Categories ─────────────────────────

enum Cat { images, videos, audio, documents, archives, apks }

class CatInfo {
  final String label;
  final IconData icon;
  final Color color;
  const CatInfo(this.label, this.icon, this.color);
}

const Map<Cat, CatInfo> catInfo = {
  Cat.images: CatInfo('Images', Icons.image_rounded, Color(0xFF8B5CF6)),
  Cat.videos: CatInfo('Videos', Icons.play_circle_rounded, Color(0xFFEF4444)),
  Cat.audio: CatInfo('Audio', Icons.music_note_rounded, Color(0xFFF59E0B)),
  Cat.documents:
      CatInfo('Documents', Icons.description_rounded, Color(0xFF3B82F6)),
  Cat.archives: CatInfo('Archives', Icons.folder_zip_rounded, Color(0xFF14B8A6)),
  Cat.apks: CatInfo('APKs', Icons.android_rounded, Color(0xFF22C55E)),
};

const Map<Cat, Set<String>> _ext = {
  Cat.images: {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'},
  Cat.videos: {'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv', 'wmv', 'm4v'},
  Cat.audio: {'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'opus', 'amr', 'wma'},
  Cat.documents: {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf',
    'odt', 'ods', 'odp', 'epub', 'md', 'json', 'xml', 'html'
  },
  Cat.archives: {'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2'},
  Cat.apks: {'apk'},
};

String nameOf(String p) => p.split('/').last;

String extOf(String p) {
  final n = nameOf(p);
  final i = n.lastIndexOf('.');
  return i <= 0 ? '' : n.substring(i + 1).toLowerCase();
}

Cat? catOf(String p) {
  final e = extOf(p);
  if (e.isEmpty) return null;
  for (final en in _ext.entries) {
    if (en.value.contains(e)) return en.key;
  }
  return null;
}

bool canExtract(String p) {
  final l = p.toLowerCase();
  return l.endsWith('.zip') ||
      l.endsWith('.tar') ||
      l.endsWith('.tar.gz') ||
      l.endsWith('.tgz') ||
      l.endsWith('.tar.bz2');
}

IconData iconFor(String path, {bool dir = false}) {
  if (dir) return Icons.folder_rounded;
  final c = catOf(path);
  return c == null ? Icons.insert_drive_file_rounded : catInfo[c]!.icon;
}

Color colorFor(String path, {bool dir = false}) {
  if (dir) return kFolder;
  final c = catOf(path);
  return c == null ? const Color(0xFF94A3B8) : catInfo[c]!.color;
}

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String fmtDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

// ───────────────────────── Storage volumes ─────────────────────────

class Volume {
  final String name;
  final String path;
  final bool removable;
  const Volume(this.name, this.path, this.removable);
}

List<Volume> getVolumes() {
  final vols = <Volume>[const Volume('Internal storage', kInternalRoot, false)];
  final found = <String>{};

  // 1) list /storage
  try {
    for (final e in Directory('/storage').listSync()) {
      final n = nameOf(e.path);
      if (n == 'emulated' || n == 'self') continue;
      found.add(e.path);
    }
  } catch (_) {}

  // 2) fallback: /proc/mounts (works when /storage listing is blocked)
  try {
    final mounts = File('/proc/mounts').readAsLinesSync();
    final re = RegExp(r'(/storage/|/mnt/media_rw/)([0-9A-Fa-f]{4}-[0-9A-Fa-f]{4})');
    for (final line in mounts) {
      final m = re.firstMatch(line);
      if (m != null) found.add('/storage/${m.group(2)}');
    }
  } catch (_) {}

  var i = 0;
  for (final p in found) {
    if (!FileSystemEntity.isDirectorySync(p)) continue;
    i++;
    vols.add(Volume(i == 1 ? 'SD card / USB' : 'SD card / USB $i', p, true));
  }
  return vols;
}

String volumeRootOf(String path) {
  if (path.startsWith(kInternalRoot)) return kInternalRoot;
  final parts = path.split('/');
  if (parts.length >= 3 && parts[1] == 'storage') return '/storage/${parts[2]}';
  return kInternalRoot;
}

String volumeName(String root) => root == kInternalRoot ? 'Internal storage' : 'SD card / USB';

class Usage {
  final int total;
  final int used;
  const Usage(this.total, this.used);
  double get frac => total == 0 ? 0 : (used / total).clamp(0.0, 1.0);
}

Future<Usage?> diskUsage(String path) async {
  try {
    final r = await Process.run('df', ['-k', path]);
    final lines = r.stdout.toString().trim().split('\n');
    if (lines.length < 2) return null;
    final p = lines.last.trim().split(RegExp(r'\s+'));
    if (p.length < 4) return null;
    final total = int.parse(p[1]) * 1024;
    final used = int.parse(p[2]) * 1024;
    if (total <= 0) return null;
    return Usage(total, used);
  } catch (_) {
    return null;
  }
}

// ───────────────────────── Media scanner ─────────────────────────

class FileInfo {
  final Cat cat;
  final String path;
  final int size;
  final DateTime modified;
  const FileInfo(this.cat, this.path, this.size, this.modified);
  String get name => nameOf(path);
}

List<List<dynamic>> scanJob(List<String> roots) {
  final out = <List<dynamic>>[];
  void walk(Directory d, int depth) {
    if (depth > 12) return;
    List<FileSystemEntity> l;
    try {
      l = d.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final e in l) {
      final name = nameOf(e.path);
      if (name.startsWith('.')) continue;
      if (e is Directory) {
        if (depth == 0 && name == 'Android') continue;
        walk(e, depth + 1);
      } else if (e is File) {
        final c = catOf(e.path);
        if (c == null) continue;
        try {
          final st = e.statSync();
          out.add([c.index, e.path, st.size, st.modified.millisecondsSinceEpoch]);
        } catch (_) {}
      }
    }
  }

  for (final r in roots) {
    walk(Directory(r), 0);
  }
  return out;
}

class Scanner {
  static final ValueNotifier<List<FileInfo>?> files = ValueNotifier(null);
  static bool _running = false;

  static Future<void> scan(List<String> roots) async {
    if (_running) return;
    _running = true;
    try {
      final rows = await compute(scanJob, roots);
      files.value = rows
          .map((r) => FileInfo(Cat.values[r[0] as int], r[1] as String,
              r[2] as int, DateTime.fromMillisecondsSinceEpoch(r[3] as int)))
          .toList();
    } catch (_) {
      files.value = files.value ?? <FileInfo>[];
    }
    _running = false;
  }

  static void remove(String path) {
    files.value = files.value?.where((f) => f.path != path).toList();
  }
}

// ───────────────────────── File operations (isolate) ─────────────────────────

class FileClip {
  static List<String> paths = [];
  static bool move = false;
}

bool _exists(String p) =>
    FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound;

String uniquePath(String path) {
  if (!_exists(path)) return path;
  final dir = path.substring(0, path.lastIndexOf('/'));
  final n = nameOf(path);
  final i = n.lastIndexOf('.');
  final base = i > 0 ? n.substring(0, i) : n;
  final ext = i > 0 ? n.substring(i) : '';
  var k = 1;
  while (true) {
    final c = '$dir/$base ($k)$ext';
    if (!_exists(c)) return c;
    k++;
  }
}

void _copyEntity(String src, String destDir) {
  if (destDir == src || destDir.startsWith('$src/')) return; // into itself
  final dest = uniquePath('$destDir/${nameOf(src)}');
  if (FileSystemEntity.isDirectorySync(src)) {
    Directory(dest).createSync(recursive: true);
    for (final e in Directory(src).listSync()) {
      _copyEntity(e.path, dest);
    }
  } else {
    File(src).copySync(dest);
  }
}

void _deleteEntity(String p) {
  if (FileSystemEntity.isDirectorySync(p)) {
    Directory(p).deleteSync(recursive: true);
  } else {
    File(p).deleteSync();
  }
}

void _moveEntity(String src, String destDir) {
  if (destDir == src || destDir.startsWith('$src/')) return;
  final dest = uniquePath('$destDir/${nameOf(src)}');
  try {
    if (FileSystemEntity.isDirectorySync(src)) {
      Directory(src).renameSync(dest);
    } else {
      File(src).renameSync(dest);
    }
  } catch (_) {
    _copyEntity(src, destDir);
    _deleteEntity(src);
  }
}

/// args: [mode, target, ...sources]
///  extract: target = output dir, sources[0] = archive
///  zip:     target = output .zip path
///  copy / move: target = destination dir
///  delete:  target unused
Future<void> fileJob(List<String> a) async {
  final mode = a[0];
  final target = a[1];
  final srcs = a.skip(2).toList();
  switch (mode) {
    case 'extract':
      await extractFileToDisk(srcs.first, target);
      break;
    case 'zip':
      final enc = ZipFileEncoder();
      enc.create(target);
      for (final p in srcs) {
        if (FileSystemEntity.isDirectorySync(p)) {
          await enc.addDirectory(Directory(p));
        } else {
          await enc.addFile(File(p));
        }
      }
      enc.close();
      break;
    case 'copy':
      for (final s in srcs) {
        _copyEntity(s, target);
      }
      break;
    case 'move':
      for (final s in srcs) {
        _moveEntity(s, target);
      }
      break;
    case 'delete':
      for (final s in srcs) {
        _deleteEntity(s);
      }
      break;
  }
}

// ───────────────────────── Shared widgets ─────────────────────────

class OxLogo extends StatelessWidget {
  final double size;
  const OxLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccent, kAccent2],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        '0x',
        style: TextStyle(
          color: const Color(0xFF06120C),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.44,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class FileThumb extends StatelessWidget {
  final String path;
  final bool dir;
  final double size;
  const FileThumb(this.path, {super.key, this.dir = false, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = colorFor(path, dir: dir);
    Widget iconBox() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconFor(path, dir: dir), color: color),
        );
    if (!dir && catOf(path) == Cat.images) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 140,
          errorBuilder: (_, __, ___) => iconBox(),
        ),
      );
    }
    return iconBox();
  }
}
