//! Colours and spacing taken from the original app's theme tokens (see MECHANICS.md).

use eframe::egui::{self, Color32, CornerRadius, FontFamily, FontId, Stroke, TextStyle};

pub const BG_MAIN: Color32 = Color32::from_rgb(0x07, 0x0b, 0x10);
pub const BG_PANEL: Color32 = Color32::from_rgb(0x0b, 0x11, 0x18);
pub const BG_CARD: Color32 = Color32::from_rgb(0x0f, 0x16, 0x1f);
pub const BG_CARD_HOVER: Color32 = Color32::from_rgb(0x15, 0x1e, 0x29);
pub const BG_INPUT: Color32 = Color32::from_rgb(0x0d, 0x14, 0x1c);
pub const LINE: Color32 = Color32::from_rgb(0x1b, 0x23, 0x2d);
pub const LINE_SOFT: Color32 = Color32::from_rgb(0x16, 0x1d, 0x26);
pub const TEXT: Color32 = Color32::from_rgb(0xee, 0xf3, 0xf8);
pub const TEXT_DIM: Color32 = Color32::from_rgb(0x8b, 0x98, 0xa8);
pub const TEXT_MUTED: Color32 = Color32::from_rgb(0x5b, 0x68, 0x78);
pub const ACCENT: Color32 = Color32::from_rgb(0x22, 0xd3, 0xee);
pub const ACCENT_STRONG: Color32 = Color32::from_rgb(0x06, 0xb6, 0xd4);
pub const ACCENT_DIM: Color32 = Color32::from_rgb(0x0e, 0x74, 0x90);
pub const STL: Color32 = Color32::from_rgb(0x60, 0xa5, 0xfa);
pub const THREEMF: Color32 = Color32::from_rgb(0x34, 0xd3, 0x99);
pub const SVG: Color32 = Color32::from_rgb(0xc0, 0x84, 0xfc);
pub const WARN: Color32 = Color32::from_rgb(0xfb, 0xbf, 0x24);
pub const DANGER: Color32 = Color32::from_rgb(0xf8, 0x71, 0x71);
pub const MODEL_TINT: [u8; 3] = [0x1f, 0xb6, 0xcc];

pub const TOPBAR_H: f32 = 52.0;
pub const SIDEBAR_W: f32 = 248.0;
pub const CARD_MIN_W: f32 = 210.0;
pub const PAD: f32 = 18.0;

pub fn radius(r: u8) -> CornerRadius {
    CornerRadius::same(r)
}

pub fn format_color(ext: &str) -> Color32 {
    match ext {
        "stl" => STL,
        "3mf" => THREEMF,
        "svg" => SVG,
        _ => TEXT_DIM,
    }
}

pub fn apply(ctx: &egui::Context) {
    let mut style = (*ctx.style()).clone();
    let mut v = egui::Visuals::dark();
    v.panel_fill = BG_MAIN;
    v.window_fill = BG_PANEL;
    v.extreme_bg_color = BG_INPUT;
    v.faint_bg_color = BG_CARD;
    v.override_text_color = Some(TEXT);
    v.hyperlink_color = ACCENT;
    v.selection.bg_fill = ACCENT_DIM;
    v.selection.stroke = Stroke::new(1.0_f32, ACCENT);
    v.widgets.noninteractive.bg_fill = BG_CARD;
    v.widgets.noninteractive.bg_stroke = Stroke::new(1.0_f32, LINE);
    v.widgets.noninteractive.fg_stroke = Stroke::new(1.0_f32, TEXT_DIM);
    v.widgets.inactive.bg_fill = BG_CARD;
    v.widgets.inactive.weak_bg_fill = BG_CARD;
    v.widgets.inactive.bg_stroke = Stroke::new(1.0_f32, LINE);
    v.widgets.inactive.fg_stroke = Stroke::new(1.0_f32, TEXT);
    v.widgets.hovered.bg_fill = BG_CARD_HOVER;
    v.widgets.hovered.weak_bg_fill = BG_CARD_HOVER;
    v.widgets.hovered.bg_stroke = Stroke::new(1.0_f32, ACCENT_DIM);
    v.widgets.hovered.fg_stroke = Stroke::new(1.0_f32, TEXT);
    v.widgets.active.bg_fill = ACCENT_DIM;
    v.widgets.active.weak_bg_fill = ACCENT_DIM;
    v.widgets.active.bg_stroke = Stroke::new(1.0_f32, ACCENT);
    v.widgets.active.fg_stroke = Stroke::new(1.0_f32, Color32::WHITE);
    v.widgets.open.bg_fill = BG_CARD_HOVER;
    v.window_shadow = egui::epaint::Shadow {
        offset: [0, 8],
        blur: 28,
        spread: 0,
        color: Color32::from_black_alpha(160),
    };
    v.popup_shadow = v.window_shadow;
    v.window_corner_radius = radius(10);
    v.menu_corner_radius = radius(8);
    style.visuals = v;
    style.spacing.item_spacing = egui::vec2(8.0, 8.0);
    style.spacing.button_padding = egui::vec2(10.0, 6.0);
    style.spacing.scroll.bar_width = 8.0;
    style.spacing.interact_size.y = 26.0;
    style.text_styles = [
        (TextStyle::Heading, FontId::new(19.0, FontFamily::Proportional)),
        (TextStyle::Body, FontId::new(13.5, FontFamily::Proportional)),
        (TextStyle::Button, FontId::new(13.0, FontFamily::Proportional)),
        (TextStyle::Small, FontId::new(11.5, FontFamily::Proportional)),
        (TextStyle::Monospace, FontId::new(12.5, FontFamily::Monospace)),
    ]
    .into();
    ctx.set_style(style);
}
