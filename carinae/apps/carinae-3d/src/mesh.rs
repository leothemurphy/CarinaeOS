//! Reading model files: STL (binary and ASCII), 3MF (zip package with slicer metadata), SVG size.

use std::collections::HashMap;
use std::io::{Cursor, Read};

#[derive(Clone, Default, Debug)]
pub struct Mesh {
    pub pos: Vec<[f32; 3]>,
    pub idx: Vec<[u32; 3]>,
    pub min: [f32; 3],
    pub max: [f32; 3],
    pub volume_cm3: f64,
    pub tris: u64,
}

impl Mesh {
    pub fn new(pos: Vec<[f32; 3]>, idx: Vec<[u32; 3]>) -> Mesh {
        let mut m = Mesh { pos, idx, ..Default::default() };
        m.recompute();
        m
    }

    pub fn recompute(&mut self) {
        if self.pos.is_empty() {
            self.min = [0.0; 3];
            self.max = [0.0; 3];
        } else {
            let mut lo = [f32::MAX; 3];
            let mut hi = [f32::MIN; 3];
            for p in &self.pos {
                for k in 0..3 {
                    if p[k] < lo[k] {
                        lo[k] = p[k];
                    }
                    if p[k] > hi[k] {
                        hi[k] = p[k];
                    }
                }
            }
            self.min = lo;
            self.max = hi;
        }
        let mut vol = 0.0f64;
        for t in &self.idx {
            let a = self.pos[t[0] as usize];
            let b = self.pos[t[1] as usize];
            let c = self.pos[t[2] as usize];
            // signed tetra volume, divided by 6
            let cx = b[1] as f64 * c[2] as f64 - b[2] as f64 * c[1] as f64;
            let cy = b[2] as f64 * c[0] as f64 - b[0] as f64 * c[2] as f64;
            let cz = b[0] as f64 * c[1] as f64 - b[1] as f64 * c[0] as f64;
            vol += a[0] as f64 * cx + a[1] as f64 * cy + a[2] as f64 * cz;
        }
        self.volume_cm3 = (vol / 6.0).abs() / 1000.0;
        self.tris = self.idx.len() as u64;
    }

    pub fn dims(&self) -> [f32; 3] {
        [
            (self.max[0] - self.min[0]).max(0.0),
            (self.max[1] - self.min[1]).max(0.0),
            (self.max[2] - self.min[2]).max(0.0),
        ]
    }

    pub fn center(&self) -> [f32; 3] {
        [
            (self.min[0] + self.max[0]) * 0.5,
            (self.min[1] + self.max[1]) * 0.5,
            (self.min[2] + self.max[2]) * 0.5,
        ]
    }

    pub fn radius(&self) -> f32 {
        let d = self.dims();
        (0.5 * (d[0] * d[0] + d[1] * d[1] + d[2] * d[2]).sqrt()).max(0.001)
    }

    pub fn merge(&mut self, other: &Mesh, m: &Mat) {
        let base = self.pos.len() as u32;
        for p in &other.pos {
            self.pos.push(m.apply(*p));
        }
        for t in &other.idx {
            self.idx.push([t[0] + base, t[1] + base, t[2] + base]);
        }
        self.recompute();
    }
}

/// A 3MF transform: three rows of three, then the translation, as the format writes them.
#[derive(Clone, Copy, Debug)]
pub struct Mat(pub [f32; 12]);

impl Default for Mat {
    fn default() -> Self {
        Mat([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])
    }
}

impl Mat {
    pub fn parse(s: &str) -> Mat {
        let nums: Vec<f32> = s
            .split(|c: char| c == ' ' || c == ',' || c == '\t' || c == '\n' || c == '\r')
            .filter(|p| !p.is_empty())
            .filter_map(|p| p.parse::<f32>().ok())
            .collect();
        if nums.len() < 12 {
            return Mat::default();
        }
        let mut m = [0.0f32; 12];
        m.copy_from_slice(&nums[0..12]);
        Mat(m)
    }

    pub fn apply(&self, p: [f32; 3]) -> [f32; 3] {
        let m = &self.0;
        [
            p[0] * m[0] + p[1] * m[3] + p[2] * m[6] + m[9],
            p[0] * m[1] + p[1] * m[4] + p[2] * m[7] + m[10],
            p[0] * m[2] + p[1] * m[5] + p[2] * m[8] + m[11],
        ]
    }

    /// self then child (parent × child), as 3MF nests build items and components.
    pub fn then(&self, child: &Mat) -> Mat {
        let a = &self.0;
        let b = &child.0;
        let at = |i: usize, j: usize| -> f32 {
            match j {
                0 => a[i] * b[0] + a[3 + i] * b[1] + a[6 + i] * b[2],
                1 => a[i] * b[3] + a[3 + i] * b[4] + a[6 + i] * b[5],
                _ => a[i] * b[6] + a[3 + i] * b[7] + a[6 + i] * b[8],
            }
        };
        let mut m = [0.0f32; 12];
        for i in 0..3 {
            m[i] = at(i, 0);
            m[3 + i] = at(i, 1);
            m[6 + i] = at(i, 2);
        }
        m[9] = a[9] * b[0] + a[10] * b[1] + a[11] * b[2] + b[9];
        m[10] = a[9] * b[3] + a[10] * b[4] + a[11] * b[5] + b[10];
        m[11] = a[9] * b[6] + a[10] * b[7] + a[11] * b[8] + b[11];
        Mat(m)
    }
}

// ---------------------------------------------------------------- STL

pub fn parse_stl(data: &[u8]) -> Result<Mesh, String> {
    if data.len() >= 84 {
        let n = u32::from_le_bytes([data[80], data[81], data[82], data[83]]) as u64;
        if 84 + n * 50 == data.len() as u64 {
            return parse_stl_binary(data, n as usize);
        }
    }
    // Look at the header: "solid" plus printable text means ASCII.
    let head = &data[..data.len().min(512)];
    let printable = head.iter().all(|b| *b == b'\t' || *b == b'\n' || *b == b'\r' || (0x20..0x7f).contains(b));
    if printable || std::str::from_utf8(head).map(|s| s.trim_start().starts_with("solid")).unwrap_or(false) {
        let text = String::from_utf8_lossy(data);
        let m = parse_stl_ascii(&text);
        if m.tris > 0 {
            return Ok(m);
        }
    }
    if data.len() >= 84 {
        let n = u32::from_le_bytes([data[80], data[81], data[82], data[83]]) as usize;
        let fit = (data.len().saturating_sub(84)) / 50;
        if n > 0 && n <= fit {
            return parse_stl_binary(data, n);
        }
    }
    Err("não parece um STL válido".into())
}

fn parse_stl_binary(data: &[u8], n: usize) -> Result<Mesh, String> {
    let mut pos = Vec::with_capacity(n * 3);
    let mut idx = Vec::with_capacity(n);
    let mut off = 84usize;
    for t in 0..n {
        off += 12; // skip the facet normal, it is recomputed from the vertices
        if off + 36 > data.len() {
            return Err("STL binário cortado".into());
        }
        for v in 0..3 {
            let mut c = [0.0f32; 3];
            for k in 0..3 {
                let b = off + v * 12 + k * 4;
                c[k] = f32::from_le_bytes([data[b], data[b + 1], data[b + 2], data[b + 3]]);
            }
            pos.push(c);
        }
        off += 36 + 2;
        idx.push([(t * 3) as u32, (t * 3 + 1) as u32, (t * 3 + 2) as u32]);
    }
    Ok(Mesh::new(pos, idx))
}

fn parse_stl_ascii(text: &str) -> Mesh {
    let mut pos: Vec<[f32; 3]> = Vec::new();
    let mut idx: Vec<[u32; 3]> = Vec::new();
    let mut cur: Vec<u32> = Vec::new();
    for line in text.lines() {
        let l = line.trim_start();
        if let Some(rest) = l.strip_prefix("vertex ").or_else(|| l.strip_prefix("vertex\t")) {
            let nums: Vec<f32> = rest
                .split_whitespace()
                .filter_map(|p| p.parse::<f32>().ok())
                .collect();
            if nums.len() >= 3 {
                pos.push([nums[0], nums[1], nums[2]]);
                cur.push((pos.len() - 1) as u32);
                if cur.len() == 3 {
                    idx.push([cur[0], cur[1], cur[2]]);
                    cur.clear();
                }
            }
        }
    }
    if pos.is_empty() {
        return Mesh::default();
    }
    Mesh::new(pos, idx)
}

// ---------------------------------------------------------------- SVG

/// Size of an SVG in millimetres (width/height attributes, else the viewBox).
pub fn parse_svg_size(text: &str) -> [f32; 3] {
    let head: String = text.chars().take(4000).collect();
    let mut w = read_attr(&head, "width");
    let mut h = read_attr(&head, "height");
    if w.is_none() || h.is_none() {
        if let Some(vb) = attr_of(&head, "viewBox") {
            let n: Vec<f32> = vb
                .split(|c: char| c == ' ' || c == ',')
                .filter(|s| !s.is_empty())
                .filter_map(|s| s.trim().parse::<f32>().ok())
                .collect();
            if n.len() == 4 {
                w = w.or(Some(n[2]));
                h = h.or(Some(n[3]));
            }
        }
    }
    [w.unwrap_or(0.0), h.unwrap_or(0.0), 1.0]
}

fn read_attr(scope: &str, attr: &str) -> Option<f32> {
    let v = attr_of(scope, attr)?;
    let numeric: String = v
        .chars()
        .take_while(|c| c.is_ascii_digit() || *c == '.' || *c == '-' || *c == '+')
        .collect();
    numeric.parse::<f32>().ok()
}

fn attr_of(scope: &str, attr: &str) -> Option<String> {
    let key = format!("{}=\"", attr);
    let mut from = 0usize;
    while let Some(rel) = scope[from..].find(&key) {
        let start = from + rel + key.len();
        if let Some(end_rel) = scope[start..].find('"') {
            return Some(scope[start..start + end_rel].to_string());
        }
        from = start;
    }
    // single quotes
    let key = format!("{}='", attr);
    let start = scope.find(&key)? + key.len();
    let end = scope[start..].find('\'')?;
    Some(scope[start..start + end].to_string())
}

// ---------------------------------------------------------------- 3MF

#[derive(Clone, Default, Debug)]
pub struct FilamentUse {
    pub material: String,
    pub color_name: String,
    pub hex: String,
    pub grams: Option<f64>,
    pub meters: Option<f64>,
}

#[derive(Clone, Default, Debug)]
pub struct Plate {
    pub index: u32,
    pub name: String,
    pub object_ids: Vec<String>,
    pub seconds: Option<u64>,
    pub grams: Option<f64>,
    pub filaments: Vec<FilamentUse>,
    pub piece_names: Vec<String>,
}

#[derive(Clone, Default, Debug)]
pub struct Meta3mf {
    pub title: String,
    pub designer: String,
    pub license: String,
    pub origin: String,
    pub description: String,
    pub printer: String,
    pub nozzle: String,
    pub layer_height: String,
    pub infill: String,
    pub supports: Option<bool>,
    pub profile: String,
    pub source_app: String,
    pub filaments: Vec<FilamentUse>,
    pub sliced: bool,
    /// Every other key/value the package carries — dates, slicer settings, plate
    /// notes — as the file spells it, so nothing that came with the file is lost.
    pub extras: Vec<(String, String)>,
}

pub struct ThreeMf {
    pub mesh: Mesh,
    /// One entry per plate: the plate's facts and its own geometry.
    pub plates: Vec<(Plate, Mesh)>,
    pub meta: Meta3mf,
}

struct Obj3mf {
    id: String,
    name: String,
    pos: Vec<[f32; 3]>,
    idx: Vec<[u32; 3]>,
    /// (part the component lives in, object id in that part, its transform)
    comps: Vec<(String, String, Mat)>,
}

/// One `.model` part of the package. Bambu Studio and OrcaSlicer keep the real
/// geometry in `3D/Objects/*.model` and reference it from `3D/3dmodel.model`,
/// so a reader that only looks at the main part sees an empty model.
struct Part {
    key: String,
    objs: Vec<Obj3mf>,
}

fn part_key(path: &str) -> String {
    path.trim().trim_start_matches('/').replace('\\', "/").to_lowercase()
}

fn resolve_parts<'a>(parts: &'a [Part], key: &str) -> Option<&'a Vec<Obj3mf>> {
    let k = part_key(key);
    parts.iter().find(|p| p.key == k).map(|p| &p.objs)
}

pub fn read_3mf(bytes: &[u8]) -> Result<ThreeMf, String> {
    let mut zip = zip::ZipArchive::new(Cursor::new(bytes.to_vec()))
        .map_err(|e| format!("pacote 3MF inválido: {e}"))?;
    let mut model_xml = String::new();
    let mut model_path = String::new();
    for i in 0..zip.len() {
        let name = match zip.by_index(i) {
            Ok(f) => f.name().to_string(),
            Err(_) => continue,
        };
        if name.eq_ignore_ascii_case("3D/3dmodel.model") {
            model_path = name.clone();
            break;
        }
    }
    if model_path.is_empty() {
        for i in 0..zip.len() {
            if let Ok(f) = zip.by_index(i) {
                let name = f.name().to_string();
                if name.to_lowercase().ends_with(".model") {
                    model_path = name;
                    break;
                }
            }
        }
    }
    if model_path.is_empty() {
        return Err("3MF sem arquivo de geometria".into());
    }
    if let Ok(mut f) = zip.by_name(&model_path) {
        f.read_to_string(&mut model_xml).map_err(|e| e.to_string())?;
    }
    // Every other .model part of the package: Bambu Studio and OrcaSlicer put the
    // geometry there and only list components in the main part.
    let mut other_parts: Vec<(String, String)> = Vec::new();
    for i in 0..zip.len() {
        if let Ok(mut f) = zip.by_index(i) {
            let name = f.name().to_string();
            if !name.to_lowercase().ends_with(".model") || name.eq_ignore_ascii_case(&model_path) {
                continue;
            }
            let mut text = String::new();
            if f.read_to_string(&mut text).is_ok() && !text.is_empty() {
                other_parts.push((name, text));
            }
        }
    }

    let mut settings = String::new();
    let mut project = String::new();
    let mut source = String::new();
    let mut slice = String::new();
    let mut plate_pngs: HashMap<u32, Vec<u8>> = HashMap::new();
    for i in 0..zip.len() {
        let (name, data) = match zip.by_index(i) {
            Ok(mut f) => {
                let n = f.name().to_string();
                let mut v = Vec::new();
                let _ = f.read_to_end(&mut v);
                (n, v)
            }
            Err(_) => continue,
        };
        let lower = name.to_lowercase();
        if lower.ends_with("_rels/.rels") || lower.ends_with("types.xml") {
            continue;
        }
        if lower.ends_with("metadata/model_settings.config") {
            settings = String::from_utf8_lossy(&data).to_string();
        } else if lower.ends_with("metadata/project_settings.config") {
            project = String::from_utf8_lossy(&data).to_string();
        } else if lower.ends_with("metadata/source_info.config") {
            source = String::from_utf8_lossy(&data).to_string();
        } else if lower.ends_with("metadata/slice_info.config") {
            slice = String::from_utf8_lossy(&data).to_string();
        } else if lower.ends_with(".png") && lower.contains("metadata/") {
            let base = lower.rsplit('/').next().unwrap_or("");
            let n = base
                .trim_start_matches("plate_")
                .trim_start_matches("top_")
                .trim_start_matches("pick_")
                .trim_start_matches("plate_no_light_")
                .trim_end_matches(".png")
                .parse::<u32>()
                .unwrap_or(0);
            if n > 0 {
                plate_pngs.entry(n).or_insert(data);
            }
        }
    }

    let mut parts: Vec<Part> = Vec::new();
    parts.push(Part {
        key: part_key(&model_path),
        objs: parse_objects(&model_xml, &part_key(&model_path)),
    });
    for (name, text) in &other_parts {
        parts.push(Part {
            key: part_key(name),
            objs: parse_objects(text, &part_key(name)),
        });
    }
    let main_key = part_key(&model_path);
    let build = parse_build(&model_xml);
    let mut meta = Meta3mf::default();
    let mut extras: Vec<(String, String)> = Vec::new();
    for (k, v) in parse_model_metadata(&model_xml) {
        add_extra(&mut extras, &k, &v);
        match k.to_lowercase().as_str() {
            "title" => meta.title = v,
            "designer" => meta.designer = v,
            "license" => meta.license = v,
            "origin" => meta.origin = v,
            "description" => meta.description = v,
            _ => {}
        }
    }

    // whole model
    let mut all = Mesh::default();
    let mut per_object: HashMap<String, Mesh> = HashMap::new();
    for (id, m) in &build {
        let mut one = Mesh::default();
        resolve(id, m, &parts, &main_key, &mut one, 0);
        if one.pos.is_empty() {
            continue;
        }
        per_object.insert(id.clone(), one.clone());
        all.merge(&one, &Mat::default());
    }
    if all.pos.is_empty() {
        return Err("3MF sem geometria".into());
    }

    // plate map from model_settings.config
    let mut plates_raw = parse_plates(&settings);
    if plates_raw.is_empty() {
        // a single implicit plate
        plates_raw.push(Plate {
            index: 1,
            name: String::new(),
            object_ids: build.iter().map(|(id, _)| id.clone()).collect(),
            ..Default::default()
        });
    }
    let pieces = parse_object_names(&settings);
    let sliced = parse_slice_info(&slice, &mut plates_raw, &mut extras);
    for p in plates_raw.iter_mut() {
        p.name = if p.name.trim().is_empty() {
            format!("Bandeja {}", p.index)
        } else {
            p.name.clone()
        };
        for oid in &p.object_ids {
            if let Some(n) = pieces.get(oid) {
                p.piece_names.push(n.clone());
            }
        }
        if let Some(png) = plate_pngs.get(&p.index) {
            let _ = png;
        }
    }
    parse_project_settings(&project, &mut meta, &mut plates_raw);
    // Plate settings the slicers keep beside the geometry: plate type, the model
    // that sits on it, locked state, the printer it was sliced for…
    for (i, block) in plate_blocks(&settings).into_iter().enumerate() {
        for (k, v) in parse_metadata_pairs(&block) {
            if k.eq_ignore_ascii_case("plater_id") {
                continue;
            }
            add_extra(&mut extras, &format!("Bandeja {} · {}", i + 1, k), &v);
        }
    }
    project_extras(&project, &mut extras);
    for line in source.lines() {
        let t = line.trim();
        if t.to_lowercase().starts_with("application") {
            if let Some(v) = t.split('=').nth(1) {
                meta.source_app = v.trim().to_string();
            }
        }
    }
    meta.sliced = sliced;
    meta.extras = extras;

    let mut plates: Vec<(Plate, Mesh)> = Vec::new();
    for p in plates_raw {
        let mut m = Mesh::default();
        for oid in &p.object_ids {
            if let Some(one) = per_object.get(oid) {
                m.merge(one, &Mat::default());
            }
        }
        if m.pos.is_empty() {
            m = all.clone();
        }
        plates.push((p, m));
    }
    Ok(ThreeMf { mesh: all, plates, meta })
}

/// The PNG the slicer stored for a plate, if any.
pub fn read_3mf_plate_png(bytes: &[u8], plate: u32) -> Option<Vec<u8>> {
    let mut zip = zip::ZipArchive::new(Cursor::new(bytes.to_vec())).ok()?;
    let mut best: Option<Vec<u8>> = None;
    for i in 0..zip.len() {
        if let Ok(mut f) = zip.by_index(i) {
            let name = f.name().to_string();
            let lower = name.to_lowercase();
            if !lower.ends_with(".png") || !lower.contains("metadata/") {
                continue;
            }
            let base = lower.rsplit('/').next().unwrap_or("").to_string();
            let want = format!("plate_{}.png", plate);
            if base == want {
                let mut v = Vec::new();
                let _ = f.read_to_end(&mut v);
                return Some(v);
            }
            for prefix in ["top_", "plate_no_light_", "pick_"] {
                let w = format!("{}{}.png", prefix, plate);
                if base == w {
                    let mut v = Vec::new();
                    let _ = f.read_to_end(&mut v);
                    if best.is_none() {
                        best = Some(v);
                    }
                }
            }
        }
    }
    best
}

fn resolve(id: &str, m: &Mat, parts: &[Part], part: &str, out: &mut Mesh, depth: u32) {
    if depth > 12 {
        return;
    }
    let objs = match resolve_parts(parts, part) {
        Some(o) => o,
        None => return,
    };
    if let Some(o) = objs.iter().find(|o| o.id == id) {
        if !o.idx.is_empty() {
            let mut local = Mesh::new(o.pos.clone(), o.idx.clone());
            let mut v = Vec::with_capacity(local.pos.len());
            for p in local.pos.drain(..) {
                v.push(m.apply(p));
            }
            local = Mesh::new(v, o.idx.clone());
            out.merge(&local, &Mat::default());
        }
        for (cpart, cid, cm) in &o.comps {
            let child = if cpart.is_empty() { part } else { cpart };
            resolve(cid, &m.then(cm), parts, child, out, depth + 1);
        }
    }
}

fn parse_objects(xml: &str, part: &str) -> Vec<Obj3mf> {
    let mut out = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = xml[from..].find("<object ") {
        let start = from + rel;
        let end = match xml[start..].find("</object>") {
            Some(e) => start + e + 9,
            None => break,
        };
        let block = &xml[start..end];
        let id = attr_of(block, "id").unwrap_or_default();
        let name = attr_of(block, "name").unwrap_or_else(|| format!("Objeto {id}"));
        let mut pos = Vec::new();
        let mut idx = Vec::new();
        if let (Some(vs), Some(te)) = (block.find("<vertices>"), block.find("</vertices>")) {
            let mut p = vs;
            while let Some(r) = block[p..te].find("<vertex ") {
                let s = p + r;
                let e = match block[s..].find("/>") {
                    Some(x) => s + x,
                    None => break,
                };
                let tag = &block[s..e];
                pos.push([
                    attr_of(tag, "x").and_then(|v| v.parse().ok()).unwrap_or(0.0),
                    attr_of(tag, "y").and_then(|v| v.parse().ok()).unwrap_or(0.0),
                    attr_of(tag, "z").and_then(|v| v.parse().ok()).unwrap_or(0.0),
                ]);
                p = e + 2;
            }
        }
        if let (Some(ts), Some(te)) = (block.find("<triangles>"), block.find("</triangles>")) {
            let mut p = ts;
            while let Some(r) = block[p..te].find("<triangle ") {
                let s = p + r;
                let e = match block[s..].find("/>") {
                    Some(x) => s + x,
                    None => break,
                };
                let tag = &block[s..e];
                let a = attr_of(tag, "v1").and_then(|v| v.parse::<u32>().ok());
                let b = attr_of(tag, "v2").and_then(|v| v.parse::<u32>().ok());
                let c = attr_of(tag, "v3").and_then(|v| v.parse::<u32>().ok());
                if let (Some(a), Some(b), Some(c)) = (a, b, c) {
                    if (a as usize) < pos.len() && (b as usize) < pos.len() && (c as usize) < pos.len() {
                        idx.push([a, b, c]);
                    }
                }
                p = e + 2;
            }
        }
        let mut comps = Vec::new();
        if let (Some(cs), Some(ce)) = (block.find("<components>"), block.find("</components>")) {
            let mut p = cs;
            while let Some(r) = block[p..ce].find("<component ") {
                let s = p + r;
                let e = match block[s..].find("/>") {
                    Some(x) => s + x,
                    None => break,
                };
                let tag = &block[s..e];
                if let Some(cid) = attr_of(tag, "objectid") {
                    let m = attr_of(tag, "transform").map(|t| Mat::parse(&t)).unwrap_or_default();
                    // A component may name another .model part of the package; when it
                    // doesn't, the object is looked up in the part it was written in.
                    let target = match attr_of(tag, "path") {
                        Some(p) if !p.trim().is_empty() => part_key(&p),
                        _ => part.to_string(),
                    };
                    comps.push((target, cid, m));
                }
                p = e + 2;
            }
        }
        out.push(Obj3mf { id, name, pos, idx, comps });
        from = end;
    }
    out
}

fn parse_build(xml: &str) -> Vec<(String, Mat)> {
    let mut out = Vec::new();
    let (s, e) = match (xml.find("<build"), xml.rfind("</build>")) {
        (Some(s), Some(e)) => (s, e),
        _ => return out,
    };
    let block = &xml[s..e];
    let mut p = 0usize;
    while let Some(r) = block[p..].find("<item ") {
        let st = p + r;
        let en = match block[st..].find("/>") {
            Some(x) => st + x,
            None => break,
        };
        let tag = &block[st..en];
        if let Some(id) = attr_of(tag, "objectid") {
            let m = attr_of(tag, "transform").map(|t| Mat::parse(&t)).unwrap_or_default();
            out.push((id, m));
        }
        p = en + 2;
    }
    out
}

fn parse_model_metadata(xml: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = xml[from..].find("<metadata ") {
        let s = from + rel;
        let tag_end = match xml[s..].find('>') {
            Some(x) => s + x,
            None => break,
        };
        let tag = &xml[s..tag_end];
        let name = attr_of(tag, "name").unwrap_or_default();
        if let Some(close) = xml[tag_end..].find("</metadata>") {
            let val = xml[tag_end + 1..tag_end + close].to_string();
            out.push((name, val));
            from = tag_end + close + 11;
        } else {
            from = tag_end + 1;
        }
    }
    out
}

/// Plates and which objects sit on each, from `Metadata/model_settings.config`.
fn parse_plates(settings: &str) -> Vec<Plate> {
    let mut out: Vec<Plate> = Vec::new();
    let mut from = 0usize;
    while let Some(rel) = settings[from..].find("<plate>") {
        let s = from + rel;
        let e = match settings[s..].find("</plate>") {
            Some(x) => s + x,
            None => break,
        };
        let block = &settings[s..e];
        let mut p = Plate { index: out.len() as u32 + 1, ..Default::default() };
        let mut visible = true;
        for (k, v) in parse_metadata_pairs(block) {
            match k.as_str() {
                "plater_id" => p.index = v.parse().unwrap_or(p.index),
                "plater_name" => p.name = v,
                "locked" => visible = v != "true" || true,
                _ => {}
            }
        }
        let mut q = 0usize;
        while let Some(r) = block[q..].find("<model_instance>") {
            let ms = q + r;
            let me = match block[ms..].find("</model_instance>") {
                Some(x) => ms + x,
                None => break,
            };
            for (k, v) in parse_metadata_pairs(&block[ms..me]) {
                if k == "object_id" {
                    p.object_ids.push(v);
                }
            }
            q = me + 17;
        }
        let _ = visible;
        if !p.object_ids.is_empty() {
            out.push(p);
        }
        from = e + 9;
    }
    out
}

fn parse_object_names(settings: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    let mut from = 0usize;
    while let Some(rel) = settings[from..].find("<object ") {
        let s = from + rel;
        let tag_end = match settings[s..].find('>') {
            Some(x) => s + x,
            None => break,
        };
        let id = attr_of(&settings[s..tag_end], "id").unwrap_or_default();
        let e = match settings[s..].find("</object>") {
            Some(x) => s + x,
            None => break,
        };
        let block = &settings[s..e];
        for (k, v) in parse_metadata_pairs(block) {
            if k == "name" && !id.is_empty() {
                map.insert(id.clone(), v);
                break;
            }
        }
        from = e + 9;
    }
    map
}

/// `<metadata key="k" value="v"/>` pairs inside a block.
fn parse_metadata_pairs(block: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut p = 0usize;
    while let Some(r) = block[p..].find("<metadata ") {
        let s = p + r;
        let e = match block[s..].find("/>") {
            Some(x) => s + x,
            None => break,
        };
        let tag = &block[s..e];
        let k = attr_of(tag, "key").unwrap_or_default();
        let v = attr_of(tag, "value").unwrap_or_default();
        if !k.is_empty() {
            out.push((k, v));
        }
        p = e + 2;
    }
    out
}

/// One file fact, kept once and in the order the file lists it. Long values are
/// left out (a whole settings blob is not a fact anyone reads on a card).
fn add_extra(extras: &mut Vec<(String, String)>, key: &str, value: &str) {
    let key = key.trim();
    let value = value.trim();
    if key.is_empty() || value.is_empty() || value.chars().count() > 160 {
        return;
    }
    if extras.len() >= 240 || extras.iter().any(|(k, _)| k.eq_ignore_ascii_case(key)) {
        return;
    }
    extras.push((key.to_string(), value.to_string()));
}

/// Each `<plate>…</plate>` block of `model_settings.config`, as text.
fn plate_blocks(settings: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = settings;
    while let Some(a) = rest.find("<plate") {
        let after = &rest[a..];
        let end = match after.find("</plate>") {
            Some(e) => e + "</plate>".len(),
            None => break,
        };
        out.push(after[..end].to_string());
        rest = &after[end..];
    }
    out
}

/// The slicer's project settings, which a Bambu-style 3MF keeps as one JSON
/// document: every plain value becomes a fact, nested ones are left alone.
fn project_extras(project: &str, extras: &mut Vec<(String, String)>) {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(project) else {
        return;
    };
    let Some(obj) = value.as_object() else {
        return;
    };
    let mut keys: Vec<&String> = obj.keys().collect();
    keys.sort();
    for k in keys.into_iter().take(80) {
        let val = match obj.get(k) {
            Some(serde_json::Value::String(s)) => s.clone(),
            Some(serde_json::Value::Number(n)) => n.to_string(),
            Some(serde_json::Value::Bool(b)) => if *b { "sim" } else { "não" }.to_string(),
            Some(serde_json::Value::Array(items)) => {
                let mut parts: Vec<String> = Vec::new();
                for item in items.iter().take(6) {
                    match item {
                        serde_json::Value::String(s) => parts.push(s.clone()),
                        serde_json::Value::Number(n) => parts.push(n.to_string()),
                        serde_json::Value::Bool(b) => {
                            parts.push(if *b { "sim" } else { "não" }.to_string())
                        }
                        _ => {}
                    }
                }
                parts.join(", ")
            }
            _ => continue,
        };
        add_extra(extras, &format!("Fatiador · {k}"), &val);
    }
}

fn parse_slice_info(
    slice: &str,
    plates: &mut Vec<Plate>,
    extras: &mut Vec<(String, String)>,
) -> bool {
    if slice.trim().is_empty() {
        return false;
    }
    // What the slicer wrote about the whole project (its version, the printer…).
    if let Some(hs) = slice.find("<header>") {
        if let Some(he) = slice[hs..].find("</header>") {
            for (k, v) in parse_metadata_pairs(&slice[hs..hs + he]) {
                add_extra(extras, &k, &v);
            }
        }
    }
    let mut any = false;
    let mut from = 0usize;
    while let Some(rel) = slice[from..].find("<plate>") {
        let s = from + rel;
        let e = match slice[s..].find("</plate>") {
            Some(x) => s + x,
            None => break,
        };
        let block = &slice[s..e];
        let pairs = parse_metadata_pairs(block);
        let mut index: Option<u32> = None;
        let mut seconds: Option<u64> = None;
        let mut grams: Option<f64> = None;
        for (k, v) in &pairs {
            match k.as_str() {
                "index" => index = v.parse().ok(),
                "prediction" => seconds = v.parse::<f64>().ok().map(|f| f as u64),
                "weight" => grams = v.parse().ok(),
                _ => {}
            }
        }
        // Everything else the slicer noted about this plate (support used, plate
        // type, the printer it was sliced for…), under the plate's own name.
        let plate_no = index.unwrap_or(0);
        for (k, v) in &pairs {
            if !matches!(k.as_str(), "index" | "prediction" | "weight") {
                add_extra(extras, &format!("Bandeja {} · {}", plate_no, k), v);
            }
        }
        // filament entries
        let mut fils = Vec::new();
        let mut q = 0usize;
        while let Some(r) = block[q..].find("<filament ") {
            let fs = q + r;
            let fe = match block[fs..].find("/>") {
                Some(x) => fs + x,
                None => break,
            };
            let tag = &block[fs..fe];
            fils.push(FilamentUse {
                material: attr_of(tag, "type").unwrap_or_default(),
                color_name: String::new(),
                hex: normalise_hex(&attr_of(tag, "color").unwrap_or_default()),
                grams: attr_of(tag, "used_g").and_then(|v| v.parse().ok()),
                meters: attr_of(tag, "used_m").and_then(|v| v.parse().ok()),
            });
            q = fe + 2;
        }
        any = true;
        if let Some(pl) = plates.iter_mut().find(|p| p.index == index.unwrap_or(u32::MAX)) {
            pl.seconds = seconds;
            pl.grams = grams;
            pl.filaments = fils;
        } else if let Some(idx) = index {
            plates.push(Plate {
                index: idx,
                seconds,
                grams,
                filaments: fils,
                ..Default::default()
            });
        }
        from = e + 8;
    }
    any
}

fn parse_project_settings(project: &str, meta: &mut Meta3mf, plates: &mut [Plate]) {
    let v: serde_json::Value = match serde_json::from_str(project) {
        Ok(v) => v,
        Err(_) => return,
    };
    let s = |key: &str| -> Option<String> {
        match &v[key] {
            serde_json::Value::String(t) => Some(t.clone()),
            serde_json::Value::Array(a) => a.first().and_then(|x| x.as_str()).map(|x| x.to_string()),
            serde_json::Value::Number(n) => Some(n.to_string()),
            _ => None,
        }
    };
    if let Some(p) = s("printer_model") {
        meta.printer = p;
    }
    if let Some(p) = s("nozzle_diameter") {
        meta.nozzle = p;
    }
    if let Some(p) = s("layer_height") {
        meta.layer_height = p;
    }
    if let Some(p) = s("sparse_infill_density") {
        meta.infill = p;
    }
    if let Some(p) = s("support_enable") {
        meta.supports = Some(p == "1" || p.eq_ignore_ascii_case("true"));
    }
    if let Some(p) = s("print_settings_id") {
        meta.profile = p;
    }
    let mut fils: Vec<FilamentUse> = Vec::new();
    if let serde_json::Value::Array(cols) = &v["filament_colour"] {
        for c in cols {
            if let Some(t) = c.as_str() {
                fils.push(FilamentUse { hex: normalise_hex(t), ..Default::default() });
            }
        }
    }
    if let serde_json::Value::Array(tys) = &v["filament_type"] {
        for (i, t) in tys.iter().enumerate() {
            if let Some(t) = t.as_str() {
                if i < fils.len() {
                    fils[i].material = t.to_string();
                } else {
                    fils.push(FilamentUse { material: t.to_string(), ..Default::default() });
                }
            }
        }
    }
    if let serde_json::Value::Array(names) = &v["filament_settings_id"] {
        for (i, n) in names.iter().enumerate() {
            if let Some(n) = n.as_str() {
                if i < fils.len() {
                    fils[i].color_name = n.to_string();
                }
            }
        }
    }
    meta.filaments = fils.clone();
    for p in plates.iter_mut() {
        if p.filaments.is_empty() {
            p.filaments = fils.clone();
        } else {
            // fill the colour of each used filament from the project list
            for f in p.filaments.iter_mut() {
                if f.hex.is_empty() {
                    if let Some(src) = fils.iter().find(|x| x.material == f.material) {
                        f.hex = src.hex.clone();
                        f.color_name = src.color_name.clone();
                    }
                }
            }
        }
    }
}

pub fn normalise_hex(h: &str) -> String {
    let t = h.trim();
    if t.is_empty() {
        return String::new();
    }
    let body = t.trim_start_matches('#');
    if body.len() >= 6 {
        format!("#{}", &body[0..6].to_uppercase())
    } else {
        format!("#{}", body.to_uppercase())
    }
}

pub fn hex_to_rgb(h: &str) -> [u8; 3] {
    let b = h.trim_start_matches('#');
    if b.len() < 6 {
        return [128, 128, 128];
    }
    let p = |i: usize| u8::from_str_radix(&b[i..i + 2], 16).unwrap_or(128);
    [p(0), p(2), p(4)]
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    /// Bambu Studio and OrcaSlicer keep the geometry in side .model parts and
    /// list only `<component p:path="…">` entries in the main part: without
    /// following those, the model looks empty and the card says it can't draw it.
    #[test]
    fn a_component_can_point_at_another_model_part() {
        let main = r#"<?xml version="1.0"?>
<model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06">
 <resources>
  <object id="2" type="model">
   <components>
    <component p:path="/3D/Objects/a.model" objectid="1" transform="1 0 0 0 1 0 0 0 1 0 0 0"/>
   </components>
  </object>
 </resources>
 <build><item objectid="2" printable="1"/></build>
</model>"#;
        let part = r#"<?xml version="1.0"?>
<model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">
 <resources>
  <object id="1" type="model">
   <mesh>
    <vertices>
     <vertex x="0" y="0" z="0"/><vertex x="10" y="0" z="0"/><vertex x="0" y="10" z="0"/>
    </vertices>
    <triangles><triangle v1="0" v2="1" v3="2"/></triangles>
   </mesh>
  </object>
 </resources>
</model>"#;
        let mut buf: Vec<u8> = Vec::new();
        {
            let mut w = zip::ZipWriter::new(Cursor::new(&mut buf));
            let opts = zip::write::SimpleFileOptions::default();
            w.start_file("3D/3dmodel.model", opts).unwrap();
            w.write_all(main.as_bytes()).unwrap();
            w.start_file("3D/Objects/a.model", opts).unwrap();
            w.write_all(part.as_bytes()).unwrap();
            w.finish().unwrap();
        }
        let three = read_3mf(&buf).expect("o pacote devia ser lido");
        assert_eq!(three.mesh.tris, 1, "o triângulo da parte lateral faltou");
        assert_eq!(three.mesh.pos.len(), 3);
    }
}
