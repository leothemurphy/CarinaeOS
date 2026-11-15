//! Carinae 3D — a 3D model vault, rebuilt as a native Rust app.
//! Behaviour and look follow the original Electron app; see MECHANICS.md.

// No console window: on Windows the program links as a GUI app, so double
// clicking the .exe opens only the window. Output still reaches a file when
// the program is started with a redirection (`app.exe > run.log`).
#![cfg_attr(windows, windows_subsystem = "windows")]

mod filaments;
mod logo;
mod mesh;
mod render;
mod slicers;
mod store;
mod svg;
mod theme;

use eframe::egui::{
    self, Align2, Color32, FontId, Pos2, Rect, Sense, Stroke, StrokeKind, TextureHandle,
    TextureOptions, UserData, Vec2, ViewportCommand,
};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{Receiver, Sender, TryRecvError};
use store::Model;

// ---------------------------------------------------------------- state

#[derive(PartialEq, Clone, Copy, Debug)]
enum Section {
    All,
    Favorites,
    Duplicates,
    Filaments,
    Settings,
}

impl Section {
    /// The names `--section` accepts, so a screenshot can be taken of any page.
    fn parse(s: &str) -> Option<Section> {
        match s.trim().to_lowercase().as_str() {
            "all" | "todos" | "biblioteca" => Some(Section::All),
            "favorites" | "favoritos" => Some(Section::Favorites),
            "duplicates" | "duplicados" => Some(Section::Duplicates),
            "filaments" | "filamentos" => Some(Section::Filaments),
            "settings" | "configuracoes" | "configurações" => Some(Section::Settings),
            _ => None,
        }
    }
}

#[derive(PartialEq, Clone, Copy, Debug)]
enum Filter {
    All,
    Stl,
    ThreeMf,
    Svg,
}

#[derive(Clone, Debug, Default)]
struct Loaded {
    mesh: mesh::Mesh,
    meta: mesh::Meta3mf,
    plates: Vec<(mesh::Plate, mesh::Mesh)>,
    plate_pngs: Vec<Option<egui::ColorImage>>,
    error: Option<String>,
    svg_dims: Option<[f32; 3]>,
    /// The SVG drawn into an RGBA buffer, ready to become a texture.
    svg_rgba: Option<(usize, usize, Vec<u8>)>,
}

/// What a card shows besides the picture, read once when its thumbnail is made.
#[derive(Clone, Debug, Default)]
struct CardInfo {
    sliced: bool,
    dims: Option<[f32; 3]>,
}

/// One thumbnail to draw, handed to the worker thread. Rendering a card can take
/// seconds for a heavy model, so it never runs on the thread that draws the window.
struct ThumbJob {
    idx: usize,
    key: String,
    /// Path, size and date: what the saved picture is filed under.
    stamp: String,
    model: Model,
}

/// A finished card, coming back from the worker.
struct ThumbDone {
    idx: usize,
    key: String,
    stamp: String,
    img: Option<egui::ColorImage>,
    info: CardInfo,
}

/// Buttons clicked on a card this frame.
#[derive(Clone, Copy, Debug, Default)]
struct CardActs {
    star: Option<usize>,
    assign: Option<usize>,
    slicer: Option<usize>,
    rename: Option<usize>,
    delete: Option<usize>,
    /// The card index whose small button was hit, so the big card doesn't also open.
    touch: Option<usize>,
}

struct Viewer {
    idx: usize,
    loaded: Loaded,
    cam: render::Camera,
    auto_rotate: bool,
    wireframe: bool,
    plate: usize,
    /// Show the slicer's own plate picture instead of the model drawn here.
    show_plate: bool,
    tex: Option<TextureHandle>,
    needs_render: bool,
    tick: u64,
    plate_tex: Vec<Option<TextureHandle>>,
    ask_trash: bool,
}

enum Dialog {
    None,
    ConnectFolder(String),
    Rename(PathBuf, String),
    Move(PathBuf, String, String),
    Trash(Vec<PathBuf>),
    Spool(Box<filaments::Spool>, Option<String>),
    /// A new folder name being typed.
    NewColl(String),
    /// Renaming: id, text being typed.
    RenameColl(String, String),
    /// Which folder to file a model into: paths, name being typed for a new one.
    Assign(Vec<PathBuf>, String),
}

struct App {
    settings: store::Settings,
    models: Vec<Model>,
    section: Section,
    filter: Filter,
    search: String,
    page: usize,
    sort: String,
    page_size: usize,
    dups: HashMap<String, Vec<usize>>,
    thumb: HashMap<String, Option<TextureHandle>>,
    info: HashMap<String, CardInfo>,
    thumb_queue: Vec<usize>,
    open: Option<Viewer>,
    toast: Option<(String, f64)>,
    slicers: Vec<slicers::Slicer>,
    dialog: Dialog,
    last_slicer: String,
    shot_path: Option<PathBuf>,
    shot_frames: u32,
    /// When the picture was asked for, so a heavy library can't hold it up for ever.
    shot_t0: std::time::Instant,
    /// True once the picture has been requested, so it isn't asked for twice.
    shot_asked: bool,
    /// Cards are drawn on worker threads; the window only uploads what is ready.
    thumb_tx: Vec<Sender<ThumbJob>>,
    thumb_next: usize,
    thumb_rx: Receiver<ThumbDone>,
    /// Keys already sent to the worker, so no card is drawn twice.
    thumb_busy: std::collections::HashSet<String>,
    /// How many times a card that came back empty has been tried again.
    thumb_tries: HashMap<String, u8>,
    /// Cards to try again, and when: a drive that is still waking up can lose
    /// the first read, and a card must not stay blank for the whole session.
    thumb_retry: Vec<(std::time::Instant, usize, String)>,
    expand_folders: Vec<String>,
    hover: Option<usize>,
    /// Which of the person's own folders (classifications) is being shown, if any.
    coll: Option<String>,
    /// The mark, rendered once by `logo` and reused everywhere it is shown.
    logo: Option<TextureHandle>,
    /// One model per copy group is kept on the shelf; these are the extra files,
    /// which the grid hides so a duplicate never shows up twice.
    dup_hidden: std::collections::HashSet<usize>,
    /// For each copy group, the model that stays — its favourite, else the oldest.
    dup_keep: HashMap<String, usize>,
}

impl App {
    fn new(cc: &eframe::CreationContext<'_>, shot_path: Option<PathBuf>) -> App {
        theme::apply(&cc.egui_ctx);
        symbol_fallback(&cc.egui_ctx);
        let settings = store::Settings::load();
        let page_size = settings.page_size;
        let sort = settings.sort.clone();
        // The card pictures are drawn off the UI thread. A 3MF with two million
        // triangles takes seconds to rasterise; doing that between frames froze
        // the window (and stopped `--screenshot` from ever taking its picture).
        // Two workers, so a library full of heavy files still fills in quickly.
        let (done_tx, thumb_rx) = std::sync::mpsc::channel::<ThumbDone>();
        let mut thumb_tx: Vec<Sender<ThumbJob>> = Vec::new();
        for _ in 0..2 {
            let (tx, job_rx) = std::sync::mpsc::channel::<ThumbJob>();
            thumb_tx.push(tx);
            let done_tx = done_tx.clone();
            let worker_ctx = cc.egui_ctx.clone();
            std::thread::spawn(move || {
                while let Ok(job) = job_rx.recv() {
                    // A file that makes the reader panic must never take the
                    // worker down with it: that leaves every later card blank.
                    let (img, info) = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                        make_card(&job.model)
                    }))
                    .unwrap_or_else(|_| (None, CardInfo::default()));
                    let done = ThumbDone {
                        idx: job.idx,
                        key: job.key,
                        stamp: job.stamp,
                        img,
                        info,
                    };
                    if done_tx.send(done).is_err() {
                        break;
                    }
                    // A finished card is worth a frame, even in a window nobody touched.
                    worker_ctx.request_repaint();
                }
            });
        }
        let mut app = App {
            settings,
            models: Vec::new(),
            section: Section::All,
            filter: Filter::All,
            search: String::new(),
            page: 0,
            sort,
            page_size,
            dups: HashMap::new(),
            thumb: HashMap::new(),
            info: HashMap::new(),
            thumb_queue: Vec::new(),
            open: None,
            toast: None,
            slicers: slicers::detect(),
            dialog: Dialog::None,
            last_slicer: String::new(),
            shot_path,
            shot_frames: 0,
            shot_t0: std::time::Instant::now(),
            shot_asked: false,
            thumb_tx,
            thumb_next: 0,
            thumb_rx,
            thumb_busy: std::collections::HashSet::new(),
            thumb_tries: HashMap::new(),
            thumb_retry: Vec::new(),
            expand_folders: Vec::new(),
            hover: None,
            coll: None,
            logo: Some(cc.egui_ctx.load_texture(
                "carinae-logo",
                logo::color_image(logo::PX),
                TextureOptions::LINEAR,
            )),
            dup_hidden: std::collections::HashSet::new(),
            dup_keep: HashMap::new(),
        };
        app.rescan();
        if let Ok(name) = std::env::var("CARINAE3D_START_SECTION") {
            if let Some(s) = Section::parse(&name) {
                app.section = s;
            }
        }
        if app.shot_path.is_some() {
            // `CARINAE3D_OPEN=<n>` opens the n-th card of the page, so a screenshot
            // run can photograph the detail window without a mouse.
            if let Ok(which) = std::env::var("CARINAE3D_OPEN") {
                let vis = app.visible();
                let pick = which.trim().parse::<usize>().unwrap_or(0);
                if let Some(&idx) = vis.get(pick) {
                    let ctx = cc.egui_ctx.clone();
                    app.open_viewer(idx, &ctx);
                }
            }
            eprintln!(
                "[carinae] config={:?} folders={:?} models={} na_grade={} copias_ocultas={} duplicados={} pastas={:?}",
                store::config_dir(),
                app.settings.folders,
                app.models.len(),
                app.visible().len(),
                app.dup_hidden.len(),
                app.dups.values().filter(|g| g.len() > 1).count(),
                app.settings
                    .collections
                    .iter()
                    .map(|c| format!(
                        "{}={}",
                        c.name,
                        app.models
                            .iter()
                            .filter(|m| app.settings.collection_of(&m.path) == Some(c.id.as_str()))
                            .count()
                    ))
                    .collect::<Vec<_>>()
            );
            // The per-model dump reads every file and prints what is inside it. It is
            // a diagnostic, not part of the picture: on a library of a few hundred big
            // models it alone took minutes, which is why it is opt-in.
            if std::env::var("CARINAE3D_DUMP_MODELS").is_ok() {
                for m in &app.models {
                    let loaded = load_model(&m.path, &m.ext);
                    let note = match &loaded.error {
                        Some(e) => format!("erro={e}"),
                        None => format!(
                            "tris={} verts={} bandejas={}",
                            loaded.mesh.tris,
                            loaded.mesh.pos.len(),
                            loaded.plates.len()
                        ),
                    };
                    eprintln!(
                        "[carinae]   {:?} ext={} size={} png={} {note}",
                        m.path,
                        m.ext,
                        m.size,
                        if loaded.svg_rgba.is_some() { "sim" } else { "nao" }
                    );
                }
            }
        }
        app
    }

    fn rescan(&mut self) {
        self.models = store::scan(&self.settings.folders);
        self.models.sort_by(|a, b| a.path.cmp(&b.path));
        self.recompute_duplicates();
        // A file that has gone takes its folder label with it, so the counts stay true.
        let alive: Vec<String> = self
            .models
            .iter()
            .map(|m| m.path.to_string_lossy().to_string())
            .collect();
        self.settings.prune_placement(&alive);
        self.thumb.clear();
        self.info.clear();
        self.thumb_busy.clear();
        // Cards are drawn in the order the grid shows them, so the page in view is
        // ready first instead of after every other file in the library.
        self.thumb_queue = self.visible();
        self.page = 0;
        let n = self.models.len();
        self.notify(format!("Biblioteca atualizada: {n} modelos"));
    }

    fn recompute_duplicates(&mut self) {
        self.dups.clear();
        if self.models.is_empty() {
            return;
        }
        let mut by_size: HashMap<u64, Vec<usize>> = HashMap::new();
        for (i, m) in self.models.iter().enumerate() {
            by_size.entry(m.size).or_default().push(i);
        }
        for (_, idxs) in by_size {
            if idxs.len() < 2 {
                continue;
            }
            // Same size is cheap to check; the original's CRC-32 (0x406787) then
            // throws out files that only share a length, before the SHA-256 pass.
            let mut by_crc: HashMap<u32, Vec<usize>> = HashMap::new();
            for i in idxs {
                match store::crc32_file(&self.models[i].path) {
                    Some(c) => by_crc.entry(c).or_default().push(i),
                    // Unreadable file: leave it out rather than call it a duplicate.
                    None => continue,
                }
            }
            let mut by_hash: HashMap<String, Vec<usize>> = HashMap::new();
            for (_, group) in by_crc {
                if group.len() < 2 {
                    continue;
                }
                for i in group {
                    if let Some(fp) = store::fingerprint(&self.models[i].path) {
                        by_hash.entry(fp).or_default().push(i);
                    }
                }
            }
            for (fp, group) in by_hash {
                if group.len() > 1 {
                    self.dups.insert(fp, group);
                }
            }
        }
        self.choose_kept();
    }

    /// A duplicate is not accepted: out of each group of identical files exactly
    /// one stays on the shelf, and the rest are kept off the grid. Nothing on
    /// disk is touched — the extra copies stay where they are until the person
    /// sends one to the recycle bin from the Duplicados page.
    ///
    /// Which one stays, in order: the one they marked a favourite; then the
    /// oldest, which is usually the first copy that was saved; then the shortest
    /// path, so the choice never depends on the order the folder was scanned.
    fn choose_kept(&mut self) {
        self.dup_keep.clear();
        self.dup_hidden.clear();
        let groups: Vec<(String, Vec<usize>)> =
            self.dups.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        for (fp, group) in groups {
            let key = |i: &usize| {
                let m = &self.models[*i];
                (
                    !self.settings.is_favorite(&m.path),
                    store::sort_key_time(m.modified),
                    m.path.to_string_lossy().len(),
                    m.path.to_string_lossy().to_string(),
                )
            };
            let kept = match group.iter().min_by_key(|i| key(i)) {
                Some(i) => *i,
                None => continue,
            };
            self.dup_keep.insert(fp, kept);
            for i in &group {
                if *i != kept {
                    self.dup_hidden.insert(*i);
                }
            }
        }
    }

    /// The copies in one group, the kept one first.
    fn dup_group_sorted(&self, idxs: &[usize], fp: &str) -> Vec<usize> {
        let kept = self.dup_keep.get(fp).cloned();
        let mut out: Vec<usize> = idxs.to_vec();
        out.sort_by_key(|i| (Some(*i) != kept, *i));
        out
    }

    fn notify(&mut self, text: String) {
        self.toast = Some((text, 0.0));
    }

    // ------------------------------------------------------------ listing

    fn sort_models(&self, list: &mut Vec<usize>) {
        match self.sort.as_str() {
            "date_asc" => list.sort_by_key(|i| store::sort_key_time(self.models[*i].modified)),
            "name_asc" => list.sort_by(|a, b| self.models[*a].name.to_lowercase().cmp(&self.models[*b].name.to_lowercase())),
            "name_desc" => list.sort_by(|a, b| self.models[*b].name.to_lowercase().cmp(&self.models[*a].name.to_lowercase())),
            "size_desc" => list.sort_by(|a, b| self.models[*b].size.cmp(&self.models[*a].size)),
            "size_asc" => list.sort_by(|a, b| self.models[*a].size.cmp(&self.models[*b].size)),
            _ => list.sort_by_key(|i| std::cmp::Reverse(store::sort_key_time(self.models[*i].modified))),
        }
        // Favourites always sit at the top of the grid, as in the original; the
        // sort above still decides the order inside each of the two groups.
        list.sort_by_key(|i| !self.settings.is_favorite(&self.models[*i].path));
    }

    fn visible(&self) -> Vec<usize> {
        let q = self.search.trim().to_lowercase();
        let mut out: Vec<usize> = self
            .models
            .iter()
            .enumerate()
            .filter(|(i, m)| {
                if !q.is_empty() && !m.name.to_lowercase().contains(&q) {
                    return false;
                }
                match self.section {
                    Section::Favorites => return self.settings.is_favorite(&m.path),
                    Section::Duplicates => {
                        return self.dups.values().any(|g| g.contains(i));
                    }
                    _ => {}
                }
                // A duplicate is not shown twice: one card per group stays and
                // the extra copies wait on the Duplicados page.
                if self.dup_hidden.contains(i) {
                    return false;
                }
                if let Some(cid) = &self.coll {
                    if self.settings.collection_of(&m.path) != Some(cid.as_str()) {
                        return false;
                    }
                }
                match self.filter {
                    Filter::All => true,
                    Filter::Stl => m.ext == "stl",
                    Filter::ThreeMf => m.ext == "3mf",
                    Filter::Svg => m.ext == "svg",
                }
            })
            .map(|(i, _)| i)
            .collect();
        self.sort_models(&mut out);
        out
    }

    fn counts(&self) -> (usize, usize, usize, usize) {
        let stl = self.models.iter().filter(|m| m.ext == "stl").count();
        let tmf = self.models.iter().filter(|m| m.ext == "3mf").count();
        let svg = self.models.iter().filter(|m| m.ext == "svg").count();
        let dups = self.dup_hidden.len();
        (stl, tmf, svg, dups)
    }

    // ------------------------------------------------------------ thumbnails

    /// Takes the cards the worker finished and asks it for the ones the grid needs.
    /// Both halves are cheap: an upload here, a message there.
    fn pump_thumbs(&mut self, ctx: &egui::Context) {
        let mut uploads = 0;
        loop {
            match self.thumb_rx.try_recv() {
                Ok(done) => {
                    self.thumb_busy.remove(&done.key);
                    match done.img {
                        Some(ci) => {
                            let tex = ctx.load_texture(
                                format!("thumb{}", done.idx),
                                ci.clone(),
                                TextureOptions::LINEAR,
                            );
                            // Filed away, so the next run opens with pictures already.
                            thumb_cache_put(&done.stamp, &ci, &done.info);
                            self.thumb.insert(done.key.clone(), Some(tex));
                            self.info.insert(done.key, done.info);
                        }
                        None => {
                            // Reading a card can fail once (a drive still waking
                            // up, a file another program has open). Try again in a
                            // moment instead of leaving that card blank for ever.
                            let tries = {
                                let t = self.thumb_tries.entry(done.key.clone()).or_insert(0);
                                *t += 1;
                                *t
                            };
                            if tries <= 3 {
                                self.thumb_retry.push((
                                    std::time::Instant::now()
                                        + std::time::Duration::from_millis(800 * tries as u64),
                                    done.idx,
                                    done.key.clone(),
                                ));
                            } else {
                                self.thumb.insert(done.key.clone(), None);
                            }
                            self.info.insert(done.key, done.info);
                        }
                    }
                    uploads += 1;
                    if uploads >= 12 {
                        break;
                    }
                }
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => break,
            }
        }

        // While cards are still coming, ask for frames: a window nobody touches
        // is otherwise only drawn when the mouse moves.
        if !self.thumb_queue.is_empty() || !self.thumb_busy.is_empty() || !self.thumb_retry.is_empty()
        {
            ctx.request_repaint_after(std::time::Duration::from_millis(80));
        }

        // The ones whose second chance has come.
        if !self.thumb_retry.is_empty() {
            let now = std::time::Instant::now();
            let mut later: Vec<(std::time::Instant, usize, String)> = Vec::new();
            for (at, idx, key) in std::mem::take(&mut self.thumb_retry) {
                if at > now {
                    later.push((at, idx, key));
                } else if let Some(i) = self
                    .models
                    .iter()
                    .position(|m| m.path.to_string_lossy() == key)
                {
                    self.thumb_queue.push(i);
                }
            }
            self.thumb_retry = later;
        }

        // Keep the workers busy, but never queue the whole library at once.
        while self.thumb_busy.len() < 6 && !self.thumb_queue.is_empty() {
            let idx = self.thumb_queue.remove(0);
            if idx >= self.models.len() {
                continue;
            }
            let key = self.models[idx].path.to_string_lossy().to_string();
            if self.thumb.contains_key(&key) || self.thumb_busy.contains(&key) {
                continue;
            }
            let stamp = thumb_stamp(&self.models[idx]);
            // A picture drawn on an earlier run is put up at once.
            if let Some((ci, info)) = thumb_cache_get(&stamp) {
                let tex = ctx.load_texture(format!("thumb{}", idx), ci, TextureOptions::LINEAR);
                self.thumb.insert(key.clone(), Some(tex));
                self.info.insert(key, info);
                continue;
            }
            let job = ThumbJob {
                idx,
                key: key.clone(),
                stamp,
                model: self.models[idx].clone(),
            };
            if self.thumb_tx.is_empty() {
                break;
            }
            let which = self.thumb_next % self.thumb_tx.len();
            self.thumb_next = self.thumb_next.wrapping_add(1);
            if self.thumb_tx[which].send(job).is_err() {
                break;
            }
            self.thumb_busy.insert(key);
        }
    }

    /// True once the cards on the page in view have pictures, so a screenshot
    /// taken now shows a real library instead of empty tiles.
    fn page_cards_ready(&self) -> bool {
        let want = self.page_size.clamp(1, 8);
        let vis = self.visible();
        let start = self.page * self.page_size;
        let end = (start + self.page_size).min(vis.len());
        if start >= end {
            return true;
        }
        let ready = (start..end)
            .filter(|i| {
                self.thumb
                    .contains_key(&self.models[*i].path.to_string_lossy().to_string())
            })
            .count();
        ready >= want.min(end - start)
    }

    /// The label the card's slicer button shows.
    fn slicer_label(&self) -> String {
        match self.settings.default_slicer.as_str() {
            "system" | "" => "Abrir".to_string(),
            id => self
                .slicers
                .iter()
                .find(|s| s.id == id)
                .map(|s| s.name.split_whitespace().next().unwrap_or("Abrir").to_string())
                .unwrap_or_else(|| "Abrir".to_string()),
        }
    }

    /// Opens the folder picker for these files.
    fn ask_assign(&mut self, paths: Vec<PathBuf>) {
        self.dialog = Dialog::Assign(paths, String::new());
    }

    /// Sends a model to whichever slicer the person chose in the settings.
    fn open_in_slicer(&mut self, idx: usize) {
        if idx >= self.models.len() {
            return;
        }
        let path = self.models[idx].path.clone();
        let ext = self.models[idx].ext.clone();
        let slicer_id = self.settings.default_slicer.clone();
        let res = if slicer_id == "system" || slicer_id.is_empty() {
            slicers::open_system(&path)
        } else if ext == "svg" {
            match self.slicers.iter().find(|s| s.id == slicer_id) {
                Some(s) if s.svg => slicers::open_with(s, &path),
                Some(s) => Err(format!("{} não abre SVG", s.name)),
                None => Err("fatiador não encontrado".into()),
            }
        } else {
            match self.slicers.iter().find(|s| s.id == slicer_id) {
                Some(s) => slicers::open_with(s, &path),
                None => Err("fatiador não encontrado".into()),
            }
        };
        match res {
            Ok(()) => self.notify(format!("Abrindo {}", self.models[idx].name)),
            Err(e) => self.notify(format!("Não foi possível abrir: {e}")),
        }
    }
}

// ---------------------------------------------------------------- helpers

fn ui_rect(painter: &egui::Painter, rect: Rect, fill: Color32, stroke: Option<Color32>, r: u8) {
    painter.rect_filled(rect, theme::radius(r), fill);
    if let Some(c) = stroke {
        painter.rect_stroke(
            rect,
            theme::radius(r),
            Stroke::new(1.0_f32, c),
            StrokeKind::Inside,
        );
    }
}

fn chip(painter: &egui::Painter, pos: Pos2, text: &str, fg: Color32, bg: Color32) -> Rect {
    let galley = painter.layout_no_wrap(text.to_string(), FontId::proportional(10.5), fg);
    let pad = Vec2::new(6.0, 3.0);
    let rect = Rect::from_min_size(pos, galley.size() + pad * 2.0);
    painter.rect_filled(rect, theme::radius(4), bg);
    painter.galley(rect.min + pad, galley, fg);
    rect
}

fn dot(painter: &egui::Painter, center: Pos2, r: f32, color: Color32) {
    painter.circle_filled(center, r + 1.5, Color32::from_black_alpha(90));
    painter.circle_filled(center, r, color);
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        let t: String = s.chars().take(max.saturating_sub(1)).collect();
        format!("{t}…")
    }
}

fn make_card(m: &Model) -> (Option<egui::ColorImage>, CardInfo) {
    let w = 240usize;
    let h = 160usize;
    let bg = [theme::BG_CARD.r(), theme::BG_CARD.g(), theme::BG_CARD.b()];
    let mut info = CardInfo::default();
    match m.ext.as_str() {
        "stl" => {
            let data = match std::fs::read(&m.path) {
                Ok(d) => d,
                Err(_) => return (None, info),
            };
            let parsed = match mesh::parse_stl(&data) {
                Ok(p) => p,
                Err(_) => return (None, info),
            };
            info.dims = Some(parsed.dims());
            let rgba = render::render(
                &parsed,
                w,
                h,
                &render::Camera::default(),
                false,
                bg,
                theme::MODEL_TINT,
            );
            (
                Some(egui::ColorImage::from_rgba_unmultiplied([w, h], &rgba)),
                info,
            )
        }
        "3mf" => {
            let data = match std::fs::read(&m.path) {
                Ok(d) => d,
                Err(_) => return (None, info),
            };
            let t = mesh::read_3mf(&data).ok();
            if let Some(t) = &t {
                info.dims = Some(t.mesh.dims());
                info.sliced = t.meta.sliced || t.plates.iter().any(|(p, _)| p.seconds.is_some());
            }
            if let Some(png) = mesh::read_3mf_plate_png(&data, 1) {
                if let Some(ci) = decode_png(&png) {
                    return (Some(ci), info);
                }
            }
            match t {
                Some(t) => {
                    let rgba = render::render(
                        &t.mesh,
                        w,
                        h,
                        &render::Camera::default(),
                        false,
                        bg,
                        theme::MODEL_TINT,
                    );
                    (Some(egui::ColorImage::from_rgba_unmultiplied([w, h], &rgba)), info)
                }
                None => (None, info),
            }
        }
        "svg" => {
            if let Ok(text) = std::fs::read_to_string(&m.path) {
                let d = mesh::parse_svg_size(&text);
                if d[0] > 0.0 && d[1] > 0.0 {
                    info.dims = Some(d);
                }
                // draw the drawing itself, so the card shows the real picture
                if let Some(rgba) = svg::preview(
                    &text,
                    w,
                    h,
                    bg,
                    [
                        theme::SVG.r(),
                        theme::SVG.g(),
                        theme::SVG.b(),
                    ],
                ) {
                    return (
                        Some(egui::ColorImage::from_rgba_unmultiplied([w, h], &rgba)),
                        info,
                    );
                }
            }
            (None, info)
        }
        _ => (None, info),
    }
}

fn decode_png(bytes: &[u8]) -> Option<egui::ColorImage> {
    let img = image::load_from_memory(bytes).ok()?.to_rgba8();
    let (w, h) = (img.width() as usize, img.height() as usize);
    Some(egui::ColorImage::from_rgba_unmultiplied(
        [w, h],
        &img.into_raw(),
    ))
}

/// What a card picture is filed under: the path plus its size and date, so a file
/// that changed gets drawn again and one that hasn't is taken from the shelf.
fn thumb_stamp(m: &Model) -> String {
    let when = m
        .modified
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("{}|{}|{}", m.path.to_string_lossy(), m.size, when)
}

/// Where a drawn card is kept between runs (`%APPDATA%\Carinae3D\thumbs`).
fn thumb_cache_file(stamp: &str, ext: &str) -> Option<PathBuf> {
    let backwards: Vec<u8> = stamp.bytes().rev().collect();
    let a = store::crc32(stamp.as_bytes());
    let b = store::crc32(&backwards);
    let dir = store::config_dir().join("thumbs");
    std::fs::create_dir_all(&dir).ok()?;
    Some(dir.join(format!("{a:08x}{b:08x}.{ext}")))
}

/// The picture drawn for this exact file an earlier time, if it is still there.
fn thumb_cache_get(stamp: &str) -> Option<(egui::ColorImage, CardInfo)> {
    let bytes = std::fs::read(thumb_cache_file(stamp, "png")?).ok()?;
    let ci = decode_png(&bytes)?;
    let mut info = CardInfo::default();
    if let Some(note) = thumb_cache_file(stamp, "txt") {
        if let Ok(text) = std::fs::read_to_string(note) {
            for line in text.lines() {
                if let Some(v) = line.strip_prefix("dims=") {
                    let n: Vec<f32> = v.split(',').filter_map(|t| t.trim().parse().ok()).collect();
                    if n.len() == 3 {
                        info.dims = Some([n[0], n[1], n[2]]);
                    }
                } else if let Some(v) = line.strip_prefix("sliced=") {
                    info.sliced = v.trim() == "1";
                }
            }
        }
    }
    Some((ci, info))
}

/// Keep a drawn card for the next time the app opens.
fn thumb_cache_put(stamp: &str, img: &egui::ColorImage, info: &CardInfo) {
    let Some(png) = thumb_cache_file(stamp, "png") else {
        return;
    };
    let [w, h] = img.size;
    let mut rgba = Vec::with_capacity(img.pixels.len() * 4);
    for p in &img.pixels {
        rgba.extend_from_slice(&[p.r(), p.g(), p.b(), p.a()]);
    }
    if let Some(buf) = image::RgbaImage::from_raw(w as u32, h as u32, rgba) {
        let _ = buf.save(&png);
    }
    if let Some(note) = thumb_cache_file(stamp, "txt") {
        let mut text = String::new();
        if let Some(d) = info.dims {
            text.push_str(&format!("dims={},{},{}\n", d[0], d[1], d[2]));
        }
        text.push_str(&format!("sliced={}\n", if info.sliced { 1 } else { 0 }));
        let _ = std::fs::write(note, text);
    }
}

fn load_model(path: &Path, ext: &str) -> Loaded {
    let mut out = Loaded::default();
    match std::fs::read(path) {
        Ok(data) => match ext {
            "stl" => match mesh::parse_stl(&data) {
                Ok(m) => out.mesh = m,
                Err(e) => out.error = Some(e),
            },
            "3mf" => match mesh::read_3mf(&data) {
                Ok(t) => {
                    out.mesh = t.mesh;
                    out.meta = t.meta;
                    for (p, _m) in t.plates.iter().enumerate() {
                        let png = mesh::read_3mf_plate_png(&data, p as u32 + 1)
                            .as_deref()
                            .and_then(decode_png);
                        out.plate_pngs.push(png);
                    }
                    out.plates = t.plates;
                }
                Err(e) => out.error = Some(e),
            },
            "svg" => {
                let text = String::from_utf8_lossy(&data).to_string();
                let mut dims = mesh::parse_svg_size(&text);
                if dims[0] <= 0.0 || dims[1] <= 0.0 {
                    if let Some([w, h]) = svg::size(&text) {
                        dims = [w, h, 0.0];
                    }
                }
                out.svg_dims = Some(dims);
                out.svg_rgba = svg::preview(
                    &text,
                    640,
                    460,
                    [theme::BG_CARD.r(), theme::BG_CARD.g(), theme::BG_CARD.b()],
                    [theme::SVG.r(), theme::SVG.g(), theme::SVG.b()],
                )
                .map(|rgba| (640usize, 460usize, rgba));
                if out.svg_rgba.is_none() {
                    out.error = Some("desenho sem formas que se possam mostrar".into());
                }
            }
            _ => out.error = Some("formato desconhecido".into()),
        },
        Err(e) => out.error = Some(format!("não foi possível ler o arquivo: {e}")),
    }
    out
}

fn send_to_trash(path: &Path) -> Result<(), String> {
    #[cfg(windows)]
    {
        let ps = format!(
            "$p='{}'; Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p,'OnlyErrorDialogs','SendToRecycleBin')",
            path.display().to_string().replace('\'', "''")
        );
        let status = std::process::Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", &ps])
            .status()
            .map_err(|e| e.to_string())?;
        if status.success() {
            Ok(())
        } else {
            Err("a lixeira do Windows recusou o arquivo".into())
        }
    }
    #[cfg(not(windows))]
    {
        let home = std::env::var("HOME").map_err(|_| "sem HOME".to_string())?;
        let base = PathBuf::from(home).join(".local/share/Trash");
        let files = base.join("files");
        let info = base.join("info");
        std::fs::create_dir_all(&files).map_err(|e| e.to_string())?;
        std::fs::create_dir_all(&info).map_err(|e| e.to_string())?;
        let name = path
            .file_name()
            .ok_or("arquivo sem nome")?
            .to_string_lossy()
            .to_string();
        let mut target = files.join(&name);
        let mut n = 1;
        while target.exists() {
            target = files.join(format!("{name}.{n}"));
            n += 1;
        }
        std::fs::rename(path, &target).map_err(|e| e.to_string())?;
        let info_text = format!(
            "[Trash Info]\nPath={}\nDeletionDate={}\n",
            path.display(),
            store::format_date(Some(std::time::SystemTime::now()))
        );
        let _ = std::fs::write(info.join(format!("{}.trashinfo", name)), info_text);
        Ok(())
    }
}

// ---------------------------------------------------------------- app

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if let Some(v) = self.open.as_mut() {
            v.tick += 1;
            if v.auto_rotate && v.loaded.error.is_none() {
                v.cam.yaw += 0.010;
                if v.tick % 4 == 0 {
                    v.needs_render = true;
                }
            }
        }

        // keyboard
        let (f5, esc, left, right, del) = ctx.input(|i| {
            (
                i.key_pressed(egui::Key::F5),
                i.key_pressed(egui::Key::Escape),
                i.key_pressed(egui::Key::ArrowLeft),
                i.key_pressed(egui::Key::ArrowRight),
                i.key_pressed(egui::Key::Delete),
            )
        });
        if f5 && !matches!(self.dialog, Dialog::ConnectFolder(_)) {
            self.rescan();
        }
        if esc {
            match self.dialog {
                Dialog::None => self.open = None,
                _ => self.dialog = Dialog::None,
            }
        }
        if self.open.is_some() {
            if left {
                self.step_viewer(-1, ctx);
            }
            if right {
                self.step_viewer(1, ctx);
            }
            if del {
                if let Some(v) = &self.open {
                    let path = self.models[v.idx].path.clone();
                    self.dialog = Dialog::Trash(vec![path]);
                }
            }
        }

        self.pump_thumbs(ctx);
        if !self.thumb_queue.is_empty() {
            ctx.request_repaint();
        }

        // screenshot support: draw a good number of frames, then save the window
        // as it stands and quit. Nothing here waits on a person, and nothing in it
        // keeps drawing after the picture is written.
        if let Some(path) = self.shot_path.clone() {
            self.shot_frames += 1;
            let waited = self.shot_t0.elapsed().as_secs_f32();
            let ready = self.page_cards_ready();
            // 120 frames of a settled window, and in any case a picture before the
            // caller's patience runs out (a big library can take a while to draw).
            let go = (self.shot_frames >= 120 && ready) || waited > 40.0;
            if go && !self.shot_asked {
                self.shot_asked = true;
                ctx.send_viewport_cmd(ViewportCommand::Screenshot(UserData::default()));
            }
            let shot = ctx.input(|i| {
                i.raw.events.iter().find_map(|e| match e {
                    egui::Event::Screenshot { image, .. } => Some(image.clone()),
                    _ => None,
                })
            });
            if let Some(img) = shot {
                let mut rgba = Vec::with_capacity(img.pixels.len() * 4);
                for p in &img.pixels {
                    let [r, g, b, a] = p.to_array();
                    rgba.extend_from_slice(&[r, g, b, a]);
                }
                if let Some(buf) = image::RgbaImage::from_raw(img.size[0] as u32, img.size[1] as u32, rgba) {
                    if let Some(dir) = path.parent() {
                        let _ = std::fs::create_dir_all(dir);
                    }
                    match buf.save(&path) {
                        Ok(()) => eprintln!(
                            "[carinae] foto: {} ({}x{}, {} frames, {:.1}s)",
                            path.display(),
                            img.size[0],
                            img.size[1],
                            self.shot_frames,
                            waited
                        ),
                        Err(e) => eprintln!("[carinae] nao foi possivel salvar a foto: {e}"),
                    }
                }
                // Quit at once: a window that is still up would keep the caller waiting.
                std::process::exit(0);
            }
            ctx.request_repaint();
        }

        self.sidebar(ctx);
        self.topbar(ctx);
        egui::CentralPanel::default().show(ctx, |ui| {
            let r = ui.max_rect();
            ui.painter().rect_filled(r, theme::radius(0), theme::BG_MAIN);
            self.content(ui);
        });
        self.viewer_ui(ctx);
        self.dialog_ui(ctx);
        self.toast_ui(ctx);

        if self.toast.is_some() {
            ctx.request_repaint();
        }
        if let Some(v) = &self.open {
            if v.auto_rotate || v.needs_render {
                ctx.request_repaint();
            }
        }
    }
}

impl App {
    fn step_viewer(&mut self, dir: i32, ctx: &egui::Context) {
        let list = self.visible();
        if list.is_empty() {
            return;
        }
        let cur = match &self.open {
            Some(v) => v.idx,
            None => return,
        };
        let pos = list.iter().position(|i| *i == cur).unwrap_or(0) as i32;
        let next = (pos + dir).clamp(0, list.len() as i32 - 1) as usize;
        let idx = list[next];
        self.open_viewer(idx, ctx);
    }

    fn open_viewer(&mut self, idx: usize, ctx: &egui::Context) {
        let m = &self.models[idx];
        let loaded = load_model(&m.path, &m.ext);
        // upload plate pictures once
        let mut plate_tex: Vec<Option<TextureHandle>> = Vec::new();
        for (i, png) in loaded.plate_pngs.iter().enumerate() {
            plate_tex.push(png.as_ref().map(|ci| {
                ctx.load_texture(format!("plate{idx}_{i}"), ci.clone(), TextureOptions::LINEAR)
            }));
        }
        self.open = Some(Viewer {
            idx,
            loaded,
            cam: render::Camera::default(),
            auto_rotate: self.settings.auto_rotate,
            wireframe: self.settings.wireframe,
            plate: 0,
            show_plate: false,
            tex: None,
            needs_render: true,
            tick: 0,
            plate_tex,
            ask_trash: false,
        });
    }

    // -------------------------------------------------------- sidebar

    fn sidebar(&mut self, ctx: &egui::Context) {
        let panel = egui::SidePanel::left("sidebar")
            .exact_width(theme::SIDEBAR_W)
            .resizable(false);
        panel.show(ctx, |ui| {
            let full = ui.max_rect();
            ui.painter().rect_filled(full, theme::radius(0), theme::BG_PANEL);
            ui.painter().vline(
                full.right() - 0.5,
                full.y_range(),
                Stroke::new(1.0_f32, theme::LINE),
            );
            ui.add_space(14.0);
            ui.horizontal(|ui| {
                ui.add_space(16.0);
                let (r, _) = ui.allocate_exact_size(Vec2::splat(26.0), Sense::hover());
                match &self.logo {
                    Some(t) => {
                        ui.painter().image(
                            t.id(),
                            r,
                            Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                            Color32::WHITE,
                        );
                    }
                    None => {
                        ui.painter().rect_filled(r, theme::radius(7), theme::ACCENT_DIM);
                        ui.painter().text(
                            r.center(),
                            Align2::CENTER_CENTER,
                            "C",
                            FontId::proportional(15.0),
                            Color32::WHITE,
                        );
                    }
                }
                ui.add_space(2.0);
                ui.vertical(|ui| {
                    ui.add_space(2.0);
                    ui.label(
                        egui::RichText::new("Carinae 3D")
                            .size(14.5)
                            .strong()
                            .color(theme::TEXT),
                    );
                    ui.label(
                        egui::RichText::new("Biblioteca de modelos")
                            .size(10.5)
                            .color(theme::TEXT_MUTED),
                    );
                });
            });
            ui.add_space(16.0);

            let (stl, tmf, svg, dups) = self.counts();
            let total = self.models.len();
            let favs = self
                .models
                .iter()
                .filter(|m| self.settings.is_favorite(&m.path))
                .count();

            section_label(ui, "BIBLIOTECA");
            let mut want: Option<Section> = None;
            if nav_item(ui, "◈", "Todos os Modelos", Some(total), self.section == Section::All && self.coll.is_none()) {
                want = Some(Section::All);
            }
            if nav_item(ui, "★", "Favoritos", Some(favs), self.section == Section::Favorites) {
                want = Some(Section::Favorites);
            }
            if nav_item(ui, "⧉", "Duplicados", Some(dups), self.section == Section::Duplicates) {
                want = Some(Section::Duplicates);
            }
            ui.add_space(10.0);
            ui.horizontal(|ui| {
                ui.add_space(16.0);
                ui.label(
                    egui::RichText::new("PASTAS")
                        .size(10.0)
                        .color(theme::TEXT_MUTED)
                        .strong(),
                );
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.add_space(12.0);
                    if ui
                        .add(egui::Button::new(egui::RichText::new("+").size(14.0)).frame(false))
                        .on_hover_text("Criar uma pasta para classificar modelos")
                        .clicked()
                    {
                        self.dialog = Dialog::NewColl(String::new());
                    }
                });
            });
            ui.add_space(4.0);
            {
                let colls = self.settings.collections.clone();
                let mut pick: Option<Option<String>> = None;
                egui::ScrollArea::vertical()
                    .id_salt("colls")
                    .auto_shrink([false, false])
                    .max_height(190.0)
                    .show(ui, |ui| {
                        if colls.is_empty() {
                            ui.horizontal(|ui| {
                                ui.add_space(16.0);
                                ui.label(
                                    egui::RichText::new(
                                        "Crie uma pasta para\nclassificar seus modelos.",
                                    )
                                    .size(11.5)
                                    .color(theme::TEXT_MUTED),
                                );
                            });
                        }
                        for c in &colls {
                            let n = self
                                .models
                                .iter()
                                .filter(|m| self.settings.collection_of(&m.path) == Some(c.id.as_str()))
                                .count();
                            let active = self.coll.as_deref() == Some(c.id.as_str());
                            if nav_item(ui, "▤", &c.name, Some(n), active) {
                                pick = Some(if active { None } else { Some(c.id.clone()) });
                            }
                        }
                    });
                if let Some(p) = pick {
                    self.coll = p;
                    self.section = Section::All;
                    self.page = 0;
                }
            }

            ui.add_space(10.0);
            section_label(ui, "ESTOQUE");
            if nav_item(ui, "◍", "Filamentos", Some(self.settings.spools.len()), self.section == Section::Filaments) {
                want = Some(Section::Filaments);
            }
            ui.add_space(10.0);
            section_label(ui, "SISTEMA");
            if nav_item(ui, "⚙", "Configurações", None, self.section == Section::Settings) {
                want = Some(Section::Settings);
            }
            if let Some(s) = want {
                self.section = s;
                self.coll = None;
                self.page = 0;
            }

            ui.add_space(14.0);
            ui.separator();
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                ui.add_space(16.0);
                ui.label(
                    egui::RichText::new("PASTAS CONECTADAS")
                        .size(10.0)
                        .color(theme::TEXT_MUTED)
                        .strong(),
                );
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.add_space(12.0);
                    if ui
                        .add(egui::Button::new(egui::RichText::new("+").size(14.0)).frame(false))
                        .on_hover_text("Conectar uma pasta")
                        .clicked()
                    {
                        self.dialog = Dialog::ConnectFolder(String::new());
                    }
                });
            });
            ui.add_space(4.0);

            let folders = self.settings.folders.clone();
            let mut remove: Option<String> = None;
            egui::ScrollArea::vertical()
                .id_salt("folders")
                .auto_shrink([false, false])
                .max_height(220.0)
                .show(ui, |ui| {
                    if folders.is_empty() {
                        ui.horizontal(|ui| {
                            ui.add_space(16.0);
                            ui.label(
                                egui::RichText::new("Nenhuma pasta ainda.\nConecte uma pasta de modelos.")
                                    .size(11.5)
                                    .color(theme::TEXT_MUTED),
                            );
                        });
                    }
                    for f in &folders {
                        let count = self.models.iter().filter(|m| &m.folder == f).count();
                        let name = Path::new(f)
                            .file_name()
                            .and_then(|s| s.to_str())
                            .unwrap_or(f)
                            .to_string();
                        let expanded = self.expand_folders.iter().any(|x| x == f);
                        ui.horizontal(|ui| {
                            ui.add_space(10.0);
                            let arrow = if expanded { "▾" } else { "▸" };
                            if ui
                                .add(egui::Button::new(egui::RichText::new(arrow).size(10.0)).frame(false))
                                .clicked()
                            {
                                if expanded {
                                    self.expand_folders.retain(|x| x != f);
                                } else {
                                    self.expand_folders.push(f.clone());
                                }
                            }
                            ui.label(egui::RichText::new("🗀").size(11.0).color(theme::ACCENT));
                            ui.label(egui::RichText::new(truncate(&name, 18)).size(12.0).color(theme::TEXT));
                            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                                ui.add_space(8.0);
                                if ui
                                    .add(egui::Button::new(egui::RichText::new("×").size(12.0)).frame(false))
                                    .on_hover_text("Desconectar")
                                    .clicked()
                                {
                                    remove = Some(f.clone());
                                }
                                ui.label(
                                    egui::RichText::new(count.to_string())
                                        .size(10.5)
                                        .color(theme::TEXT_MUTED),
                                );
                            });
                        });
                        if expanded {
                            let mut subs: HashMap<String, usize> = HashMap::new();
                            for m in self.models.iter().filter(|m| &m.folder == f) {
                                if !m.rel_dir.is_empty() {
                                    *subs.entry(m.rel_dir.clone()).or_insert(0) += 1;
                                }
                            }
                            let mut keys: Vec<_> = subs.into_iter().collect();
                            keys.sort();
                            for (sub, n) in keys {
                                ui.horizontal(|ui| {
                                    ui.add_space(40.0);
                                    ui.label(
                                        egui::RichText::new(truncate(&sub.replace('\\', "/"), 20))
                                            .size(11.0)
                                            .color(theme::TEXT_DIM),
                                    );
                                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                                        ui.add_space(10.0);
                                        ui.label(
                                            egui::RichText::new(n.to_string())
                                                .size(10.0)
                                                .color(theme::TEXT_MUTED),
                                        );
                                    });
                                });
                            }
                        }
                    }
                });
            if let Some(f) = remove {
                self.settings.folders.retain(|x| x != &f);
                self.settings.save();
                self.rescan();
            }

            let size: u64 = self.models.iter().map(|m| m.size).sum();
            ui.with_layout(egui::Layout::bottom_up(egui::Align::Min), |ui| {
                ui.add_space(10.0);
                ui.horizontal(|ui| {
                    ui.add_space(16.0);
                    ui.label(
                        egui::RichText::new(format!(
                            "{total} modelos · {}",
                            store::format_bytes(size)
                        ))
                        .size(10.5)
                        .color(theme::TEXT_MUTED),
                    );
                });
                ui.label(
                    egui::RichText::new(format!("STL {stl}  ·  3MF {tmf}  ·  SVG {svg}"))
                        .size(10.0)
                        .color(theme::TEXT_MUTED),
                );
                ui.add_space(2.0);
            });
        });
    }

    // -------------------------------------------------------- topbar

    fn topbar(&mut self, ctx: &egui::Context) {
        egui::TopBottomPanel::top("topbar")
            .exact_height(theme::TOPBAR_H)
            .show(ctx, |ui| {
                let rect = ui.max_rect();
                ui.painter().rect_filled(rect, theme::radius(0), theme::BG_PANEL);
                ui.painter().hline(
                    rect.x_range(),
                    rect.bottom() - 0.5,
                    Stroke::new(1.0_f32, theme::LINE),
                );
                ui.horizontal_centered(|ui| {
                    ui.add_space(18.0);
                    let (r, _) = ui.allocate_exact_size(Vec2::new(260.0, 30.0), Sense::hover());
                    ui_rect(ui.painter(), r, theme::BG_INPUT, Some(theme::LINE), 6);
                    ui.painter().text(
                        r.left_center() + Vec2::new(10.0, 0.0),
                        Align2::LEFT_CENTER,
                        "⌕",
                        FontId::proportional(14.0),
                        theme::TEXT_MUTED,
                    );
                    let edit_rect = r.shrink2(Vec2::new(26.0, 3.0));
                    let mut child = ui.new_child(
                        egui::UiBuilder::new()
                            .max_rect(edit_rect)
                            .layout(egui::Layout::left_to_right(egui::Align::Center)),
                    );
                    child.add(
                        egui::TextEdit::singleline(&mut self.search)
                            .hint_text("Buscar modelos…")
                            .desired_width(edit_rect.width())
                            .frame(false),
                    );
                    ui.add_space(6.0);
                    for (f, label, color) in [
                        (Filter::All, "Todos", theme::TEXT_DIM),
                        (Filter::Stl, "STL", theme::STL),
                        (Filter::ThreeMf, "3MF", theme::THREEMF),
                        (Filter::Svg, "SVG", theme::SVG),
                    ] {
                        let sel = self.filter == f;
                        let (rr, resp) =
                            ui.allocate_exact_size(Vec2::new(label.len() as f32 * 8.5 + 18.0, 26.0), Sense::click());
                        let bg = if sel { theme::ACCENT_DIM } else { theme::BG_CARD };
                        ui_rect(ui.painter(), rr, bg, Some(if sel { theme::ACCENT } else { theme::LINE }), 6);
                        ui.painter().text(
                            rr.center(),
                            Align2::CENTER_CENTER,
                            label,
                            FontId::proportional(11.5),
                            if sel { Color32::WHITE } else { color },
                        );
                        if resp.clicked() {
                            self.filter = f;
                            self.page = 0;
                        }
                    }

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        ui.add_space(18.0);
                        if ui
                            .add(egui::Button::new(egui::RichText::new("⟳").size(14.0)).frame(false))
                            .on_hover_text("Atualizar (F5)")
                            .clicked()
                        {
                            self.rescan();
                        }
                        ui.add_space(8.0);
                        egui::ComboBox::from_id_salt("pagesize")
                            .selected_text(format!("{} / página", self.page_size))
                            .width(104.0)
                            .show_ui(ui, |ui| {
                                for n in [50usize, 100, 150] {
                                    if ui
                                        .selectable_label(self.page_size == n, format!("{n} / página"))
                                        .clicked()
                                    {
                                        self.page_size = n;
                                        self.settings.page_size = n;
                                        self.settings.save();
                                        self.page = 0;
                                    }
                                }
                            });
                        ui.add_space(8.0);
                        let sort_label = match self.sort.as_str() {
                            "date_asc" => "Data ↑",
                            "name_asc" => "Nome A–Z",
                            "name_desc" => "Nome Z–A",
                            "size_desc" => "Tamanho ↓",
                            "size_asc" => "Tamanho ↑",
                            _ => "Data ↓",
                        };
                        egui::ComboBox::from_id_salt("sort")
                            .selected_text(sort_label)
                            .width(118.0)
                            .show_ui(ui, |ui| {
                                for (k, label) in [
                                    ("date_desc", "Data ↓ (recentes)"),
                                    ("date_asc", "Data ↑ (antigos)"),
                                    ("name_asc", "Nome A–Z"),
                                    ("name_desc", "Nome Z–A"),
                                    ("size_desc", "Tamanho ↓"),
                                    ("size_asc", "Tamanho ↑"),
                                ] {
                                    if ui.selectable_label(self.sort == k, label).clicked() {
                                        self.sort = k.to_string();
                                        self.settings.sort = self.sort.clone();
                                        self.settings.save();
                                        self.page = 0;
                                    }
                                }
                            });
                    });
                });
            });
    }

    // -------------------------------------------------------- content

    fn content(&mut self, ui: &mut egui::Ui) {
        match self.section {
            Section::Filaments => self.filaments_page(ui),
            Section::Settings => self.settings_page(ui),
            Section::Duplicates => self.duplicates_page(ui),
            _ => self.library_page(ui),
        }
    }

    fn header(&self, ui: &mut egui::Ui, title: &str, subtitle: &str) {
        ui.add_space(theme::PAD);
        ui.horizontal(|ui| {
            ui.add_space(theme::PAD);
            ui.vertical(|ui| {
                ui.label(egui::RichText::new(title).size(21.0).strong());
                ui.label(
                    egui::RichText::new(subtitle)
                        .size(12.0)
                        .color(theme::TEXT_DIM),
                );
            });
        });
        ui.add_space(10.0);
    }

    /// Same header, plus a row of small counted pills — the numbers that say at a
    /// glance how much is in the library and in which format.
    fn header_pills(
        &self,
        ui: &mut egui::Ui,
        title: &str,
        subtitle: &str,
        pills: &[(String, Color32)],
        right: impl FnOnce(&mut egui::Ui),
    ) {
        ui.add_space(theme::PAD);
        ui.horizontal(|ui| {
            ui.add_space(theme::PAD);
            ui.vertical(|ui| {
                ui.label(egui::RichText::new(title).size(21.0).strong());
                ui.label(
                    egui::RichText::new(subtitle)
                        .size(12.0)
                        .color(theme::TEXT_DIM),
                );
                if !pills.is_empty() {
                    ui.add_space(8.0);
                    ui.horizontal(|ui| {
                        for (text, color) in pills {
                            let galley = ui.painter().layout_no_wrap(
                                text.clone(),
                                FontId::proportional(10.5),
                                *color,
                            );
                            let (rect, _) = ui.allocate_exact_size(
                                Vec2::new(galley.size().x + 27.0, 21.0),
                                Sense::hover(),
                            );
                            ui_rect(ui.painter(), rect, theme::BG_CARD, Some(theme::LINE), 10);
                            dot(
                                ui.painter(),
                                Pos2::new(rect.left() + 11.0, rect.center().y),
                                3.2,
                                *color,
                            );
                            ui.painter().galley(
                                Pos2::new(
                                    rect.left() + 19.0,
                                    rect.center().y - galley.size().y / 2.0,
                                ),
                                galley,
                                *color,
                            );
                            ui.add_space(5.0);
                        }
                    });
                }
            });
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                ui.add_space(theme::PAD);
                right(ui);
            });
        });
        ui.add_space(12.0);
    }

    fn library_page(&mut self, ui: &mut egui::Ui) {
        let (stl, tmf, svg, dups) = self.counts();
        let total = self.models.len();
        if let Some(cid) = self.coll.clone() {
            let name = self
                .settings
                .collection_name(&cid)
                .unwrap_or("Pasta")
                .to_string();
            let inside = self
                .models
                .iter()
                .filter(|m| self.settings.collection_of(&m.path) == Some(cid.as_str()))
                .count();
            ui.add_space(theme::PAD);
            let mut go_back = false;
            let mut want_rename = false;
            let mut want_delete = false;
            self.header_pills(
                ui,
                &name,
                &format!("Pasta · {inside} de {total} modelos · classificação feita por você"),
                &[
                    (format!("{inside} nesta pasta"), theme::ACCENT),
                    (format!("{} sem pasta", total.saturating_sub(inside)), theme::TEXT_DIM),
                ],
                |ui| {
                    if ui.button("Mostrar todos").clicked() {
                        go_back = true;
                    }
                    if ui.button("Renomear").clicked() {
                        want_rename = true;
                    }
                    if ui.button("Excluir pasta").clicked() {
                        want_delete = true;
                    }
                },
            );
            if go_back {
                self.coll = None;
            }
            if want_rename {
                self.dialog = Dialog::RenameColl(cid.clone(), name.clone());
            }
            if want_delete {
                self.settings.remove_collection(&cid);
                self.coll = None;
            }
        } else {
            let title = match self.section {
                Section::Favorites => "Favoritos",
                _ => "Todos os Modelos",
            };
            let favs = self.settings.favorites.len();
            let folders = self.settings.collections.len();
            let mut pills: Vec<(String, Color32)> = vec![
                (format!("{total} modelos"), theme::TEXT),
                (format!("{stl} STL"), theme::STL),
                (format!("{tmf} 3MF"), theme::THREEMF),
                (format!("{svg} SVG"), theme::SVG),
                (format!("{favs} favoritos"), theme::ACCENT),
                (format!("{folders} pastas"), theme::TEXT_DIM),
            ];
            if dups > 0 {
                pills.push((format!("{dups} duplicados"), theme::WARN));
            }
            let mut want_rescan = false;
            let mut want_folder = false;
            self.header_pills(
                ui,
                title,
                "Sua biblioteca de modelos 3D: clique numa peça para abrir, ou use os botões do cartão.",
                &pills,
                |ui| {
                    if ui.button("⟳ Digitalizar").clicked() {
                        want_rescan = true;
                    }
                    if ui.button("▤ Nova pasta").clicked() {
                        want_folder = true;
                    }
                },
            );
            if want_rescan {
                self.rescan();
            }
            if want_folder {
                self.dialog = Dialog::NewColl(String::new());
            }
        }
        if self.models.is_empty() {
            self.empty_state(ui);
            return;
        }
        let list = self.visible();
        let pages = (list.len() + self.page_size - 1) / self.page_size.max(1);
        if self.page >= pages {
            self.page = pages.saturating_sub(1);
        }
        let start = self.page * self.page_size;
        let end = (start + self.page_size).min(list.len());
        let slice: Vec<usize> = list[start..end].to_vec();

        egui::ScrollArea::vertical()
            .id_salt("grid")
            .auto_shrink([false, false])
            .show(ui, |ui| {
                let avail = ui.available_width() - theme::PAD * 2.0;
                let cols = ((avail + 12.0) / (theme::CARD_MIN_W + 12.0)).floor().max(1.0) as usize;
                let cw = (avail - 12.0 * (cols as f32 - 1.0)) / cols as f32;
                let ch = cw * 0.66 + 116.0;
                let mut clicked: Option<usize> = None;
                let mut acts = CardActs::default();
                ui.add_space(2.0);
                for chunk in slice.chunks(cols) {
                    ui.horizontal(|ui| {
                        ui.add_space(theme::PAD);
                        for &idx in chunk {
                            let m = &self.models[idx];
                            let (rect, resp) =
                                ui.allocate_exact_size(Vec2::new(cw, ch), Sense::click());
                            let hovered = resp.hovered();
                            let fav = self.settings.is_favorite(&m.path);
                            let dup = self.dups.values().any(|g| g.contains(&idx));
                            let key = m.path.to_string_lossy().to_string();
                            let tex = self.thumb.get(&key).and_then(|t| t.as_ref());
                            let folder = self
                                .settings
                                .collection_of(&m.path)
                                .and_then(|id| self.settings.collection_name(id))
                                .map(|s| s.to_string());
                            let info = self.info.get(&key);
                            let slicer_label = self.slicer_label();
                            draw_card(
                                ui,
                                rect,
                                m,
                                hovered,
                                fav,
                                dup,
                                tex,
                                info,
                                folder.as_deref(),
                                &slicer_label,
                                true,
                                &mut acts,
                                idx,
                            );
                            if resp.clicked() {
                                clicked = Some(idx);
                            }
                        }
                        ui.add_space(theme::PAD);
                    });
                    ui.add_space(12.0);
                }
                if slice.is_empty() {
                    ui.add_space(40.0);
                    ui.vertical_centered(|ui| {
                        ui.label(
                            egui::RichText::new("Nada encontrado com esses filtros.")
                                .size(13.0)
                                .color(theme::TEXT_DIM),
                        );
                    });
                }
                ui.add_space(8.0);
                // pager
                if pages > 1 {
                    ui.horizontal(|ui| {
                        ui.add_space(theme::PAD);
                        if ui
                            .add_enabled(self.page > 0, egui::Button::new("‹ Anterior"))
                            .clicked()
                        {
                            self.page = self.page.saturating_sub(1);
                        }
                        ui.label(
                            egui::RichText::new(format!(
                                "Página {} de {} · {} modelos",
                                self.page + 1,
                                pages,
                                list.len()
                            ))
                            .size(11.5)
                            .color(theme::TEXT_DIM),
                        );
                        if ui
                            .add_enabled(self.page + 1 < pages, egui::Button::new("Próxima ›"))
                            .clicked()
                        {
                            self.page += 1;
                        }
                    });
                }
                ui.add_space(16.0);
                if let Some(i) = acts.star {
                    let p = self.models[i].path.clone();
                    self.settings.toggle_favorite(&p);
                }
                if let Some(i) = acts.assign {
                    self.ask_assign(vec![self.models[i].path.clone()]);
                }
                if let Some(i) = acts.rename {
                    let m = &self.models[i];
                    let stem = m
                        .path
                        .file_stem()
                        .map(|s| s.to_string_lossy().to_string())
                        .unwrap_or_default();
                    self.dialog = Dialog::Rename(m.path.clone(), stem);
                }
                if let Some(i) = acts.delete {
                    self.dialog = Dialog::Trash(vec![self.models[i].path.clone()]);
                }
                if let Some(i) = acts.slicer {
                    self.open_in_slicer(i);
                }
                if let Some(i) = clicked {
                    if acts.touch != Some(i) {
                        self.open_viewer(i, ui.ctx());
                    }
                }
            });
    }

    fn empty_state(&mut self, ui: &mut egui::Ui) {
        let rect = Rect::from_min_size(
            ui.max_rect().min + Vec2::new(theme::PAD, 20.0),
            Vec2::new(ui.available_width() - theme::PAD * 2.0, 300.0),
        );
        ui_rect(ui.painter(), rect, theme::BG_CARD, Some(theme::LINE), 10);
        let logo_id = self.logo.as_ref().map(|t| t.id());
        let p = ui.painter();
        match logo_id {
            Some(id) => {
                let badge = Rect::from_center_size(
                    Pos2::new(rect.center_top().x, rect.top() + 56.0),
                    Vec2::splat(54.0),
                );
                p.image(
                    id,
                    badge,
                    Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                    Color32::WHITE,
                );
            }
            None => {
                p.text(
                    rect.center_top() + Vec2::new(0.0, 40.0),
                    Align2::CENTER_TOP,
                    "◈",
                    FontId::proportional(34.0),
                    theme::ACCENT,
                );
            }
        }
        p.text(
            rect.center_top() + Vec2::new(0.0, 92.0),
            Align2::CENTER_TOP,
            "Conecte uma pasta para começar",
            FontId::proportional(16.0),
            theme::TEXT,
        );
        p.text(
            rect.center_top() + Vec2::new(0.0, 118.0),
            Align2::CENTER_TOP,
            "Carinae 3D indexa arquivos STL, 3MF e SVG que já estão no seu computador.",
            FontId::proportional(12.0),
            theme::TEXT_DIM,
        );
        let mut y = rect.center_top().y + 160.0;
        for (label, dir) in quick_folders() {
            let b = Rect::from_center_size(
                Pos2::new(rect.center().x, y),
                Vec2::new(260.0, 30.0),
            );
            let resp = ui.interact(b, egui::Id::new(("quick", label)), Sense::click());
            ui_rect(
                ui.painter(),
                b,
                if resp.hovered() { theme::BG_CARD_HOVER } else { theme::BG_INPUT },
                Some(theme::LINE),
                6,
            );
            ui.painter().text(
                b.center(),
                Align2::CENTER_CENTER,
                format!("Conectar {label}"),
                FontId::proportional(12.0),
                theme::TEXT,
            );
            if resp.clicked() {
                self.settings.folders.push(dir);
                self.settings.save();
                self.rescan();
            }
            y += 38.0;
        }
    }

    fn duplicates_page(&mut self, ui: &mut egui::Ui) {
        self.header(
            ui,
            "Duplicados",
            "Arquivos com o mesmo conteúdo. A biblioteca mostra só um de cada grupo — as cópias ficam aqui.",
        );
        if self.dups.is_empty() {
            ui.add_space(30.0);
            ui.vertical_centered(|ui| {
                ui.label(
                    egui::RichText::new("Nenhum duplicado encontrado.")
                        .size(13.0)
                        .color(theme::TEXT_DIM),
                );
            });
            return;
        }
        let extra: Vec<PathBuf> = {
            let mut v: Vec<usize> = self.dup_hidden.iter().cloned().collect();
            v.sort();
            v.iter().map(|i| self.models[*i].path.clone()).collect()
        };
        ui.horizontal(|ui| {
            ui.add_space(theme::PAD);
            ui.label(
                egui::RichText::new(format!(
                    "{} {} fora da grade · um de cada grupo continua à vista",
                    extra.len(),
                    if extra.len() == 1 { "cópia" } else { "cópias" }
                ))
                .size(11.5)
                .color(theme::TEXT_DIM),
            );
            if !extra.is_empty() {
                ui.add_space(12.0);
                if ui
                    .add(
                        egui::Button::new(
                            egui::RichText::new(format!(
                                "Mandar {} para a lixeira",
                                if extra.len() == 1 { "a cópia" } else { "as cópias" }
                            ))
                            .size(11.5)
                            .color(theme::DANGER),
                        )
                        .fill(theme::BG_INPUT),
                    )
                    .clicked()
                {
                    self.dialog = Dialog::Trash(extra.clone());
                }
            }
        });
        ui.add_space(8.0);
        let mut groups: Vec<(String, Vec<usize>)> =
            self.dups.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        groups.sort_by_key(|(_, v)| std::cmp::Reverse(v.len()));
        let mut trash: Option<Vec<PathBuf>> = None;
        egui::ScrollArea::vertical().id_salt("dups").show(ui, |ui| {
            ui.add_space(4.0);
            for (fp, idxs) in groups {
                let idxs = self.dup_group_sorted(&idxs, &fp);
                let rect_h = 46.0 + idxs.len() as f32 * 24.0;
                let rect = Rect::from_min_size(
                    Pos2::new(ui.max_rect().left() + theme::PAD, ui.cursor().top()),
                    Vec2::new(ui.available_width() - theme::PAD * 2.0, rect_h),
                );
                ui.allocate_space(Vec2::new(rect.width(), rect_h + 10.0));
                ui_rect(ui.painter(), rect, theme::BG_CARD, Some(theme::LINE), 8);
                ui.painter().text(
                    rect.min + Vec2::new(14.0, 10.0),
                    Align2::LEFT_TOP,
                    format!("{} arquivos iguais · 1 fica · {}", idxs.len(), store::format_bytes(self.models[idxs[0]].size)),
                    FontId::proportional(13.0),
                    theme::WARN,
                );
                ui.painter().text(
                    rect.right_top() + Vec2::new(-14.0, 11.0),
                    Align2::RIGHT_TOP,
                    format!("sha256 {}…", &fp[0..10.min(fp.len())]),
                    FontId::monospace(10.0),
                    theme::TEXT_MUTED,
                );
                let mut y = rect.min.y + 34.0;
                for (rank, idx) in idxs.iter().enumerate() {
                    let m = &self.models[*idx];
                    ui.painter().text(
                        Pos2::new(rect.min.x + 16.0, y),
                        Align2::LEFT_CENTER,
                        truncate(&format!("{}.{}", m.name, m.ext), 40),
                        FontId::proportional(11.5),
                        theme::TEXT,
                    );
                    ui.painter().text(
                        Pos2::new(rect.min.x + 380.0, y),
                        Align2::LEFT_CENTER,
                        truncate(&m.dir().to_string_lossy(), 60),
                        FontId::proportional(10.5),
                        theme::TEXT_MUTED,
                    );
                    if rank > 0 {
                        let b = Rect::from_min_size(
                            Pos2::new(rect.right() - 96.0, y - 10.0),
                            Vec2::new(82.0, 20.0),
                        );
                        let resp =
                            ui.interact(b, egui::Id::new(("duptrash", idx)), Sense::click());
                        ui_rect(
                            ui.painter(),
                            b,
                            if resp.hovered() { theme::BG_CARD_HOVER } else { theme::BG_INPUT },
                            Some(theme::LINE),
                            5,
                        );
                        ui.painter().text(
                            b.center(),
                            Align2::CENTER_CENTER,
                            "Lixeira",
                            FontId::proportional(10.5),
                            theme::DANGER,
                        );
                        if resp.clicked() {
                            trash = Some(vec![m.path.clone()]);
                        }
                    } else {
                        chip(
                            ui.painter(),
                            Pos2::new(rect.right() - 96.0, y - 8.0),
                            "no lugar",
                            theme::THREEMF,
                            theme::BG_INPUT,
                        );
                    }
                    y += 24.0;
                }
            }
            ui.add_space(16.0);
        });
        if let Some(t) = trash {
            self.dialog = Dialog::Trash(t);
        }
    }

    fn filaments_page(&mut self, ui: &mut egui::Ui) {
        self.header(
            ui,
            "Filamentos",
            "O estoque de carretéis usado para saber se um modelo pode ser impresso agora.",
        );
        ui.horizontal(|ui| {
            ui.add_space(theme::PAD);
            if ui
                .add(egui::Button::new(egui::RichText::new("+ Adicionar carretel").strong()))
                .clicked()
            {
                self.dialog = Dialog::Spool(Box::new(filaments::Spool::default()), None);
            }
            ui.add_space(12.0);
            let kg = filaments::total_stock_g(&self.settings.spools) / 1000.0;
            ui.label(
                egui::RichText::new(format!(
                    "{} carretéis · {kg:.2} kg disponíveis",
                    self.settings.spools.len()
                ))
                .size(12.0)
                .color(theme::TEXT_DIM),
            );
        });
        ui.add_space(14.0);
        let spools = self.settings.spools.clone();
        let mut edit: Option<(Box<filaments::Spool>, Option<String>)> = None;
        let mut remove: Option<String> = None;
        egui::ScrollArea::vertical().id_salt("spools").show(ui, |ui| {
            let avail = ui.available_width() - theme::PAD * 2.0;
            let cols = ((avail + 12.0) / 280.0).floor().max(1.0) as usize;
            let cw = (avail - 12.0 * (cols as f32 - 1.0)) / cols as f32;
            for chunk in spools.chunks(cols) {
                ui.horizontal(|ui| {
                    ui.add_space(theme::PAD);
                    for s in chunk {
                        let (rect, _) = ui.allocate_exact_size(Vec2::new(cw, 128.0), Sense::hover());
                        ui_rect(ui.painter(), rect, theme::BG_CARD, Some(theme::LINE), 8);
                        let col = Color32::from_rgb(
                            mesh::hex_to_rgb(&s.hex)[0],
                            mesh::hex_to_rgb(&s.hex)[1],
                            mesh::hex_to_rgb(&s.hex)[2],
                        );
                        dot(ui.painter(), rect.min + Vec2::new(26.0, 30.0), 13.0, col);
                        ui.painter().text(
                            rect.min + Vec2::new(52.0, 18.0),
                            Align2::LEFT_TOP,
                            format!("{} {}", s.brand, s.material),
                            FontId::proportional(13.0),
                            theme::TEXT,
                        );
                        ui.painter().text(
                            rect.min + Vec2::new(52.0, 38.0),
                            Align2::LEFT_TOP,
                            format!(
                                "{} · {}",
                                if s.line.is_empty() { "—" } else { s.line.as_str() },
                                if s.color_name.is_empty() { s.hex.as_str() } else { s.color_name.as_str() }
                            ),
                            FontId::proportional(11.0),
                            theme::TEXT_DIM,
                        );
                        let frac = if s.total_g > 0.0 {
                            (s.remaining_g / s.total_g).clamp(0.0, 1.0) as f32
                        } else {
                            0.0
                        };
                        let bar = Rect::from_min_size(
                            rect.min + Vec2::new(16.0, 62.0),
                            Vec2::new(rect.width() - 32.0, 6.0),
                        );
                        ui.painter().rect_filled(bar, theme::radius(3), theme::BG_INPUT);
                        let mut fill = bar;
                        fill.set_width(bar.width() * frac);
                        let col2 = if frac < 0.2 { theme::DANGER } else { col };
                        ui.painter().rect_filled(fill, theme::radius(3), col2);
                        ui.painter().text(
                            rect.min + Vec2::new(16.0, 74.0),
                            Align2::LEFT_TOP,
                            format!("{:.0} g de {:.0} g", s.remaining_g, s.total_g),
                            FontId::proportional(11.0),
                            theme::TEXT_DIM,
                        );
                        if let Some(pr) = s.price {
                            ui.painter().text(
                                rect.right_top() + Vec2::new(-16.0, 74.0),
                                Align2::RIGHT_TOP,
                                format!("R$ {pr:.2}"),
                                FontId::proportional(11.0),
                                theme::TEXT_MUTED,
                            );
                        }
                        let be = Rect::from_min_size(
                            rect.min + Vec2::new(16.0, 96.0),
                            Vec2::new(64.0, 22.0),
                        );
                        let re = ui.interact(be, egui::Id::new(("spooledit", &s.id)), Sense::click());
                        ui_rect(ui.painter(), be, theme::BG_INPUT, Some(theme::LINE), 5);
                        ui.painter().text(
                            be.center(),
                            Align2::CENTER_CENTER,
                            "Editar",
                            FontId::proportional(10.5),
                            theme::TEXT_DIM,
                        );
                        if re.clicked() {
                            edit = Some((Box::new(s.clone()), Some(s.id.clone())));
                        }
                        let bd = Rect::from_min_size(
                            rect.min + Vec2::new(88.0, 96.0),
                            Vec2::new(64.0, 22.0),
                        );
                        let rd = ui.interact(bd, egui::Id::new(("spooldel", &s.id)), Sense::click());
                        ui_rect(ui.painter(), bd, theme::BG_INPUT, Some(theme::LINE), 5);
                        ui.painter().text(
                            bd.center(),
                            Align2::CENTER_CENTER,
                            "Remover",
                            FontId::proportional(10.5),
                            theme::DANGER,
                        );
                        if rd.clicked() {
                            remove = Some(s.id.clone());
                        }
                    }
                });
                ui.add_space(12.0);
            }
            if spools.is_empty() {
                ui.add_space(30.0);
                ui.vertical_centered(|ui| {
                    ui.label(
                        egui::RichText::new("Nenhum carretel cadastrado.")
                            .size(13.0)
                            .color(theme::TEXT_DIM),
                    );
                });
            }
            ui.add_space(20.0);
        });
        if let Some((s, id)) = edit {
            self.dialog = Dialog::Spool(s, id);
        }
        if let Some(id) = remove {
            self.settings.spools.retain(|s| s.id != id);
            self.settings.save();
        }
    }

    fn settings_page(&mut self, ui: &mut egui::Ui) {
        self.header(ui, "Configurações", "Pastas, fatiadores e preferências.");
        egui::ScrollArea::vertical().id_salt("settings").show(ui, |ui| {
            ui.add_space(4.0);
            // Two columns of cards, like the library's grid, so the four blocks fit
            // on one screen instead of stacking into a long strip with half of each
            // card left empty.
            let gutter = theme::PAD * 0.6;
            let col = ((ui.available_width() - theme::PAD * 2.0 - gutter) / 2.0).max(320.0);
            ui.horizontal_top(|ui| {
                ui.add_space(theme::PAD);
                ui.vertical(|ui| {
                    ui.set_width(col);
                    card_block(ui, "Pastas conectadas", |ui| {
                        let folders = self.settings.folders.clone();
                        if folders.is_empty() {
                            ui.label(egui::RichText::new("Nenhuma pasta conectada.").color(theme::TEXT_DIM));
                        }
                        for f in folders {
                            ui.horizontal(|ui| {
                                ui.label(egui::RichText::new("🗀").color(theme::ACCENT));
                                // Room for the path that is left after the button, so a
                                // deep folder name can't push the button off the card.
                                let room = ((ui.available_width() - 96.0) / 5.8).max(8.0) as usize;
                                ui.label(
                                    egui::RichText::new(truncate(&f, room))
                                        .size(11.5)
                                        .color(theme::TEXT),
                                );
                                if ui.small_button("remover").clicked() {
                                    self.settings.folders.retain(|x| x != &f);
                                    self.settings.save();
                                    self.rescan();
                                }
                            });
                        }
                        if ui.button("+ Conectar pasta").clicked() {
                            self.dialog = Dialog::ConnectFolder(String::new());
                        }
                    });

                    ui.add_space(12.0);
                    card_block(ui, "Fatiadores encontrados", |ui| {
                        // Eleven rows at the default 26 px row height filled more than
                        // the window; the list is a plain list, so it can be tight.
                        ui.spacing_mut().item_spacing.y = 2.0;
                        let slicers = self.slicers.clone();
                        for s in &slicers {
                            ui.horizontal(|ui| {
                                let installed = s.exe.is_some();
                                let sel = self.settings.default_slicer == s.id;
                                let mut v = sel;
                                ui.add_enabled_ui(installed, |ui| {
                                    if ui.radio(sel, &s.name).clicked() {
                                        v = true;
                                    }
                                });
                                if v != sel {
                                    self.settings.default_slicer = s.id.clone();
                                    self.settings.save();
                                }
                                // The path gets whatever room the card has left; a
                                // narrow column would otherwise push it off the card.
                                let room = (ui.available_width() / 5.6).max(8.0) as usize;
                                match &s.exe {
                                    Some(p) => {
                                        ui.label(
                                            egui::RichText::new(truncate(
                                                &p.to_string_lossy(),
                                                room,
                                            ))
                                            .size(10.5)
                                            .color(theme::TEXT_MUTED),
                                        );
                                    }
                                    None => {
                                        ui.label(
                                            egui::RichText::new("não instalado")
                                                .size(10.5)
                                                .color(theme::TEXT_MUTED),
                                        );
                                    }
                                }
                            });
                        }
                        ui.add_space(4.0);
                        ui.horizontal(|ui| {
                            let sel = self.settings.default_slicer == "system";
                            if ui.radio(sel, "Padrão do Windows").clicked() {
                                self.settings.default_slicer = "system".into();
                                self.settings.save();
                            }
                        });
                        ui.label(
                            egui::RichText::new(
                                "Modelos SVG abrem só nos fatiadores que aceitam SVG (todos menos Cura e SuperSlicer).",
                            )
                            .size(10.5)
                            .color(theme::TEXT_MUTED),
                        );
                        if ui.button("Detectar novamente").clicked() {
                            self.slicers = slicers::detect();
                        }
                    });
                });

                ui.add_space(gutter);
                ui.vertical(|ui| {
                    ui.set_width(col);
                    card_block(ui, "Visualizador", |ui| {
                        let mut ar = self.settings.auto_rotate;
                        if ui.checkbox(&mut ar, "Girar o modelo automaticamente").changed() {
                            self.settings.auto_rotate = ar;
                            self.settings.save();
                        }
                        let mut wf = self.settings.wireframe;
                        if ui.checkbox(&mut wf, "Mostrar só as arestas (wireframe)").changed() {
                            self.settings.wireframe = wf;
                            self.settings.save();
                        }
                    });

                    ui.add_space(12.0);
                    card_block(ui, "Sobre", |ui| {
                        let logo_id = self.logo.as_ref().map(|t| t.id());
                        ui.horizontal(|ui| {
                            if let Some(id) = logo_id {
                                let (r, _) = ui.allocate_exact_size(Vec2::splat(34.0), Sense::hover());
                                ui.painter().image(
                                    id,
                                    r,
                                    Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                                    Color32::WHITE,
                                );
                                ui.add_space(8.0);
                            }
                            ui.label(
                                egui::RichText::new("Carinae 3D 1.6.0 — biblioteca local de modelos 3D")
                                    .size(12.0)
                                    .color(theme::TEXT),
                            );
                        });
                        ui.add_space(4.0);
                        ui.label(
                            egui::RichText::new(format!(
                                "Configuração salva em {}",
                                store::settings_path().display()
                            ))
                            .size(10.5)
                            .color(theme::TEXT_MUTED),
                        );
                        ui.add_space(4.0);
                        ui.label(
                            egui::RichText::new(
                                "Reconstruído a partir do Vault3D 1.6.0 (arquivo de instalação NSIS, \
                                 produto \"Vault3D\", versão 1.6.0). Este app não baixa nem envia nada.",
                            )
                            .size(10.5)
                            .color(theme::TEXT_MUTED),
                        );
                    });
                });
                ui.add_space(theme::PAD);
            });
            ui.add_space(30.0);
        });
    }

    // -------------------------------------------------------- viewer

    fn viewer_ui(&mut self, ctx: &egui::Context) {
        if self.open.is_none() {
            return;
        }
        let mut close = false;
        let open_next: Option<usize> = None;
        let mut start_trash = false;
        let mut toggle_fav: Option<PathBuf> = None;
        let mut dialog_open: Option<Dialog> = None;
        let mut open_slicer: Option<PathBuf> = None;

        let screen = ctx.screen_rect();
        // A window inside the app: a little smaller than the page behind it, so the
        // library is still visible around the edges.
        let size = Vec2::new(
            (screen.width() - 70.0).min(1040.0).max(620.0),
            (screen.height() - 60.0).min(720.0).max(420.0),
        );
        let (v_idx, title, ext, path, size_bytes, modified) = {
            let v = self.open.as_ref().unwrap();
            let m = &self.models[v.idx];
            (
                v.idx,
                m.name.clone(),
                m.ext.clone(),
                m.path.clone(),
                m.size,
                store::format_date(m.modified),
            )
        };

        // A dim layer behind the window, over the library but not over the sidebar.
        // A click on it closes the picture, so it reads as one card laid on top.
        let veil = Rect::from_min_max(
            Pos2::new(screen.left() + theme::SIDEBAR_W, screen.top()),
            screen.right_bottom(),
        );
        egui::Area::new(egui::Id::new("viewer_veil"))
            .order(egui::Order::Middle)
            .fixed_pos(veil.left_top())
            .show(ctx, |ui| {
                ui.painter()
                    .rect_filled(veil, 0.0, Color32::from_black_alpha(150));
                if ui.allocate_rect(veil, Sense::click()).clicked() {
                    close = true;
                }
            });

        // The picture is drawn in an Area rather than an egui Window: a Window given
        // fixed_size and an anchor drew its frame but none of its contents.
        let frame = egui::Frame::NONE
            .fill(theme::BG_PANEL)
            .stroke(egui::Stroke::new(1.0_f32, theme::LINE))
            .corner_radius(theme::radius(10))
            .inner_margin(0);
        let card_pos = Pos2::new(
            ((screen.width() - size.x) * 0.5).max(8.0),
            ((screen.height() - size.y) * 0.5).max(8.0),
        );
        let _ = card_pos;
        egui::Area::new(egui::Id::new("viewer_card"))
            .order(egui::Order::Foreground)
            .anchor(
                egui::Align2::CENTER_CENTER,
                Vec2::new(theme::SIDEBAR_W * 0.5, 0.0),
            )
            .show(ctx, |ui| {
                frame.show(ui, |ui| {
                    ui.set_width(size.x);
                ui.horizontal(|ui| {
                    ui.add_space(14.0);
                    ui.vertical(|ui| {
                        ui.add_space(10.0);
                        ui.label(egui::RichText::new(&title).size(16.0).strong());
                        ui.label(
                            egui::RichText::new(format!("{}.{} · {} · {modified}", title, ext, store::format_bytes(size_bytes)))
                                .size(10.5)
                                .color(theme::TEXT_MUTED),
                        );
                    });
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        ui.add_space(10.0);
                        let close_btn = egui::Button::new(
                            egui::RichText::new("✕  Fechar").size(12.5).color(theme::TEXT),
                        )
                        .fill(theme::BG_CARD_HOVER)
                        .stroke(egui::Stroke::new(1.0_f32, theme::LINE))
                        .min_size(Vec2::new(86.0, 28.0));
                        if ui.add(close_btn).on_hover_text("Fechar esta janela (Esc)").clicked() {
                            close = true;
                        }
                        ui.add_space(6.0);
                        let fav = self.settings.is_favorite(&path);
                        let label = if fav { "★ Favorito" } else { "☆ Favoritar" };
                        if ui.button(label).clicked() {
                            toggle_fav = Some(path.clone());
                        }
                    });
                });
                ui.add_space(6.0);
                ui.horizontal_top(|ui| {
                    ui.add_space(14.0);
                    let left_w = size.x - 380.0;
                    let left_h = size.y - 110.0;
                    let (rect, resp) = ui.allocate_exact_size(Vec2::new(left_w, left_h), Sense::drag());
                    ui_rect(ui.painter(), rect, theme::BG_CARD, Some(theme::LINE), 8);
                    // interaction
                    let v = self.open.as_mut().unwrap();
                    if resp.dragged() {
                        let d = resp.drag_delta();
                        v.cam.yaw -= d.x * 0.008;
                        v.cam.pitch = (v.cam.pitch + d.y * 0.006).clamp(-1.4, 1.4);
                        v.needs_render = true;
                    }
                    if resp.hovered() {
                        let scroll = ui.input(|i| i.smooth_scroll_delta.y);
                        if scroll.abs() > 0.1 {
                            v.cam.zoom = (v.cam.zoom * (1.0 + scroll * 0.0015)).clamp(0.3, 6.0);
                            v.needs_render = true;
                        }
                    }
                    // which mesh is shown
                    let show_mesh: mesh::Mesh = if ext == "3mf" && !v.loaded.plates.is_empty() {
                        v.loaded.plates[v.plate.min(v.loaded.plates.len() - 1)].1.clone()
                    } else {
                        v.loaded.mesh.clone()
                    };
                    // What the big picture shows: the model drawn here, or — when the
                    // person asks for it — the slicer's own picture of the same plate.
                    let plate_tex = if ext == "3mf" {
                        v.plate_tex.get(v.plate).and_then(|t| t.as_ref()).map(|t| t.id())
                    } else {
                        None
                    };
                    let want_plate = v.show_plate && plate_tex.is_some();
                    if v.needs_render {
                        let rw = (rect.width() as usize).min(760).max(64);
                        let rh = (rect.height() as usize).min(560).max(64);
                        if ext == "svg" {
                            if let Some((pw, ph, rgba)) = v.loaded.svg_rgba.clone() {
                                let img = egui::ColorImage::from_rgba_unmultiplied([pw, ph], &rgba);
                                match &mut v.tex {
                                    Some(t) => t.set(img, TextureOptions::LINEAR),
                                    None => {
                                        v.tex = Some(ctx.load_texture(
                                            "svgview",
                                            img,
                                            TextureOptions::LINEAR,
                                        ))
                                    }
                                }
                            }
                            v.needs_render = false;
                        } else {
                            let rgba = render::render(
                                &show_mesh,
                                rw,
                                rh,
                                &v.cam,
                                v.wireframe,
                                [theme::BG_CARD.r(), theme::BG_CARD.g(), theme::BG_CARD.b()],
                                theme::MODEL_TINT,
                            );
                            let img = egui::ColorImage::from_rgba_unmultiplied([rw, rh], &rgba);
                            match &mut v.tex {
                                Some(t) => t.set(img, TextureOptions::LINEAR),
                                None => {
                                    v.tex = Some(ctx.load_texture("viewer", img, TextureOptions::LINEAR))
                                }
                            }
                            v.needs_render = false;
                        }
                    }
                    let v = self.open.as_ref().unwrap();
                    if ext == "svg" && v.tex.is_none() {
                        ui.painter().text(
                            rect.center(),
                            Align2::CENTER_CENTER,
                            "SVG — desenho vetorial",
                            FontId::proportional(14.0),
                            theme::TEXT_DIM,
                        );
                        if let Some(d) = v.loaded.svg_dims {
                            ui.painter().text(
                                rect.center() + Vec2::new(0.0, 24.0),
                                Align2::CENTER_CENTER,
                                store::format_dimensions(d),
                                FontId::proportional(11.5),
                                theme::TEXT_MUTED,
                            );
                        }
                    } else {
                        // Whichever picture is chosen is painted on every frame: one
                        // that is only drawn on the frame that made it is gone by the
                        // next, which is the blinking this page used to have.
                        let picture = if want_plate {
                            v.plate_tex.get(v.plate).and_then(|t| t.as_ref())
                        } else {
                            v.tex.as_ref()
                        };
                        if let Some(tex) = picture {
                            let sz = tex.size_vec2();
                            let scale = (rect.width() / sz.x).min(rect.height() / sz.y);
                            let img_rect = Rect::from_center_size(rect.center(), sz * scale);
                            ui.painter().image(
                                tex.id(),
                                img_rect,
                                Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
                                Color32::WHITE,
                            );
                        }
                    }
                    if let Some(err) = &v.loaded.error {
                        let box_rect = Rect::from_center_size(
                            rect.center() + Vec2::new(0.0, 30.0),
                            Vec2::new(rect.width().min(420.0), 74.0),
                        );
                        ui_rect(
                            ui.painter(),
                            box_rect,
                            theme::BG_INPUT,
                            Some(theme::LINE),
                            8,
                        );
                        ui.painter().text(
                            box_rect.center() + Vec2::new(0.0, -16.0),
                            Align2::CENTER_CENTER,
                            "Esta peça não pôde ser desenhada",
                            FontId::proportional(13.0),
                            theme::WARN,
                        );
                        ui.painter().text(
                            box_rect.center() + Vec2::new(0.0, 12.0),
                            Align2::CENTER_CENTER,
                            truncate(err, 66),
                            FontId::proportional(11.0),
                            theme::TEXT_MUTED,
                        );
                    }
                    // overlay controls
                    let mut bx = rect.left() + 12.0;
                    let by = rect.bottom() - 34.0;
                    let mut vclick: Option<usize> = None;
                    let mut buttons: Vec<(&str, bool)> = vec![
                        ("⟳ Girar", v.auto_rotate),
                        ("▦ Arestas", v.wireframe),
                        ("⤢ Resetar", false),
                    ];
                    // Only offered when this file brings a picture of its own plate.
                    if plate_tex.is_some() {
                        buttons.push(("▣ Fatiador", v.show_plate));
                    }
                    for (vi, (label, on)) in buttons.into_iter().enumerate()
                    {
                        let b = Rect::from_min_size(Pos2::new(bx, by), Vec2::new(78.0, 24.0));
                        let resp = ui.interact(b, egui::Id::new(("vbtn", label)), Sense::click());
                        ui_rect(
                            ui.painter(),
                            b,
                            if on { theme::ACCENT_DIM } else { theme::BG_INPUT },
                            Some(theme::LINE),
                            5,
                        );
                        ui.painter().text(
                            b.center(),
                            Align2::CENTER_CENTER,
                            label,
                            FontId::proportional(10.5),
                            if on { Color32::WHITE } else { theme::TEXT_DIM },
                        );
                        if resp.clicked() {
                            vclick = Some(vi);
                        }
                        bx += 86.0;
                    }
                    if !v.loaded.plates.is_empty() && v.loaded.plates.len() > 1 {
                        let info = format!(
                            "Bandeja {} de {} · use ‹ › ou clique na lista",
                            v.plate + 1,
                            v.loaded.plates.len()
                        );
                        ui.painter().text(
                            Pos2::new(rect.right() - 12.0, by + 12.0),
                            Align2::RIGHT_CENTER,
                            info,
                            FontId::proportional(10.5),
                            theme::TEXT_MUTED,
                        );
                    }

                    // ---- details column
                    if let Some(vi) = vclick {
                        let v = self.open.as_mut().unwrap();
                        match vi {
                            0 => v.auto_rotate = !v.auto_rotate,
                            1 => {
                                v.wireframe = !v.wireframe;
                                v.needs_render = true;
                            }
                            3 => v.show_plate = !v.show_plate,
                            _ => {
                                v.cam = render::Camera::default();
                                v.needs_render = true;
                            }
                        }
                    }
                    ui.add_space(10.0);
                    let mut set_plate: Option<usize> = None;
                    // The ficha gets a Ui placed at an explicit rect. Inside the
                    // horizontal row a ScrollArea only ever drew its first row here.
                    let drect = egui::Rect::from_min_size(
                        egui::Pos2::new(rect.right() + 22.0, rect.top()),
                        Vec2::new(
                            (ui.max_rect().right() - rect.right() - 36.0).max(300.0),
                            left_h,
                        ),
                    );
                    let mut dui = ui.new_child(
                        egui::UiBuilder::new()
                            .max_rect(drect)
                            .layout(egui::Layout::top_down(egui::Align::Min)),
                    );
                    egui::ScrollArea::vertical()
                        .id_salt("details")
                        .max_height(left_h)
                        .show(&mut dui, |ui| {
                            ui.set_width((drect.width() - 10.0).max(280.0));
                            let v = self.open.as_ref().unwrap();
                            let l = &v.loaded;
                            // primary action
                            if ui
                                .add_sized(
                                    [340.0, 30.0],
                                    egui::Button::new(
                                        egui::RichText::new("Abrir no fatiador").size(13.0).strong(),
                                    ),
                                )
                                .clicked()
                            {
                                open_slicer = Some(path.clone());
                            }
                            ui.add_space(4.0);
                            ui.horizontal(|ui| {
                                if ui.button("Renomear").clicked() {
                                    dialog_open =
                                        Some(Dialog::Rename(path.clone(), title.clone()));
                                }
                                if ui.button("Mover").clicked() {
                                    dialog_open =
                                        Some(Dialog::Move(path.clone(), String::new(), String::new()));
                                }
                                if ui.button("Pasta").clicked() {
                                    let _ = slicers::reveal(&path);
                                }
                                if ui.button("Classificar").clicked() {
                                    dialog_open = Some(Dialog::Assign(vec![path.clone()], String::new()));
                                }
                                if ui
                                    .add(egui::Button::new(
                                        egui::RichText::new("Lixeira").color(theme::DANGER),
                                    ))
                                    .clicked()
                                {
                                    start_trash = true;
                                }
                            });
                            ui.add_space(8.0);
                            // facts
                            let mut rows: Vec<(String, String)> = Vec::new();
                            rows.push(("Formato".into(), ext.to_uppercase()));
                            rows.push(("Tamanho".into(), store::format_bytes(size_bytes)));
                            rows.push(("Modificado".into(), modified.clone()));
                            if let Some(cid) = self.settings.collection_of(&path) {
                                if let Some(name) = self.settings.collection_name(cid) {
                                    rows.push(("Pasta".into(), name.to_string()));
                                }
                            }
                            let dims = if let Some(d) = l.svg_dims {
                                d
                            } else {
                                l.mesh.dims()
                            };
                            if dims[0] > 0.0 {
                                rows.push(("Dimensões".into(), store::format_dimensions(dims)));
                            }
                            if l.mesh.tris > 0 {
                                rows.push(("Triângulos".into(), format!("{}", l.mesh.tris)));
                                rows.push(("Volume".into(), format!("{:.1} cm³", l.mesh.volume_cm3)));
                            }
                            if !l.plates.is_empty() {
                                rows.push(("Bandejas".into(), l.plates.len().to_string()));
                            }
                            let m = l.meta.clone();
                            if !m.printer.is_empty() {
                                rows.push(("Impressora".into(), m.printer.clone()));
                            }
                            if !m.nozzle.is_empty() {
                                rows.push(("Bico".into(), format!("{} mm", m.nozzle)));
                            }
                            if !m.layer_height.is_empty() {
                                rows.push(("Camada".into(), format!("{} mm", m.layer_height)));
                            }
                            if !m.infill.is_empty() {
                                rows.push(("Preenchimento".into(), format!("{}%", m.infill)));
                            }
                            if let Some(s) = m.supports {
                                rows.push(("Suportes".into(), if s { "sim".into() } else { "não".into() }));
                            }
                            if !m.profile.is_empty() {
                                rows.push(("Perfil".into(), m.profile.clone()));
                            }
                            if !m.designer.is_empty() {
                                rows.push(("Autor".into(), m.designer.clone()));
                            }
                            if !m.title.is_empty() {
                                rows.push(("Título".into(), m.title.clone()));
                            }
                            if !m.description.is_empty() {
                                rows.push(("Descrição".into(), m.description.clone()));
                            }
                            if !m.license.is_empty() {
                                rows.push(("Licença".into(), m.license.clone()));
                            }
                            if !m.source_app.is_empty() {
                                rows.push(("Fatiado com".into(), m.source_app.clone()));
                            }
                            ui_rect(ui.painter(), ui.available_rect_before_wrap().shrink2(Vec2::ZERO), theme::BG_CARD, Some(theme::LINE), 8);
                            ui.add_space(6.0);
                            ui.horizontal(|ui| {
                                ui.add_space(8.0);
                                ui.vertical(|ui| {
                                    ui.label(egui::RichText::new("Ficha técnica").size(12.0).strong());
                                    for (k, val) in &rows {
                                        ui.horizontal(|ui| {
                                            ui.label(
                                                egui::RichText::new(format!("{k}:"))
                                                    .size(11.0)
                                                    .color(theme::TEXT_MUTED),
                                            );
                                            ui.label(
                                                egui::RichText::new(truncate(val, 42))
                                                    .size(11.0)
                                                    .color(theme::TEXT),
                                            );
                                        });
                                    }
                                });
                            });
                            ui.add_space(8.0);

                            // plates
                            if !l.plates.is_empty() {
                                ui.label(egui::RichText::new("Bandejas").size(12.0).strong());
                                for (i, (p, _m)) in l.plates.iter().enumerate() {
                                    let label = format!(
                                        "{}  {}{}{}",
                                        p.name,
                                        p.seconds.map(store::format_duration).unwrap_or_default(),
                                        if p.grams.is_some() { " · " } else { "" },
                                        p.grams.map(|g| format!("{g:.1} g")).unwrap_or_default()
                                    );
                                    let mut text = format!("{} {label}", if i == v.plate { "●" } else { "○" });
                                    if text.lines().count() > 6 {
                                        text = truncate(&text, 60);
                                    }
                                    if ui.selectable_label(i == v.plate, text).clicked() {
                                        set_plate = Some(i);
                                    }
                                }
                                ui.add_space(6.0);
                            }
                            // filaments
                            let fils = if !l.meta.filaments.is_empty() {
                                l.meta.filaments.clone()
                            } else if let Some((p, _)) = l.plates.first() {
                                p.filaments.clone()
                            } else {
                                Vec::new()
                            };
                            if !fils.is_empty() {
                                ui.label(egui::RichText::new("Filamentos").size(12.0).strong());
                                for f in &fils {
                                    ui.horizontal(|ui| {
                                        let col = Color32::from_rgb(
                                            mesh::hex_to_rgb(&f.hex)[0],
                                            mesh::hex_to_rgb(&f.hex)[1],
                                            mesh::hex_to_rgb(&f.hex)[2],
                                        );
                                        let (r, _) =
                                            ui.allocate_exact_size(Vec2::splat(12.0), Sense::hover());
                                        ui.painter().circle_filled(r.center(), 5.0, col);
                                        ui.label(
                                            egui::RichText::new(truncate(
                                                &format!(
                                                    "{} {}{}",
                                                    f.material,
                                                    f.color_name,
                                                    f.grams.map(|g| format!(" · {g:.1} g")).unwrap_or_default()
                                                ),
                                                34,
                                            ))
                                            .size(11.0)
                                            .color(theme::TEXT_DIM),
                                        );
                                    });
                                }
                                // stock match
                                let needs: Vec<filaments::Need> = fils
                                    .iter()
                                    .map(|f| filaments::Need {
                                        material: f.material.clone(),
                                        hex: f.hex.clone(),
                                        grams: f.grams,
                                    })
                                    .collect();
                                let (status, used) = filaments::evaluate(&needs, &self.settings.spools);
                                let color = match status {
                                    filaments::Status::Ok => theme::THREEMF,
                                    filaments::Status::NoColor => theme::WARN,
                                    filaments::Status::Missing => theme::DANGER,
                                };
                                ui.add_space(4.0);
                                ui.horizontal(|ui| {
                                    let (r, _) = ui.allocate_exact_size(Vec2::new(8.0, 8.0), Sense::hover());
                                    ui.painter().circle_filled(r.center(), 4.0, color);
                                    ui.label(
                                        egui::RichText::new(status.label())
                                            .size(11.0)
                                            .color(color),
                                    );
                                });
                                for i in used {
                                    if let Some(s) = self.settings.spools.get(i) {
                                        ui.label(
                                            egui::RichText::new(format!(
                                                "  {} {} · {:.0} g restantes",
                                                s.brand, s.material, s.remaining_g
                                            ))
                                            .size(10.5)
                                            .color(theme::TEXT_MUTED),
                                        );
                                    }
                                }
                            }
                            // Everything else the package carries — dates, slicer
                            // settings, plate notes — as the file spells it, so the
                            // page has all the information the file came with.
                            if !l.meta.extras.is_empty() {
                                ui.add_space(4.0);
                                ui.label(
                                    egui::RichText::new(format!(
                                        "Tudo o que vem no ficheiro ({})",
                                        l.meta.extras.len()
                                    ))
                                    .size(12.0)
                                    .strong(),
                                );
                                ui.add_space(2.0);
                                for (k, val) in &l.meta.extras {
                                    ui.label(
                                        egui::RichText::new(format!(
                                            "{}: {}",
                                            truncate(k, 34),
                                            truncate(val, 70)
                                        ))
                                        .size(10.5)
                                        .color(theme::TEXT_DIM),
                                    );
                                }
                            }
                            ui.add_space(14.0);
                        });
                    if let Some(p) = set_plate {
                        let v = self.open.as_mut().unwrap();
                        v.plate = p;
                        v.needs_render = true;
                    }
                });
                });
            });

        if let Some(p) = toggle_fav {
            self.settings.toggle_favorite(&p);
        }
        if close {
            self.open = None;
        }
        if start_trash {
            self.dialog = Dialog::Trash(vec![path.clone()]);
        }
        if let Some(d) = dialog_open {
            self.dialog = d;
        }
        if let Some(_p) = open_slicer {
            let slicer_id = self.settings.default_slicer.clone();
            let res = if slicer_id == "system" {
                slicers::open_system(&path)
            } else if self.models[v_idx].ext == "svg" {
                match self.slicers.iter().find(|s| s.id == slicer_id) {
                    Some(s) if s.svg => slicers::open_with(s, &path),
                    Some(s) => Err(format!("{} não abre SVG", s.name)),
                    None => Err("fatiador não encontrado".into()),
                }
            } else {
                match self.slicers.iter().find(|s| s.id == slicer_id) {
                    Some(s) => slicers::open_with(s, &path),
                    None => Err("fatiador não encontrado".into()),
                }
            };
            match res {
                Ok(()) => self.notify("Abrindo no fatiador…".into()),
                Err(e) => self.notify(e),
            }
            self.last_slicer = slicer_id;
        }
        if open_next.is_some() {
            // reserved for future keyboard navigation
        }
    }

    // -------------------------------------------------------- dialogs

    fn dialog_ui(&mut self, ctx: &egui::Context) {
        let mut close = false;
        match &mut self.dialog {
            Dialog::None => return,
            Dialog::ConnectFolder(text) => {
                let mut t = text.clone();
                let mut ok = false;
                egui::Window::new("Conectar pasta")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(460.0, 150.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        ui.label("Caminho completo da pasta com modelos STL, 3MF ou SVG:");
                        ui.add(
                            egui::TextEdit::singleline(&mut t)
                                .hint_text("C:\\Users\\voce\\Modelos")
                                .desired_width(430.0),
                        );
                        ui.add_space(6.0);
                        ui.horizontal(|ui| {
                            for (label, dir) in quick_folders() {
                                if ui.small_button(label).clicked() {
                                    t = dir;
                                }
                            }
                        });
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Conectar").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok {
                    let p = PathBuf::from(&t);
                    if p.is_dir() {
                        self.settings.folders.push(t.clone());
                        self.settings.save();
                        self.rescan();
                        close = true;
                    } else {
                        self.notify("Essa pasta não existe".into());
                    }
                }
                if let Dialog::ConnectFolder(orig) = &mut self.dialog {
                    *orig = t;
                }
            }
            Dialog::Rename(path, text) => {
                let mut t = text.clone();
                let mut ok = false;
                let p = path.clone();
                egui::Window::new("Renomear")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(420.0, 120.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        ui.label("Novo nome (sem a extensão):");
                        ui.add(egui::TextEdit::singleline(&mut t).desired_width(390.0));
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Renomear").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok && !t.trim().is_empty() {
                    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("");
                    let mut target = p.clone();
                    target.set_file_name(format!("{}.{}", t.trim(), ext));
                    if target.exists() {
                        self.notify("Já existe um arquivo com esse nome".into());
                    } else if let Err(e) = std::fs::rename(&p, &target) {
                        self.notify(format!("Não foi possível renomear: {e}"));
                    } else {
                        self.notify("Renomeado".into());
                        close = true;
                    }
                    self.rescan();
                    self.open = None;
                }
                if let Dialog::Rename(_, orig) = &mut self.dialog {
                    *orig = t;
                }
            }
            Dialog::Move(path, dest, new_sub) => {
                let mut d = dest.clone();
                let mut sub = new_sub.clone();
                let mut ok = false;
                let p = path.clone();
                let folders = self.settings.folders.clone();
                egui::Window::new("Mover modelo")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(520.0, 380.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        ui.label("Escolha a pasta de destino:");
                        egui::ScrollArea::vertical()
                            .max_height(200.0)
                            .id_salt("movetree")
                            .show(ui, |ui| {
                                for f in &folders {
                                    let name = Path::new(f)
                                        .file_name()
                                        .and_then(|s| s.to_str())
                                        .unwrap_or(f)
                                        .to_string();
                                    if ui.selectable_label(d == *f, format!("🗀 {name}")).clicked() {
                                        d = f.clone();
                                    }
                                    let mut subs: Vec<String> = self
                                        .models
                                        .iter()
                                        .filter(|m| &m.folder == f && !m.rel_dir.is_empty())
                                        .map(|m| m.rel_dir.clone())
                                        .collect();
                                    subs.sort();
                                    subs.dedup();
                                    for s in subs {
                                        let full = format!("{}\\{}", f.trim_end_matches(['/', '\\']), s);
                                        if ui.selectable_label(false, format!("    └ {s}")).clicked() {
                                            d = full;
                                        }
                                    }
                                }
                            });
                        ui.add_space(6.0);
                        ui.horizontal(|ui| {
                            ui.label("Nova subpasta (opcional):");
                            ui.add(egui::TextEdit::singleline(&mut sub).desired_width(200.0));
                        });
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Mover").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok && !d.is_empty() {
                    let mut dir = PathBuf::from(&d);
                    if !sub.trim().is_empty() {
                        dir = dir.join(sub.trim());
                    }
                    if std::fs::create_dir_all(&dir).is_err() {
                        self.notify("Não foi possível criar a pasta".into());
                    } else if let Some(name) = p.file_name() {
                        let target = dir.join(name);
                        if target.exists() {
                            self.notify("Já existe um arquivo com esse nome no destino".into());
                        } else if let Err(e) = std::fs::rename(&p, &target) {
                            self.notify(format!("Não foi possível mover: {e}"));
                        } else {
                            self.notify("Modelo movido".into());
                            close = true;
                            self.rescan();
                            self.open = None;
                        }
                    }
                }
                if let Dialog::Move(_, od, os) = &mut self.dialog {
                    *od = d;
                    *os = sub;
                }
            }
            Dialog::Trash(paths) => {
                let list = paths.clone();
                let mut ok = false;
                egui::Window::new("Mover para a lixeira")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(460.0, 160.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        ui.label(format!(
                            "Mover {} arquivo(s) para a lixeira do sistema?",
                            list.len()
                        ));
                        for p in list.iter().take(4) {
                            ui.label(
                                egui::RichText::new(truncate(
                                    &p.file_name().unwrap_or_default().to_string_lossy(),
                                    46,
                                ))
                                .size(11.0)
                                .color(theme::TEXT_DIM),
                            );
                        }
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui
                                .add(egui::Button::new(
                                    egui::RichText::new("Mover para a lixeira").color(theme::DANGER),
                                ))
                                .clicked()
                            {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok {
                    let mut moved = 0;
                    for p in list {
                        if send_to_trash(&p).is_ok() {
                            moved += 1;
                            self.settings.favorites.retain(|f| Path::new(f) != p);
                        }
                    }
                    self.settings.save();
                    self.notify(format!("{moved} arquivo(s) na lixeira"));
                    close = true;
                    self.open = None;
                    self.rescan();
                }
            }
            Dialog::Spool(s, editing) => {
                let mut sp = (**s).clone();
                let mut ok = false;
                let is_edit = editing.is_some();
                egui::Window::new(if is_edit { "Editar carretel" } else { "Novo carretel" })
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(460.0, 400.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        egui::Grid::new("spoolgrid").num_columns(2).spacing([10.0, 8.0]).show(ui, |ui| {
                            ui.label("Marca");
                            ui.add(egui::TextEdit::singleline(&mut sp.brand).desired_width(260.0));
                            ui.end_row();
                            ui.label("Material");
                            egui::ComboBox::from_id_salt("mat")
                                .selected_text(&sp.material)
                                .show_ui(ui, |ui| {
                                    for m in filaments::known_materials() {
                                        if ui.selectable_label(sp.material == m, m).clicked() {
                                            sp.material = m.to_string();
                                        }
                                    }
                                });
                            ui.end_row();
                            ui.label("Linha");
                            ui.add(egui::TextEdit::singleline(&mut sp.line).desired_width(260.0));
                            ui.end_row();
                            ui.label("Cor");
                            ui.horizontal(|ui| {
                                ui.add(egui::TextEdit::singleline(&mut sp.color_name).desired_width(160.0));
                                ui.add(egui::TextEdit::singleline(&mut sp.hex).desired_width(80.0));
                                let col = Color32::from_rgb(
                                    mesh::hex_to_rgb(&sp.hex)[0],
                                    mesh::hex_to_rgb(&sp.hex)[1],
                                    mesh::hex_to_rgb(&sp.hex)[2],
                                );
                                let (r, _) = ui.allocate_exact_size(Vec2::splat(16.0), Sense::hover());
                                ui.painter().circle_filled(r.center(), 7.0, col);
                            });
                            ui.end_row();
                            ui.label("Peso (g)");
                            ui.horizontal(|ui| {
                                ui.add(egui::DragValue::new(&mut sp.total_g).speed(10.0));
                                for w in filaments::quick_weights() {
                                    if ui.small_button(format!("{w:.0}")).clicked() {
                                        sp.total_g = w;
                                        sp.remaining_g = sp.remaining_g.min(w);
                                    }
                                }
                            });
                            ui.end_row();
                            ui.label("Restante (g)");
                            ui.add(egui::DragValue::new(&mut sp.remaining_g).speed(10.0));
                            ui.end_row();
                            ui.label("Preço");
                            let mut price = sp.price.unwrap_or(0.0);
                            if ui
                                .add(egui::DragValue::new(&mut price).speed(1.0).prefix("R$ "))
                                .changed()
                            {
                                sp.price = Some(price);
                            }
                            ui.end_row();
                        });
                        ui.add_space(10.0);
                        ui.horizontal(|ui| {
                            if ui.button("Salvar").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok {
                    if sp.brand.trim().is_empty() && sp.material.trim().is_empty() {
                        self.notify("Informe a marca e o material".into());
                    } else {
                        if sp.id.is_empty() {
                            sp.id = format!(
                                "{}",
                                std::time::SystemTime::now()
                                    .duration_since(std::time::UNIX_EPOCH)
                                    .map(|d| d.as_nanos())
                                    .unwrap_or(0)
                            );
                        }
                        if let Some(id) = editing.clone() {
                            if let Some(slot) = self.settings.spools.iter_mut().find(|x| x.id == id) {
                                *slot = sp.clone();
                            }
                        } else {
                            self.settings.spools.push(sp.clone());
                        }
                        self.settings.save();
                        self.notify("Estoque atualizado".into());
                        close = true;
                    }
                }
                if let Dialog::Spool(os, _) = &mut self.dialog {
                    **os = sp;
                }
            }
            Dialog::NewColl(text) => {
                let mut t = text.clone();
                let mut ok = false;
                egui::Window::new("Nova pasta")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(420.0, 170.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        ui.label("Dê um nome à classificação. Ele é só seu e fica salvo aqui.");
                        ui.add_space(6.0);
                        let r = ui.add(
                            egui::TextEdit::singleline(&mut t)
                                .hint_text("Ex.: Vasos, Peças do carro, Presentes")
                                .desired_width(380.0),
                        );
                        r.request_focus();
                        ui.label(
                            egui::RichText::new("Os arquivos continuam onde estão no disco.")
                                .size(11.0)
                                .color(theme::TEXT_MUTED),
                        );
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Criar pasta").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok && !t.trim().is_empty() {
                    let id = self.settings.add_collection(t.trim());
                    self.coll = Some(id);
                    self.section = Section::All;
                    self.notify("Pasta criada".into());
                    close = true;
                }
                if let Dialog::NewColl(orig) = &mut self.dialog {
                    *orig = t;
                }
            }
            Dialog::RenameColl(id, text) => {
                let mut t = text.clone();
                let id = id.clone();
                let mut ok = false;
                egui::Window::new("Renomear pasta")
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(420.0, 150.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        let r = ui.add(egui::TextEdit::singleline(&mut t).desired_width(380.0));
                        r.request_focus();
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Salvar").clicked() {
                                ok = true;
                            }
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                        });
                    });
                if ok && !t.trim().is_empty() {
                    self.settings.rename_collection(&id, t.trim());
                    self.notify("Pasta renomeada".into());
                    close = true;
                }
                if let Dialog::RenameColl(_, orig) = &mut self.dialog {
                    *orig = t;
                }
            }
            Dialog::Assign(paths, text) => {
                let files = paths.clone();
                let mut t = text.clone();
                let colls = self.settings.collections.clone();
                let current = files
                    .first()
                    .and_then(|p| self.settings.collection_of(p))
                    .map(|s| s.to_string());
                let mut chosen: Option<Option<String>> = None;
                let mut make = false;
                let title = if files.len() == 1 {
                    "Mover para uma pasta".to_string()
                } else {
                    format!("Mover {} arquivos", files.len())
                };
                egui::Window::new(title)
                    .collapsible(false)
                    .resizable(false)
                    .fixed_size(Vec2::new(440.0, 400.0))
                    .anchor(Align2::CENTER_CENTER, Vec2::ZERO)
                    .show(ctx, |ui| {
                        for p in files.iter().take(3) {
                            ui.label(
                                egui::RichText::new(truncate(
                                    &p.file_name().unwrap_or_default().to_string_lossy(),
                                    44,
                                ))
                                .size(11.5)
                                .color(theme::TEXT_DIM),
                            );
                        }
                        ui.add_space(8.0);
                        egui::ScrollArea::vertical()
                            .id_salt("assignlist")
                            .max_height(200.0)
                            .show(ui, |ui| {
                                if ui
                                    .selectable_label(current.is_none(), "◦  Sem pasta")
                                    .clicked()
                                {
                                    chosen = Some(None);
                                }
                                for c in &colls {
                                    let here = current.as_deref() == Some(c.id.as_str());
                                    let n = self.settings.collection_count(&c.id);
                                    if ui
                                        .selectable_label(here, format!("▤  {}   ({n})", c.name))
                                        .clicked()
                                    {
                                        chosen = Some(Some(c.id.clone()));
                                    }
                                }
                                if colls.is_empty() {
                                    ui.label(
                                        egui::RichText::new(
                                            "Você ainda não criou pastas. Escreva um nome abaixo.",
                                        )
                                        .size(11.5)
                                        .color(theme::TEXT_MUTED),
                                    );
                                }
                            });
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            ui.add(
                                egui::TextEdit::singleline(&mut t)
                                    .hint_text("Nova pasta...")
                                    .desired_width(240.0),
                            );
                            if ui.button("Criar e mover").clicked() {
                                make = true;
                            }
                        });
                        ui.add_space(8.0);
                        ui.horizontal(|ui| {
                            if ui.button("Cancelar").clicked() {
                                close = true;
                            }
                            if ui.button("Excluir esta pasta").clicked() {
                                if let Some(id) = current.clone() {
                                    self.settings.remove_collection(&id);
                                    self.notify("Pasta excluída".into());
                                    close = true;
                                }
                            }
                        });
                    });
                if make {
                    if t.trim().is_empty() {
                        self.notify("Escreva o nome da pasta".into());
                    } else {
                        let id = self.settings.add_collection(t.trim());
                        chosen = Some(Some(id));
                    }
                }
                if let Some(target) = chosen {
                    for p in &files {
                        self.settings.set_collection(p, target.as_deref());
                    }
                    match target.as_deref().and_then(|id| self.settings.collection_name(id)) {
                        Some(name) => self.notify(format!("{} arquivo(s) em {}", files.len(), name)),
                        None => self.notify("Arquivo(s) sem pasta".into()),
                    }
                    close = true;
                }
                if let Dialog::Assign(_, orig) = &mut self.dialog {
                    *orig = t;
                }
            }
        }
        if close {
            self.dialog = Dialog::None;
        }
    }

    fn toast_ui(&mut self, ctx: &egui::Context) {
        let Some((text, t)) = &mut self.toast else { return };
        *t += ctx.input(|i| i.stable_dt) as f64;
        if *t > 3.2 {
            self.toast = None;
            return;
        }
        let alpha = (1.0 - ((*t - 2.6) / 0.6).max(0.0)) as f32;
        let screen = ctx.screen_rect();
        let pos = Pos2::new(screen.right() - 18.0, screen.bottom() - 24.0);
        let galley = ctx.fonts(|f| {
            f.layout_no_wrap(
                text.clone(),
                FontId::proportional(12.0),
                Color32::from_white_alpha((alpha * 255.0) as u8),
            )
        });
        let rect = Rect::from_min_size(
            Pos2::new(pos.x - galley.size().x - 28.0, pos.y - galley.size().y - 22.0),
            galley.size() + Vec2::new(28.0, 20.0),
        );
        let p = ctx.layer_painter(egui::LayerId::new(
            egui::Order::Tooltip,
            egui::Id::new("toast"),
        ));
        p.rect_filled(
            rect,
            theme::radius(8),
            Color32::from_rgba_unmultiplied(21, 30, 41, (alpha * 245.0) as u8),
        );
        p.rect_stroke(
            rect,
            theme::radius(8),
            Stroke::new(1.0_f32, Color32::from_rgba_unmultiplied(0x22, 0xd3, 0xee, (alpha * 120.0) as u8)),
            StrokeKind::Inside,
        );
        p.galley(rect.min + Vec2::new(14.0, 10.0), galley, Color32::WHITE);
        ctx.request_repaint();
    }
}

// ---------------------------------------------------------------- drawing helpers

#[allow(clippy::too_many_arguments)]
fn draw_card(
    ui: &mut egui::Ui,
    rect: Rect,
    m: &Model,
    hovered: bool,
    fav: bool,
    dup: bool,
    tex: Option<&TextureHandle>,
    info: Option<&CardInfo>,
    folder: Option<&str>,
    _slicer_label: &str,
    show_trash: bool,
    acts: &mut CardActs,
    idx: usize,
) {
    let p = ui.painter();
    ui_rect(
        p,
        rect,
        if hovered { theme::BG_CARD_HOVER } else { theme::BG_CARD },
        Some(if hovered { theme::ACCENT_DIM } else { theme::LINE }),
        8,
    );
    let thumb_h = (rect.height() - 108.0).max(40.0);
    let thumb = Rect::from_min_size(rect.min, Vec2::new(rect.width(), thumb_h));
    if let Some(t) = tex {
        let sz = t.size_vec2();
        let scale = (thumb.width() / sz.x).max(thumb.height() / sz.y);
        let draw = Rect::from_center_size(thumb.center(), sz * scale);
        p.image(
            t.id(),
            draw.intersect(thumb),
            Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)),
            Color32::WHITE,
        );
    } else {
        // nothing rendered yet: a quiet panel in the format's colour, no loud fill
        p.rect_filled(thumb, theme::radius(8), theme::BG_CARD_HOVER);
        p.text(
            thumb.center(),
            Align2::CENTER_CENTER,
            match m.ext.as_str() {
                "stl" => "◮",
                "3mf" => "◫",
                _ => "◈",
            },
            FontId::proportional(30.0),
            theme::format_color(&m.ext),
        );
    }
    // faint vignette at the bottom of the picture so the text below reads
    let fade = Rect::from_min_size(
        Pos2::new(thumb.left(), thumb.bottom() - 22.0),
        Vec2::new(thumb.width(), 22.0),
    );
    p.rect_filled(
        fade,
        theme::radius(0),
        Color32::from_rgba_unmultiplied(15, 22, 31, 90),
    );

    let ext_rect = chip(
        p,
        thumb.min + Vec2::new(8.0, 8.0),
        &format!(".{}", m.ext.to_uppercase()),
        theme::format_color(&m.ext),
        Color32::from_rgba_unmultiplied(10, 15, 22, 210),
    );
    if info.map(|i| i.sliced).unwrap_or(false) {
        chip(
            p,
            Pos2::new(ext_rect.right() + 6.0, ext_rect.top()),
            "fatiado",
            theme::ACCENT,
            Color32::from_rgba_unmultiplied(10, 15, 22, 210),
        );
    }
    if dup {
        chip(
            p,
            thumb.min + Vec2::new(8.0, 30.0),
            "duplicado",
            theme::WARN,
            Color32::from_rgba_unmultiplied(10, 15, 22, 210),
        );
    }
    // star
    let star_rect = Rect::from_min_size(
        Pos2::new(thumb.right() - 26.0, thumb.top() + 6.0),
        Vec2::splat(20.0),
    );
    let resp = ui.interact(star_rect, egui::Id::new(("fav", idx)), Sense::click());
    p.text(
        star_rect.center(),
        Align2::CENTER_CENTER,
        if fav { "★" } else { "☆" },
        FontId::proportional(15.0),
        if fav { theme::WARN } else { Color32::from_white_alpha(150) },
    );
    if resp.clicked() {
        acts.star = Some(idx);
    }

    // text block
    let base = Pos2::new(rect.left() + 10.0, thumb.bottom() + 8.0);
    p.text(
        base,
        Align2::LEFT_TOP,
        truncate(&m.name, ((rect.width() - 20.0) / 6.6) as usize),
        FontId::proportional(12.5),
        theme::TEXT,
    );
    p.text(
        base + Vec2::new(0.0, 19.0),
        Align2::LEFT_TOP,
        format!("{} · {}", store::format_bytes(m.size), store::format_date(m.modified)),
        FontId::proportional(10.5),
        theme::TEXT_MUTED,
    );
    if let Some(i) = info {
        if let Some(d) = i.dims {
            p.text(
                base + Vec2::new(0.0, 35.0),
                Align2::LEFT_TOP,
                store::format_dimensions(d),
                FontId::proportional(10.0),
                theme::TEXT_MUTED,
            );
        }
    }

    // ---- footer: where it lives, then the row of always-visible actions
    let btn_h = 27.0;
    let by = rect.bottom() - btn_h - 9.0;
    let folder_label = match folder {
        Some(f) => format!("▤ {f}"),
        None => truncate(&m.rel_dir.replace('\\', "/"), ((rect.width() - 20.0) / 5.6) as usize),
    };
    p.text(
        Pos2::new(rect.left() + 10.0, by - 11.0),
        Align2::LEFT_CENTER,
        folder_label,
        FontId::proportional(10.0),
        if folder.is_some() { theme::ACCENT } else { theme::TEXT_MUTED },
    );
    if !show_trash {
        return;
    }
    let gap = 6.0;
    let bw = ((rect.width() - 16.0 - gap * 2.0) / 3.0).max(28.0);
    let defs: [(String, Color32, u8); 3] = [
        ("▤ Pasta".to_string(), theme::ACCENT, 0),
        ("Renomear".to_string(), theme::TEXT, 1),
        ("✕ Excluir".to_string(), theme::DANGER, 2),
    ];
    let mut bx = rect.left() + 8.0;
    for (text, fg, kind) in defs.into_iter() {
        let b = Rect::from_min_size(Pos2::new(bx, by), Vec2::new(bw, btn_h));
        if card_btn(ui, b, egui::Id::new(("cardbtn", idx, kind)), &text, fg, false) {
            match kind {
                0 => acts.assign = Some(idx),
                1 => acts.rename = Some(idx),
                _ => acts.delete = Some(idx),
            }
            acts.touch = Some(idx);
        }
        bx += bw + gap;
    }
}

/// A labelled button drawn straight onto a card: filled on hover, outlined
/// otherwise, so it reads as something to press and not as decoration.
fn card_btn(ui: &egui::Ui, rect: Rect, id: egui::Id, label: &str, fg: Color32, hot: bool) -> bool {
    let resp = ui.interact(rect, id, Sense::click()).on_hover_cursor(egui::CursorIcon::PointingHand);
    let hovered = resp.hovered();
    let fill = if hovered {
        Color32::from_rgba_unmultiplied(fg.r(), fg.g(), fg.b(), 52)
    } else if hot {
        Color32::from_rgba_unmultiplied(fg.r(), fg.g(), fg.b(), 26)
    } else {
        Color32::from_rgba_unmultiplied(255, 255, 255, 13)
    };
    let stroke = if hovered { fg } else { theme::LINE };
    ui_rect(ui.painter(), rect, fill, Some(stroke), 6);
    ui.painter().text(
        rect.center(),
        Align2::CENTER_CENTER,
        label,
        FontId::proportional(10.0),
        if hovered { Color32::WHITE } else { fg },
    );
    resp.clicked()
}

fn section_label(ui: &mut egui::Ui, text: &str) {
    ui.horizontal(|ui| {
        ui.add_space(16.0);
        ui.label(
            egui::RichText::new(text)
                .size(9.5)
                .strong()
                .color(theme::TEXT_MUTED),
        );
    });
    ui.add_space(2.0);
}

fn nav_item(ui: &mut egui::Ui, glyph: &str, label: &str, count: Option<usize>, active: bool) -> bool {
    let (rect, resp) = ui.allocate_exact_size(
        Vec2::new(ui.available_width(), 30.0),
        Sense::click(),
    );
    let rect = rect.shrink2(Vec2::new(10.0, 0.0));
    if active {
        ui_rect(ui.painter(), rect, theme::BG_CARD_HOVER, None, 6);
        ui.painter().rect_filled(
            Rect::from_min_size(rect.min + Vec2::new(0.0, 6.0), Vec2::new(2.0, rect.height() - 12.0)),
            theme::radius(1),
            theme::ACCENT,
        );
    } else if resp.hovered() {
        ui_rect(ui.painter(), rect, theme::BG_CARD, None, 6);
    }
    ui.painter().text(
        rect.left_center() + Vec2::new(12.0, 0.0),
        Align2::LEFT_CENTER,
        glyph,
        FontId::proportional(12.0),
        if active { theme::ACCENT } else { theme::TEXT_MUTED },
    );
    ui.painter().text(
        rect.left_center() + Vec2::new(30.0, 0.0),
        Align2::LEFT_CENTER,
        label,
        FontId::proportional(12.0),
        if active { theme::TEXT } else { theme::TEXT_DIM },
    );
    if let Some(c) = count {
        ui.painter().text(
            rect.right_center() + Vec2::new(-10.0, 0.0),
            Align2::RIGHT_CENTER,
            c.to_string(),
            FontId::proportional(10.0),
            theme::TEXT_MUTED,
        );
    }
    resp.clicked()
}

fn card_block(ui: &mut egui::Ui, title: &str, add: impl FnOnce(&mut egui::Ui)) {
    // The same card as the library: BG_CARD panel, LINE edge, 8 px corners. The
    // frame paints the background before the content, so nothing has to guess
    // how tall the block will be.
    egui::Frame::NONE
        .fill(theme::BG_CARD)
        .stroke(Stroke::new(1.0_f32, theme::LINE))
        .corner_radius(theme::radius(8))
        .inner_margin(egui::Margin::symmetric(14, 12))
        .show(ui, |ui| {
            ui.set_width(ui.available_width());
            ui.horizontal(|ui| {
                // a short accent bar on the left of the title, like the card edge
                let (bar, _) = ui.allocate_exact_size(Vec2::new(3.0, 15.0), Sense::hover());
                ui.painter().rect_filled(bar, theme::radius(2), theme::ACCENT);
                ui.add_space(2.0);
                ui.label(
                    egui::RichText::new(title)
                        .size(13.0)
                        .strong()
                        .color(theme::TEXT),
                );
            });
            ui.add_space(8.0);
            add(ui);
        });
}

fn quick_folders() -> Vec<(&'static str, String)> {
    let mut out: Vec<(&'static str, String)> = Vec::new();
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_default();
    if home.is_empty() {
        return out;
    }
    let h = PathBuf::from(home);
    for (label, sub) in [
        ("Documentos", "Documents"),
        ("Downloads", "Downloads"),
        ("Área de Trabalho", "Desktop"),
        ("Imagens 3D", "Pictures"),
    ] {
        let p = h.join(sub);
        if p.is_dir() {
            out.push((label, p.to_string_lossy().to_string()));
        }
    }
    out
}

/// The built-in egui fonts have no ▤ ⌕ ▦ ☐ and similar symbols; on Linux they come
/// from a system font (DejaVu Sans or Noto Sans Symbols 2), added as a fallback so
/// the letters still use the app's own font.
fn symbol_fallback(ctx: &egui::Context) {
    #[cfg(not(windows))]
    {
        let candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
            "/usr/share/fonts/truetype/noto/NotoSansMath-Regular.ttf",
            "/usr/share/fonts/truetype/noto/NotoSansSymbols-Regular.ttf",
            "/usr/share/fonts/truetype/freefont/FreeSerif.ttf",
            "/usr/share/fonts/TTF/DejaVuSans.ttf",
            "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
        ];
        let mut fonts = egui::FontDefinitions::default();
        let mut added = false;
        for (i, path) in candidates.iter().enumerate() {
            if let Ok(bytes) = std::fs::read(path) {
                let name = format!("system-symbols-{i}");
                fonts.font_data.insert(name.clone(), std::sync::Arc::new(egui::FontData::from_owned(bytes)));
                for family in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
                    fonts.families.entry(family).or_default().push(name.clone());
                }
                added = true;
            }
        }
        if added {
            ctx.set_fonts(fonts);
        }
    }
    #[cfg(windows)]
    let _ = ctx;
}

// ---------------------------------------------------------------- entry point

fn main() -> eframe::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    // `--write-icon icon.ico` writes the mark as a Windows icon file, which is
    // what makes build.rs able to put it inside the .exe. It needs no window.
    if let Some(i) = args.iter().position(|a| a == "--write-icon") {
        let path = args
            .get(i + 1)
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("icon.ico"));
        match logo::write_ico(&path) {
            Ok(bytes) => println!("[carinae] ícone: {} ({} bytes)", path.display(), bytes),
            Err(e) => {
                eprintln!("[carinae] não foi possível escrever o ícone: {e}");
                std::process::exit(1);
            }
        }
        return Ok(());
    }
    let mut shot: Option<PathBuf> = None;
    if let Some(i) = args.iter().position(|a| a == "--screenshot") {
        if let Some(p) = args.get(i + 1) {
            shot = Some(PathBuf::from(p));
        }
    }
    let mut viewport = egui::ViewportBuilder::default()
        .with_title("Carinae 3D")
        .with_app_id("carinae-3d")
        .with_inner_size([1300.0, 820.0])
        .with_min_inner_size([960.0, 600.0])
        .with_icon(egui::IconData {
            rgba: logo::rgba(64),
            width: 64,
            height: 64,
        });
    if shot.is_some() {
        // A check must never steal the keyboard or sit on top of what the person
        // is doing. The window still draws while it isn't focused, which is what
        // makes the picture possible at all.
        viewport = viewport
            .with_active(false)
            .with_position([0.0, 0.0]);
        // Behind everything. Windows keeps drawing a covered window, so the
        // picture still arrives; macOS and Linux may stop, so they stay where
        // they are.
        #[cfg(target_os = "windows")]
        {
            viewport = viewport.with_window_level(egui::WindowLevel::AlwaysOnBottom);
        }
    }
    let options = eframe::NativeOptions {
        viewport,
        // A picture must be the same size every time, so a saved window size (or a
        // maximised window) is not carried into a check run.
        persist_window: shot.is_none(),
        // On macOS the window must not take the other app's place when it opens.
        #[cfg(target_os = "macos")]
        event_loop_builder: if shot.is_some() {
            use winit::platform::macos::EventLoopBuilderExtMacOS as _;
            Some(Box::new(
                |builder: &mut winit::event_loop::EventLoopBuilder<eframe::UserEvent>| {
                    builder.with_activate_ignoring_other_apps(false);
                },
            ))
        } else {
            None
        },
        ..Default::default()
    };
    eframe::run_native(
        "Carinae 3D",
        options,
        Box::new(move |cc| Ok(Box::new(App::new(cc, shot.clone())))),
    )
}
