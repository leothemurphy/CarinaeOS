//! Filament stock and colour matching (CIE76 ΔE in Lab, matched at 25, material by name).

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Spool {
    pub id: String,
    pub brand: String,
    pub material: String,
    pub line: String,
    pub color_name: String,
    pub hex: String,
    pub total_g: f64,
    pub remaining_g: f64,
    pub price: Option<f64>,
}

impl Default for Spool {
    fn default() -> Self {
        Spool {
            id: String::new(),
            brand: String::new(),
            material: "PLA".into(),
            line: String::new(),
            color_name: String::new(),
            hex: "#22D3EE".into(),
            total_g: 1000.0,
            remaining_g: 1000.0,
            price: None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Status {
    Ok,
    NoColor,
    Missing,
}

impl Status {
    pub fn label(&self) -> &'static str {
        match self {
            Status::Ok => "Pronto para imprimir",
            Status::NoColor => "Cor diferente",
            Status::Missing => "Sem estoque",
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct Need {
    pub material: String,
    pub hex: String,
    pub grams: Option<f64>,
}

pub fn known_materials() -> Vec<&'static str> {
    vec![
        "PLA", "PLA+", "PLA Silk", "PLA Matte", "PETG", "ABS", "ASA", "TPU", "NYLON", "PC", "PVA",
        "HIPS", "ASA-CF", "PLA-CF", "PETG-CF", "Resina",
    ]
}

pub fn quick_weights() -> [f64; 4] {
    [250.0, 500.0, 1000.0, 2000.0]
}

pub fn norm_material(m: &str) -> String {
    m.trim()
        .to_uppercase()
        .replace(' ', "")
        .replace('-', "")
        .replace('_', "")
}

fn srgb_to_lin(c: f32) -> f32 {
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

/// sRGB hex to CIE Lab (D65).
pub fn hex_to_lab(hex: &str) -> (f32, f32, f32) {
    let rgb = crate::mesh::hex_to_rgb(hex);
    let r = srgb_to_lin(rgb[0] as f32 / 255.0);
    let g = srgb_to_lin(rgb[1] as f32 / 255.0);
    let b = srgb_to_lin(rgb[2] as f32 / 255.0);
    let x = r * 0.4124 + g * 0.3576 + b * 0.1805;
    let y = r * 0.2126 + g * 0.7152 + b * 0.0722;
    let z = r * 0.0193 + g * 0.1192 + b * 0.9505;
    let xn = 0.95047;
    let zn = 1.08883;
    let f = |t: f32| {
        if t > 0.008856 {
            t.cbrt()
        } else {
            7.787 * t + 16.0 / 116.0
        }
    };
    let fx = f(x / xn);
    let fy = f(y);
    let fz = f(z / zn);
    ((116.0 * fy - 16.0), (500.0 * (fx - fy)), (200.0 * (fy - fz)))
}

pub fn delta_e(a: &str, b: &str) -> f32 {
    let (l1, a1, b1) = hex_to_lab(a);
    let (l2, a2, b2) = hex_to_lab(b);
    ((l1 - l2).powi(2) + (a1 - a2).powi(2) + (b1 - b2).powi(2))
        .sqrt()
        .round()
}

pub const COLOR_THRESHOLD: f32 = 25.0;

/// Whether the stock can print these filaments, and which spools answer them.
pub fn evaluate(needs: &[Need], spools: &[Spool]) -> (Status, Vec<usize>) {
    if needs.is_empty() || spools.is_empty() {
        return (Status::Missing, Vec::new());
    }
    let mut used: Vec<usize> = Vec::new();
    let mut all_ok = true;
    let mut any_material = false;
    for need in needs {
        let want = norm_material(&need.material);
        let mut found = None;
        for (i, s) in spools.iter().enumerate() {
            if norm_material(&s.material) != want {
                continue;
            }
            any_material = true;
            let close = need.hex.is_empty() || delta_e(&s.hex, &need.hex) <= COLOR_THRESHOLD;
            if !close {
                continue;
            }
            if need.grams.map(|g| s.remaining_g >= g).unwrap_or(true) {
                found = Some(i);
                break;
            }
            if found.is_none() {
                found = Some(i);
            }
        }
        match found {
            Some(i) => {
                if !used.contains(&i) {
                    used.push(i);
                }
            }
            None => all_ok = false,
        }
    }
    if all_ok {
        (Status::Ok, used)
    } else if any_material {
        (Status::NoColor, used)
    } else {
        (Status::Missing, used)
    }
}

pub fn total_stock_g(spools: &[Spool]) -> f64 {
    spools.iter().map(|s| s.remaining_g).sum()
}
