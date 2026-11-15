//! Windows resources for the .exe.
//!
//! Windows takes the icon it shows in Explorer and on the taskbar from a
//! resource section inside the program, not from code, so `icon.ico` has to be
//! compiled into it. The MinGW toolchain `build.bat` puts on the PATH knows how
//! (that is `windres`); when it isn't there, or when `icon.ico` hasn't been
//! generated yet, the build simply goes ahead without an icon file rather than
//! failing.
//!
//! `icon.ico` is written by the program itself: `carinae-3d --write-icon icon.ico`.

fn main() {
    println!("cargo:rerun-if-changed=icon.ico");
    println!("cargo:rerun-if-changed=icon.rc");

    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os != "windows" {
        return;
    }
    if !std::path::Path::new("icon.rc").exists() || !std::path::Path::new("icon.ico").exists() {
        return;
    }
    let out = match std::env::var("OUT_DIR") {
        Ok(v) => std::path::PathBuf::from(v),
        Err(_) => return,
    };
    let obj = out.join("carinae_icon.o");
    match std::process::Command::new("windres")
        .arg("-i")
        .arg("icon.rc")
        .arg("-o")
        .arg(&obj)
        .output()
    {
        Ok(o) if o.status.success() => {
            println!("cargo:rustc-link-arg-bins={}", obj.display());
        }
        Ok(o) => {
            // Not fatal: an icon is a nicety, a build that fails is not.
            println!(
                "cargo:warning=windres não conseguiu compilar icon.rc: {}",
                String::from_utf8_lossy(&o.stderr).trim()
            );
        }
        Err(e) => {
            println!("cargo:warning=sem windres no PATH, o .exe fica sem ícone de arquivo: {e}");
        }
    }
}
