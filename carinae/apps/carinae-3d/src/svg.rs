//! A very small SVG reader.
//!
//! It understands the primitives a laser-cut or vector drawing uses — lines,
//! rectangles, circles, ellipses, polylines, polygons and the usual path
//! commands — and draws them with straight segments into a plain RGBA buffer, so
//! an SVG can be shown as a real picture instead of a note saying "vector".
//! Curves become a few straight pieces, and a group's `transform` is ignored:
//! that is enough for a preview, not for faithful rendering.

struct Seg {
    a: [f32; 2],
    b: [f32; 2],
}

/// The drawing's own coordinate box: `viewBox` when present, else width/height.
pub fn size(text: &str) -> Option<[f32; 2]> {
    let tag = text.split_once("<svg").map(|(_, rest)| rest)?;
    let tag = tag.split_once('>').map(|(t, _)| t)?;
    if let Some(vb) = attr(tag, "viewBox") {
        let n = nums(&vb);
        if n.len() >= 4 && n[2] > 0.0 && n[3] > 0.0 {
            return Some([n[2], n[3]]);
        }
    }
    let w = attr(tag, "width").and_then(|v| first_num(&v));
    let h = attr(tag, "height").and_then(|v| first_num(&v));
    match (w, h) {
        (Some(w), Some(h)) if w > 0.0 && h > 0.0 => Some([w, h]),
        _ => None,
    }
}

fn attr(tag: &str, name: &str) -> Option<String> {
    let pat = format!("{name}=");
    let mut from = 0usize;
    while let Some(i) = tag[from..].find(&pat) {
        let at = from + i;
        // make sure the name isn't the tail of a longer attribute (stroke-width)
        let ok = at == 0
            || !tag.as_bytes()[at - 1].is_ascii_alphanumeric()
                && tag.as_bytes()[at - 1] != b'-';
        if ok {
            let rest = &tag[at + pat.len()..];
            if let Some(q) = rest.chars().next() {
                if q == '"' || q == '\'' {
                    let body = &rest[1..];
                    if let Some(end) = body.find(q) {
                        return Some(body[..end].to_string());
                    }
                }
            }
        }
        from = at + pat.len();
    }
    None
}

fn first_num(s: &str) -> Option<f32> {
    let cleaned: String = s
        .chars()
        .take_while(|c| c.is_ascii_digit() || *c == '.' || *c == '-' || *c == '+' || *c == 'e')
        .collect();
    cleaned.parse::<f32>().ok()
}

fn nums(s: &str) -> Vec<f32> {
    let mut out = Vec::new();
    let mut cur = String::new();
    for c in s.chars() {
        let numeric = c.is_ascii_digit() || c == '.' || c == '-' || c == '+' || c == 'e' || c == 'E';
        if numeric {
            cur.push(c);
        } else {
            if !cur.is_empty() {
                if let Ok(v) = cur.parse::<f32>() {
                    out.push(v);
                }
                cur.clear();
            }
            // a lone '-' or '+' starts a new number
            if c == '-' || c == '+' {
                cur.push(c);
            }
        }
    }
    if !cur.is_empty() {
        if let Ok(v) = cur.parse::<f32>() {
            out.push(v);
        }
    }
    out
}

fn n(v: &[f32], i: usize) -> f32 {
    v.get(i).copied().unwrap_or(0.0)
}

fn segments(text: &str) -> Vec<Seg> {
    let mut segs: Vec<Seg> = Vec::new();
    let mut i = 0usize;
    while let Some(rel) = text[i..].find('<') {
        let start = i + rel;
        let end = match text[start..].find('>') {
            Some(e) => start + e,
            None => break,
        };
        let tag = &text[start + 1..end];
        let name: String = tag
            .chars()
            .take_while(|c| c.is_ascii_alphabetic())
            .collect::<String>()
            .to_lowercase();
        let body = &tag[name.len()..];
        match name.as_str() {
            "line" => {
                let v = nums(body);
                segs.push(Seg {
                    a: [n(&v, 0), n(&v, 1)],
                    b: [n(&v, 2), n(&v, 3)],
                });
            }
            "rect" => {
                let x = attr(body, "x").and_then(|v| first_num(&v)).unwrap_or(0.0);
                let y = attr(body, "y").and_then(|v| first_num(&v)).unwrap_or(0.0);
                let w = attr(body, "width").and_then(|v| first_num(&v)).unwrap_or(0.0);
                let h = attr(body, "height").and_then(|v| first_num(&v)).unwrap_or(0.0);
                if w > 0.0 && h > 0.0 {
                    let p = [[x, y], [x + w, y], [x + w, y + h], [x, y + h], [x, y]];
                    for k in 0..4 {
                        segs.push(Seg { a: p[k], b: p[k + 1] });
                    }
                }
            }
            "circle" | "ellipse" => {
                let cx = attr(body, "cx").and_then(|v| first_num(&v)).unwrap_or(0.0);
                let cy = attr(body, "cy").and_then(|v| first_num(&v)).unwrap_or(0.0);
                let rx = if name == "circle" {
                    attr(body, "r").and_then(|v| first_num(&v)).unwrap_or(0.0)
                } else {
                    attr(body, "rx").and_then(|v| first_num(&v)).unwrap_or(0.0)
                };
                let ry = if name == "circle" {
                    rx
                } else {
                    attr(body, "ry").and_then(|v| first_num(&v)).unwrap_or(0.0)
                };
                if rx > 0.0 && ry > 0.0 {
                    let steps = 28;
                    let mut prev = [cx + rx, cy];
                    for k in 1..=steps {
                        let t = k as f32 / steps as f32 * std::f32::consts::TAU;
                        let p = [cx + rx * t.cos(), cy + ry * t.sin()];
                        segs.push(Seg { a: prev, b: p });
                        prev = p;
                    }
                }
            }
            "polyline" | "polygon" => {
                let v = nums(&attr(body, "points").unwrap_or_default());
                let pts: Vec<[f32; 2]> = v.chunks(2).map(|c| [n(c, 0), n(c, 1)]).collect();
                for k in 0..pts.len().saturating_sub(1) {
                    segs.push(Seg { a: pts[k], b: pts[k + 1] });
                }
                if name == "polygon" && pts.len() > 2 {
                    segs.push(Seg {
                        a: *pts.last().unwrap(),
                        b: pts[0],
                    });
                }
            }
            "path" => {
                if let Some(d) = attr(body, "d") {
                    path_segments(&d, &mut segs);
                }
            }
            _ => {}
        }
        i = end + 1;
    }
    segs
}

/// Path commands → straight pieces. Curves go straight to their end point; the
/// outline is still recognisable, which is what a preview needs.
fn path_segments(d: &str, segs: &mut Vec<Seg>) {
    let mut cur = [0.0f32, 0.0];
    let mut start = [0.0f32, 0.0];
    let mut cmd = 'M';
    let mut chars = d.chars().peekable();
    let mut num = String::new();
    let mut args: Vec<f32> = Vec::new();

    fn flush(num: &mut String, args: &mut Vec<f32>) {
        if num.is_empty() {
            return;
        }
        if let Ok(v) = num.parse::<f32>() {
            args.push(v);
        }
        num.clear();
    }

    loop {
        let c = chars.next();
        let is_cmd = match c {
            Some(ch) => ch.is_ascii_alphabetic(),
            None => true,
        };
        if is_cmd {
            flush(&mut num, &mut args);
            // apply the previous command with whatever arguments it received
            apply(cmd, &args, &mut cur, &mut start, segs);
            args.clear();
            match c {
                Some(ch) => cmd = ch,
                None => break,
            }
            // a path may start with implicit lineto after moveto
            if cmd == 'Z' || cmd == 'z' {
                flush(&mut num, &mut args);
                apply(cmd, &args, &mut cur, &mut start, segs);
                args.clear();
            }
        } else {
            match c {
                Some(ch) if ch.is_ascii_digit() || ch == '.' || ch == 'e' || ch == 'E' => num.push(ch),
                Some(ch) if ch == '-' || ch == '+' => {
                    flush(&mut num, &mut args);
                    num.push(ch);
                }
                Some(_) => {}
                None => {}
            }
        }
    }
}

fn apply(cmd: char, a: &[f32], cur: &mut [f32; 2], start: &mut [f32; 2], segs: &mut Vec<Seg>) {
    let rel = cmd.is_ascii_lowercase();
    let c = cmd.to_ascii_uppercase();
    let mut i = 0usize;
    let step = match c {
        'M' | 'L' | 'T' => 2,
        'H' | 'V' => 1,
        'C' => 6,
        'S' | 'Q' => 4,
        'A' => 7,
        _ => 0,
    };
    if c == 'Z' {
        if *cur != *start {
            segs.push(Seg { a: *cur, b: *start });
        }
        *cur = *start;
        return;
    }
    if step == 0 {
        return;
    }
    while i + step <= a.len() {
        let next = match c {
            'H' => [if rel { cur[0] + a[i] } else { a[i] }, cur[1]],
            'V' => [cur[0], if rel { cur[1] + a[i] } else { a[i] }],
            'M' | 'L' => [
                if rel { cur[0] + a[i] } else { a[i] },
                if rel { cur[1] + a[i + 1] } else { a[i + 1] },
            ],
            // curves and arcs: straight to the end point
            _ => [
                if rel { cur[0] + a[i + step - 2] } else { a[i + step - 2] },
                if rel { cur[1] + a[i + step - 1] } else { a[i + step - 1] },
            ],
        };
        if c == 'M' {
            *cur = next;
            *start = next;
        } else {
            segs.push(Seg { a: *cur, b: next });
            *cur = next;
        }
        i += step;
        // repeated moveto arguments are linetos
        if c == 'M' && i + 2 <= a.len() {
            let mut k = i;
            while k + 2 <= a.len() {
                let p = [
                    if rel { cur[0] + a[k] } else { a[k] },
                    if rel { cur[1] + a[k + 1] } else { a[k + 1] },
                ];
                segs.push(Seg { a: *cur, b: p });
                *cur = p;
                k += 2;
            }
            return;
        }
    }
}

/// Draws the drawing into a fresh RGBA buffer of `w` by `h` pixels.
pub fn preview(text: &str, w: usize, h: usize, bg: [u8; 3], fg: [u8; 3]) -> Option<Vec<u8>> {
    let segs = segments(text);
    if segs.is_empty() || w == 0 || h == 0 {
        return None;
    }
    let mut min = [f32::MAX, f32::MAX];
    let mut max = [f32::MIN, f32::MIN];
    for s in &segs {
        for p in [s.a, s.b] {
            min[0] = min[0].min(p[0]);
            min[1] = min[1].min(p[1]);
            max[0] = max[0].max(p[0]);
            max[1] = max[1].max(p[1]);
        }
    }
    let span_x = (max[0] - min[0]).max(0.001);
    let span_y = (max[1] - min[1]).max(0.001);
    let pad = 10.0f32;
    let sx = (w as f32 - pad * 2.0) / span_x;
    let sy = (h as f32 - pad * 2.0) / span_y;
    let s = sx.min(sy);
    // centre it
    let used_w = span_x * s;
    let used_h = span_y * s;
    let ox = (w as f32 - used_w) / 2.0 - min[0] * s;
    let oy = (h as f32 - used_h) / 2.0 - min[1] * s;

    let mut buf = vec![0u8; w * h * 4];
    for px in buf.chunks_mut(4) {
        px[0] = bg[0];
        px[1] = bg[1];
        px[2] = bg[2];
        px[3] = 255;
    }
    for seg in &segs {
        let a = (seg.a[0] * s + ox, seg.a[1] * s + oy);
        let b = (seg.b[0] * s + ox, seg.b[1] * s + oy);
        line(&mut buf, w, h, a, b, fg);
    }
    Some(buf)
}

fn put(buf: &mut [u8], w: usize, h: usize, x: isize, y: isize, c: [u8; 3]) {
    if x < 0 || y < 0 || x >= w as isize || y >= h as isize {
        return;
    }
    let i = (y as usize * w + x as usize) * 4;
    buf[i] = c[0];
    buf[i + 1] = c[1];
    buf[i + 2] = c[2];
    buf[i + 3] = 255;
}

fn line(buf: &mut [u8], w: usize, h: usize, a: (f32, f32), b: (f32, f32), c: [u8; 3]) {
    let (x0, y0) = (a.0.round() as isize, a.1.round() as isize);
    let (x1, y1) = (b.0.round() as isize, b.1.round() as isize);
    let dx = (x1 - x0).abs();
    let dy = (y1 - y0).abs();
    let sx = if x0 < x1 { 1 } else { -1 };
    let sy = if y0 < y1 { 1 } else { -1 };
    let mut err = dx - dy;
    let (mut x, mut y) = (x0, y0);
    loop {
        put(buf, w, h, x, y, c);
        put(buf, w, h, x + 1, y, c);
        put(buf, w, h, x, y + 1, c);
        if x == x1 && y == y1 {
            break;
        }
        let e2 = 2 * err;
        if e2 > -dy {
            err -= dy;
            x += sx;
        }
        if e2 < dx {
            err += dx;
            y += sy;
        }
    }
}
