// ============================================================
//  Pórtico 0.1 — prévia de teste (motor Gecko / Firefox)
//  Ajustes padrão do Pórtico. O instalador acrescenta no fim
//  a linha da página inicial.
// ============================================================

// --- Visual do Pórtico ---
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.uidensity", 0);
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", false);           // abas na lateral: ative pelo menu da barra de abas
user_pref("browser.tabs.groups.enabled", true);      // grupos de abas
user_pref("browser.tabs.splitView.enabled", true);   // tela dividida (onde a versão do motor já tiver)
user_pref("browser.toolbars.bookmarks.visibility", "always");
user_pref("browser.startup.page", 1);                // abrir a página inicial do Pórtico
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("browser.aboutConfig.showWarning", false);

// --- Escudo: privacidade forte por padrão ---
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("dom.security.https_only_mode", true);
user_pref("network.trr.mode", 2);                    // DNS seguro (com reserva se falhar)
user_pref("network.trr.uri", "https://dns.quad9.net/dns-query");
user_pref("network.cookie.cookieBehavior", 5);       // cookies isolados por site
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("extensions.pocket.enabled", false);

// --- Sem envio de dados de uso ---
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.discovery.enabled", false);

// --- IA desligada por padrão (o usuário liga se quiser) ---
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.sidebar", false);
user_pref("browser.tabs.groups.smart.enabled", false);

// --- Desempenho e bateria ---
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("gfx.webrender.all", true);
user_pref("reader.parse-on-load.enabled", true);

// --- Downloads ---
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.always_ask_before_handling_new_types", false);
