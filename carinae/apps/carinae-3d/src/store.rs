//! Settings kept on disk, folder scanning and the duplicate fingerprint.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

pub const MODEL_EXTS: [&str; 3] = ["stl", "3mf", "svg"];

/// A named classification the person makes up themselves ("Vasos", "Peças do carro",
/// "Presentes"). Models are filed into it by path, so the files on disk stay put.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct Coll {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
}

fn def_slicer() -> String {
    "system".to_string()
}
fn def_page() -> usize {
    50
}
fn def_sort() -> String {
    "date_desc".to_string()
}
fn def_true() -> bool {
    true
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Settings {
    #[serde(default)]
    pub folders: Vec<String>,
    #[serde(default)]
    pub favorites: Vec<String>,
    #[serde(default)]
    pub spools: Vec<crate::filaments::Spool>,
    #[serde(default = "def_slicer")]
    pub default_slicer: String,
    #[serde(default = "def_page")]
    pub page_size: usize,
    #[serde(default = "def_sort")]
    pub sort: String,
    #[serde(default = "def_true")]
    pub auto_rotate: bool,
    #[serde(default)]
    pub wireframe: bool,
    #[serde(default = "def_true")]
    pub onboarded: bool,
    /// The person's own classifications, in the order they were made.
    #[serde(default)]
    pub collections: Vec<Coll>,
    /// Model path -> classification id. Empty string means "no folder".
    #[serde(default)]
    pub placement: HashMap<String, String>,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            folders: Vec::new(),
            favorites: Vec::new(),
            spools: Vec::new(),
            default_slicer: def_slicer(),
            page_size: def_page(),
            sort: def_sort(),
            auto_rotate: true,
            wireframe: false,
            onboarded: true,
            collections: Vec::new(),
            placement: HashMap::new(),
        }
    }
}

impl Settings {
    /// Next free classification id ("c1", "c2", …).
    fn next_coll_id(&self) -> String {
        let mut n = 1usize;
        loop {
            let id = format!("c{n}");
            if !self.collections.iter().any(|c| c.id == id) {
                return id;
            }
            n += 1;
        }
    }

    /// Makes a classification and returns its id. A duplicate name is allowed but
    /// gets a "(2)" suffix so the list stays readable.
    pub fn add_collection(&mut self, name: &str) -> String {
        let mut name = name.trim().to_string();
        if name.is_empty() {
            name = "Nova pasta".to_string();
        }
        let mut candidate = name.clone();
        let mut n = 2;
        while self.collections.iter().any(|c| c.name.eq_ignore_ascii_case(&candidate)) {
            candidate = format!("{name} ({n})");
            n += 1;
        }
        let id = self.next_coll_id();
        self.collections.push(Coll { id: id.clone(), name: candidate });
        self.save();
        id
    }

    pub fn rename_collection(&mut self, id: &str, name: &str) {
        let name = name.trim();
        if name.is_empty() {
            return;
        }
        if let Some(c) = self.collections.iter_mut().find(|c| c.id == id) {
            c.name = name.to_string();
        }
        self.save();
    }

    /// Drops a classification. The models stay where they are on disk; they just
    /// go back to "sem pasta".
    pub fn remove_collection(&mut self, id: &str) {
        self.collections.retain(|c| c.id != id);
        self.placement.retain(|_, v| v != id);
        self.save();
    }

    pub fn collection_name(&self, id: &str) -> Option<&str> {
        self.collections
            .iter()
            .find(|c| c.id == id)
            .map(|c| c.name.as_str())
    }

    pub fn collection_of(&self, path: &Path) -> Option<&str> {
        let key = path.to_string_lossy().to_string();
        match self.placement.get(&key) {
            Some(v) if !v.is_empty() => Some(v.as_str()),
            _ => None,
        }
    }

    /// Files a model into a classification (or takes it out when id is None).
    pub fn set_collection(&mut self, path: &Path, id: Option<&str>) {
        let key = path.to_string_lossy().to_string();
        match id {
            Some(v) if !v.is_empty() => {
                self.placement.insert(key, v.to_string());
            }
            _ => {
                self.placement.remove(&key);
            }
        }
        self.save();
    }

    pub fn collection_count(&self, id: &str) -> usize {
        self.placement.values().filter(|v| v.as_str() == id).count()
    }

    /// Forgets entries whose model no longer exists, so the counts stay honest.
    pub fn prune_placement(&mut self, alive: &[String]) {
        let before = self.placement.len();
        self.placement.retain(|k, _| alive.iter().any(|a| a == k));
        if self.placement.len() != before {
            self.save();
        }
    }
}

pub fn config_dir() -> PathBuf {
    // An explicit override keeps tests (and portable installs) away from the real settings.
    if let Ok(dir) = std::env::var("CARINAE3D_CONFIG_DIR") {
        if !dir.is_empty() {
            return PathBuf::from(dir);
        }
    }
    #[cfg(windows)]
    {
        if let Ok(appdata) = std::env::var("APPDATA") {
            return PathBuf::from(appdata).join("Carinae3D");
        }
    }
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        return PathBuf::from(xdg).join("carinae-3d");
    }
    if let Ok(home) = std::env::var("HOME") {
        return PathBuf::from(home).join(".config").join("carinae-3d");
    }
    PathBuf::from(".").join("carinae-3d-config")
}

pub fn settings_path() -> PathBuf {
    config_dir().join("settings.json")
}

impl Settings {
    pub fn load() -> Settings {
        let p = settings_path();
        if let Ok(text) = std::fs::read_to_string(&p) {
            if let Ok(s) = serde_json::from_str::<Settings>(&text) {
                return s;
            }
        }
        let mut s = Settings::default();
        s.onboarded = false;
        s
    }

    pub fn save(&self) {
        let dir = config_dir();
        let _ = std::fs::create_dir_all(&dir);
        if let Ok(text) = serde_json::to_string_pretty(self) {
            let _ = std::fs::write(settings_path(), text);
        }
    }

    pub fn is_favorite(&self, path: &Path) -> bool {
        let key = path.to_string_lossy().to_string();
        self.favorites.iter().any(|f| *f == key)
    }

    pub fn toggle_favorite(&mut self, path: &Path) {
        let key = path.to_string_lossy().to_string();
        if let Some(i) = self.favorites.iter().position(|f| *f == key) {
            self.favorites.remove(i);
        } else {
            self.favorites.push(key);
        }
        self.save();
    }
}

#[derive(Clone, Debug)]
pub struct Model {
    pub path: PathBuf,
    pub name: String,
    pub ext: String,
    pub size: u64,
    pub modified: Option<SystemTime>,
    pub folder: String,
    pub rel_dir: String,
}

impl Model {
    pub fn dir(&self) -> PathBuf {
        self.path.parent().map(|p| p.to_path_buf()).unwrap_or_default()
    }
    pub fn rel_label(&self) -> String {
        if self.rel_dir.is_empty() {
            self.folder.clone()
        } else {
            format!(
                "{}/{}",
                self.folder.trim_end_matches(['/', '\\']),
                self.rel_dir.replace('\\', "/")
            )
        }
    }
}

fn ignored_dir(name: &str) -> bool {
    let lower = name.to_lowercase();
    lower.starts_with('.')
        || lower.starts_with('$')
        || lower == "system volume information"
        || lower == "node_modules"
        || lower == "__macosx"
        || lower == "windows"
}

/// Walks every connected folder and lists the model files inside.
pub fn scan(folders: &[String]) -> Vec<Model> {
    let mut out = Vec::new();
    let own = config_dir();
    for root in folders {
        let base = PathBuf::from(root);
        if !base.is_dir() {
            continue;
        }
        walk(&base, &base, root, &own, 0, &mut out);
    }
    out
}

fn walk(dir: &Path, base: &Path, root: &str, own: &Path, depth: u32, out: &mut Vec<Model>) {
    if depth > 12 {
        return;
    }
    if dir == own {
        return;
    }
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        let ft = match entry.file_type() {
            Ok(f) => f,
            Err(_) => continue,
        };
        if ft.is_dir() {
            if ignored_dir(&name) {
                continue;
            }
            walk(&path, base, root, own, depth + 1, out);
        } else if ft.is_file() {
            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();
            if !MODEL_EXTS.contains(&ext.as_str()) {
                continue;
            }
            let meta = entry.metadata().ok();
            let size = meta.as_ref().map(|m| m.len()).unwrap_or(0);
            let modified = meta.as_ref().and_then(|m| m.modified().ok());
            let rel = path
                .parent()
                .and_then(|p| p.strip_prefix(base).ok())
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default();
            out.push(Model {
                path: path.clone(),
                name: path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("sem nome")
                    .to_string(),
                ext,
                size,
                modified,
                folder: root.to_string(),
                rel_dir: rel,
            });
        }
    }
}

/// The buffer size the original's own code uses when it streams a file through a
/// checksum (32 KiB, the output buffer in the unpacker at 0x403116).
pub const STREAM_CHUNK: usize = 0x8000;
/// The one CRC-32 table (built on first use), from the polynomial at 0x406787.
fn crc_table() -> &'static [u32; 256] {
    static TABLE: OnceLock<[u32; 256]> = OnceLock::new();
    TABLE.get_or_init(|| {
        let mut t = [0u32; 256];
        for (i, slot) in t.iter_mut().enumerate() {
            let mut v = i as u32;
            for _ in 0..8 {
                v = (v >> 1) ^ (0xedb8_8320 & (0u32.wrapping_sub(v & 1)));
            }
            *slot = v;
        }
        t
    })
}

/// CRC-32 exactly as the original program computes it at 0x406787: a 256-entry
/// table built from the reflected polynomial 0xedb88320, the running value
/// inverted at the start and at the end (the same checksum zlib calls crc32).
pub fn crc32(bytes: &[u8]) -> u32 {
    crc32_update(0, bytes, crc_table())
}

/// Continues a CRC-32 across chunks, so a big file never has to be held in memory.
fn crc32_update(crc: u32, bytes: &[u8], table: &[u32; 256]) -> u32 {
    let mut v = !crc;
    for b in bytes {
        v = (v >> 8) ^ table[((v ^ *b as u32) & 0xff) as usize];
    }
    !v
}

/// CRC-32 of a whole file, read in 32 KiB pieces (see `STREAM_CHUNK`).
pub fn crc32_file(path: &Path) -> Option<u32> {
    let mut f = std::fs::File::open(path).ok()?;
    let mut buf = vec![0u8; STREAM_CHUNK];
    let mut crc = 0u32;
    loop {
        let n = f.read(&mut buf).ok()?;
        if n == 0 {
            break;
        }
        crc = crc32_update(crc, &buf[..n], crc_table());
    }
    Some(crc)
}

/// SHA-256 of the whole file when it is small, otherwise of size + head + middle + tail.
/// The original uses the same sampling so a big model does not have to be read twice.
pub fn fingerprint(path: &Path) -> Option<String> {
    let mut f = std::fs::File::open(path).ok()?;
    let len = f.metadata().ok()?.len();
    let mut hasher = Sha256::new();
    if len <= 2 * 1024 * 1024 {
        let mut buf = Vec::with_capacity(len as usize);
        f.read_to_end(&mut buf).ok()?;
        hasher.update(&buf);
        // The bytes are already here, so the recovered CRC-32 of them is mixed in
        // as well: it can only make two different files harder to confuse.
        hasher.update(crc32(&buf).to_be_bytes());
    } else {
        const CHUNK: u64 = 65536;
        hasher.update(len.to_be_bytes());
        let mut chunk = vec![0u8; CHUNK as usize];
        f.seek(SeekFrom::Start(0)).ok()?;
        f.read_exact(&mut chunk).ok()?;
        hasher.update(&chunk);
        f.seek(SeekFrom::Start(len / 2 - CHUNK / 2)).ok()?;
        f.read_exact(&mut chunk).ok()?;
        hasher.update(&chunk);
        f.seek(SeekFrom::Start(len - CHUNK)).ok()?;
        f.read_exact(&mut chunk).ok()?;
        hasher.update(&chunk);
    }
    let digest = hasher.finalize();
    let mut s = String::with_capacity(64);
    for b in digest {
        s.push_str(&format!("{:02x}", b));
    }
    Some(s)
}

pub fn format_bytes(n: u64) -> String {
    if n < 1024 {
        format!("{n} B")
    } else if n < 1024 * 1024 {
        format!("{:.0} KB", n as f64 / 1024.0)
    } else if n < 1024 * 1024 * 1024 {
        format!("{:.1} MB", n as f64 / (1024.0 * 1024.0))
    } else {
        format!("{:.2} GB", n as f64 / (1024.0 * 1024.0 * 1024.0))
    }
}

pub fn format_dimensions(d: [f32; 3]) -> String {
    if d[0] <= 0.0 && d[1] <= 0.0 {
        return String::new();
    }
    format!("{:.0} × {:.0} × {:.0} mm", d[0], d[1], d[2])
}

pub fn format_duration(seconds: u64) -> String {
    let h = seconds / 3600;
    let m = (seconds % 3600) / 60;
    if h > 0 {
        format!("{h}h {m:02}min")
    } else {
        format!("{m}min")
    }
}

/// Day the file was last written, as the library shows it.
pub fn format_date(t: Option<SystemTime>) -> String {
    let t = match t {
        Some(t) => t,
        None => return String::new(),
    };
    let secs = t.duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) as i64;
    let (y, m, d) = civil_from_days(secs.div_euclid(86400));
    format!("{d:02}/{m:02}/{y}")
}

pub fn sort_key_time(t: Option<SystemTime>) -> u64 {
    t.and_then(|x| x.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Howard Hinnant's days-to-civil algorithm.
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sandbox() -> PathBuf {
        let dir = std::env::temp_dir().join("carinae3d-test-config");
        let _ = std::fs::create_dir_all(&dir);
        std::env::set_var("CARINAE3D_CONFIG_DIR", &dir);
        dir
    }

    #[test]
    fn folders_name_classify_and_leave_the_files_alone() {
        let dir = sandbox();
        let _ = std::fs::remove_file(dir.join("settings.json"));
        let mut s = Settings::default();
        assert!(s.collections.is_empty());

        let vasos = s.add_collection("Vasos");
        let carro = s.add_collection("  Peças do carro ");
        assert_eq!(s.collection_name(&vasos), Some("Vasos"));
        assert_eq!(s.collection_name(&carro), Some("Peças do carro"));
        assert_ne!(vasos, carro);

        // a second folder with the same name is kept apart
        let again = s.add_collection("Vasos");
        assert_eq!(s.collection_name(&again), Some("Vasos (2)"));

        let a = Path::new("C:/models/a.stl");
        let b = Path::new("C:/models/b.3mf");
        s.set_collection(a, Some(&vasos));
        s.set_collection(b, Some(&vasos));
        assert_eq!(s.collection_of(a), Some(vasos.as_str()));
        assert_eq!(s.collection_count(&vasos), 2);

        // filing elsewhere moves it, it does not copy
        s.set_collection(b, Some(&carro));
        assert_eq!(s.collection_count(&vasos), 1);
        assert_eq!(s.collection_count(&carro), 1);
        assert_eq!(s.collection_of(b), Some(carro.as_str()));

        s.set_collection(a, None);
        assert_eq!(s.collection_of(a), None);
        assert_eq!(s.collection_count(&vasos), 0);

        s.rename_collection(&carro, "Carro");
        assert_eq!(s.collection_name(&carro), Some("Carro"));

        let reloaded = Settings::load();
        assert_eq!(reloaded.collection_name(&carro), Some("Carro"));
        assert_eq!(reloaded.collection_of(b), Some(carro.as_str()));

        // deleting a folder never touches the file, it only loses the label
        s.remove_collection(&carro);
        assert_eq!(s.collection_name(&carro), None);
        assert_eq!(s.collection_of(b), None);

        // a stale path is pruned once the file has gone
        s.set_collection(a, Some(&vasos));
        s.prune_placement(&[]);
        assert_eq!(s.collection_count(&vasos), 0);
    }

    /// The check value of CRC-32: the algorithm the original uses at 0x406787 is
    /// the ordinary reflected CRC-32, so "123456789" must give 0xCBF43926.
    #[test]
    fn crc32_matches_the_standard_check_value() {
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        assert_eq!(crc32(b""), 0);
        assert_eq!(crc32(b"a"), 0xE8B7_BE43);
        // streaming in pieces must agree with one pass
        let data: Vec<u8> = (0..100_000u32).map(|i| (i % 251) as u8).collect();
        let table = TABLE_FOR_TEST;
        let mut running = 0u32;
        for part in data.chunks(STREAM_CHUNK) {
            running = crc32_update(running, part, &table);
        }
        assert_eq!(running, crc32(&data));
    }

    #[test]
    fn same_size_files_that_differ_are_not_duplicates() {
        let dir = sandbox();
        let one = dir.join("one.stl");
        let two = dir.join("two.stl");
        std::fs::write(&one, b"solid a\nendsolid a\n").unwrap();
        std::fs::write(&two, b"solid b\nendsolid b\n").unwrap();
        assert_eq!(store_size(&one), store_size(&two));
        assert_ne!(crc32_file(&one).unwrap(), crc32_file(&two).unwrap());
        let copy = dir.join("copy.stl");
        std::fs::copy(&one, &copy).unwrap();
        assert_eq!(crc32_file(&one).unwrap(), crc32_file(&copy).unwrap());
        assert_eq!(fingerprint(&one), fingerprint(&copy));
    }

    fn store_size(p: &Path) -> u64 {
        std::fs::metadata(p).map(|m| m.len()).unwrap_or(0)
    }

    static TABLE_FOR_TEST: [u32; 256] = build_table();

    const fn build_table() -> [u32; 256] {
        let mut t = [0u32; 256];
        let mut i = 0;
        while i < 256 {
            let mut v = i as u32;
            let mut k = 0;
            while k < 8 {
                v = (v >> 1) ^ (0xedb8_8320 & (0u32.wrapping_sub(v & 1)));
                k += 1;
            }
            t[i] = v;
            i += 1;
        }
        t
    }
}
