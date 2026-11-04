// Cores do Pórtico na janela do navegador (claro/escuro conforme o sistema)
const CLARO={colors:{frame:"#e8eefc",frame_inactive:"#eef2fb",tab_background_text:"#0f172a",tab_selected:"#ffffff",tab_line:"#2563eb",toolbar:"#ffffff",toolbar_text:"#0f172a",toolbar_field:"#f1f5f9",toolbar_field_text:"#0f172a",toolbar_field_border_focus:"#2563eb",popup:"#ffffff",popup_text:"#0f172a",sidebar:"#f4f7fe",sidebar_text:"#0f172a",ntp_background:"#eef2ff",ntp_text:"#0f172a",button_background_active:"#dbeafe",icons:"#334155",icons_attention:"#2563eb"}};
const ESCURO={colors:{frame:"#0b1026",frame_inactive:"#0e1430",tab_background_text:"#e2e8f0",tab_selected:"#1a2347",tab_line:"#60a5fa",toolbar:"#1a2347",toolbar_text:"#e2e8f0",toolbar_field:"#0f1735",toolbar_field_text:"#e2e8f0",toolbar_field_border_focus:"#60a5fa",popup:"#151d3d",popup_text:"#e2e8f0",sidebar:"#0f1735",sidebar_text:"#e2e8f0",ntp_background:"#0b1026",ntp_text:"#e2e8f0",button_background_active:"#25315f",icons:"#cbd5e1",icons_attention:"#60a5fa"}};
const mq=window.matchMedia("(prefers-color-scheme: dark)");
const aplicar=()=>browser.theme.update(mq.matches?ESCURO:CLARO);
mq.addEventListener("change",aplicar);aplicar();
