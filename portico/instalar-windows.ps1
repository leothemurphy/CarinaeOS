# ============================================================
#  Pórtico 0.1 — instalador da prévia de teste (Windows 10/11)
#  Cria um perfil "Pórtico" separado, com o visual, a página
#  inicial e a privacidade do Pórtico. Não mexe no seu Firefox.
# ============================================================
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host ""
Write-Host "  Pórtico 0.1 — instalando a prévia de teste" -ForegroundColor Cyan
Write-Host ""

function Find-Engine {
  $c = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
    "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe"
  )
  foreach ($p in $c) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}

$Engine = Find-Engine
if (-not $Engine) {
  Write-Host "  O Pórtico usa o motor do Firefox, que não está instalado." -ForegroundColor Yellow
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "  Instalando o motor com o winget..."
    winget install -e --id Mozilla.Firefox --accept-source-agreements --accept-package-agreements | Out-Host
    $Engine = Find-Engine
  }
  if (-not $Engine) {
    Write-Host "  Instale o Firefox em https://www.mozilla.org/firefox/ e rode este instalador de novo." -ForegroundColor Red
    Start-Process "https://www.mozilla.org/firefox/"
    Read-Host "  Pressione Enter para sair"
    exit 1
  }
}

$Dest    = Join-Path $env:LOCALAPPDATA 'Portico'
$Perfil = Join-Path $Dest 'Perfil'
New-Item -ItemType Directory -Force -Path $Perfil | Out-Null
Copy-Item -Path (Join-Path $Here 'perfil\*') -Destination $Perfil -Recurse -Force
Copy-Item -Path (Join-Path $Here 'inicio') -Destination $Dest -Recurse -Force
Copy-Item -Path (Join-Path $Here 'icones\portico.ico') -Destination $Dest -Force

$HomeUrl = 'file:///' + (($Dest -replace '\\','/') + '/inicio/inicio.html').Replace(' ','%20')
Add-Content -Path (Join-Path $Perfil 'user.js') -Value "user_pref(`"browser.startup.homepage`", `"$HomeUrl`");" -Encoding UTF8

$Shell = New-Object -ComObject WScript.Shell
$Targets = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Pórtico.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Desktop'))  'Pórtico.lnk')
)
foreach ($t in $Targets) {
  $l = $Shell.CreateShortcut($t)
  $l.TargetPath = $Engine
  $l.Arguments = "-profile `"$Perfil`""
  $l.IconLocation = (Join-Path $Dest 'portico.ico')
  $l.Description = 'Pórtico — navegador do AtriumOS (prévia de teste)'
  $l.WorkingDirectory = Split-Path -Parent $Engine
  $l.Save()
}

# desinstalador
$Un = @"
Remove-Item -Recurse -Force '$Dest'
Remove-Item -Force '$($Targets[0])','$($Targets[1])' -ErrorAction SilentlyContinue
Write-Host 'Pórtico removido.'
"@
Set-Content -Path (Join-Path $Dest 'desinstalar.ps1') -Value $Un -Encoding UTF8

Write-Host "  Pronto! O atalho 'Pórtico' está na Área de Trabalho e no menu Iniciar." -ForegroundColor Green
Write-Host "  Para remover: $Dest\desinstalar.ps1"
Start-Process -FilePath $Engine -ArgumentList "-profile `"$Perfil`""
Start-Sleep -Seconds 2
