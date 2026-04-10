$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $scriptDir 'waveforms_svg'
if (Test-Path $outDir) {
    Get-ChildItem -Path $outDir -File | Remove-Item -Force
} else {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$waveData = @'
0|Twang
1|Clav
2|Xylophone
3|Slippery Slope
4|Enharmonic Square
5|Xylophone 2
6|Mellow Square
7|Chaos 1
8|Chaos 2
9|Chaos 3
10|Chaos 4
11|Bright Square
12|Hollow
13|BP Square
14|Ski Slope 1
15|Rasp
16|Peal
17|Fuzz
18|Floss
19|Excite
20|Awaken
21|Energize
22|BP Twang
23|Complex Pulse
24|Mellow Square 2
25|Harmonic Square
26|Thin Ramp
27|Xylophone 3
28|Thin Square
29|Harmonic Ramp
30|Rouse
31|Waken
32|Sine
33|Sawtooth
34|Square
35|Dome 1
36|Dome 2
37|Mellow Dome
38|Dome 3
39|Dome 4
40|Rasp 1
41|Rasp 2
42|Rasp 3
43|Rasp 4
44|Dome 5
45|HP Saw
46|High BP Saw
47|High BP Square
48|Vocal
49|Squeeze box
50|Pulse
51|Limp Saw
52|Spark Wave 1
53|Spark Wave 2
54|Spark Wave 3
55|Mid Wave 1
56|Cacophonous Buzz 1
57|Mid Buzz 1
58|Dome 6
59|Soft Dome 3
60|Dome 7
61|Spark Wave 4
62|Spark Wave 5
63|Soft Dome 4
64|Dome 8
65|Organ
66|Spark Wave 5
67|Soft Wave 1
68|Soft Wave 2
69|Spark Wave 7
70|Reed
71|Soft Wave 3
72|Soft Wave 4
73|Saxophone
74|Soft Wave 5
75|Trashy Wave 1
76|Trashy Wave 2
77|Trashy Wave 3
78|Trashy Wave 4
79|Trashy Wave 5
80|Trashy Wave 6
81|Jaw Harp 1
82|Jaw Harp 2
83|Soft Wave 6
84|Thin 1
85|Thin 2
86|Spark Wave 8
87|Spark Wave 9
88|Spark Wave 10
89|Soft Dome 5
90|Soft Dome 6
91|Cacophonous Buzz 2
92|Thin 3
93|Spark Wave 11
94|Soft Dome 7
95|Soft Wave 7
96|Sine 2
97|Sync'd Sine
98|Trashy Wave 7
99|Twingle Pad
100|Dome 9
101|Thin 4
102|Thin 5
103|Trashy Wave 8
104|Trashy Wave 9
105|Trashy Wave 10
106|Trashy Wave 11
107|Trashy Wave 12
108|Trashy Wave 13
109|Spark Wave 12
110|Spark Wave 13
111|Trashy Wave 14
112|Trashy Wave 15
113|Rainbow
114|Soft Dome 8
115|Trashy Wave 15
116|Soothing 1
117|Soothing 2
118|Space Wave
119|5th Rasp
120|Octave Wave
121|Triangle + Overtones
122|Pulse + Overtones
123|Rising Square
124|Soft Wave 8
125|Cacophonous Buzz 3
126|Silence
127|White Noise
'@

$waves = foreach ($m in [regex]::Matches($waveData, '(?m)^\s*(\d+)\|(.+?)\s*$')) {
    [pscustomobject]@{
        N = [int]$m.Groups[1].Value
        Name = $m.Groups[2].Value
    }
}

$manifestPath = Join-Path $scriptDir 'waveform-manifest.csv'
if (Test-Path $manifestPath) {
    $waves = Import-Csv $manifestPath | ForEach-Object {
        [pscustomobject]@{
            N = [int]$_.N
            Name = [string]$_.Name
        }
    }
}

function Sanitize-Name([string]$name) {
    $s = $name.ToLower()
    $s = $s -replace '[^a-z0-9\+]+', '-'
    $s = $s -replace '\+', 'plus'
    $s = $s.Trim('-')
    if ([string]::IsNullOrWhiteSpace($s)) { $s = 'wave' }
    return $s
}

function Get-WavePoints([int]$n, [string]$name) {
    $rng = [System.Random]::new($n + 1731)
    $steps = 96
    $vals = New-Object double[] $steps
    $lower = $name.ToLower()

    for ($i = 0; $i -lt $steps; $i++) {
        $t = $i / ($steps - 1)
        $base = 0.0

        if ($lower -match 'silence') {
            $base = 0
        } elseif ($lower -match 'white noise') {
            $base = ($rng.NextDouble() * 2.0) - 1.0
        } elseif ($lower -match 'sync') {
            $base = [Math]::Sin($t * [Math]::PI * 4.0) * 0.6 + [Math]::Sin($t * [Math]::PI * 12.0) * 0.25
        } elseif ($lower -match 'sine') {
            $base = [Math]::Sin($t * [Math]::PI * 2.0) * 0.85
        } elseif ($lower -match 'triangle') {
            $phase = ($t * 2.0) % 1.0
            $tri = if ($phase -lt 0.5) { ($phase * 4.0) - 1.0 } else { 3.0 - ($phase * 4.0) }
            $base = $tri * 0.85
        } elseif ($lower -match 'square|pulse') {
            $duty = if ($lower -match 'pulse') { 0.25 } else { 0.5 }
            $cycles = if ($lower -match 'complex|overtones') { 3.0 } else { 1.0 }
            $phase = ($t * $cycles) % 1.0
            $base = if ($phase -lt $duty) { 0.78 } else { -0.78 }
        } elseif ($lower -match 'saw|ramp') {
            $cycles = if ($lower -match 'high|thin') { 2.0 } else { 1.0 }
            $phase = ($t * $cycles) % 1.0
            $base = ($phase * 2.0) - 1.0
        } elseif ($lower -match 'dome|soft dome|space wave|soothing') {
            $base = [Math]::Sin($t * [Math]::PI) * 0.75
            $base += [Math]::Sin($t * [Math]::PI * 6.0) * 0.08
        } elseif ($lower -match 'organ') {
            $base = [Math]::Sin($t * [Math]::PI * 2.0) * 0.45 + [Math]::Sin($t * [Math]::PI * 6.0) * 0.25
        } elseif ($lower -match 'buzz|fuzz|rasp|chaos|trashy|spark|thin|jaw harp|xylophone|clav|twang|reed|sax|vocal|awaken|energize|floss|excite|hollow|peal|rainbow') {
            $base = [Math]::Sin($t * [Math]::PI * (2 + ($n % 5))) * 0.25
            $base += (($rng.NextDouble() * 2.0) - 1.0) * 0.35
            if ($lower -match 'chaos|trashy|white') { $base += (($rng.NextDouble() * 2.0) - 1.0) * 0.25 }
        } else {
            $base = [Math]::Sin($t * [Math]::PI * 2.0) * 0.4 + (($rng.NextDouble() * 2.0) - 1.0) * 0.2
        }

        if ($lower -match 'overtones|harmonic|bp|high bp') {
            $base += [Math]::Sin($t * [Math]::PI * 8.0) * 0.2
        }

        if ($lower -match 'rising') {
            $base += ($t - 0.5) * 0.5
        }

        if ($lower -match 'limp') {
            $base *= 0.55
        }

        if ($base -gt 1.0) { $base = 1.0 }
        if ($base -lt -1.0) { $base = -1.0 }
        $vals[$i] = $base
    }

    return ,$vals
}

foreach ($w in $waves) {
    $vals = Get-WavePoints -n $w.N -name $w.Name
    $svgWidth = 320
    $svgHeight = 120
    $mx = 12
    $my = 14
    $plotW = $svgWidth - ($mx * 2)
    $plotH = $svgHeight - ($my * 2)
    $midY = $my + ($plotH / 2.0)

    $pts = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $vals.Length; $i++) {
        $x = $mx + ($i / ($vals.Length - 1.0)) * $plotW
        $y = $midY - ($vals[$i] * ($plotH * 0.45))
        $pts.Add(([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###},{1:0.###}', $x, $y)))
    }

    $safe = Sanitize-Name $w.Name
    $fileName = [string]::Format('{0:D3}-{1}.svg', [int]$w.N, [string]$safe)
    $path = Join-Path $outDir $fileName

    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$svgWidth" height="$svgHeight" viewBox="0 0 $svgWidth $svgHeight" role="img" aria-label="Waveform $($w.N) $($w.Name)">
    <rect x="0" y="0" width="$svgWidth" height="$svgHeight" fill="#f6f7f9"/>
    <line x1="$mx" y1="$midY" x2="$(($svgWidth - $mx))" y2="$midY" stroke="#c4c9d4" stroke-width="1"/>
  <polyline points="$(($pts -join ' '))" fill="none" stroke="#111827" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <text x="12" y="18" font-family="Arial, Helvetica, sans-serif" font-size="12" fill="#111827">$($w.N): $($w.Name)</text>
</svg>
"@

    Set-Content -Path $path -Value $svg -Encoding UTF8
}

$csvPath = Join-Path $outDir 'waveform-index.csv'
$waves | Select-Object N, Name, @{N='File';E={ [string]::Format('{0:D3}-{1}.svg', [int]$_.N, [string](Sanitize-Name $_.Name)) }} | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Output ("Generated {0} SVG files in {1}" -f $waves.Count, $outDir)
