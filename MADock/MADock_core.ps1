# MADock 共通項目関数 スクリプト


$global:configFile = "$PSScriptRoot\config.txt"
$global:ffmpeg = $null	 # ffmpegの実行ファイルパス


# 設定読み込み関数
function Load-Config {
    $config = @{}
    if (Test-Path $global:configFile) {
        Get-Content $global:configFile | ForEach-Object {
            if ($_ -match "^\s*([^=]+)\s*=\s*(.+)\s*$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $config[$key] = $value
            }
        }
    }
    return $config
}

$global:config = Load-Config    # グローバル設定読み込み

# 設定保存関数（必要なキーだけ更新）
function Save-Config {
    param ([hashtable]$updates)
    $config = Load-Config
    foreach ($key in $updates.Keys) {
        $config[$key] = $updates[$key]
    }
    $lines = $config.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -Encoding UTF8 -Path $global:configFile -Value $lines
}

# ffmpeg.exe の存在確認
function Test-FFmpegPath($path) {
    return (Test-Path $path) -and ($path.ToLower().EndsWith("ffmpeg.exe"))
}


# ffmpeg パスの読み込みまたは選択
if ($global:config.ContainsKey("ffmpeg_path") -and (Test-FFmpegPath $global:config["ffmpeg_path"])) {
    $global:ffmpeg = $global:config["ffmpeg_path"]

    # ffprobe.exe を同じフォルダから検出
    $ffprobeCandidate = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($global:ffmpeg), "ffprobe.exe")
    if (Test-Path $ffprobeCandidate) {
        $global:ffprobe = $ffprobeCandidate
    } else {
        $global:ffprobe = $null
        [System.Windows.Forms.MessageBox]::Show("ffprobe.exe が ffmpeg.exe と同じフォルダに見つかりません。ffprobeが必要な処理でエラーになる可能性があります。")
    }


} else {
    [System.Windows.Forms.MessageBox]::Show("このツールを使うには ffmpeg.exe の場所を指定する必要があります。")

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "ffmpeg.exe を選択してください"
    $dialog.Filter = "ffmpeg.exe|ffmpeg.exe"
    $dialog.InitialDirectory = [Environment]::GetFolderPath("ProgramFiles")

    if ($dialog.ShowDialog() -eq "OK" -and (Test-FFmpegPath $dialog.FileName)) {
        $global:ffmpeg = $dialog.FileName
        Save-Config @{ ffmpeg_path = $global:ffmpeg }

        # ffprobe.exe を同じフォルダから検出
        $ffprobeCandidate = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($global:ffmpeg), "ffprobe.exe")
        if (Test-Path $ffprobeCandidate) {
            $global:ffprobe = $ffprobeCandidate
        } else {
            $global:ffprobe = $null
            [System.Windows.Forms.MessageBox]::Show("ffprobe.exe が ffmpeg.exe と同じフォルダに見つかりません。ffprobeが必要な処理でエラーになる可能性があります。")
        }

    } else {
        [System.Windows.Forms.MessageBox]::Show("ffmpeg.exe が選択されなかったため、終了します。")
        exit
    }
}


# 出力ファイル名の重複処理

function GetSafeOutputPath($path) {
    if ($global:config["prevent_overwrite"] -eq "true" -and (Test-Path $path)) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $ext = [System.IO.Path]::GetExtension($path)
        $dir = [System.IO.Path]::GetDirectoryName($path)
        $i = 1
        $style = $global:config["overwrite_suffix_style"]
        do {
            switch ($style) {
                "paren"   { $newPath = "$dir\$base`($i)$ext" }
                default   { $newPath = "$dir\$base`_$i$ext" }
            }
            $i++
        } while (Test-Path $newPath)
        return $newPath
    } else {
        return $path
    }
}

