# MADock 映像・音声情報取得ロジック スクリプト（MADock_utils.ps1）


# ビットレート取得
function GetAudioSpecs($inputPath) {
    $specJson = "$env:TEMP\ffprobe_spec.json"
    $args = "-v error -select_streams a:0 -show_entries stream=bit_rate,sample_rate,channels,sample_fmt -of json `"$inputPath`""
    Start-Process -FilePath $ffprobe -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput $specJson

    if (-not (Test-Path $specJson)) {
        return @{ bit_rate = "512k"; sample_rate = 48000; channels = 2; sample_fmt = "s16" }
    }

    $specData = Get-Content $specJson -Raw | ConvertFrom-Json
    Remove-Item $specJson -Force

    $bitrate = "512k"
    $rawBitrate = "$($specData.streams[0].bit_rate)"

    if ($rawBitrate -match '^\d+$') {
        $kbps = [math]::Round([double]$rawBitrate / 1000)
        $bitrate = "$kbps" + "k"
    } elseif ($rawBitrate -match '^(\d+)[kK]$') {
        $bitrate = "$($matches[1])k"
    }

    return @{
        bit_rate    = $bitrate
        sample_rate = $specData.streams[0].sample_rate
        channels    = $specData.streams[0].channels
        sample_fmt  = $specData.streams[0].sample_fmt
    }
}


# 音声ファイルのコーデックを判定
function GetAudioCodecName($inputPath) {
    if (-not $ffprobe -or -not (Test-Path $ffprobe)) {
        return "unknown"
    }

    $codecJson = "$env:TEMP\ffprobe_codec.json"
    $args = "-v error -select_streams a:0 -show_entries stream=codec_name -of json `"$inputPath`""
    Start-Process -FilePath $ffprobe -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput $codecJson

    if (-not (Test-Path $codecJson)) {
        return "unknown"
    }

    $data = Get-Content $codecJson -Raw | ConvertFrom-Json
    Remove-Item $codecJson -Force

    return $data.streams[0].codec_name
}


# コーデック対応表（音声）
$containerAudioSupport = @{
    "mp4" = @("aac", "alac")
    "mov" = @("wav", "aac", "alac", "mp3")
    "mkv" = @("wav", "aac", "alac", "mp3", "flac", "opus")
}

# コーデック対応表（映像）
$containerVideoSupport = @{
    "mp4" = @("h264", "hevc")
    "mov" = @("h264", "prores", "mpeg4", "dvvideo")
    "mkv" = @("h264", "hevc", "vp8", "vp9", "mpeg4", "theora")
}

# コーデック判定関数（音声）
function IsCodecSupported($container, $codecName, $audioExt) {
    return $containerAudioSupport[$container] -contains $codecName -or $containerAudioSupport[$container] -contains $audioExt
}

# コーデック判定関数（映像）
function IsVideoCodecSupported($container, $codecName) {
    return $containerVideoSupport[$container] -contains $codecName
}

# 映像ファイルコーデックを判定
function GetVideoCodecName($inputPath) {
    if (-not $ffprobe -or -not (Test-Path $ffprobe)) {
        return "unknown"
    }

    $codecJson = "$env:TEMP\ffprobe_vcodec.json"
    $args = "-v error -select_streams v:0 -show_entries stream=codec_name -of json `"$inputPath`""
    Start-Process -FilePath $ffprobe -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput $codecJson

    if (-not (Test-Path $codecJson)) {
        return "unknown"
    }

    $data = Get-Content $codecJson -Raw | ConvertFrom-Json
    Remove-Item $codecJson -Force

    if (-not $data.streams -or $data.streams.Count -eq 0) {
        return "unknown"
    }

    return $data.streams[0].codec_name
}

# 映像コーデック対応案内
function AssertVideoCodecSupported($container, $videoPath) {
    $codec = GetVideoCodecName $videoPath
    $supported = $containerVideoSupport[$container] -join ", "

    if (-not $codec -or $codec -eq "unknown") {
        [void][System.Windows.Forms.MessageBox]::Show(
            "$container 出力の映像コーデックを判定できませんでした。`n対応コーデック: $supported`nこのまま処理を続けると失敗する可能性があります。",
            "コーデック判定不能",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        Write-Host "[Assert] 非対応: $codec → return $false （処理キャンセル）"
        return $false
    }

    if (-not (IsVideoCodecSupported $container $codec)) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "$container 出力はこの映像コーデックに対応していません（$codec）。`n対応コーデック: $supported",
            "非対応コーデック",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        Write-Host "[Assert] 非対応: $codec → return $false （処理キャンセル）"
        return $false
    }

    return $true
}

