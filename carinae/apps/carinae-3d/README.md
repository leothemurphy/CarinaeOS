# Carinae 3D

A native re-creation of the Vault3D 3D-model library: it reads a folder full of
`.stl`, `.3mf` and `.svg` files, draws a picture of each one, and lets you open,
rename, file and print them.

Written in Rust with eframe/egui. One source tree builds on Windows and on Linux.

## Where to get it (instaladores)

After a release build, run `python makedist.py`. It fills the `dist\` folder:

| file | what it is |
| --- | --- |
| `dist\Carinae3D-1.6.0-windows-x64.exe` | the Windows program — double-click it, nothing to install |
| `dist\Carinae3D-1.6.0-windows-x64.zip` | the same program plus `LEIA-ME.txt`, as one download |
| `dist\Carinae3D-1.6.0-linux-fonte.zip` | source + `build-linux.sh` for Linux |

There is **no Linux binary**: the program is compiled on the machine that runs
it, because a Linux desktop program depends on the libraries of that
distribution. `build-linux.sh` checks them, tells you what to install and builds
`target/release/carinae-3d`.

## Build on Windows

Everything needed is already on this machine:

```
build.bat build --release
```

`build.bat` puts the MinGW-w64 UCRT compiler and Cargo on the PATH for you, so it
works from a plain command prompt. The program ends up in
`target\release\carinae-3d.exe`.

The first build downloads about 330 crates (eframe, image, zip, serde, sha2) and
takes a few minutes; later builds are quick.

## Build on Linux

Install the usual desktop packages eframe needs, then build:

```
sudo apt install build-essential pkg-config libxkbcommon-dev libwayland-dev \
                 libx11-dev libxcursor-dev libxrandr-dev libxi-dev libgl1-mesa-dev
./build-linux.sh
```

The result is `target/release/carinae-3d`. Nothing in the code is
Windows-only: the two platform differences (where settings live, and which
command opens a file or a folder in the desktop's file manager) are chosen at
compile time.

## Using it

1. **Conectar pasta** — point Carinae 3D at the folder(s) holding your models.
   It looks up to 12 folders deep and skips hidden folders, `node_modules`,
   `__MACOSX` and system folders.
2. **Pastas** (in the sidebar) are your own classifications — "Vasos",
   "Peças do carro", "Presentes". Make one with **+**. Every card carries its
   own row of buttons — **▤ Pasta**, **Renomear** and **✕ Excluir** — so filing,
   renaming and removing happen from the card itself. A model belongs to one
   folder at a time. This is a label kept in the app's settings: **the files on
   disk never move, and no folder is created on your disk**. Excluir sends the
   file to the system recycle bin, never into the void. Favourites are listed
   first, in the library and in each folder.
3. **Duplicados** finds files that are byte-identical (a CRC-32 of the whole file
   first, then SHA-256 when it is 2 MB or smaller, otherwise its size plus the
   first, middle and last 64 KB). **Only one of each group stays in the library**:
   a favourite wins, then the oldest file, then the shortest path. The other
   copies never appear in the grid — they wait on the **Duplicados** page, each
   with its own **Lixeira** button, behind a single button that sends them all to
   the recycle bin. Nothing is removed behind your back and nothing on disk moves.
4. **Filamentos** keeps your spools and tells you, for a sliced 3MF, whether you
   have enough of each colour in stock (a colour counts as a match at ΔE ≤ 25).
5. **Configurações** lists the slicers found on the computer and which one opens
   a model, plus the viewer toggles. Its blocks are cards in the same style as
   the library's, two by two, so the whole page fits one window.

Keys: `F5` refresh, `Esc` or the **✕ Fechar** button in the preview's title bar
closes the preview, `←`/`→` previous/next model, `Delete` send the open model to
the recycle bin.

### Pictures

A card's picture is a real render, made by the same rasterizer for every format:

* `.stl` — binary or ASCII.
* `.3mf` — the whole package is read, including the side parts Bambu Studio and
  OrcaSlicer write (`3D/Objects/*.model`) and reach through
  `<component p:path="…">`; a sliced project first shows its plate picture.
* `.svg` — the drawing itself is drawn (lines, rectangles, circles, ellipses,
  polygons and the `M/L/H/V/C/Q/A/Z` path commands) instead of a "vector file"
  note. Transforms on groups are ignored, so a rotated drawing may look straight.

## Where things are kept

Settings, favourites, spools and folders live in one JSON file:

* Windows: `%APPDATA%\Carinae3D\settings.json`
* Linux: `$XDG_CONFIG_HOME/carinae-3d/settings.json` (usually
  `~/.config/carinae-3d/settings.json`)

Set `CARINAE3D_CONFIG_DIR` to use another folder (handy for a portable copy or
for testing).

## The mark

The logo is **drawn by the program**, not loaded from a picture file
(`src/logo.rs`): a rounded cyan tile with a diagonal gradient, a soft glow, a
light isometric cube and a four-point star. One drawing feeds the sidebar badge,
the window and taskbar icon, and the file icon.

`icon.ico` (16, 24, 32, 48, 64, 128 and 256 px) is written by the program
itself:

```
carinae-3d --write-icon icon.ico
```

`build.rs` then hands it to `windres` and links it into the `.exe`, which is what
makes Explorer show it. On a machine without `windres` the build still succeeds,
just without the file icon.

## Checking it without a person at the keyboard

```
carinae-3d --screenshot out.png
```

Starts, draws about 120 frames of the library, writes the picture and quits. It is
how the layout was checked while building it. The window opens **without taking
focus** (`with_active(false)`, and on Windows behind everything), so a check never
steals the keyboard from whoever is using the computer; it keeps drawing while it
is unfocused, which is what makes the picture possible. A picture is never held up
for more than 40 seconds, even when the library holds hundreds of heavy models,
and the window size is fixed at 1300×820 for a check (a saved window size is not
carried over). Card pictures are drawn on a background thread, so a two-million
triangle model can no longer freeze the window while it is being drawn.

`CARINAE3D_START_SECTION=duplicados` (also `favoritos`, `filamentos`,
`configuracoes`) opens that page first, so any page can be photographed the same
way. `CARINAE3D_DUMP_MODELS=1` adds one line per model with its triangle count to
the log; it reads every file, so it is off unless asked for.

## What it does differently from the original

`MECHANICS.md` lists every behaviour taken from the original (with the file and
line it was read from) and every place this rebuild deliberately differs — the
main one being that there is no online service behind it, so "Em Alta" is
explained instead of filled with invented data.
