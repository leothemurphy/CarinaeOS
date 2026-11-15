//! A small software renderer: flat-shaded triangles into an RGBA buffer.
//! Values (45 degree field of view, camera distance r/sin(22.5 deg)*1.15, model colour
//! #1fb6cc, three lights, ambient 0.35, ACES tone mapping at exposure 1.1) come from the
//! original's thumbnail renderer; see MECHANICS.md.

use crate::mesh::Mesh;

#[derive(Clone, Copy, Debug)]
pub struct Camera {
    /// Rotation around the vertical axis, radians.
    pub yaw: f32,
    /// Tilt, radians (clamped).
    pub pitch: f32,
    /// Zoom: 1.0 fits the model, larger values move closer.
    pub zoom: f32,
    /// Shift of the model on screen, in fractions of the viewport.
    pub pan: [f32; 2],
}

impl Default for Camera {
    fn default() -> Self {
        Camera { yaw: 0.62, pitch: 0.52, zoom: 1.0, pan: [0.0, 0.0] }
    }
}

const FOV: f32 = 45.0 * std::f32::consts::PI / 180.0;
const AMBIENT: f32 = 0.35;
const EXPOSURE: f32 = 1.1;

fn aces(x: f32) -> f32 {
    let x = x * EXPOSURE;
    let y = (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
    y.clamp(0.0, 1.0)
}

fn norm(v: [f32; 3]) -> [f32; 3] {
    let l = (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).sqrt().max(1e-9);
    [v[0] / l, v[1] / l, v[2] / l]
}

fn cross(a: [f32; 3], b: [f32; 3]) -> [f32; 3] {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}

fn dot(a: [f32; 3], b: [f32; 3]) -> f32 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

/// Renders `mesh` into a `w` x `h` RGBA buffer (rows top to bottom, 4 bytes a pixel).
pub fn render(
    mesh: &Mesh,
    w: usize,
    h: usize,
    cam: &Camera,
    wireframe: bool,
    bg: [u8; 3],
    tint: [u8; 3],
) -> Vec<u8> {
    let mut color = vec![0u8; w * h * 4];
    let mut depth = vec![f32::INFINITY; w * h];
    // background: a soft vertical gradient, a touch lighter in the middle
    for y in 0..h {
        let t = (y as f32 / h.max(1) as f32 - 0.45).abs();
        let k = 1.0 - 0.35 * t;
        let r = (bg[0] as f32 * k) as u8;
        let g = (bg[1] as f32 * k) as u8;
        let b = (bg[2] as f32 * k) as u8;
        for x in 0..w {
            let i = (y * w + x) * 4;
            color[i] = r;
            color[i + 1] = g;
            color[i + 2] = b;
            color[i + 3] = 255;
        }
    }
    if mesh.idx.is_empty() || w == 0 || h == 0 {
        return color;
    }

    let c = mesh.center();
    let radius = mesh.radius();
    let dist = (radius / (FOV * 0.5).sin()) * 1.15 / cam.zoom.max(0.05);
    let cp = cam.pitch.clamp(-1.5, 1.5);
    let eye = [
        c[0] + dist * cp.cos() * cam.yaw.sin(),
        c[1] + dist * cp.cos() * cam.yaw.cos(),
        c[2] + dist * cp.sin(),
    ];
    let zaxis = norm([eye[0] - c[0], eye[1] - c[1], eye[2] - c[2]]);
    let up_world = if cp.cos().abs() < 0.02 { [0.0, 1.0, 0.0] } else { [0.0, 0.0, 1.0] };
    let xaxis = norm(cross(up_world, zaxis));
    let yaxis = cross(zaxis, xaxis);

    let focal = (h as f32 * 0.5) / (FOV * 0.5).tan();
    let cx = w as f32 * 0.5 + cam.pan[0] * w as f32;
    let cy = h as f32 * 0.5 + cam.pan[1] * h as f32;

    let project = |p: [f32; 3]| -> Option<([f32; 2], f32)> {
        let d = [p[0] - eye[0], p[1] - eye[1], p[2] - eye[2]];
        let zv = dot(d, zaxis);
        if zv > -0.001 {
            return None;
        }
        let xv = dot(d, xaxis);
        let yv = dot(d, yaxis);
        let inv = 1.0 / (-zv);
        Some(([cx + xv * inv * focal, cy - yv * inv * focal], -zv))
    };

    let l_key = norm([100.0, 150.0, 100.0]);
    let l_fill = norm([-100.0, -50.0, -100.0]);
    let l_rim = norm([0.0, -100.0, 50.0]);
    let fill_col = [0.44f32, 0.56, 0.69];
    let rim_col = [0.0f32, 0.90, 1.0];
    let base = [
        tint[0] as f32 / 255.0,
        tint[1] as f32 / 255.0,
        tint[2] as f32 / 255.0,
    ];
    let view = norm([c[0] - eye[0], c[1] - eye[1], c[2] - eye[2]]);

    let mut zbuf = vec![f32::INFINITY; w * h];
    let mut edges: Vec<([f32; 2], [f32; 2])> = Vec::new();

    for t in &mesh.idx {
        let (a, b, cc) = (
            mesh.pos[t[0] as usize],
            mesh.pos[t[1] as usize],
            mesh.pos[t[2] as usize],
        );
        let pa = project(a);
        let pb = project(b);
        let pc = project(cc);
        let (pa, pb, pc) = match (pa, pb, pc) {
            (Some(x), Some(y), Some(z)) => (x, y, z),
            _ => continue,
        };
        // face normal in world space
        let n = norm(cross(
            [b[0] - a[0], b[1] - a[1], b[2] - a[2]],
            [cc[0] - a[0], cc[1] - a[1], cc[2] - a[2]],
        ));
        let mut shade = n;
        if dot(shade, view) < 0.0 {
            shade = [-shade[0], -shade[1], -shade[2]];
        }
        let k = AMBIENT + 1.4 * dot(shade, l_key).max(0.0);
        let f = 0.8 * dot(shade, l_fill).max(0.0);
        let r = 0.5 * dot(shade, l_rim).max(0.0);
        let rgb = [
            aces(base[0] * k + fill_col[0] * f * base[0] + rim_col[0] * r),
            aces(base[1] * k + fill_col[1] * f * base[1] + rim_col[1] * r),
            aces(base[2] * k + fill_col[2] * f * base[2] + rim_col[2] * r),
        ];
        let px = [
            (rgb[0] * 255.0) as u8,
            (rgb[1] * 255.0) as u8,
            (rgb[2] * 255.0) as u8,
        ];

        let minx = pa.0[0].min(pb.0[0]).min(pc.0[0]).floor().max(0.0) as i32;
        let maxx = pa.0[0].max(pb.0[0]).max(pc.0[0]).ceil().min(w as f32 - 1.0) as i32;
        let miny = pa.0[1].min(pb.0[1]).min(pc.0[1]).floor().max(0.0) as i32;
        let maxy = pa.0[1].max(pb.0[1]).max(pc.0[1]).ceil().min(h as f32 - 1.0) as i32;

        let area = (pb.0[0] - pa.0[0]) * (pc.0[1] - pa.0[1]) - (pc.0[0] - pa.0[0]) * (pb.0[1] - pa.0[1]);
        if area.abs() < 1e-6 {
            continue;
        }
        if wireframe {
            edges.push((pa.0, pb.0));
            edges.push((pb.0, pc.0));
            edges.push((pc.0, pa.0));
            continue;
        }
        let inv_area = 1.0 / area;
        for y in miny..=maxy {
            if y < 0 || y as usize >= h {
                continue;
            }
            for x in minx..=maxx {
                if x < 0 || x as usize >= w {
                    continue;
                }
                let p = [x as f32 + 0.5, y as f32 + 0.5];
                let w0 = ((pb.0[0] - p[0]) * (pc.0[1] - p[1]) - (pc.0[0] - p[0]) * (pb.0[1] - p[1])) * inv_area;
                let w1 = ((pc.0[0] - p[0]) * (pa.0[1] - p[1]) - (pa.0[0] - p[0]) * (pc.0[1] - p[1])) * inv_area;
                let w2 = 1.0 - w0 - w1;
                if w0 < -0.001 || w1 < -0.001 || w2 < -0.001 {
                    continue;
                }
                let inv_z = w0 / pa.1 + w1 / pb.1 + w2 / pc.1;
                if inv_z <= 0.0 {
                    continue;
                }
                let z = 1.0 / inv_z;
                let i = y as usize * w + x as usize;
                if z < zbuf[i] {
                    zbuf[i] = z;
                    let o = i * 4;
                    color[o] = px[0];
                    color[o + 1] = px[1];
                    color[o + 2] = px[2];
                    color[o + 3] = 255;
                }
            }
        }
    }

    if wireframe {
        for (a, b) in edges {
            draw_line(&mut color, &mut zbuf, w, h, a, b, [0x22, 0xd3, 0xee]);
        }
    }
    let _ = &mut depth;
    color
}

fn draw_line(
    color: &mut [u8],
    zbuf: &mut [f32],
    w: usize,
    h: usize,
    a: [f32; 2],
    b: [f32; 2],
    rgb: [u8; 3],
) {
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    let steps = dx.abs().max(dy.abs()).ceil() as i32;
    if steps <= 0 || steps > 4000 {
        return;
    }
    for s in 0..=steps {
        let t = s as f32 / steps as f32;
        let x = a[0] + dx * t;
        let y = a[1] + dy * t;
        if x < 0.0 || y < 0.0 || x >= w as f32 || y >= h as f32 {
            continue;
        }
        let i = y as usize * w + x as usize;
        let o = i * 4;
        let k = 0.85;
        color[o] = (rgb[0] as f32 * k) as u8;
        color[o + 1] = (rgb[1] as f32 * k) as u8;
        color[o + 2] = (rgb[2] as f32 * k) as u8;
        color[o + 3] = 255;
        zbuf[i] = 0.0;
    }
}
