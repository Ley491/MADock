# MADock 処理関数ロジック スクリプト(MADock_main.ps1)

# 音声ファイル変換（FLAC→WAV変換）
function ConvertFlacToWav($inputPath, $baseName) {
    $codecName = GetAudioCodecName $inputPath
    if ($codecName -ne "flac") { return $inputPath }

    $specs = GetAudioSpecs $inputPath
    $sampleRate = $specs.sample_rate
    $channels   = $specs.channels
    $sampleFmt  = $specs.sample_fmt

    $pcmCodec = switch ($sampleFmt) {
        "s16" { "pcm_s16le" }
        "s24" { "pcm_s24le" }
        "s32" { "pcm_s32le" }
        "flt" { "pcm_f32le" }
        default { "pcm_s16le" }
    }

    $tempWav = "$env:TEMP\$baseName`_converted.wav"
    $ffmpegArgs = "-y -i `"$inputPath`" -ar $sampleRate -ac $channels -c:a $pcmCodec -f wav `"$tempWav`""
    Start-Process -FilePath $ffmpeg -ArgumentList $ffmpegArgs -NoNewWindow -Wait
    return $tempWav
}



# 処理関数（Start-Process構造）
# MP4出力
function ProcessMP4($base, $outputPath) {

    if (-not (AssertVideoCodecSupported "mp4" $global:video_file)) {
        return $false
    }   # 入力映像映像形式対応チェック

    $suffix = if ($config["use_suffix"] -eq "dock") { "_dock" } else { "" }
    $outputMP4 = GetSafeOutputPath("$outputPath\$base$suffix.mp4")
    $durationOption = if ($config["duration_mode"] -eq "trim") { "-shortest" } else { "" }

    $codecName = GetAudioCodecName $global:audio_file
    $specs = GetAudioSpecs $global:audio_file
    $sample_fmt = $specs.sample_fmt
    $samplerate = $specs.sample_rate
    $channels = $specs.channels

    $audioInput = $global:audio_file
    $audioCodec = "copy"

    if ($codecName -notin @("aac", "alac")) {
        $useAlac = $false

        if ($sample_fmt -in @("s24", "s32", "flt")) {
            $msg = "この音声は24bitまたは32bit floatです。ALAC(Yes)の場合は24bitに変換します。AAC(No)の場合は16bitに変換します。"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg, "ALACで出力しますか？",
                [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) { return $false }
            $useAlac = ($result -eq [System.Windows.Forms.DialogResult]::Yes)
        }

        $targetCodec = if ($useAlac) { "alac" } else { "aac" }
        $tempAudio = "$env:TEMP\$base`_encoded.m4a"

        Start-Process -FilePath $ffmpeg -ArgumentList "-y -i `"$global:audio_file`" -c:a $targetCodec `"$tempAudio`"" -NoNewWindow -Wait

        $audioInput = $tempAudio
        $audioCodec = "copy"
    }

    $bitrate = switch ($sample_fmt) {
        "s16" { "192k" }
        "s24" { "384k" }
        "s32" { "384k" }
        "flt" { "512k" }
        default { "256k" }
    }

    $argsMP4 = "-y -i `"$global:video_file`" -i `"$audioInput`" -map 0:v:0 -map 1:a:0 -c:v copy -c:a $audioCodec -b:a $bitrate -ar $samplerate -ac $channels $durationOption `"$outputMP4`""
    Start-Process -FilePath $ffmpeg -ArgumentList $argsMP4 -NoNewWindow -Wait

    [System.Windows.Forms.MessageBox]::Show("MP4処理完了: $outputMP4")
    return $true
}

# MKV出力
function ProcessMKV($base, $outputPath) {
    if (-not (AssertVideoCodecSupported "mkv" $global:video_file)) { return $false }   # 入力映像映像形式対応チェック

    $suffix = if ($config["use_suffix"] -eq "dock") { "_dock" } else { "" }
    $outputMKV = GetSafeOutputPath("$outputPath\$base$suffix.mkv")
    $durationOption = if ($config["duration_mode"] -eq "trim") { "-shortest" } else { "" }

    $codecName = GetAudioCodecName $global:audio_file
    $audioExt = [System.IO.Path]::GetExtension($global:audio_file).ToLower().TrimStart(".")

    if (IsCodecSupported "mkv" $codecName $audioExt) {
        $finalAudio = $global:audio_file
    } else {
        [System.Windows.Forms.MessageBox]::Show("MKV出力はこの音声コーデックに対応していません。")
        return $false
    }

    $argsMKV = "-y -i `"$global:video_file`" -i `"$finalAudio`" -map 0:v -map 1:a -c:v copy -c:a copy $durationOption `"$outputMKV`""
    Start-Process -FilePath $ffmpeg -ArgumentList $argsMKV -NoNewWindow -Wait
    [System.Windows.Forms.MessageBox]::Show("MKV処理完了: $outputMKV")
    
    return $true
}


# MOV出力
function ProcessMOV($base, $outputPath) {
    if (-not (AssertVideoCodecSupported "mov" $global:video_file)) { return $false }  # 入力映像映像形式対応チェック

    $suffix = if ($config["use_suffix"] -eq "dock") { "_dock" } else { "" }
    $outputMOV = GetSafeOutputPath("$outputPath\$base$suffix.mov")
    $durationOption = if ($config["duration_mode"] -eq "trim") { "-shortest" } else { "" }

    $codecName = GetAudioCodecName $global:audio_file
    $audioExt = [System.IO.Path]::GetExtension($global:audio_file).ToLower().TrimStart(".")

    if (IsCodecSupported "mov" $codecName $audioExt) {
        $finalAudio = $global:audio_file
    } elseif ($codecName -eq "flac") {
        $finalAudio = ConvertFlacToWav $global:audio_file $base
    } else {
        [System.Windows.Forms.MessageBox]::Show("MOV出力は WAV / AAC / ALAC / MP3 / FLAC のみ対応しています。")
        return $false
    }

    $specs = GetAudioSpecs $finalAudio
    $samplerate = $specs.sample_rate
    $channels = $specs.channels

    $argsMOV = "-y -i `"$global:video_file`" -i `"$finalAudio`" -map 0:v -map 1:a -c:v copy -c:a copy -ar $samplerate -ac $channels $durationOption `"$outputMOV`""
    Start-Process -FilePath $ffmpeg -ArgumentList $argsMOV -NoNewWindow -Wait
    [System.Windows.Forms.MessageBox]::Show("MOV処理完了: $outputMOV")
    
    return $true
}



# 処理分岐
function TryProcess {
    # mp4, mkv, mov 以外の入力音声ファイルを自動キャンセル
    $ext = [System.IO.Path]::GetExtension($global:video_file).ToLower().TrimStart(".")
    if ($ext -notin @("mp4", "mkv", "mov")) {
        [System.Windows.Forms.MessageBox]::Show("対応していない映像形式です。")
        return
    }

    # 映像・音声ファイルが揃っている時
    if ($global:video_file -and $global:audio_file) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($global:video_file)

        # 出力先パスのセーフティ処理
        $outputPath = if ($sameFolderCheck.Checked -and $global:video_file) {
            [System.IO.Path]::GetDirectoryName($global:video_file)
        } elseif ([string]::IsNullOrWhiteSpace($config["output_path"]) -or -not (Test-Path $config["output_path"])) {
            $PSScriptRoot
        } else {
            $config["output_path"]
        }

        $mp4Success = $false
        $movSuccess = $false
        $mkvSuccess = $false

        if ($radioMP4.Checked -or $checkMP4Also.Checked) {
            $mp4Success = ProcessMP4 $base $outputPath
        }   # MP4
        if ($radioMKV.Checked) {
            $mkvSuccess = ProcessMKV $base $outputPath
        }   # MKV
        if ($radioMOV.Checked) {
            $movSuccess = ProcessMOV $base $outputPath
        }   # MOV

        if (-not ($mp4Success -or $mkvSuccess -or $movSuccess)) {
            $status.Text = "出力できる形式がありませんでした。"
            return
        }

        # 共通処理
        $status.Text = "処理完了。ファイルを確認してください。"
        if ($openFolderCheck.Checked -and (Test-Path $outputPath)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$outputPath`""
        }

        # 実行時のUI状態を config.txt に保存
        $selectedFormat = if ($radioMP4.Checked) {
            "mp4"
        } elseif ($radioMKV.Checked) {
            "mkv"
        } elseif ($radioMOV.Checked) {
            "mov"
        } else {
            ""
        }

        Save-Config @{
            open_folder_after_export = $openFolderCheck.Checked.ToString().ToLower()
            output_to_same_folder    = $sameFolderCheck.Checked.ToString().ToLower()
            mp4_also_export          = $checkMP4Also.Checked.ToString().ToLower()
            selected_output_format   = $selectedFormat
        }

        # 一時ファイル削除
        $tempWav    = "$env:TEMP\$base`_converted.wav"
        $tempAlac   = "$env:TEMP\$base`_alac.m4a"
        $tempEncoded = "$env:TEMP\$base`_encoded.m4a"

        foreach ($tempFile in @($tempWav, $tempAlac, $tempEncoded)) {
            if ((Test-Path $tempFile) -and ($tempFile -ne $global:audio_file)) {
                try {
                    Remove-Item $tempFile -Force
                } catch {
                    Write-Host "一時ファイル削除失敗: $($_.Exception.Message)"
                }
            }
        }

    # 映像ファイルのみの時
    } elseif ($global:video_file -and -not $global:audio_file) {
        $outputPath = if ($sameFolderCheck.Checked -and $global:video_file) {
            [System.IO.Path]::GetDirectoryName($global:video_file)
        } elseif ([string]::IsNullOrWhiteSpace($config["output_path"]) -or -not (Test-Path $config["output_path"])) {
            $PSScriptRoot
        } else {
            $config["output_path"]
        }

        ExtractAudioFromVideo $global:video_file $outputPath

    # 音声ファイルのみ or 何も指定されていない時
    } else {
        [System.Windows.Forms.MessageBox]::Show("映像と音声ファイルを両方指定してください。")
    }
}

