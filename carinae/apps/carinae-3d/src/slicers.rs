//! Finding slicers on this computer and opening a model in one.

use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug)]
pub struct Slicer {
    pub id: String,
    pub name: String,
    pub exe: Option<PathBuf>,
    /// Arguments that go before the model (e.g. `run com.x.Slicer` for a Flatpak).
    pub pre_args: Vec<String>,
    pub svg: bool,
}

/// The slicers the original knows, in its order, with whether each opens an SVG.
fn table() -> Vec<(&'static str, &'static str, bool, Vec<&'static str>)> {
    vec![
        ("bambu", "Bambu Studio", true, vec!["BambuStudio.exe", "bambu-studio", "bambustudio"]),
        ("orca", "OrcaSlicer", true, vec!["orca-slicer.exe", "OrcaSlicer.exe", "orcaslicer"]),
        ("prusa", "PrusaSlicer", true, vec!["prusa-slicer.exe", "PrusaSlicer.exe", "prusaslicer"]),
        ("cura", "UltiMaker Cura", false, vec!["UltiMaker-Cura.exe", "cura.exe", "cura", "ultimaker-cura"]),
        ("creality", "Creality Print", true, vec!["CrealityPrint.exe", "Creality Print.exe", "creality-print"]),
        ("anycubic", "Anycubic Slicer Next", true, vec!["AnycubicSlicerNext.exe", "anycubic-slicer-next"]),
        ("elegoo", "ElegooSlicer", true, vec!["ElegooSlicer.exe", "elegooslicer"]),
        ("flashforge", "Orca-Flashforge", true, vec!["Orca-Flashforge.exe", "orca-flashforge"]),
        ("snapmaker", "Snapmaker Orca", true, vec!["Snapmaker_Orca.exe", "snapmaker-orca"]),
        ("qidi", "QIDIStudio", true, vec!["QIDIStudio.exe", "qidi-studio", "qidistudio"]),
        ("superslicer", "SuperSlicer", false, vec!["superslicer.exe", "SuperSlicer.exe", "superslicer"]),
    ]
}

fn roots() -> Vec<PathBuf> {
    let mut out: Vec<PathBuf> = Vec::new();
    if cfg!(windows) {
        for var in ["ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA", "APPDATA"] {
            if let Ok(v) = std::env::var(var) {
                let base = PathBuf::from(v);
                if var == "LOCALAPPDATA" || var == "APPDATA" {
                    out.push(base.join("Programs"));
                } else {
                    out.push(base.clone());
                    out.push(base.join("Programs"));
                }
            }
        }
    } else {
        for p in ["/usr/bin", "/usr/local/bin", "/opt", "/snap/bin", "/var/lib/flatpak/exports/bin"] {
            out.push(PathBuf::from(p));
        }
        if let Ok(home) = std::env::var("HOME") {
            let h = PathBuf::from(home);
            out.push(h.join(".local/bin"));
            out.push(h.join("Applications"));
            out.push(h.join(".local/share/flatpak/exports/bin"));
        }
    }
    out
}

fn path_binaries() -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Ok(path) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path) {
            out.push(dir);
        }
    }
    out
}

fn find_in(dir: &Path, names: &[&str], depth: u32) -> Option<PathBuf> {
    if depth > 1 {
        return None;
    }
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return None,
    };
    let mut subdirs: Vec<PathBuf> = Vec::new();
    for e in entries.flatten() {
        let p = e.path();
        if p.is_file() {
            let fname = p.file_name().and_then(|s| s.to_str()).unwrap_or("");
            if names.iter().any(|n| n.eq_ignore_ascii_case(fname)) {
                return Some(p);
            }
        } else if p.is_dir() {
            subdirs.push(p);
        }
    }
    subdirs.sort_by(|a, b| b.cmp(a)); // newest version folder first
    for d in subdirs {
        if let Some(hit) = find_in(&d, names, depth + 1) {
            return Some(hit);
        }
    }
    None
}

/// Detects the slicers present on this computer.
pub fn detect() -> Vec<Slicer> {
    let mut out = Vec::new();
    let roots = roots();
    let bins = path_binaries();
    for (id, name, svg, names) in table() {
        let mut found: Option<PathBuf> = None;
        for root in roots.iter() {
            // a folder with the program's name, then its executable inside
            for n in &names {
                let stem = n.trim_end_matches(".exe");
                let direct = root.join(n);
                if direct.is_file() {
                    found = Some(direct);
                    break;
                }
                let dir = root.join(stem);
                if dir.is_dir() {
                    if let Some(hit) = find_in(&dir, &names, 0) {
                        found = Some(hit);
                        break;
                    }
                }
            }
            if found.is_some() {
                break;
            }
        }
        if found.is_none() {
            for dir in bins.iter() {
                for n in &names {
                    let p = dir.join(n);
                    if p.is_file() {
                        found = Some(p);
                        break;
                    }
                }
                if found.is_some() {
                    break;
                }
            }
        }
        let mut pre_args = Vec::new();
        #[cfg(not(windows))]
        if found.is_none() {
            // AppImages and Flatpaks have no fixed file name: their menu entry (.desktop) says how to start them.
            if let Some(mut cmd) = from_desktop_entries(name) {
                found = Some(PathBuf::from(cmd.remove(0)));
                pre_args = cmd;
            }
        }
        out.push(Slicer { id: id.to_string(), name: name.to_string(), exe: found, pre_args, svg });
    }
    out
}

/// Looks for a menu entry whose name is the slicer's and returns its command, without
/// the `%f`/`%U` placeholders. Only the `Exec=` of the main `[Desktop Entry]` group counts.
#[cfg(not(windows))]
fn from_desktop_entries(name: &str) -> Option<Vec<String>> {
    let want: String = name.to_lowercase().chars().filter(|c| c.is_alphanumeric()).collect();
    let mut dirs: Vec<PathBuf> = Vec::new();
    if let Ok(home) = std::env::var("HOME") {
        dirs.push(PathBuf::from(&home).join(".local/share/applications"));
        dirs.push(PathBuf::from(&home).join(".local/share/flatpak/exports/share/applications"));
    }
    for d in ["/var/lib/flatpak/exports/share/applications", "/usr/local/share/applications", "/usr/share/applications"] {
        dirs.push(PathBuf::from(d));
    }
    for dir in dirs {
        let entries = match std::fs::read_dir(&dir) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("desktop") {
                continue;
            }
            let text = match std::fs::read_to_string(&p) {
                Ok(t) => t,
                Err(_) => continue,
            };
            let mut in_main = false;
            let (mut entry_name, mut exec) = (None::<String>, None::<String>);
            for line in text.lines() {
                let line = line.trim();
                if line.starts_with('[') {
                    in_main = line == "[Desktop Entry]";
                    continue;
                }
                if !in_main {
                    continue;
                }
                if let Some(v) = line.strip_prefix("Name=") {
                    entry_name = Some(v.to_string());
                } else if let Some(v) = line.strip_prefix("Exec=") {
                    exec = Some(v.to_string());
                }
            }
            let (Some(n), Some(x)) = (entry_name, exec) else { continue };
            let n: String = n.to_lowercase().chars().filter(|c| c.is_alphanumeric()).collect();
            if n != want && !n.starts_with(&want) {
                continue;
            }
            let parts = split_exec(&x);
            if !parts.is_empty() {
                return Some(parts);
            }
        }
    }
    None
}

/// Splits an `Exec=` line (with its simple quoting) and drops the field codes.
#[cfg(not(windows))]
fn split_exec(line: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut quoted = false;
    let mut has = false;
    let mut chars = line.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '"' => {
                quoted = !quoted;
                has = true;
            }
            '\\' if quoted => {
                if let Some(n) = chars.next() {
                    cur.push(n);
                }
            }
            ' ' | '\t' if !quoted => {
                if has || !cur.is_empty() {
                    out.push(std::mem::take(&mut cur));
                    has = false;
                }
            }
            _ => cur.push(c),
        }
    }
    if has || !cur.is_empty() {
        out.push(cur);
    }
    out.into_iter()
        .filter(|a| !(a.len() == 2 && a.starts_with('%')))
        .map(|a| a.replace("%%", "%"))
        .collect()
}

pub fn open_with(slicer: &Slicer, file: &Path) -> Result<(), String> {
    match &slicer.exe {
        Some(exe) => Command::new(exe)
            .args(&slicer.pre_args)
            .arg(file)
            .spawn()
            .map(|_| ())
            .map_err(|e| format!("não foi possível abrir {}: {e}", slicer.name)),
        None => Err(format!("{} não está instalado neste computador", slicer.name)),
    }
}

/// Opens the file with whatever this computer uses by default.
pub fn open_system(file: &Path) -> Result<(), String> {
    #[cfg(windows)]
    {
        let cmd = format!("start \"\" \"{}\"", file.display());
        Command::new("cmd")
            .args(["/C", &cmd])
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        Command::new("xdg-open")
            .arg(file)
            .spawn()
            .map(|_| ())
            .map_err(|e| format!("xdg-open: {e}"))
    }
}

/// Opens the folder holding the file, with the file selected where the system allows it.
pub fn reveal(file: &Path) -> Result<(), String> {
    #[cfg(windows)]
    {
        let cmd = format!("explorer /select,\"{}\"", file.display());
        Command::new("cmd")
            .args(["/C", &cmd])
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        let dir = file.parent().unwrap_or(Path::new("."));
        Command::new("xdg-open")
            .arg(dir)
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
}
