$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $scriptDir 'waveform-manifest.csv'
$outDir = Join-Path $scriptDir 'waveforms_svg_pass2'

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

function Hash-Noise([int]$seed, [int]$index) {
    # Cheap deterministic pseudo-noise in [-1, 1]
    $x = [Math]::Sin(($seed * 12.9898 + $index * 78.233)) * 43758.5453
    $f = $x - [Math]::Floor($x)
    return ($f * 2.0) - 1.0
}

function SmoothStep([double]$t) {
    return ($t * $t * (3 - (2 * $t)))
}

function Build-BaseWave([int]$n, [string]$name, [int]$steps) {
    $vals = New-Object double[] $steps
    $lower = $name.ToLower()

    for ($i = 0; $i -lt $steps; $i++) {
        $t = $i / [double]($steps - 1)
        $v = 0.0

        if ($lower -match 'silence') {
            $v = 0
        } elseif ($lower -match 'white noise') {
            $v = Hash-Noise ($n + 9107) $i
        } elseif ($lower -match 'sine') {
            $freq = if ($lower -match 'sync') { 2.0 } else { 1.0 }
            $v = [Math]::Sin(($t * [Math]::PI * 2.0 * $freq)) * 0.88
            if ($lower -match 'sync') {
                $v += [Math]::Sin(($t * [Math]::PI * 2.0 * 5.0)) * 0.15
            }
        } elseif ($lower -match 'triangle') {
            $phase = ($t * 2.0) % 1.0
            $tri = if ($phase -lt 0.5) { ($phase * 4.0) - 1.0 } else { 3.0 - ($phase * 4.0) }
            $v = $tri * 0.82
        } elseif ($lower -match 'square|pulse') {
            $duty = 0.5
            if ($lower -match 'complex') { $duty = 0.35 }
            if ($lower -match 'pulse') { $duty = 0.22 }
            $cycles = if ($lower -match 'overtones') { 2.0 } else { 1.0 }
            $phase = ($t * $cycles) % 1.0
            $v = if ($phase -lt $duty) { 0.76 } else { -0.76 }
            if ($lower -match 'rising') {
                $v += ($t - 0.5) * 0.35
            }
        } elseif ($lower -match 'saw|ramp') {
            $cycles = if ($lower -match 'high|thin') { 1.8 } else { 1.0 }
            $phase = ($t * $cycles) % 1.0
            $v = (($phase * 2.0) - 1.0) * 0.86
            if ($lower -match 'limp') { $v *= 0.55 }
        } elseif ($lower -match 'dome|space wave|soothing') {
            $a = [Math]::Sin($t * [Math]::PI)
            $v = $a * 0.8
            $v += [Math]::Sin($t * [Math]::PI * (4 + ($n % 3))) * 0.07
            if ($lower -match 'soft') { $v *= 0.75 }
        } elseif ($lower -match 'organ') {
            $v = [Math]::Sin($t * [Math]::PI * 2.0) * 0.42
            $v += [Math]::Sin($t * [Math]::PI * 6.0) * 0.29
            $v += [Math]::Sin($t * [Math]::PI * 10.0) * 0.1
        } elseif ($lower -match 'xylophone|clav|twang|peal') {
            # Pluck-like: fast attack, noisy decay
            $env = [Math]::Exp(-3.2 * $t)
            $v = [Math]::Sin($t * [Math]::PI * (8.0 + ($n % 4))) * 0.55 * $env
            $v += Hash-Noise ($n + 3001) $i * 0.18 * $env
        } elseif ($lower -match 'jaw harp|reed|sax|vocal') {
            $v = [Math]::Sin($t * [Math]::PI * (2.4 + ($n % 3))) * 0.45
            $v += [Math]::Sin($t * [Math]::PI * (7.0 + ($n % 2))) * 0.2
            $v += Hash-Noise ($n + 444) $i * 0.1
        } elseif ($lower -match 'bp|high bp') {
            # Bandpass-ish: center-emphasized shape
            $center = [Math]::Abs((2 * $t) - 1)
            $env = 1.0 - (SmoothStep($center))
            $v = [Math]::Sin($t * [Math]::PI * 2.0) * 0.2
            $v += ($env - 0.5) * 1.2
            if ($lower -match 'square') {
                $v = if ($v -ge 0) { 0.55 } else { -0.45 }
            }
        } elseif ($lower -match 'spark|trashy|chaos|fuzz|buzz|rasp|thin|rainbow|awaken|energize|floss|excite|hollow|waken|rouse') {
            $base = [Math]::Sin($t * [Math]::PI * (2.0 + ($n % 4))) * 0.22
            $grain = Hash-Noise ($n + 1200) $i * 0.28
            $fine = [Math]::Sin($t * [Math]::PI * (10.0 + ($n % 5))) * 0.09
            $v = $base + $grain + $fine

            if ($lower -match 'thin') { $v *= 0.55 }
            if ($lower -match 'soft') { $v *= 0.7 }
            if ($lower -match 'trashy|chaos|fuzz') {
                $v += Hash-Noise ($n + 8400) ($i * 3) * 0.2
            }
        } else {
            $v = [Math]::Sin($t * [Math]::PI * 2.0) * 0.4
            $v += Hash-Noise ($n + 2024) $i * 0.15
        }

        if ($lower -match 'overtones|harmonic|octave') {
            $v += [Math]::Sin($t * [Math]::PI * 8.0) * 0.22
        }

        if ($lower -match 'mid') {
            $v *= 0.72
        }

        $vals[$i] = Clamp $v -1.0 1.0
    }

    return ,$vals
}

function Sanitize-Name([string]$name) {
    $s = $name.ToLower()
    $s = $s -replace '[^a-z0-9\+]+', '-'
    $s = $s -replace '\+', 'plus'
    $s = $s.Trim('-')
    if ([string]::IsNullOrWhiteSpace($s)) { $s = 'wave' }
    return $s
}

foreach ($w in $waves) {
    $steps = 128
    $vals = Build-BaseWave -n $w.N -name $w.Name -steps $steps

    $svgWidth = 300
    $svgHeight = 90
    $mx = 10
    $my = 10
    $plotW = $svgWidth - ($mx * 2)
    $plotH = $svgHeight - ($my * 2)
    $midY = $my + ($plotH / 2.0)

    $pts = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $vals.Length; $i++) {
        $x = $mx + ($i / ($vals.Length - 1.0)) * $plotW
        $y = $midY - ($vals[$i] * ($plotH * 0.46))
        $pts.Add(([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###},{1:0.###}', $x, $y)))
    }

    $safe = Sanitize-Name $w.Name
    $fileName = [string]::Format('{0:D3}-{1}.svg', [int]$w.N, [string]$safe)
    $path = Join-Path $outDir $fileName

    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$svgWidth" height="$svgHeight" viewBox="0 0 $svgWidth $svgHeight" role="img" aria-label="Waveform $($w.N) $($w.Name)">
  <rect x="0" y="0" width="$svgWidth" height="$svgHeight" fill="#ffffff"/>
  <line x1="$mx" y1="$midY" x2="$(($svgWidth - $mx))" y2="$midY" stroke="#d3d6dd" stroke-width="1"/>
  <polyline points="$(($pts -join ' '))" fill="none" stroke="#1b1f27" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"@

    Set-Content -Path $path -Value $svg -Encoding UTF8
}

$csvPath = Join-Path $outDir 'waveform-index.csv'
$waves | Select-Object N, Name, @{N='File';E={ [string]::Format('{0:D3}-{1}.svg', [int]$_.N, [string](Sanitize-Name $_.Name)) }} | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Output ("Generated pass2 {0} SVG files in {1}" -f $waves.Count, $outDir)
