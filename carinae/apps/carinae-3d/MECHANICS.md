# Carinae 3D — mechanics read from the original

The original is an Electron app (Vault3D 1.6.0, Windows installer `Vault3D-Setup-1.6.0.exe`,
NSIS-packed). Its code is JavaScript, not machine code, so there was nothing for Ghidra to
decompile: the sheet below was read from the app's own files, extracted from
`%LOCALAPPDATA%\Programs\Vault3D\resources\app.asar` (the installed copy the installer writes),
with the line numbers given as the "address". Every value is *observed* unless marked
*estimated*.

## Inside the installer's machine code (Ghidra, Deep mode)

The `.exe` really was opened as a native program and decompiled. What is in it is the NSIS
installer engine and nothing else — 92 functions, 165 imports from 7 DLLs, no exports. The app
being installed is a compressed block appended at file offset 96 264 (the NSIS first header,
found by the string `NullsoftInst`), so the library, thumbnail and filament rules cannot come
out of the machine code; they come from the JavaScript below. What the machine code does give,
and what the rebuild now uses, is the checksum and the streaming sizes:

| Function | Address | What it is | Value taken from it |
|---|---|---|---|
| Installer entry | `0x40338f` | reads `/S` (silent) and `/D=` (install dir) from the command line, extracts itself to a temp path and jumps into the extracted copy | the installer never runs the app's code itself; it only unpacks it |
| Data header check | `0x402edd` | opens its own file, reads it in 512-byte pieces (32 256 + 512 when the "large" flag is set), CRC-checks the whole file, then unpacks the script header found at `header + 0x1c` | block sizes `0x200` / `0x7e00`; header offset `0x1c` |
| CRC-32 | `0x406787` | builds a 256-entry table from the reflected polynomial `0xedb88320`, inverts the running value before and after | **the rebuild's `store::crc32` / `store::crc32_file`** — duplicates are now pre-filtered with it, and `crc32("123456789") = 0xCBF43926` is asserted in the tests |
| Unpacker | `0x403116` | 32 KiB dictionary/output buffer, 16 KiB input pieces, `0xffffffff`-style negative returns for errors, prints a `%d%%` progress string | streaming chunk `0x8000` (`store::STREAM_CHUNK`) |
| Decompressor | `0x4067f5` | 2 639 bytes, 189 blocks, one 16-way jump table: an LZMA decoder (literal/match/length states) | the payload is LZMA-compressed, which is why nothing app-specific appears in `.text` |
| Instruction interpreter | `0x401434` | 1 908 instructions, one `switch` per NSIS instruction: attributes, `MoveFile`, `Exec`, registry, string compare, integer ops, environment expansion, maths, file extraction (which calls `0x403116`) | the installer's own behaviour, not the app's |
| Installer bootstrap | `0x4039aa` | reads `Control Panel\Desktop\ResourceLocale`, registers a hidden window class, loads `RichEdit20W` for the licence page, then shows its dialogs | nothing the app uses |
| Directory maker | `0x405c97` | walks a path creating each component with `GetFileAttributesW` checks | nothing the app uses |

Facts from the exe's own resources (`.rsrc` at `0x63d9c0`): ProductName `Vault3D`,
ProductVersion and FileVersion `1.6.0`, copyright `© 2026 Paulo Siqueira`, language `0x0409`
(1252). Carinae 3D shows the version in **Configurações ▸ Sobre**.

## Formats and parsing

| Value | Value found | Source |
|---|---|---|
| Model file extensions the app reads | `stl`, `3mf`, `svg` (case-insensitive, lowercased on scan) | `app.js:17-18` |
| STL binary test | read little-endian u32 at offset 80 = triangle count; binary if `84 + n*50 == size`; otherwise ASCII if the first 512 bytes are printable | `stl-parser.js:20-60` |
| STL binary record | 50 bytes: 3 floats normal, 9 floats vertices, 2 bytes attribute | `stl-parser.js:62-95` |
| STL volume (mm³) | sum of signed tetra volumes `dot(a, cross(b,c)) / 6`, absolute value, `/1000` = cm³ | `stl-parser.js:110-140` |
| Triangle count | `positions.length / 9` | `stl-parser.js:145` |
| Bounds / dimensions | min/max over vertices, in mm | `stl-parser.js:100-108` |
| SVG size | `width`/`height` attributes or `viewBox`, mm assumed when the unit is missing | `svg-parser.js` |
| 3MF geometry | `3D/3dmodel.model`: `<mesh><vertices><vertex x y z>`, `<triangles><triangle v1 v2 v3>`, objects, components, `<build><item transform>`; matrices `m00 m01 m02 m10 …` comma/space separated, parent × child | `threemf-extras.js`, `thumbnail-generator.js:252-296` |
| 3MF plate map | `Metadata/model_settings.config` (`<plate><metadata key="plater_id">` + `<model_instance><metadata key="object_id">`), fallback `Metadata/plate_N.json` | `thumbnail-generator.js:307-350`, `705-800` |
| 3MF plate images | `Metadata/plate_N.png`, then `top_N.png`, `pick_N.png`, `plate_no_light_N.png` | `thumbnail-generator.js:751-770` |
| 3MF sliced time/grams | `Metadata/slice_info.config` — per `<plate>`, `<metadata key="prediction" value="seconds">`, `weight` (grams) | `thumbnail-generator.js:657-700` |
| 3MF project settings | `Metadata/project_settings.config` (JSON): `printer_model`, `nozzle_diameter`, `layer_height`, `sparse_infill_density`, `support_enable`, `filament_colour`, `filament_type`, `filament_settings_id` | `threemf-extras.js`, `thumbnail-generator.js:832-955` |
| 3MF source info | `Metadata/source_info.config` (Title / Application) | `threemf-extras.js` |
| Duplicate fingerprint | SHA-256 of the whole file when ≤ 2 MB; otherwise SHA-256 of `size (8 bytes big-endian) + first 64 KB + 64 KB from the middle + last 64 KB` | `app.js:1215-1260` |
| Duplicate rule | two models are duplicates only when their fingerprints are equal; each keeps the count and the list of where else it lives | `app.js:1265-1310` |

## Look of a card thumbnail (3D render of an STL)

| Value | Value found | Source |
|---|---|---|
| Thumbnail size | 400 × 300 px | `thumbnail-generator.js:12-60` |
| Camera | perspective, 45° field of view, isometric direction `(0.7, 0.8, 0.9)` normalised | `thumbnail-generator.js:40-58` |
| Camera distance | `radius / sin(22.5°) * 1.15` | `thumbnail-generator.js:52` |
| Model colour | `#1fb6cc`, roughness 0.35, metalness 0.15 | `thumbnail-generator.js:70-110` |
| Lights | key directional white from (100,150,100) intensity 1.4; fill `#7090b0` from (-100,-50,-100) 0.8; rim `#00e5ff` from (0,-100,50) 0.5; ambient 0.35 | `thumbnail-generator.js:72-100` |
| Tone mapping | ACES Filmic, exposure 1.1 | `thumbnail-generator.js:100-110` |

## Library behaviour

| Value | Value found | Source |
|---|---|---|
| Sections | Todos os Modelos, Favoritos, Duplicados, Em Alta, Filamentos, Configurações | `app.js:26-28` |
| Format filters | all, stl, 3mf, svg, duplicates | `app.js:27` |
| Sort orders | `date_desc` (default), `date_asc`, `name_asc`, `name_desc`, `size_desc`, `size_asc` | `app.js:120-135` |
| Page sizes | 50 (default), 100, 150 | `app.js:43-60` |
| Search | matches the model name, case-insensitive, trimming spaces | `app.js:1770-1800` |
| Cards per row | responsive, minimum card width ~210 px | `styles.css` grid rules |
| Viewer keys | `Esc` closes, `←`/`→` previous/next model, `Delete` sends the selection to the trash, `F5` rescans the folders | `app.js:329-340`, `527-545`, `3086`, `3360` |
| Viewer toggles | auto-rotate on by default, wireframe off by default | `app.js:36-38` |
| Move dialog | a folder tree of every connected folder and subfolder; a new subfolder can be created inline | `app.js:3729-3960` |

## Design tokens

| Token | Value | Source |
|---|---|---|
| Window | 1300 × 820, minimum 960 × 600, background `#0a0e17` | `main.js:30-70` |
| App background | `#070b10` | `theme.css` (`--bg-main`) |
| Panel | `#0b1118` | `theme.css` (`--bg-panel`) |
| Card | `#0f161f`, hover `#151e29` | `theme.css` |
| Hairline | `rgba(255,255,255,0.07)` | `theme.css` (`--line`) |
| Text | primary `#eef3f8`, secondary `#8b98a8`, muted `#5b6878` | `theme.css` |
| Accent | `#22d3ee`, strong `#06b6d4` | `theme.css` |
| Format colours | STL `#60a5fa`, 3MF `#34d399`, SVG `#c084fc`, warning `#fbbf24` | `theme.css` |
| Top bar height | 52 px | `theme.css` (`--topbar-h`) |
| Sidebar width | 248 px | `theme.css` (`--sidebar-w`) |
| Corner radius | 6 px controls, 8 px cards | `theme.css` |
| Body font | Plus Jakarta Sans 13.5 px (Carinae 3D uses egui's default font — see limits) | `theme.css` |

## Filament stock and matching

| Value | Value found | Source |
|---|---|---|
| Spool fields | brand, material, line, colour name + hex, total grams, remaining grams, price | `filament-stock.js:337-360` |
| Quick weights | 250, 500, 1000, 2000 g | `filament-stock.js:10` |
| Status | `ok` (has the material in a close colour), `no-color` (has the material, not the colour), missing | `filament-stock.js:79-95` |
| Colour distance | CIE76 ΔE in Lab, matched when ΔE ≤ 25 | `filament-match.js:20-60` |
| Material match | normalised name: exact after upper-casing and stripping spaces/dashes (`PLA+` ≠ `PLA`, `PETG` = `petg`) | `filament-match.js:5-19` |
| Stock summary | sums remaining grams across spools | `filament-match.js:70-95` |

## Slicers

| Value | Value found | Source |
|---|---|---|
| Known slicers | Bambu Studio, OrcaSlicer, PrusaSlicer, UltiMaker Cura, Creality Print, Anycubic Slicer Next, ElegooSlicer, Orca-Flashforge, Snapmaker Orca, QIDIStudio, SuperSlicer | `slicers.js:11-25` |
| SVG-capable | every one except UltiMaker Cura and SuperSlicer | `slicers.js:13-24` |
| Detection | folder names in `Program Files`, `Program Files (x86)`, `%LOCALAPPDATA%\Programs`, plus the Windows uninstall registry; newest version first; one subfolder deep | `slicers.js:88-140` |
| Default choice | `system` = "Padrão do Windows" (open with the OS default) | `slicers.js:27-29` |
| Remembered slicer | the last one used per session | `app.js:14` |

## What Carinae 3D deliberately does differently

* Carinae 3D is a native Rust app (eframe/egui) instead of Electron, so it ships as one small
  `.exe` (and one Linux binary) with no Chromium.
* The original's account/login, "Em Alta" (trending models) list and online update check talk to
  its own web service. Carinae 3D has no such backend: the trending section explains this
  instead of showing a list it cannot fetch (`estimated` decision, not a value from the code).
* The original's font (Plus Jakarta Sans) is not embedded in this build; egui's default font is
  used, at a similar size and weight.
* Plate/print-time values come from the slicer's own metadata inside the 3MF; when a file was
  never sliced those fields stay empty, exactly as in the original.

## Pastas (folders) — added on request

The original deleted its own "Projetos" grouping (`app.js:75`, "Os Projetos (agrupar vários
Modelos num card) foram removidos"). The person asked for that idea back, so Carinae 3D has
**Pastas**: a name they choose ("Vasos", "Peças do carro"), shown in the sidebar with a count.

| What | How it works |
| --- | --- |
| Where a model is filed | one classification per model, by absolute path, stored in `settings.json` (`placement`) |
| Creating one | `Pastas ▸ +`, or type a name straight inside **Mover para uma pasta** |
| Filing | the ▤ **Pasta** button on every card, or **Classificar** in the preview |
| Renaming / removing a model | **Renomear** and **✕ Excluir** buttons on every card; Excluir goes to the system recycle bin |
| Ordering | favourites first, then the chosen sort — in the library and inside each folder |
| Duplicate names | kept apart, the second becomes "Vasos (2)" |
| Rename / delete | **Renomear** / **Excluir pasta** in the folder's own header |
| Filtering | clicking a folder shows only its models; "Mostrar todos" goes back |

## Configurações — the same cards as the library

The person asked for the settings page to be made of coloured cards too, like the library.
All four blocks ("Pastas conectadas", "Fatiadores encontrados", "Visualizador", "Sobre") are
drawn by `card_block` (`main.rs:3606`), one frame type used by every block:

| What | Value | Where |
| --- | --- | --- |
| Card fill | `theme::BG_CARD` `#0f161f` | `main.rs:3611` |
| Edge | 1 px `theme::LINE` `#1b232d` | `main.rs:3612` |
| Corners | 8 px, `theme::radius(8)` (the original's card radius) | `MECHANICS.md` look table |
| Inner margin | 14 px across, 12 px down | `main.rs:3614` |
| Title | 3x15 px `theme::ACCENT` bar, then the name at 13 px strong `theme::TEXT` | `main.rs:3619-3629` |
| Layout | two columns, `theme::PAD` (18 px) inset on both sides, 10.8 px gutter, so the four cards fit one 1300x820 window | `main.rs:2090-2091` |
| Slicer rows | `item_spacing.y = 2.0` inside that card; rows are 26 px (`interact_size.y`) + 8 px spacing by default, which pushed the eleventh slicer off the screen | `main.rs:2128` |
| Long paths | truncated to the room left on the card (`available_width / 5.x`), so nothing is pushed off the edge | `main.rs:2106`, `main.rs:2146` |

Measured on the check picture `shots\cfg.png` (1300x820): the four cards sit at
x 274..768 and 787..1281, y 146..735, all inside the window; card-coloured pixels cover 673 of
820 rows.
| The files themselves | **never moved, copied or deleted**; no directory is created on disk. Deleting a folder only drops the label, and labels of files that disappeared are pruned on the next scan |

Verified by `cargo test` (`store::tests::folders_name_classify_and_leave_the_files_alone`).

## Reading the pictures out of a model — what was missing

The person reported cards and previews saying *"não foi possível renderizar"*. The cause was in the
re-creation, not in the original: a Bambu Studio / OrcaSlicer project does not carry its geometry in
`3D/3dmodel.model`. That part holds only `<component p:path="/3D/Objects/<name>.model" objectid="…">`
entries, and the triangles live in the side parts. Reading just the main part therefore gave an empty
mesh. Confirmed on the person's own files with `probe3mf.py`: `rpi3b_desktop_completo.3mf`,
`placa-1-gabinete.3mf`, `placa-1-gabinete2.3mf`, `placa-2-acessorios.3mf`,
`GalaxyS20DexBox_hub_mesa1.3mf` and `GalaxyS20DexBox_hub_mesa2_tampa.3mf` all list components and no
triangles in the main part.

| What | How Carinae 3D does it now |
| --- | --- |
| Every part | every `*.model` entry of the package is parsed, keyed by its path with the leading `/` dropped, lower-cased |
| A component | its `p:path` (or `path`) selects the part, `objectid` the object, and `transform` is applied on top of the parent's |
| Depth | up to 8 levels of components, so a components-object inside a side part also resolves |
| Guard | a part path that is missing, or an object id that is not there, is skipped instead of failing the whole model |
| Test | `mesh::tests::a_component_can_point_at_another_model_part` — a package whose main part holds one component and whose side part holds one triangle must yield exactly 1 triangle |

Result on the six real files: 1 048 to 21 274 triangles each, none of them failing.

`svg` files used to show only a note. `src/svg.rs` now draws the drawing itself into the same RGBA
buffer the rasterizer produces: `<line>`, `<rect>`, `<circle>`, `<ellipse>`, `<polyline>`, `<polygon>`
and `<path>` (`M L H V C S Q T A Z`, relative and absolute). Curves go straight to their end point and
`transform=` on a group is ignored — honest limits of a preview, not of the original.

## The mark, and the duplicate rule — added on request

**The mark.** There is no picture file to keep in sync: the logo is *drawn by the program* in
`src/logo.rs`, so the sidebar badge, the window/taskbar icon and the file icon are all one artwork.
It is a rounded cyan tile with a diagonal gradient (sky `#29d9f0` at the top left to deep teal
`#084f66` at the bottom right), a radial glow behind the middle, an isometric cube in ink
`#edfaff` and a four-point star at the top right.

| Piece | Where | Size |
| --- | --- | --- |
| Drawing (gradient, glow, cube, star) | `logo::shade(x, y)` in `src/logo.rs`, unit square coordinates | vector, resolution-free |
| Anti-aliasing | `logo::rgba(size)` — 3×3 samples per pixel at ≥ 96 px, 4×4 below | any |
| Sidebar badge | `App::logo` texture, `logo::color_image(128)` | 26 px on screen, in the empty state 54 px |
| Window + taskbar icon | `.with_icon(egui::IconData { rgba: logo::rgba(64), … })` in `main()` | 64 px |
| File (Explorer) icon | `icon.ico`, written by `carinae-3d --write-icon icon.ico` | 7 sizes: 16, 24, 32, 48, 64, 128, 256 |
| Embedding the icon in the `.exe` | `build.rs` runs `windres -i icon.rc -o $OUT_DIR/…o` and links it (`1 ICON "icon.ico"`); on a machine without `windres` it prints a warning and still builds, just without the icon | — |
| Face shading | cube faces at 0.96 / 0.62 / 0.26 ink over the tile, so the three sides stay apart at 16 px | — |

Checked in the built binary: `RT_GROUP_ICON` "1" with seven `RT_ICON` entries, 32-bit each,
16×16 (785 B) … 256×256 (47 974 B), beside the manifest.

**Duplicates: only one of each group stays in the library.** The original listed every copy
(the group header read "N cópias"). The person asked not to accept duplicates at all, and
Carinae 3D does that without touching a single file on disk:

| Rule | How |
| --- | --- |
| Finding groups | `store::crc32_file` first (the installer's CRC-32) on files of equal size, then SHA-256 on what survives — `recompute_duplicates` |
| Which one stays | `App::choose_kept`: a favourite wins; then the oldest modification time; then the shortest path; then the name — identical on every scan, so the same card is kept |
| What the grid shows | `visible()` drops every member except the kept one, so the library (and each folder) shows one card per file content |
| Where the copies go | nowhere: they are listed on **Duplicados**, marked "no lugar" (kept) or with a **Lixeira** button each, plus one button that sends every hidden copy to the recycle bin |
| The count | the sidebar badge and the header pill count the copies *outside* the grid |
| Test | `store::tests::same_size_files_that_differ_are_not_duplicates`, plus the screenshot log line `models=11 na_grade=10 copias_ocultas=1` |

**The check run: `--screenshot <file.png>`.** A build is photographed after every change, so
this path has to work with nobody at the keyboard — and it used to hang for ever, which is
exactly what it did on a library of 368 real models.

| Rule | How |
| --- | --- |
| Draw first | at least 120 frames (`App::shot_frames`), repaint asked for every frame, because an unfocused window is told to stop drawing otherwise |
| Wait for the cards, but not for ever | `App::page_cards_ready` wants the first eight cards of the page in view; if the library is heavy the picture is taken anyway after 40 s (`shot_t0`) |
| Take the picture | `ViewportCommand::Screenshot` once (`shot_asked`), read back through `egui::Event::Screenshot`, `image::RgbaImage::save`, then `std::process::exit(0)` — a window left open would keep the caller waiting |
| No focus | `ViewportBuilder::with_active(false)`; on Windows also `WindowLevel::AlwaysOnBottom`; on macOS `with_activate_ignoring_other_apps(false)` through `NativeOptions::event_loop_builder` (winit, macOS only); never lowered on macOS or Linux, where a covered window may stop drawing |
| Same size every time | `NativeOptions::persist_window = shot.is_none()`, so a saved or maximised window is not carried into a check: 1300×820 |
| Why it hung before | the card pictures were rasterised on the drawing thread, three per frame; a 3MF with millions of triangles blocked a frame for seconds, so the frame count never arrived. They are now drawn on a worker thread (`ThumbJob` / `ThumbDone`), and the window only uploads what is ready |
| Measured | person's own library (368 models): 21.7 s, exit 0, 1300×820 PNG, 1 128 frames. Test library (11 models): 2.1 s, 122 frames. Empty library and a folder that does not exist: 2.4 s each |

## Cards that keep their picture, and a detail card — added on request

**Why the cards were empty squares.** A card picture that failed to come back was drawn as a flat
card-coloured rectangle, and nothing was kept between runs, so a slow or failed first read left a
blank card for ever. Four things changed:

| Rule | How |
| --- | --- |
| Two workers | `App::new` starts two threads that take `ThumbJob { idx, model, stamp }` and return `ThumbDone`, each wrapping `make_card(&job.model)` in `catch_unwind`, so one broken file cannot kill the thread |
| Keys for the cache | `thumb_stamp(path)` = path + size + modified; `thumb_cache_file(stamp)` = `%APPDATA%\Carinae3D\thumbs\{crc32(stamp):08x}{crc32(revision):08x}.{ext}` — the recovered installer CRC-32 is reused as the file name |
| Kept on disk | `thumb_cache_put` writes the PNG plus a `.txt` sidecar (`dims=…`, `sliced=…`); `thumb_cache_get` is read straight into a texture with no re-render |
| Retries | a picture that comes back empty is tried up to three times, 800 ms × try number apart (`thumb_tries`, `thumb_retry`) |
| Busy but smooth | at most six jobs in flight and twelve texture uploads a frame, and `request_repaint_after(80 ms)` while anything is pending |

**The detail card** (`App::viewer_ui`, `main.rs:2415`). An `egui::Area` id `viewer_card` at
`Order::Foreground`, anchored centre with half the sidebar width as an offset, so it sits inside the
page and a little narrower than the window. Behind it an `egui::Area` id `viewer_veil` at
`Order::Middle` fills the page with `from_black_alpha(150)` and a click on it closes the picture.
The card's own edge is `egui::Frame::NONE.fill(theme::BG_PANEL).stroke(1 px theme::LINE).corner_radius(10)`:
painting `ui.max_rect()` from inside the card covered the whole page (measured with `colour_map.py`,
which showed every cell as `?`), which is why the frame paints it instead.

| Rule | How |
| --- | --- |
| The picture is painted every frame | `ui.painter().image` from `Viewer::tex` on every frame; the renderer only runs when `needs_render`. Drawing it only on the frame that made it was the blinking |
| Slicer picture is opt-in | the `▣ Fatiador` button (`Viewer::show_plate`) swaps the drawn model for the slicer's own plate PNG, which is where words like "LEG" are baked into the picture |
| The facts get their own Ui | `ui.new_child(UiBuilder::new().max_rect(drect).layout(top_down))` with a `ScrollArea` inside. Inside the horizontal row the scroll area drew only its first row (measured: one text band at y 116..143 in `shots\viewer.png` and nothing below); with the child Ui `inkrows.py` counts 18 text bands from y 145 to y 743 |
| Everything the file carries | `mesh::Meta3mf::extras` — `add_extra` (skips empty, over 160 chars and duplicate keys, caps at 240), `plate_blocks` and `parse_slice_info` (a `<plate>` value becomes `Bandeja N · key`) and `project_extras` (the slicer's project settings, up to 80 top-level keys, arrays cut to six, booleans as sim/não, keyed `Fatiador · key`). Printed under "Tudo o que vem no ficheiro (N)" |
| Photographed without a mouse | `set CARINAE3D_OPEN=0` with `--screenshot` opens the first visible model before the picture is taken |
| Measured | test library 122 frames, 2.3 s; the person's 357-model library in release: 122 frames, 2.3 s — the pictures now come from the disk cache instead of being drawn again (it was 22.7 s, 1 189 frames before) |

