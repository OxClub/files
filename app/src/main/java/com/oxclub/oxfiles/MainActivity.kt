package com.oxclub.oxfiles

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.io.File

class Vol(val name: String, val root: File)

class MainActivity : ComponentActivity() {
    private var hasAccess by mutableStateOf(false)
    private var vols by mutableStateOf(listOf<Vol>())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) { OxApp(hasAccess, vols, ::askAccess) }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        hasAccess = checkAccess()
        vols = findVolumes()
    }

    private fun findVolumes(): List<Vol> {
        val list = mutableListOf(Vol("Internal storage", Environment.getExternalStorageDirectory()))
        getExternalFilesDirs(null).drop(1).filterNotNull().forEach { dir ->
            if (Environment.getExternalStorageState(dir) != Environment.MEDIA_MOUNTED) return@forEach
            val root = File(dir.absolutePath.substringBefore("/Android/data"))
            if (root.canRead() && list.none { it.root == root }) {
                list += Vol(if (list.size == 1) "SD card" else "External storage ${list.size}", root)
            }
        }
        return list
    }

    private fun checkAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager()
        else checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED

    private fun askAccess() {
        if (Build.VERSION.SDK_INT >= 30) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ), 1
            )
        }
    }
}

fun human(bytes: Long): String {
    val units = arrayOf("B", "KB", "MB", "GB")
    var v = bytes.toDouble()
    var i = 0
    while (v >= 1024 && i < units.lastIndex) { v /= 1024; i++ }
    return "%.1f %s".format(v, units[i])
}

@Composable
fun OxApp(hasAccess: Boolean, vols: List<Vol>, onGrant: () -> Unit) {
    var open by remember { mutableStateOf<Vol?>(null) }
    val cur = open
    when {
        !hasAccess -> Column(
            Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text("OxFiles", style = MaterialTheme.typography.headlineLarge)
            Spacer(Modifier.height(8.dp))
            Text("Allow storage access to browse your files.")
            Spacer(Modifier.height(16.dp))
            Button(onClick = onGrant) { Text("Allow access") }
        }
        cur != null -> Browser(cur.root) { open = null }
        else -> Home(vols) { open = it }
    }
}

@Composable
fun Home(vols: List<Vol>, onOpen: (Vol) -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("OxFiles", style = MaterialTheme.typography.headlineMedium)
        vols.forEach { v -> StorageCard(v) { onOpen(v) } }
        listOf("Images", "Videos", "Audio", "Documents", "APKs", "Archives")
            .chunked(3)
            .forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    row.forEach { name -> Card(Modifier.weight(1f)) { Text(name, Modifier.padding(20.dp)) } }
                }
            }
        Text("Category views coming next.", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
fun StorageCard(v: Vol, onClick: () -> Unit) {
    val st = runCatching { StatFs(v.root.path) }.getOrNull()
    Card(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Column(Modifier.padding(20.dp)) {
            Text(v.name, style = MaterialTheme.typography.titleMedium)
            if (st != null && st.totalBytes > 0) {
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { 1f - st.availableBytes.toFloat() / st.totalBytes },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                Text("${human(st.availableBytes)} free of ${human(st.totalBytes)}")
            }
        }
    }
}

@Composable
fun Browser(root: File, onExit: () -> Unit) {
    var dir by remember { mutableStateOf(root) }
    BackHandler { if (dir == root) onExit() else dir = dir.parentFile ?: root }
    val entries = remember(dir) {
        (dir.listFiles() ?: emptyArray())
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
    }
    Column(Modifier.fillMaxSize()) {
        Text(dir.path, Modifier.padding(16.dp), style = MaterialTheme.typography.titleSmall)
        LazyColumn {
            items(entries) { f ->
                ListItem(
                    headlineContent = { Text(f.name) },
                    supportingContent = { Text(if (f.isDirectory) "Folder" else human(f.length())) },
                    modifier = Modifier.clickable(enabled = f.isDirectory) { dir = f }
                )
            }
        }
    }
}
