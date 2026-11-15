//! The Carinae 3D mark.
//!
//! One drawing, written as plain numbers, used three ways: the badge in the
//! app's sidebar and welcome page, the window and taskbar icon (through
//! [`rgba`]), and the file icon Windows shows in Explorer (through [`write_ico`],
//! compiled into the .exe by `build.rs` with the bundled `windres`).
//!
//! The mark is a rounded cyan tile with a soft glow, an isometric cube standing
//! on it — the app is about solid models — and a small four-point star for
//! Carina, the constellation the name comes from.
//!
//! Everything is generated here, so all three sizes are the same artwork.

use eframe::egui;

/// The colour at the top-left of the tile.
const SKY: [f32; 3] = [0.16, 0.85, 0.94];
/// The colour at the bottom-right.
const DEEP: [f32; 3] = [0.03, 0.31, 0.40];
/// The "ink" of the cube and the star.
const INK: [f32; 3] = [0.93, 0.98, 1.0];
/// The size the in-app badge is rendered at; smaller sizes are downscaled by egui.
pub const PX: u32 = 128;

fn clamp01(v: f32) -> f32 {
    if v < 0.0 {
        0.0
    } else if v > 1.0 {
        1.0
    } else {
        v
    }
}

fn mix(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

fn col_mix(a: [f32; 3], b: [f32; 3], t: f32) -> [f32; 3] {
    [mix(a[0], b[0], t), mix(a[1], b[1], t), mix(a[2], b[2], t)]
}

/// Is (x, y) inside the tile — a unit square whose corners are rounded by `r`?
fn in_tile(x: f32, y: f32, r: f32) -> bool {
    let dx = (x - 0.5).abs() - (0.5 - r);
    let dy = (y - 0.5).abs() - (0.5 - r);
    if (x - 0.5).abs() > 0.5 || (y - 0.5).abs() > 0.5 {
        return false;
    }
    if dx <= 0.0 || dy <= 0.0 {
        return true;
    }
    dx * dx + dy * dy <= r * r
}

/// The even-odd rule: a point is inside when a ray crosses the outline an odd
/// number of times.
fn in_poly(x: f32, y: f32, p: &[[f32; 2]]) -> bool {
    let mut inside = false;
    let mut j = p.len() - 1;
    for i in 0..p.len() {
        let (xi, yi) = (p[i][0], p[i][1]);
        let (xj, yj) = (p[j][0], p[j][1]);
        if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi {
            inside = !inside;
        }
        j = i;
    }
    inside
}

/// The three visible faces of the cube, each with how much ink it gets: the top
/// face is brightest, the left one mid, the right one darkest, which is what
/// makes a flat drawing read as a solid object.
fn cube(x: f32, y: f32) -> Option<f32> {
    let (cx, cy) = (0.5_f32, 0.545_f32);
    let a = 0.275_f32; // half width
    let b = a * 0.5_f32; // half of the top face's height (2:1 isometric)
    let s = 0.235_f32; // the vertical edges
    let ty = cy - s * 0.5; // height of the top face's left and right corners
    let top = [[cx, ty - b], [cx + a, ty], [cx, ty + b], [cx - a, ty]];
    let left = [
        [cx - a, ty],
        [cx, ty + b],
        [cx, ty + b + s],
        [cx - a, ty + s],
    ];
    let right = [
        [cx + a, ty],
        [cx, ty + b],
        [cx, ty + b + s],
        [cx + a, ty + s],
    ];
    if in_poly(x, y, &top) {
        Some(0.96)
    } else if in_poly(x, y, &left) {
        Some(0.62)
    } else if in_poly(x, y, &right) {
        Some(0.26)
    } else {
        None
    }
}

/// A four-point star: long points up and down, short ones left and right.
fn star(x: f32, y: f32) -> bool {
    let (cx, cy) = (0.785_f32, 0.205_f32);
    let (long, short) = (0.095_f32, 0.030_f32);
    let mut p = [[0.0_f32; 2]; 8];
    for (i, slot) in p.iter_mut().enumerate() {
        let ang = std::f32::consts::FRAC_PI_2 + i as f32 * std::f32::consts::FRAC_PI_4;
        let rad = if i % 2 == 0 { long } else { short };
        *slot = [cx + rad * ang.cos(), cy - rad * ang.sin()];
    }
    in_poly(x, y, &p)
}

/// The colour of one point of the mark, or `None` where the tile is not.
fn shade(x: f32, y: f32) -> Option<[f32; 3]> {
    if !in_tile(x, y, 0.225) {
        return None;
    }
    let t = clamp01(x * 0.38 + y * 0.62);
    let mut c = col_mix(SKY, DEEP, t);
    // A soft glow in the upper left, so the tile doesn't look like flat paper.
    let d = ((x - 0.24) * (x - 0.24) + (y - 0.16) * (y - 0.16)).sqrt();
    let glow = clamp01(1.0 - d / 0.62) * 0.24;
    c = col_mix(c, [1.0, 1.0, 1.0], glow);
    if let Some(alpha) = cube(x, y) {
        c = col_mix(c, INK, alpha);
    }
    if star(x, y) {
        c = col_mix(c, INK, 0.97);
    }
    Some(c)
}

/// The mark as straight (un-premultiplied) RGBA bytes, `size` by `size`.
///
/// Every pixel is sampled several times and averaged, which is what gives the
/// rounded corners and the star's points a clean edge without any library.
pub fn rgba(size: u32) -> Vec<u8> {
    let n = size.clamp(8, 1024) as usize;
    let ss = if n >= 96 { 3usize } else { 4usize };
    let samples = (ss * ss) as f32;
    let mut out = vec![0u8; n * n * 4];
    for py in 0..n {
        for px in 0..n {
            let mut acc = [0.0f32; 3];
            let mut hits = 0.0f32;
            for sy in 0..ss {
                for sx in 0..ss {
                    let x = (px as f32 + (sx as f32 + 0.5) / ss as f32) / n as f32;
                    let y = (py as f32 + (sy as f32 + 0.5) / ss as f32) / n as f32;
                    if let Some(c) = shade(x, y) {
                        acc[0] += c[0];
                        acc[1] += c[1];
                        acc[2] += c[2];
                        hits += 1.0;
                    }
                }
            }
            if hits == 0.0 {
                continue;
            }
            let i = (py * n + px) * 4;
            out[i] = (clamp01(acc[0] / hits) * 255.0).round() as u8;
            out[i + 1] = (clamp01(acc[1] / hits) * 255.0).round() as u8;
            out[i + 2] = (clamp01(acc[2] / hits) * 255.0).round() as u8;
            out[i + 3] = (hits / samples * 255.0).round() as u8;
        }
    }
    out
}

/// The same mark as an `egui` image, ready for `Context::load_texture`.
pub fn color_image(size: u32) -> egui::ColorImage {
    let n = size.clamp(8, 1024) as usize;
    egui::ColorImage::from_rgba_unmultiplied([n, n], &rgba(size))
}

/// Windows reads an icon file as a small directory of images: each entry says
/// its size and where its bytes start. Since Vista the bytes may be a PNG, which
/// is what is written here, so sizes from 16 to 256 pixels stay sharp.
pub fn write_ico(path: &std::path::Path) -> Result<usize, String> {
    let sizes = [16u32, 24, 32, 48, 64, 128, 256];
    let mut images: Vec<(u32, Vec<u8>)> = Vec::new();
    for s in sizes {
        let n = s as usize;
        let buf = rgba(s);
        let img = image::RgbaImage::from_raw(n as u32, n as u32, buf)
            .ok_or_else(|| format!("não foi possível montar a imagem {s}x{s}"))?;
        let mut png = Vec::new();
        img.write_to(&mut std::io::Cursor::new(&mut png), image::ImageFormat::Png)
            .map_err(|e| e.to_string())?;
        images.push((s, png));
    }
    let mut out: Vec<u8> = Vec::new();
    out.extend_from_slice(&0u16.to_le_bytes()); // reserved
    out.extend_from_slice(&1u16.to_le_bytes()); // 1 = icon
    out.extend_from_slice(&(images.len() as u16).to_le_bytes());
    let mut offset = 6 + 16 * images.len() as u32;
    for (size, png) in &images {
        let side = if *size >= 256 { 0u8 } else { *size as u8 }; // 0 means 256
        out.push(side);
        out.push(side);
        out.push(0); // palette colours
        out.push(0); // reserved
        out.extend_from_slice(&1u16.to_le_bytes()); // colour planes
        out.extend_from_slice(&32u16.to_le_bytes()); // bits per pixel
        out.extend_from_slice(&(png.len() as u32).to_le_bytes());
        out.extend_from_slice(&offset.to_le_bytes());
        offset += png.len() as u32;
    }
    for (_, png) in &images {
        out.extend_from_slice(png);
    }
    std::fs::write(path, &out).map_err(|e| e.to_string())?;
    Ok(out.len())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The middle of the cube's top face is ink; the tile's corner is empty; and
    /// the corner of the square is cut off, which is what makes it a tile.
    #[test]
    fn the_mark_has_a_cube_on_a_rounded_tile() {
        let top = shade(0.5, 0.44).expect("o centro do cubo está dentro do selo");
        assert!(top[0] > 0.8 && top[2] > 0.8, "o topo do cubo é quase branco: {top:?}");
        assert!(shade(0.0, 0.0).is_none(), "o canto de fora é transparente");
        assert!(shade(0.03, 0.03).is_none(), "o canto do selo é arredondado");
        assert!(shade(0.5, 0.03).is_some(), "o topo, ao meio, é do selo");
        assert!(star(0.785, 0.205), "a estrela está no lugar");
    }

    /// Four bytes per pixel, and the edge is smooth rather than ragged.
    #[test]
    fn the_pixels_are_rgba_and_the_edge_is_soft() {
        let n = 64u32;
        let buf = rgba(n);
        assert_eq!(buf.len(), (n * n * 4) as usize);
        let alpha = |x: u32, y: u32| buf[(((y * n) + x) * 4 + 3) as usize];
        assert_eq!(alpha(0, 0), 0);
        assert_eq!(alpha(n / 2, n / 2), 255);
        let edge: Vec<u8> = (0..n).map(|x| alpha(x, 0)).collect();
        assert!(edge.iter().any(|a| *a > 0 && *a < 255), "há uma borda suave: {edge:?}");
    }
}
