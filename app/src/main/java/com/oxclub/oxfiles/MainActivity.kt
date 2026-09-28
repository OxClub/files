package com.oxclub.oxfiles

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import coil.ImageLoader
import coil.decode.VideoFrameDecoder
import java.io.File

sealed interface Screen {
    data object Home : Screen
    data class Category(val cat: Cat) : Screen
    data class Folder(val root: String, val start: String) : Screen
    data object Search : Screen
}

class MainActivity : ComponentActivity() {
    private var hasAccess by mutableStateOf(false)
    private var vols by mutableStateOf(listOf<Vol>())
    private val index = Index()
    private var scanKey = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        )
        val loader = ImageLoader.Builder(this)
            .components { add(VideoFrameDecoder.Factory()) }
            .crossfade(true)
            .build()
        setContent {
            CompositionLocalProvider(LocalLoader provides loader) {
                OxApp(hasAccess, vols, index, ::askAccess) { rescan(true) }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        hasAccess = checkAccess()
        vols = findVolumes()
        rescan(false)
    }

    private fun rescan(force: Boolean) {
        if (!hasAccess) return
        val key = vols.joinToString("|") { it.root.path }
        if (force || key != scanKey) {
            scanKey = key
            index.scan(vols.map { it.root })
        }
    }

    private fun findVolumes(): List<Vol> {
        val list = mutableListOf(Vol("Internal storage", Environment.getExternalStorageDirectory(), false))
        getExternalFilesDirs(null).drop(1).filterNotNull().forEach { dir ->
            if (Environment.getExternalStorageState(dir) != Environment.MEDIA_MOUNTED) return@forEach
            val root = File(dir.absolutePath.substringBefore("/Android/data"))
            if (root.canRead() && list.none { it.root == root }) {
                list += Vol(if (list.size == 1) "SD card" else "External storage ${list.size}", root, true)
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

@Composable
fun OxApp(hasAccess: Boolean, vols: List<Vol>, idx: Index, onGrant: () -> Unit, onRescan: () -> Unit) {
    var screen by remember { mutableStateOf<Screen>(Screen.Home) }
    BackHandler(enabled = screen != Screen.Home) { screen = Screen.Home }
    Box(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Ox.bg1, Ox.bg2)))
            .systemBarsPadding()
    ) {
        if (!hasAccess) {
            Welcome(onGrant)
        } else {
            AnimatedContent(
                targetState = screen,
                transitionSpec = {
                    val go = targetState !is Screen.Home
                    (fadeIn(tween(260)) + slideInHorizontally(tween(320)) { if (go) it / 8 else -it / 8 }) togetherWith
                        (fadeOut(tween(180)) + slideOutHorizontally(tween(320)) { if (go) -it / 8 else it / 8 })
                },
                label = "nav"
            ) { s ->
                when (s) {
                    Screen.Home -> Home(
                        vols, idx,
                        onCat = { screen = Screen.Category(it) },
                        onVol = { screen = Screen.Folder(it.root.path, it.root.path) },
                        onQuick = { v, rel -> screen = Screen.Folder(v.root.path, File(v.root, rel).path) },
                        onSearch = { screen = Screen.Search },
                        onRescan = onRescan
                    )
                    is Screen.Category -> CategoryScreen(s.cat, idx) { screen = Screen.Home }
                    is Screen.Folder -> FolderScreen(s.root, s.start) { screen = Screen.Home }
                    Screen.Search -> SearchScreen(idx) { screen = Screen.Home }
                }
            }
        }
    }
}
