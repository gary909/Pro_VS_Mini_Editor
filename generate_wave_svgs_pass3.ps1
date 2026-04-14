$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $scriptDir 'waveform-manifest.csv'
$outDir = Join-Path $scriptDir 'waveforms_svg_pass3'

if (-not (Test-Path $manifestPath)) {
    throw "Missing manifest: $manifestPath"
}

if (Test-Path $outDir) {
    Get-ChildItem -Path $outDir -File | Remove-Item -Force
} else {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$waves = Import-Csv $manifestPath | ForEach-Object {
    [pscustomobject]@{
        N = [int]$_.N
        Name = [string]$_.Name
        File = [string]$_.File
    }
}

function Clamp([double]$v, [double]$min, [double]$max) {
    if ($v -lt $min) { return $min }
    if ($v -gt $max) { return $max }
    return $v
}

function Noise([int]$seed, [int]$i) {
    $x = [Math]::Sin(($seed * 17.123 + $i * 71.91)) * 43758.5453
    $f = $x - [Math]::Floor($x)
    return ($f * 2.0) - 1.0
}

function Template([string]$kind) {
    switch ($kind) {
        'flat' { return @(0,0,0,0,0,0,0,0,0,0,0,0) }
        'sine' { return @(-0.02,0.18,0.45,0.72,0.9,0.72,0.36,0.0,-0.32,-0.62,-0.85,-0.6) }
        'triangle' { return @(-0.75,-0.4,0.0,0.4,0.75,0.35,-0.05,-0.45,-0.8,-0.4,0.0,0.35) }
        'saw' { return @(-0.8,-0.62,-0.44,-0.26,-0.08,0.1,0.28,0.46,0.64,0.82,-0.75,-0.6) }
        'ramp' { return @(0.8,0.63,0.46,0.29,0.12,-0.05,-0.22,-0.39,-0.56,-0.73,0.72,0.6) }
        'square' { return @(0.75,0.75,0.75,0.75,-0.75,-0.75,-0.75,-0.75,0.75,0.75,0.75,0.75) }
        'pulse' { return @(0.75,0.75,-0.75,-0.75,-0.75,0.75,0.75,-0.75,-0.75,-0.75,0.75,0.75) }
        'bp' { return @(0.65,0.65,0.65,-0.05,-0.05,-0.05,-0.65,-0.65,-0.65,-0.05,-0.05,0.65) }
        'dome' { return @(-0.15,0.06,0.28,0.48,0.62,0.68,0.62,0.5,0.34,0.18,0.02,-0.1) }
        'wobble' { return @(0.18,0.35,0.12,0.3,0.05,0.24,0.0,0.22,-0.05,0.15,-0.08,0.1) }
        'vocal' { return @(-0.35,-0.1,0.28,0.08,-0.18,0.32,0.42,0.22,-0.05,0.18,0.38,0.12) }
        'jaw' { return @(-0.45,0.35,-0.15,0.42,-0.08,0.28,0.0,0.34,-0.25,0.18,-0.1,0.12) }
        'spark' { return @(-0.08,0.06,0.02,0.18,-0.04,0.16,0.0,0.22,-0.05,0.11,0.03,0.19) }
        'buzz' { return @(-0.12,0.26,-0.22,0.3,-0.2,0.28,-0.18,0.25,-0.15,0.2,-0.1,0.16) }
        'chaos' { return @(-0.52,0.42,-0.38,0.58,-0.45,0.32,-0.28,0.4,-0.6,0.48,-0.22,0.2) }
        'pluck' { return @(0.8,0.2,0.45,0.08,0.28,0.04,0.16,0.02,0.1,0.0,0.06,0.0) }
        default { return @(-0.1,0.12,0.0,0.2,-0.06,0.15,0.0,0.11,-0.04,0.08,0.0,0.06) }
    }
}

function Choose-Kind([string]$name) {
    $l = $name.ToLower()

    if ($l -match 'silence') { return 'flat' }
    if ($l -match 'white noise') { return 'chaos' }
    if ($l -match 'sine') { return 'sine' }
    if ($l -match 'triangle') { return 'triangle' }
    if ($l -match 'square') { return 'square' }
    if ($l -match 'pulse') { return 'pulse' }
    if ($l -match 'saw') { return 'saw' }
    if ($l -match 'ramp') { return 'ramp' }
    if ($l -match 'dome|soothing|space wave') { return 'dome' }
    if ($l -match 'bp') { return 'bp' }
    if ($l -match 'vocal|sax|reed|organ') { return 'vocal' }
    if ($l -match 'jaw harp') { return 'jaw' }
    if ($l -match 'spark') { return 'spark' }
    if ($l -match 'buzz|fuzz|rasp') { return 'buzz' }
    if ($l -match 'chaos|trashy|rainbow') { return 'chaos' }
    if ($l -match 'xylophone|clav|twang|peal|floss|awaken|energize|excite|waken|rouse') { return 'pluck' }
    if ($l -match 'soft') { return 'wobble' }

    return 'wobble'
}

function Resample([double[]]$source, [int]$count) {
    $out = New-Object double[] $count
    $maxIdx = $source.Length - 1
    for ($i = 0; $i -lt $count; $i++) {
        $t = $i / [double]($count - 1)
        $idx = $t * $maxIdx
        $i0 = [int][Math]::Floor($idx)
        $i1 = [int][Math]::Ceiling($idx)
        $f = $idx - $i0
        $v = ($source[$i0] * (1.0 - $f)) + ($source[$i1] * $f)
        $out[$i] = $v
    }
    return ,$out
}

function Build-Trace([int]$n, [string]$name, [int]$steps) {
    $kind = Choose-Kind $name
    $tmpl = Template $kind
    $vals = Resample -source $tmpl -count $steps

    $l = $name.ToLower()
    $amp = 0.9
    $jitter = 0.025

    if ($kind -eq 'flat') { $amp = 0.0; $jitter = 0 }
    if ($l -match 'soft|mellow|limp') { $amp *= 0.75; $jitter *= 0.8 }
    if ($l -match 'chaos|trashy|white noise') { $amp *= 1.0; $jitter = 0.09 }
    if ($l -match 'buzz|fuzz|rasp') { $jitter = 0.06 }
    if ($l -match 'thin') { $amp *= 0.55 }
    if ($l -match 'high|harmonic|overtones|octave|sync') { $jitter += 0.02 }

    for ($i = 0; $i -lt $steps; $i++) {
        $vals[$i] = $vals[$i] * $amp
        if ($jitter -gt 0) {
            $vals[$i] += (Noise ($n + 6000) $i) * $jitter
        }
        if ($l -match 'rising') {
            $vals[$i] += (($i / [double]($steps - 1)) - 0.5) * 0.35
        }
        $vals[$i] = Clamp $vals[$i] -1.0 1.0
    }

    return ,$vals
}

foreach ($w in $waves) {
    $steps = 72
    $vals = Build-Trace -n $w.N -name $w.Name -steps $steps

    $svgWidth = 160
    $svgHeight = 48
    $mx = 8
    $my = 6
    $plotW = $svgWidth - ($mx * 2)
    $plotH = $svgHeight - ($my * 2)
    $midY = $my + ($plotH / 2.0)

    $pts = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $vals.Length; $i++) {
        $x = $mx + ($i / [double]($vals.Length - 1)) * $plotW
        $y = $midY - ($vals[$i] * ($plotH * 0.46))
        $pts.Add(([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###},{1:0.###}', $x, $y)))
    }

    $fileName = [string]::Format('{0:D3}-{1}.svg', [int]$w.N, [string]($w.Name.ToLower() -replace '[^a-z0-9\+]+','-' -replace '\+','plus').Trim('-'))
    if ($fileName -match '^\d{3}-\.svg$') {
        $fileName = [string]::Format('{0:D3}-wave.svg', [int]$w.N)
    }

    $path = Join-Path $outDir $fileName

    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$svgWidth" height="$svgHeight" viewBox="0 0 $svgWidth $svgHeight" role="img" aria-label="Waveform $($w.N) $($w.Name)">
  <defs>
    <filter id="glow">
      <feGaussianBlur stdDeviation="1.5" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="0" y="0" width="$svgWidth" height="$svgHeight" fill="#1f2025"/>
  <polyline points="$(($pts -join ' '))" fill="none" stroke="#1fdcf5" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" filter="url(#glow)"/>
</svg>
"@

    Set-Content -Path $path -Value $svg -Encoding UTF8
}

$csvPath = Join-Path $outDir 'waveform-index.csv'
$waves | Select-Object N, Name, @{N='File';E={ [string]::Format('{0:D3}-{1}.svg', [int]$_.N, [string](($_.Name.ToLower() -replace '[^a-z0-9\+]+','-' -replace '\+','plus').Trim('-'))) }} | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Output ("Generated pass3 {0} SVG files in {1}" -f $waves.Count, $outDir)
