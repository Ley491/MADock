# 映像ファイルから音声を分離する処理（MADock_sub.ps1）


# dot-sourceで別スクリプトの関数を読み込む記述はMADock_guiにあるので不要

# 音声ファイル情報の出力制御（まだGUIでは切り替えない）
$EnableAudioInfoOutput = $true   # ← ここを $false にすれば出力されなくなる

#音声を分離
function ExtractAudioFromVideo($videoPath, $outputDir) {
    if (-not (Test-Path $videoPath)) {
        [System.Windows.Forms.MessageBox]::Show("映像ファイルが見つかりません。")
        return
    }

    # コーデック名を取得
    $codecJson = "$env:TEMP\ffprobe_codec.json"
    $args = "-v error -select_streams a:0 -show_entries stream=codec_name -of json `"$videoPath`""
    Start-Process -FilePath $ffprobe -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput $codecJson

    if (-not (Test-Path $codecJson)) {
        [System.Windows.Forms.MessageBox]::Show("音声コーデックの取得に失敗しました。")
        return
    }

    $data = Get-Content $codecJson -Raw | ConvertFrom-Json
    Remove-Item $codecJson -Force
    $codec = $data.streams[0].codec_name

    # 拡張子をコーデックに応じて決定
    $ext = switch ($codec) {
        "aac"  { "aac" }
        "mp3"  { "mp3" }
        "alac" { "m4a" }
        "flac" { "flac" }
        "opus" { "opus" }
        "pcm_f32le"  { "wav" }
        "pcm_s24le"  { "wav" }
        "pcm_s16le"  { "wav" }
        "pcm_s32le"  { "wav" }
        default { "m4a" }  # 汎用コンテナ
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($videoPath)
    $outputAudio = GetSafeOutputPath("$outputDir\$base.$ext")

    $ffmpegArgs = "-y -i `"$videoPath`" -vn -c:a copy `"$outputAudio`""
    Start-Process -FilePath $ffmpeg -ArgumentList $ffmpegArgs -NoNewWindow -Wait

    [System.Windows.Forms.MessageBox]::Show("映像から音声を分離しました: $outputAudio")
    $status.Text = "音声分離完了。"

    if ($openFolderCheck.Checked -and (Test-Path $outputDir)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$outputDir`""
    }

    # 音声ファイル情報の出力
    if ($EnableAudioInfoOutput) {
        WriteAudioInfoToText $outputAudio $videoPath $codec
    }
}



# bitrate判定
function GetBitDepthFromSampleFmt($sampleFmt) {
    if ($codecName -eq "pcm_s24le") { return "24bit" }  #  WAVフォーマットの仕様上、24bitを32bitスロットで格納するのが一般的ため、それの補正用

    switch ($sampleFmt) {
        "s16" { return "16bit" }
        "s24" { return "24bit" }
        "s32" { return "32bit" }
        "flt" { return "32bit float" }
        "dbl" { return "64bit float" }
        default { return $sampleFmt }
    }
}

# フォーマット名判定
function GetFormatNameFromCodec($codec) {
    switch ($codec) {
        "pcm_s16le" { return "WAV" }
        "pcm_s24le" { return "WAV" }
        "pcm_s32le" { return "WAV" }
        "pcm_f32le" { return "WAV" }
        "aac"       { return "AAC" }
        "alac"      { return "ALAC" }
        "mp3"       { return "MP3" }
        "flac"      { return "FLAC" }
        "opus"      { return "Opus" }
        default     { return $codec.ToUpper() }
    }
}





# 音声ファイルの情報を出力
function WriteAudioInfoToText {
    param (
        [string]$audioPath,
        [string]$sourceVideoPath,
        [string]$originalCodec
    )

    $specJson = "$env:TEMP\ffprobe_spec.json"
    $args = "-v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels,sample_fmt -of json `"$audioPath`""
    Start-Process -FilePath $ffprobe -ArgumentList $args -NoNewWindow -Wait -RedirectStandardOutput $specJson

    if (-not (Test-Path $specJson)) {
        Write-Host "ffprobe spec取得失敗"
        return
    }

    $data = Get-Content $specJson -Raw | ConvertFrom-Json
    Remove-Item $specJson -Force

    if (-not $data.streams -or $data.streams.Count -eq 0) {
        Write-Host "ffprobe: streams が取得できませんでした。"
        return
    }

    $stream = $data.streams[0]

    # 出力ファイル名：拡張子なし + .txt
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($audioPath)
    $dirName  = [System.IO.Path]::GetDirectoryName($audioPath)
    $infoPath = "$dirName\$baseName.txt"

    
    $formatName = GetFormatNameFromCodec $stream.codec_name
    $bitDepth   = GetBitDepthFromSampleFmt $stream.sample_fmt
    $channels   = switch ($stream.channels) {
        1 { "Mono" }
        2 { "Stereo" }
        default { "$($stream.channels)ch" }
    }
    $bitrateKbps = if ($stream.bit_rate -match '^\d+$') {
        [math]::Round([double]$stream.bit_rate / 1000)
    } else {
        $stream.bit_rate
    }

    $lines = @(
        "=== Extracted Audio Info ===",
        "Source Video : $sourceVideoPath",
        "Audio File   : $audioPath",
        "",
        "Format       : $formatName $bitDepth",
        "Channels     : $channels",
        "SampleRate   : $($stream.sample_rate) Hz",
        "Bitrate      : $bitrateKbps kbps",
        "Original Codec : $originalCodec"
    )

    Set-Content -Path $infoPath -Value $lines -Encoding UTF8
}

