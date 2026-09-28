package com.oxclub.oxfiles

import android.content.Context
import android.content.Intent
import android.os.StatFs
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import coil.ImageLoader
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import java.io.File

object Ox {
    val bg1 = Color(0xFF0B0F1A)
    val bg2 = Color(0xFF141B31)
    val card = Color(0xFF161D31)
    val card2 = Color(0xFF1E2848)
    val stroke = Color(0x1FFFFFFF)
    val text = Color(0xFFF2F5FA)
    val sub = Color(0xFF9AA4B8)
    val cyan = Color(0xFF00E5FF)
    val violet = Color(0xFF7C4DFF)
    val amber = Color(0xFFFFB300)
    val grad = Brush.linearGradient(listOf(cyan, violet))
}

val LocalLoader = staticCompositionLocalOf<ImageLoader> { error("ImageLoader missing") }

fun Modifier.bounceClick(onClick: () -> Unit): Modifier = composed {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val s by animateFloatAsState(
        targetValue = if (pressed) 0.94f else 1f,
        animationSpec = spring(dampingRatio = 0.55f, stiffness = 500f),
        label = "bounce"
    )
    this.graphicsLayer { scaleX = s; scaleY = s }
        .clickable(interactionSource = src, indication = null, onClick = onClick)
}

fun Modifier.appear(i: Int): Modifier = composed {
    var on by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(i * 55L); on = true }
    val a by animateFloatAsState(if (on) 1f else 0f, tween(450), label = "appear")
    this.graphicsLayer { alpha = a; translationY = (1f - a) * 48f }
}

fun openFile(ctx: Context, path: String) {
    try {
        val f = File(path)
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(f.extension.lowercase()) ?: "*/*"
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", f)
        ctx.startActivity(
            Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        )
    } catch (e: Exception) {
        Toast.makeText(ctx, "No app found to open this file", Toast.LENGTH_SHORT).show()
    }
}

@Composable
fun Logo(dp: Dp) {
    Canvas(Modifier.size(dp)) {
        val k = size.minDimension / 108f
        drawRoundRect(Color(0xFF0B0F1A), cornerRadius = CornerRadius(28f * k))
        drawRoundRect(
            brush = Brush.linearGradient(listOf(Ox.cyan, Ox.violet), Offset(38f * k, 28f * k), Offset(70f * k, 80f * k)),
            topLeft = Offset(38.5f * k, 30.5f * k),
            size = Size(31f * k, 47f * k),
            cornerRadius = CornerRadius(15.5f * k),
            style = Stroke(7f * k)
        )
        drawLine(Ox.amber, Offset(47f * k, 47f * k), Offset(61f * k, 61f * k), 5f * k, StrokeCap.Round)
        drawLine(Ox.amber, Offset(61f * k, 47f * k), Offset(47f * k, 61f * k), 5f * k, StrokeCap.Round)
    }
}

@Composable
fun Ring(frac: Float, dp: Dp) {
    var target by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(frac) { target = frac }
    val p by animateFloatAsState(target, tween(1200, easing = FastOutSlowInEasing), label = "ring")
    Canvas(Modifier.size(dp)) {
        val sw = 10.dp.toPx()
        val tl = Offset(sw / 2, sw / 2)
        val sz = Size(size.width - sw, size.height - sw)
        drawArc(Color(0x22FFFFFF), 0f, 360f, false, tl, sz, style = Stroke(sw))
        drawArc(Ox.grad, -90f, 360f * p, false, tl, sz, style = Stroke(sw, cap = StrokeCap.Round))
    }
}

@Composable
fun IconBtn(icon: ImageVector, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).bounceClick(onClick).clip(CircleShape)
            .background(Ox.card).border(1.dp, Ox.stroke, CircleShape),
        contentAlignment = Alignment.Center
    ) { Icon(icon, null, tint = Ox.text, modifier = Modifier.size(22.dp)) }
}

@Composable
fun TopBar(title: String, sub: String, accent: Color, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        IconBtn(Icons.Rounded.ArrowBack, onBack)
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, color = Ox.text, fontSize = 22.sp, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, color = accent, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun Welcome(onGrant: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Logo(112.dp)
        Spacer(Modifier.height(28.dp))
        Text("Welcome to OxFiles", color = Ox.text, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Text(
            "Allow storage access so OxFiles can find and organise your photos, videos, music and documents.",
            color = Ox.sub, fontSize = 15.sp, lineHeight = 22.sp, textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(32.dp))
        Box(
            Modifier.bounceClick(onGrant).clip(RoundedCornerShape(16.dp))
                .background(Ox.grad).padding(horizontal = 40.dp, vertical = 16.dp)
        ) { Text("Allow access", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
    }
}

private fun LazyGridScope.full(content: @Composable LazyGridItemScope.() -> Unit) =
    item(span = { GridItemSpan(maxLineSpan) }, content = content)

@Composable
fun Home(
    vols: List<Vol>, idx: Index,
    onCat: (Cat) -> Unit, onVol: (Vol) -> Unit, onQuick: (Vol, String) -> Unit,
    onSearch: () -> Unit, onRescan: () -> Unit
) {
    val internal = vols.first()
    val quick = remember(vols) {
        listOf(
            Triple("Downloads", Icons.Rounded.Download, "Download"),
            Triple("Camera", Icons.Rounded.CameraAlt, "DCIM"),
            Triple("Screenshots", Icons.Rounded.Image, "Pictures/Screenshots"),
            Triple("Documents", Icons.Rounded.Description, "Documents")
        ).filter { File(internal.root, it.third).isDirectory }
    }
    LazyVerticalGrid(
        columns = GridCells.Adaptive(160.dp),
        contentPadding = PaddingValues(20.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        full {
            Row(Modifier.fillMaxWidth().appear(0), verticalAlignment = Alignment.CenterVertically) {
                Logo(50.dp)
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text("OxFiles", color = Ox.text, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                    Text("Your files, beautifully organised", color = Ox.sub, fontSize = 13.sp)
                }
                IconBtn(Icons.Rounded.Refresh, onRescan)
            }
        }
        full {
            val shape = RoundedCornerShape(18.dp)
            Row(
                Modifier.fillMaxWidth().appear(1).bounceClick(onSearch).clip(shape)
                    .background(Ox.card).border(1.dp, Ox.stroke, shape)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Rounded.Search, null, tint = Ox.sub)
                Spacer(Modifier.width(12.dp))
                Text("Search files", color = Ox.sub, fontSize = 15.sp)
            }
        }
        full {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                vols.take(3).forEachIndexed { i, v -> StorageCard(v, i + 2, Modifier.weight(1f)) { onVol(v) } }
            }
        }
        full { SectionTitle("Categories", idx.scanning) }
        itemsIndexed(Cat.values().toList()) { i, c -> CatTile(c, idx.counts[c] ?: 0, i + 3) { onCat(c) } }
        if (quick.isNotEmpty()) {
            full { SectionTitle("Quick access", false) }
            full {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    quick.forEach { (label, icon, path) -> Chip(label, icon) { onQuick(internal, path) } }
                }
            }
        }
    }
}

@Composable
fun SectionTitle(text: String, scanning: Boolean) {
    Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, color = Ox.text, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        if (scanning) {
            val a by rememberInfiniteTransition(label = "pulse").animateFloat(
                0.35f, 1f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "pulseA"
            )
            Text("Scanning…", color = Ox.cyan.copy(alpha = a), fontSize = 13.sp)
        }
    }
}

@Composable
fun StorageCard(v: Vol, i: Int, mod: Modifier, onClick: () -> Unit) {
    val st = runCatching { StatFs(v.root.path) }.getOrNull()
    val total = st?.totalBytes ?: 0L
    val free = st?.availableBytes ?: 0L
    val used = total - free
    val shape = RoundedCornerShape(24.dp)
    Column(
        mod.appear(i).bounceClick(onClick).clip(shape)
            .background(Brush.verticalGradient(listOf(Ox.card2, Ox.card)))
            .border(1.dp, Ox.stroke, shape).padding(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(contentAlignment = Alignment.Center) {
            Ring(if (total > 0) used.toFloat() / total else 0f, 96.dp)
            Icon(
                if (v.sd) Icons.Rounded.SdStorage else Icons.Rounded.PhoneAndroid, null,
                tint = Ox.cyan, modifier = Modifier.size(28.dp)
            )
        }
        Spacer(Modifier.height(12.dp))
        Text(v.name, color = Ox.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text("${human(used)} used", color = Ox.sub, fontSize = 13.sp)
        Text("${human(free)} free of ${human(total)}", color = Ox.sub, fontSize = 12.sp, textAlign = TextAlign.Center)
    }
}

@Composable
fun CatTile(c: Cat, count: Int, i: Int, onClick: () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    val n by animateIntAsState(count, tween(700), label = "count")
    Column(
        Modifier.appear(i).bounceClick(onClick).clip(shape)
            .background(Brush.linearGradient(listOf(c.color.copy(alpha = 0.22f), Ox.card)))
            .border(1.dp, c.color.copy(alpha = 0.30f), shape).padding(16.dp)
    ) {
        Box(
            Modifier.size(46.dp).clip(RoundedCornerShape(14.dp)).background(c.color.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center
        ) { Icon(c.icon, null, tint = c.color, modifier = Modifier.size(26.dp)) }
        Spacer(Modifier.height(14.dp))
        Text(c.label, color = Ox.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text(if (n == 1) "1 file" else "$n files", color = Ox.sub, fontSize = 13.sp)
    }
}

@Composable
fun Chip(label: String, icon: ImageVector, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        Modifier.bounceClick(onClick).clip(shape).background(Ox.card).border(1.dp, Ox.stroke, shape)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, null, tint = Ox.cyan, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(label, color = Ox.text, fontSize = 14.sp)
    }
}

@Composable
fun FileIcon(name: String, path: String, dir: Boolean) {
    val cat = catOf(name)
    val shape = RoundedCornerShape(14.dp)
    if (!dir && (cat == Cat.Images || cat == Cat.Videos)) {
        val f = remember(path) { File(path) }
        AsyncImage(
            model = f, contentDescription = null, imageLoader = LocalLoader.current,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(48.dp).clip(shape).background(Ox.card)
        )
    } else {
        val tint = if (dir) Ox.amber else (cat?.color ?: Ox.sub)
        Box(
            Modifier.size(48.dp).clip(shape).background(tint.copy(alpha = 0.16f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (dir) Icons.Rounded.Folder else (cat?.icon ?: Icons.Rounded.InsertDriveFile),
                null, tint = tint, modifier = Modifier.size(26.dp)
            )
        }
    }
}

@Composable
fun FileRow(name: String, path: String, size: Long, time: Long, dir: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FileIcon(name, path, dir)
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(name, color = Ox.text, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                if (dir) "Folder" else "${human(size)}  •  ${fmtDate(time)}",
                color = Ox.sub, fontSize = 12.sp
            )
        }
        if (dir) Icon(Icons.Rounded.ChevronRight, null, tint = Ox.sub)
    }
}

@Composable
fun Centered(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center, content = content)
}

@Composable
fun CategoryScreen(c: Cat, idx: Index, onBack: () -> Unit) {
    val list = idx.items[c].orEmpty()
    val ctx = LocalContext.current
    Column(Modifier.fillMaxSize()) {
        TopBar(c.label, if (idx.scanning) "${list.size} files • scanning…" else "${list.size} files", c.color, onBack)
        when {
            list.isEmpty() && idx.scanning -> Centered {
                CircularProgressIndicator(color = c.color)
                Spacer(Modifier.height(16.dp))
                Text("Scanning your files…", color = Ox.sub)
            }
            list.isEmpty() -> Centered {
                Icon(c.icon, null, tint = c.color.copy(alpha = 0.5f), modifier = Modifier.size(56.dp))
                Spacer(Modifier.height(12.dp))
                Text("No ${c.label.lowercase()} found", color = Ox.sub)
            }
            c == Cat.Images || c == Cat.Videos -> LazyVerticalGrid(
                columns = GridCells.Adaptive(112.dp), contentPadding = PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(list, key = { it.path }) { e ->
                    val f = remember(e.path) { File(e.path) }
                    Box(
                        Modifier.aspectRatio(1f).clip(RoundedCornerShape(14.dp)).background(Ox.card)
                            .clickable { openFile(ctx, e.path) }
                    ) {
                        AsyncImage(
                            model = f, contentDescription = null, imageLoader = LocalLoader.current,
                            contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()
                        )
                        if (c == Cat.Videos) Box(
                            Modifier.align(Alignment.Center).size(38.dp).clip(CircleShape)
                                .background(Color(0x99000000)),
                            contentAlignment = Alignment.Center
                        ) { Icon(Icons.Rounded.PlayArrow, null, tint = Color.White, modifier = Modifier.size(24.dp)) }
                    }
                }
            }
            else -> LazyColumn(contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)) {
                items(list, key = { it.path }) { e ->
                    FileRow(e.name, e.path, e.size, e.time, false) { openFile(ctx, e.path) }
                }
            }
        }
    }
}

@Composable
fun FolderScreen(root: String, start: String, onBack: () -> Unit) {
    val rootF = remember(root) { File(root) }
    var dir by remember { mutableStateOf(File(start)) }
    val ctx = LocalContext.current
    BackHandler { if (dir.path == rootF.path) onBack() else dir = dir.parentFile ?: rootF }
    val entries = remember(dir) {
        (dir.listFiles() ?: emptyArray())
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
    }
    Column(Modifier.fillMaxSize()) {
        TopBar(if (dir.path == rootF.path) "Storage" else dir.name, dir.path, Ox.cyan) {
            if (dir.path == rootF.path) onBack() else dir = dir.parentFile ?: rootF
        }
        if (entries.isEmpty()) Centered { Text("This folder is empty", color = Ox.sub) }
        else LazyColumn(contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)) {
            items(entries, key = { it.path }) { f ->
                FileRow(f.name, f.path, if (f.isDirectory) 0L else f.length(), f.lastModified(), f.isDirectory) {
                    if (f.isDirectory) dir = f else openFile(ctx, f.path)
                }
            }
        }
    }
}

@Composable
fun SearchScreen(idx: Index, onBack: () -> Unit) {
    var q by remember { mutableStateOf("") }
    val fr = remember { FocusRequester() }
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { delay(200); runCatching { fr.requestFocus() } }
    val all = remember(idx.items) { idx.items.values.flatten() }
    val res = remember(q, all) {
        if (q.trim().length < 2) emptyList() else all.filter { it.name.contains(q.trim(), true) }.take(300)
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            IconBtn(Icons.Rounded.ArrowBack, onBack)
            Spacer(Modifier.width(12.dp))
            TextField(
                value = q, onValueChange = { q = it }, singleLine = true,
                placeholder = { Text("Search all files") },
                leadingIcon = { Icon(Icons.Rounded.Search, null) },
                shape = RoundedCornerShape(16.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Ox.card, unfocusedContainerColor = Ox.card,
                    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
                    cursorColor = Ox.cyan, focusedTextColor = Ox.text, unfocusedTextColor = Ox.text,
                    focusedPlaceholderColor = Ox.sub, unfocusedPlaceholderColor = Ox.sub,
                    focusedLeadingIconColor = Ox.sub, unfocusedLeadingIconColor = Ox.sub
                ),
                modifier = Modifier.weight(1f).focusRequester(fr)
            )
        }
        when {
            q.trim().length < 2 -> Centered { Text("Type at least 2 letters", color = Ox.sub) }
            res.isEmpty() -> Centered { Text("No matches", color = Ox.sub) }
            else -> LazyColumn(contentPadding = PaddingValues(horizontal = 8.dp)) {
                items(res, key = { it.path }) { e ->
                    FileRow(e.name, e.path, e.size, e.time, false) { openFile(ctx, e.path) }
                }
            }
        }
    }
}
