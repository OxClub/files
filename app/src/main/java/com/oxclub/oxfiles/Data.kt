package com.oxclub.oxfiles

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import kotlinx.coroutines.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class Cat(val label: String, val color: Color, val icon: ImageVector, val exts: Set<String>) {
    Images("Images", Color(0xFF00E5FF), Icons.Rounded.Image,
        setOf("jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif")),
    Videos("Videos", Color(0xFFFF5C8A), Icons.Rounded.VideoLibrary,
        setOf("mp4", "mkv", "avi", "mov", "3gp", "webm", "flv", "wmv", "m4v", "mpg", "mpeg")),
    Audio("Audio", Color(0xFFB388FF), Icons.Rounded.MusicNote,
        setOf("mp3", "m4a", "wav", "flac", "ogg", "aac", "opus", "amr", "wma", "mid")),
    Documents("Documents", Color(0xFFFFB300), Icons.Rounded.Description,
        setOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf", "odt", "epub")),
    Apks("APKs", Color(0xFF3DDC84), Icons.Rounded.Android,
        setOf("apk", "xapk", "apkm")),
    Archives("Archives", Color(0xFFFF8A65), Icons.Rounded.FolderZip,
        setOf("zip", "rar", "7z", "tar", "gz", "bz2", "xz"))
}

private val extMap: Map<String, Cat> =
    Cat.values().flatMap { c -> c.exts.map { it to c } }.toMap()

fun catOf(name: String): Cat? = extMap[name.substringAfterLast('.', "").lowercase()]

class Vol(val name: String, val root: File, val sd: Boolean)

class FileEntry(val path: String, val name: String, val size: Long, val time: Long)

private val dateFmt = SimpleDateFormat("dd MMM yyyy", Locale.getDefault())
fun fmtDate(ms: Long): String = dateFmt.format(Date(ms))

fun human(bytes: Long): String {
    val units = arrayOf("B", "KB", "MB", "GB", "TB")
    var v = bytes.toDouble()
    var i = 0
    while (v >= 1024 && i < units.lastIndex) { v /= 1024; i++ }
    return if (i == 0) "$bytes B" else "%.1f %s".format(v, units[i])
}

class Index {
    var counts by mutableStateOf(mapOf<Cat, Int>())
    var items by mutableStateOf(mapOf<Cat, List<FileEntry>>())
    var scanning by mutableStateOf(false)
    private var job: Job? = null

    fun scan(roots: List<File>) {
        job?.cancel()
        job = CoroutineScope(Dispatchers.IO).launch {
            scanning = true
            val acc = Cat.values().associateWith { ArrayList<FileEntry>() }
            var n = 0
            val stack = ArrayDeque<File>(roots)
            while (stack.isNotEmpty()) {
                ensureActive()
                val dir = stack.removeLast()
                val kids = dir.listFiles() ?: continue
                for (f in kids) {
                    if (f.isDirectory) {
                        val nm = f.name
                        if (nm.startsWith(".") || (nm == "Android" && dir in roots)) continue
                        stack.addLast(f)
                    } else {
                        val cat = catOf(f.name) ?: continue
                        acc.getValue(cat).add(FileEntry(f.path, f.name, f.length(), f.lastModified()))
                        if (++n % 1000 == 0) publish(acc, false)
                    }
                }
            }
            publish(acc, true)
            scanning = false
        }
    }

    private fun publish(acc: Map<Cat, List<FileEntry>>, sort: Boolean) {
        items = acc.mapValues { (_, v) -> if (sort) v.sortedByDescending { it.time } else v.toList() }
        counts = acc.mapValues { it.value.size }
    }
}
