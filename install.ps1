#Requires -Version 5.1
<#
.SYNOPSIS
    Instala la orquestacion multi-agente en la configuracion GLOBAL de OpenCode (Windows).
.DESCRIPTION
    Equivalente a install.sh para Windows (PowerShell).
    - Copia los agentes a <config>/agents/ (backup previo si sobrescribe).
    - Si no existe opencode.json, la crea desde la plantilla.
    - Si ya existe: respeta modelo y default_agent; coloca el bloque del paquete
      ANTES de las reglas del usuario y anade las que falten (deduplicadas).
.PARAMETER ConfigDir
    Ruta de la carpeta de configuracion de OpenCode. Si no se pasa, se usa la
    variable de entorno OPENCODE_CONFIG_DIR; si tampoco esta definida, se elige
    la primera existente entre "$env:APPDATA\opencode" y
    "$env:USERPROFILE\.config\opencode", o esta ultima si ninguna existe.
#>
param(
    [string]$ConfigDir = $env:OPENCODE_CONFIG_DIR
)

$ErrorActionPreference = "Stop"

$SRC_DIR = $PSScriptRoot
$AGENTS_SRC = Join-Path $SRC_DIR "agents"

if (-not (Test-Path $AGENTS_SRC)) {
    Write-Host "ERROR: no se encuentra la carpeta de agentes en $AGENTS_SRC" -ForegroundColor Red
    exit 1
}

# Ruta de configuracion por defecto
if ([string]::IsNullOrWhiteSpace($ConfigDir)) {
    $candidates = @("$env:APPDATA\opencode", "$env:USERPROFILE\.config\opencode")
    $found = $null
    foreach ($c in $candidates) {
        if (Test-Path $c) { $found = $c; break }
    }
    if ($null -eq $found) { $found = "$env:USERPROFILE\.config\opencode" }
    $ConfigDir = $found
}

$DEST_CONFIG = $ConfigDir
$DEST_AGENTS = Join-Path $DEST_CONFIG "agents"

Write-Host "== Instalando agentes en $DEST_AGENTS =="
New-Item -ItemType Directory -Force -Path $DEST_AGENTS | Out-Null
New-Item -ItemType Directory -Force -Path $DEST_CONFIG | Out-Null

# --- helpers de canonicalizacion (equivalente a json.dumps sort_keys) ---
function Test-Dict($obj) {
    if ($null -eq $obj) { return $false }
    if ($obj -is [string] -or $obj -is [array] -or $obj -is [System.ValueType]) { return $false }
    if ($obj -is [hashtable] -or $obj -is [System.Collections.IDictionary]) { return $true }
    if ($obj.PSObject -and $obj.PSObject.Properties.Count -gt 0) { return $true }
    return $false
}

function Get-Canonical($obj) {
    if ($null -eq $obj) { return 'null' }
    if ($obj -is [bool]) { return $obj.ToString().ToLower() }
    if ($obj -is [string]) { return ($obj | ConvertTo-Json -Compress) }
    if ($obj -is [array]) {
        $items = @($obj | ForEach-Object { Get-Canonical $_ })
        return '[' + ($items -join ',') + ']'
    }
    if (Test-Dict $obj) {
        if ($obj -is [hashtable] -or $obj -is [System.Collections.IDictionary]) {
            $names = @($obj.Keys)
        } else {
            $names = @($obj.PSObject.Properties.Name)
        }
        $names = $names | Sort-Object
        $parts = @()
        foreach ($n in $names) {
            $v = if ($obj -is [hashtable] -or $obj -is [System.Collections.IDictionary]) { $obj[$n] } else { $obj.$n }
            $parts += ('"' + $n + '":' + (Get-Canonical $v))
        }
        return '{' + ($parts -join ',') + '}'
    }
    return ($obj | ConvertTo-Json -Compress -Depth 10)
}

# Copia previa de los agentes preexistentes que se vayan a sobrescribir
$backup = Join-Path $DEST_CONFIG ("agents.bak." + (Get-Date -Format "yyyyMMdd-HHmmss"))
$overwritten = 0
foreach ($f in (Get-ChildItem -Path $AGENTS_SRC -Filter *.md -File)) {
    $destFile = Join-Path $DEST_AGENTS $f.Name
    if (Test-Path $destFile) {
        if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Force -Path $backup | Out-Null }
        Copy-Item -Path $destFile -Destination (Join-Path $backup $f.Name) -Force
        $overwritten++
    }
}
if ($overwritten -gt 0) {
    Write-Host "Sobrescribidos $overwritten agente(s); copia previa en: $backup"
}

Copy-Item -Path (Join-Path $AGENTS_SRC "*.md") -Destination $DEST_AGENTS -Force
Write-Host "Agentes instalados en $DEST_AGENTS"

Write-Host "== Configurando $(Join-Path $DEST_CONFIG 'opencode.json') =="
$path = Join-Path $DEST_CONFIG "opencode.json"

$rules = @(
    [ordered]@{ action = "edit"; resource = "*"; effect = "allow" },
    [ordered]@{ action = "shell"; resource = "*"; effect = "ask" },
    [ordered]@{ action = "shell"; resource = "git status *"; effect = "allow" },
    [ordered]@{ action = "shell"; resource = "git diff *"; effect = "allow" },
    [ordered]@{ action = "shell"; resource = "git log *"; effect = "allow" },
    [ordered]@{ action = "shell"; resource = "git branch *"; effect = "allow" },
    [ordered]@{ action = "shell"; resource = "ls *"; effect = "allow" },
    [ordered]@{ action = "external_directory"; resource = "*"; effect = "ask" },
    [ordered]@{ action = "webfetch"; resource = "*"; effect = "ask" },
    [ordered]@{ action = "subagent"; resource = "*"; effect = "ask" }
)

$pkgSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($r in $rules) { [void]$pkgSet.Add((Get-Canonical $r)) }

if (-not (Test-Path $path)) {
    $template = Join-Path $SRC_DIR "opencode-global.example.json"
    Copy-Item -Path $template -Destination $path -Force
    Write-Host "No existia opencode.json: creada desde la plantilla de referencia."
    Write-Host ""
    Write-Host "Listo. OpenCode recarga la configuracion automaticamente: no hace falta reiniciar."
    Write-Host "Esta instalacion aplica a TODOS tus directorios y proyectos."
    exit 0
}

$raw = Get-Content -Path $path -Raw -Encoding UTF8
$cfg = $raw | ConvertFrom-Json

$any_change = $false

# default_agent: solo si el usuario no tenia uno definido
$defaultAgent = $cfg.default_agent
if ($null -eq $defaultAgent -or $defaultAgent -eq "") {
    if ($cfg.PSObject.Properties.Name -contains 'default_agent') {
        $cfg.default_agent = "orchestrator"
    } else {
        $cfg | Add-Member -NotePropertyName default_agent -NotePropertyValue "orchestrator"
    }
    $any_change = $true
    Write-Host "default_agent asignado: orchestrator"
} else {
    Write-Host "default_agent existente respetado: $defaultAgent"
}

if (-not ($cfg.PSObject.Properties.Name -contains 'permissions')) {
    $cfg | Add-Member -NotePropertyName permissions -NotePropertyValue @()
}
$existing = $cfg.permissions

if ($existing -is [array] -or $existing -is [System.Collections.IList]) {
    $beforeSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($r in $existing) {
        if (Test-Dict $r) { [void]$beforeSet.Add((Get-Canonical $r)) }
    }
    $added = 0
    foreach ($r in $rules) {
        if (-not $beforeSet.Contains((Get-Canonical $r))) { $added++ }
    }

    $kept = @()
    foreach ($r in $existing) {
        if ((Test-Dict $r) -and $pkgSet.Contains((Get-Canonical $r))) { continue }
        $kept += $r
    }
    $merged = @($rules) + @($kept)

    $canonExisting = (@($existing | ForEach-Object { Get-Canonical $_ })) -join "`n"
    $canonMerged = (@($merged | ForEach-Object { Get-Canonical $_ })) -join "`n"

    if ($canonMerged -ne $canonExisting) {
        $cfg.permissions = $merged
        $any_change = $true
        $keptCount = @($kept | Where-Object { Test-Dict $_ }).Count
        if ($added -gt 0) {
            Write-Host "$added regla(s) del paquete anadida(s); tus $keptCount regla(s) se conservan detras y siguen prevaleciendo; total: $($merged.Count)."
        } else {
            Write-Host "Bloque del paquete recolocado delante de tus $keptCount regla(s) para que sigan ganando ellas; total: $($merged.Count)."
        }
    } else {
        Write-Host "Tus permisos ya llevan el bloque del paquete en el orden correcto: nada que cambiar."
    }
} else {
    Write-Host "AVISO: 'permissions' no es una lista en tu opencode.json (config antigua?). No he tocado los permisos; revisalo a mano y sentite libre de usar opencode-global.example.json como referencia."
}

if ($any_change) {
    $json = $cfg | ConvertTo-Json -Depth 10
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json + "`n", $enc)
    Write-Host "opencode.json actualizado."
} else {
    Write-Host "opencode.json sin cambios."
}

Write-Host ""
Write-Host "Listo. OpenCode recarga la configuracion automaticamente: no hace falta reiniciar."
Write-Host "Esta instalacion aplica a TODOS tus directorios y proyectos."
