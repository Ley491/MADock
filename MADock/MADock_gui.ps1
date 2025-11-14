# MADock GUI スクリプト
# このスクリプトは ffmpeg.exe を用いて任意の映像と音声を結合するツールです。
# config.txt の設定でffmpeg.exe の場所を指定して動作します（GUIから設定可能）。

Add-Type -AssemblyName System.Windows.Forms

$configFile = "$PSScriptRoot\config.txt"
$ffmpeg = $null	 # ffmpegの実行ファイルパス

# 設定読み込み関数
function Load-Config {
    $config = @{}
    if (Test-Path $configFile) {
        Get-Content $configFile | ForEach-Object {
            if ($_ -match "^\s*([^=]+)\s*=\s*(.+)\s*$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $config[$key] = $value
            }
        }
    }
    return $config
}

# 設定保存関数（必要なキーだけ更新）
function Save-Config {
    param ([hashtable]$updates)
    $config = Load-Config
    foreach ($key in $updates.Keys) {
        $config[$key] = $updates[$key]
    }
    $lines = $config.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -Encoding UTF8 -Path $configFile -Value $lines
}

# ffmpeg.exe の存在確認
function Test-FFmpegPath($path) {
    return (Test-Path $path) -and ($path.ToLower().EndsWith("ffmpeg.exe"))
}

# ffmpeg パスの読み込みまたは選択
$config = Load-Config
if ($config.ContainsKey("ffmpeg_path") -and (Test-FFmpegPath $config["ffmpeg_path"])) {
    $ffmpeg = $config["ffmpeg_path"]
} else {
    [System.Windows.Forms.MessageBox]::Show("このツールを使うには ffmpeg.exe の場所を指定する必要があります。")

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "ffmpeg.exe を選択してください"
    $dialog.Filter = "ffmpeg.exe|ffmpeg.exe"
    $dialog.InitialDirectory = [Environment]::GetFolderPath("ProgramFiles")
    if ($dialog.ShowDialog() -eq "OK" -and (Test-FFmpegPath $dialog.FileName)) {
        $ffmpeg = $dialog.FileName
        Save-Config @{ ffmpeg_path = $ffmpeg }
    } else {
        [System.Windows.Forms.MessageBox]::Show("ffmpeg.exe が選択されなかったため、終了します。")
        exit
    }
}


# UI設定

$global:mp4_file = $null
$global:wav_file = $null
$global:last_video_dir = $null
$global:last_audio_dir = $null

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'FixedDialog'	# ウインドウサイズの固定
$form.MaximizeBox = $false	# 最大化ボタン非表示
$form.Text = "MADock"
$form.Size = '440,340'
$form.StartPosition = 'CenterScreen'
$form.AllowDrop = $true

# ToolTipインスタンスを作成
$tooltip = New-Object System.Windows.Forms.ToolTip


# 設定ウインドウを開くボタン
$settingsButton = New-Object System.Windows.Forms.Button
$settingsButton.FlatStyle = 'Flat'
$settingsButton.FlatAppearance.BorderSize = 0
$settingsButton.Text = "⚙"
$settingsButton.Size = '20,20'
$settingsButton.Location = New-Object System.Drawing.Point(400, 10)  # ← ここを固定値に
$tooltip.SetToolTip($settingsButton, "設定を開く")
$settingsButton.Add_Click({ ShowSettingsWindow })
$form.Controls.Add($settingsButton)

# 出力形式選択
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "出力形式"
$groupBox.Dock = 'Top'
$groupBox.Height = 60

$radioMP4 = New-Object System.Windows.Forms.RadioButton
$radioMP4.Text = "MP4 のみ"
$radioMP4.Location = '20,20'
$radioMP4.Checked = $true

$radioMKV = New-Object System.Windows.Forms.RadioButton
$radioMKV.Text = "MKV のみ"
$radioMKV.Location = '150,20'

$radioBoth = New-Object System.Windows.Forms.RadioButton
$radioBoth.Text = "MP4 + MKV"
$radioBoth.Location = '280,20'

$groupBox.Controls.Add($radioMP4)
$groupBox.Controls.Add($radioMKV)
$groupBox.Controls.Add($radioBoth)
$form.Controls.Add($groupBox)


# 隙間（空白ラベル）
$spacerBelowSeparator = New-Object System.Windows.Forms.Label
$spacerBelowSeparator.Height = 10  # 適宜調整可能
$spacerBelowSeparator.Dock = 'Top'
$form.Controls.Add($spacerBelowSeparator)


# 音声ファイル選択パネル
$wavPanel = New-Object System.Windows.Forms.Panel
$wavPanel.Height = 32
$wavPanel.Dock = 'Top'

$wavLabel = New-Object System.Windows.Forms.Label
$wavLabel.Text = "音声: 未指定"
$wavLabel.AutoSize = $false
$wavLabel.Width = 340
$wavLabel.Height = 32
$wavLabel.TextAlign = 'MiddleLeft'

$audioSelectButton = New-Object System.Windows.Forms.Button
$audioSelectButton.Text = "ファイル選択"
$audioSelectButton.Size = '80,24'
$audioSelectButton.Location = New-Object System.Drawing.Point(340, 4)
$tooltip.SetToolTip($audioSelectButton, "音声ファイルを選択")

$audioSelectButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "音声ファイルを選択してください"
    $dialog.Filter = "音声ファイル|*.wav;*.flac;*.m4a;*.alac;*.caf;*.ape;*.wv"
    # 初期ディレクトリの選択ロジック
    if ($global:last_audio_dir -and (Test-Path $global:last_audio_dir)) {
        $dialog.InitialDirectory = $global:last_audio_dir
    } elseif ($config["audio_open_path"] -and (Test-Path $config["audio_open_path"])) {
        $dialog.InitialDirectory = $config["audio_open_path"]
    } else {
        $dialog.InitialDirectory = $PSScriptRoot
    }

    if ($dialog.ShowDialog() -eq "OK") {
        $global:wav_file = $dialog.FileName
        $global:last_audio_dir = [System.IO.Path]::GetDirectoryName($dialog.FileName)
        $wavLabel.Text = "音声: " + [System.IO.Path]::GetFileName($dialog.FileName)
        $status.Text = "音声ファイルを指定しました。"
    }
})


$wavPanel.Controls.Add($wavLabel)
$wavPanel.Controls.Add($audioSelectButton)
$form.Controls.Add($wavPanel)


# 映像ファイル選択パネル
$mp4Panel = New-Object System.Windows.Forms.Panel
$mp4Panel.Height = 32
$mp4Panel.Dock = 'Top'

$mp4Label = New-Object System.Windows.Forms.Label
$mp4Label.Text = "映像: 未指定"
$mp4Label.AutoSize = $false
$mp4Label.Width = 340
$mp4Label.Height = 32
$mp4Label.TextAlign = 'MiddleLeft'

$videoSelectButton = New-Object System.Windows.Forms.Button
$videoSelectButton.Text = "ファイル選択"
$videoSelectButton.Size = '80,24'
$videoSelectButton.Location = New-Object System.Drawing.Point(340, 4)
$tooltip.SetToolTip($videoSelectButton, "映像ファイルを選択")

$videoSelectButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "映像ファイルを選択してください"
    $dialog.Filter = "MP4ファイル|*.mp4"
    # 初期ディレクトリの選択ロジック
    if ($global:last_video_dir -and (Test-Path $global:last_video_dir)) {
        $dialog.InitialDirectory = $global:last_video_dir
    } elseif ($config["video_open_path"] -and (Test-Path $config["video_open_path"])) {
        $dialog.InitialDirectory = $config["video_open_path"]
    } else {
        $dialog.InitialDirectory = $PSScriptRoot
    }

    if ($dialog.ShowDialog() -eq "OK") {
        $global:mp4_file = $dialog.FileName
        $global:last_video_dir = [System.IO.Path]::GetDirectoryName($dialog.FileName)
        $mp4Label.Text = "映像: " + [System.IO.Path]::GetFileName($dialog.FileName)
        $status.Text = "映像ファイルを指定しました。"
    }
})


$mp4Panel.Controls.Add($mp4Label)
$mp4Panel.Controls.Add($videoSelectButton)
$form.Controls.Add($mp4Panel)

# 隙間（空白ラベル）
$spacerBelowSeparator = New-Object System.Windows.Forms.Label
$spacerBelowSeparator.Height = 8  # 適宜調整可能
$spacerBelowSeparator.Dock = 'Top'
$form.Controls.Add($spacerBelowSeparator)



# ドラッグ案内の下に仕切り線（先に追加）
$separator = New-Object System.Windows.Forms.Panel
$separator.Height = 2
$separator.Dock = 'Top'
$separator.BackColor = [System.Drawing.Color]::DarkGray
$form.Controls.Add($separator)


# ドロップ案内
$label = New-Object System.Windows.Forms.Label
$label.Text = "ファイルを選択するか、mp4 と 音声ファイルをドラッグしてください"
$label.Dock = 'Top'
$label.Height = 40
$label.TextAlign = 'MiddleCenter'
$form.Controls.Add($label)


# ステータス表示
$status = New-Object System.Windows.Forms.Label
$status.Text = ""
$status.Dock = 'Bottom'
$status.Height = 40
$status.TextAlign = 'MiddleCenter'
$form.Controls.Add($status)


# 出力完了後にフォルダを開く
$openFolderCheck = New-Object System.Windows.Forms.CheckBox
$openFolderCheck.Text = "出力完了後にフォルダを開く"
$openFolderCheck.Dock = 'Bottom'
$openFolderCheck.Height = 20
$openFolderCheck.Checked = $false  # 初期状態（必要なら true）
$form.Controls.Add($openFolderCheck)

$spacerAboveRunButton = New-Object System.Windows.Forms.Label
$spacerAboveRunButton.Height = 10
$spacerAboveRunButton.Dock = 'Bottom'
$form.Controls.Add($spacerAboveRunButton)

# 実行ボタン
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "実行"
$runButton.Dock = 'Bottom'
$runButton.Height = 30
$runButton.Add_Click({ TryProcess })
$form.Controls.Add($runButton)

# 実行ボタンとリセットボタンの間に隙間
$spacer = New-Object System.Windows.Forms.Label
$spacer.Height = 8
$spacer.Dock = 'Bottom'
$form.Controls.Add($spacer)

# リセットボタン
$resetButton = New-Object System.Windows.Forms.Button
$resetButton.Text = "リセット"
$resetButton.Dock = 'Bottom'
$resetButton.Height = 30
$resetButton.Add_Click({
    $global:mp4_file = $null
    $global:wav_file = $null
    $mp4Label.Text = "映像: 未指定"
    $wavLabel.Text = "音声: 未指定"
    $status.Text = "ファイル指定をリセットしました。"
})
$form.Controls.Add($resetButton)

$spacerBelowReset = New-Object System.Windows.Forms.Label
$spacerBelowReset.Height = 8  # お好みで調整可能
$spacerBelowReset.Dock = 'Bottom'
$form.Controls.Add($spacerBelowReset)

# 設定ウインドウ関数
function ShowSettingsWindow {
    $script:config = Load-Config	# 設定ファイルの読み込み
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.FormBorderStyle = 'FixedDialog'
    $settingsForm.MaximizeBox = $false
    $settingsForm.Text = "MADock設定"
    $settingsForm.Size = '500,400'
    $settingsForm.StartPosition = 'CenterParent'

    $settingsForm.Controls.Add($styleGroup)

    # ffmpegパス
    $ffmpegLabel = New-Object System.Windows.Forms.Label
    $ffmpegLabel.Text = "ffmpeg パス:"
    $ffmpegLabel.Location = '10,20'
    $ffmpegLabel.Size = '90,20'

    $ffmpegPathBox = New-Object System.Windows.Forms.TextBox
    $ffmpegPathBox.Text = $ffmpeg
    $ffmpegPathBox.Location = '100,20'
    $ffmpegPathBox.Size = '300,20'

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = "参照"
    $browseButton.Location = '410,20'
    $browseButton.Size = '65,20'
    $browseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "ffmpeg.exe を選択してください"
        $dialog.Filter = "ffmpeg.exe|ffmpeg.exe"
        if ($ffmpegPathBox.Text -and (Test-Path $ffmpegPathBox.Text)) {
            $dialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($ffmpegPathBox.Text)
        }
        if ($dialog.ShowDialog() -eq "OK") {
            $ffmpegPathBox.Text = $dialog.FileName
        }
    })

    # 映像初期パス
    $videoPathLabel = New-Object System.Windows.Forms.Label
    $videoPathLabel.Text = "映像初期パス:"
    $videoPathLabel.Location = '10,60'
    $videoPathLabel.Size = '90,20'

    $videoPathBox = New-Object System.Windows.Forms.TextBox
    $videoPathBox.Text = $config["video_open_path"]
    $videoPathBox.Location = '100,60'
    $videoPathBox.Size = '300,20'

    $videoBrowseButton = New-Object System.Windows.Forms.Button
    $videoBrowseButton.Text = "設定"
    $videoBrowseButton.Location = '410,60'
    $videoBrowseButton.Size = '65,20'
    $videoBrowseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($videoPathBox.Text -and (Test-Path $videoPathBox.Text)) {
            $dialog.SelectedPath = $videoPathBox.Text
        }
        if ($dialog.ShowDialog() -eq "OK") {
            $videoPathBox.Text = $dialog.SelectedPath
        }
    })

    # 音声初期パス
    $audioPathLabel = New-Object System.Windows.Forms.Label
    $audioPathLabel.Text = "音声初期パス:"
    $audioPathLabel.Location = '10,90'
    $audioPathLabel.Size = '90,20'

    $audioPathBox = New-Object System.Windows.Forms.TextBox
    $audioPathBox.Text = $config["audio_open_path"]
    $audioPathBox.Location = '100,90'
    $audioPathBox.Size = '300,20'

    $audioBrowseButton = New-Object System.Windows.Forms.Button
    $audioBrowseButton.Text = "設定"
    $audioBrowseButton.Location = '410,90'
    $audioBrowseButton.Size = '65,20'
    $audioBrowseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($audioPathBox.Text -and (Test-Path $audioPathBox.Text)) {
            $dialog.SelectedPath = $audioPathBox.Text
        }
        if ($dialog.ShowDialog() -eq "OK") {
            $audioPathBox.Text = $dialog.SelectedPath
        }
    })

    # 出力先フォルダパス
    $outputPathLabel = New-Object System.Windows.Forms.Label
    $outputPathLabel.Text = "出力先フォルダ:"
    $outputPathLabel.Location = '10,120'
    $outputPathLabel.Size = '90,20'

    $outputPathBox = New-Object System.Windows.Forms.TextBox
    $outputPathBox.Text = $config["output_path"]
    $outputPathBox.Location = '100,120'
    $outputPathBox.Size = '300,20'

    $outputBrowseButton = New-Object System.Windows.Forms.Button
    $outputBrowseButton.Text = "設定"
    $outputBrowseButton.Location = '410,120'
    $outputBrowseButton.Size = '65,20'
    $outputBrowseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($outputPathBox.Text -and (Test-Path $outputPathBox.Text)) {
            $dialog.SelectedPath = $outputPathBox.Text
        }
        if ($dialog.ShowDialog() -eq "OK") {
            $outputPathBox.Text = $dialog.SelectedPath
        }
    })


    # 接尾辞の使用チェック
    $suffixCheck = New-Object System.Windows.Forms.CheckBox
    $suffixCheck.Text = "保存ファイル名を変更する"
    $suffixCheck.Location = '10,150'
    $suffixCheck.Size = '480,20'
    $suffixCheck.Checked = ($config["use_suffix"] -eq "dock")


    # 上書き防止チェック
    $overwriteCheck = New-Object System.Windows.Forms.CheckBox
    $overwriteCheck.Text = "出力ファイルの上書きを防止する（重複時は自動ナンバリング）"
    $overwriteCheck.Location = '10,180'
    $overwriteCheck.Size = '480,20'
    $overwriteCheck.Checked = $config["prevent_overwrite"] -eq "true"

    # ナンバリング形式選択
    $styleGroup = New-Object System.Windows.Forms.GroupBox
    $styleGroup.Text = "ナンバリング形式"
    $styleGroup.Location = '10,210'
    $styleGroup.Size = '470,50'

    $radioUnderscore = New-Object System.Windows.Forms.RadioButton
    $radioUnderscore.Text = "_1 形式"
    $radioUnderscore.Location = '20,20'
    $radioUnderscore.Checked = ($config["overwrite_suffix_style"] -eq "underscore")

    $radioParen = New-Object System.Windows.Forms.RadioButton
    $radioParen.Text = "(1) 形式"
    $radioParen.Location = '150,20'
    $radioParen.Checked = ($config["overwrite_suffix_style"] -eq "paren")

    $styleGroup.Controls.Add($radioUnderscore)
    $styleGroup.Controls.Add($radioParen)

    # 長さ不一致時の処理切り替え
    $trimCheck = New-Object System.Windows.Forms.CheckBox
    $trimCheck.Text = "映像と音声の長さが違う場合、短い方に合わせる（-shortest）"
    $trimCheck.Location = '10,270'
    $trimCheck.Size = '480,20'
    $trimCheck.Checked = ($config["duration_mode"] -eq "trim")

    # 保存ボタン
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "保存"
    $saveButton.Location = '395,320'
    $saveButton.Size = '80,30'
    $saveButton.Add_Click({
        $ffmpegPath = $ffmpegPathBox.Text

        # null または空文字チェック
        if ([string]::IsNullOrWhiteSpace($ffmpegPath)) {
            [System.Windows.Forms.MessageBox]::Show("ffmpeg.exe のパスが未指定です。保存できません。")
            return
        }

        # ToLower() を呼ぶ前に null でないことを保証したので安全
        if (-not $ffmpegPath.ToLower().EndsWith("ffmpeg.exe") -or -not (Test-Path $ffmpegPath)) {
            [System.Windows.Forms.MessageBox]::Show("指定されたパスが存在しないか、ffmpeg.exe ではありません。")
            return
        }


        $updates = @{
            ffmpeg_path       = $ffmpegPathBox.Text
            video_open_path   = $videoPathBox.Text
            audio_open_path   = $audioPathBox.Text
            output_path       = $outputPathBox.Text
            use_suffix = if ($suffixCheck.Checked) { "dock" } else { "none" }
            prevent_overwrite = $overwriteCheck.Checked.ToString().ToLower()
            overwrite_suffix_style  = if ($radioParen.Checked) { "paren" } else { "underscore" }
            duration_mode           = if ($trimCheck.Checked) { "trim" } else { "none" }
        }
        Save-Config $updates
        $script:config = Load-Config	# 設定ファイルの再読み込み
        $ffmpeg = $updates["ffmpeg_path"]
        [System.Windows.Forms.MessageBox]::Show("設定を保存しました。")
        $settingsForm.Close()
    })


    # コントロール追加
    $settingsForm.Controls.AddRange(@(
        $ffmpegLabel, $ffmpegPathBox, $browseButton,
        $videoPathLabel, $videoPathBox, $videoBrowseButton,
        $audioPathLabel, $audioPathBox, $audioBrowseButton,
        $outputPathLabel, $outputPathBox, $outputBrowseButton,
        $suffixCheck, $overwriteCheck, 
        $styleGroup,
        $trimCheck,
        $saveStatusLabel, $saveButton
    ))

    $settingsForm.ShowDialog()
}


# 処理関数（Start-Process構造）
function TryProcess {
    if ($global:mp4_file -and $global:wav_file) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($global:mp4_file)

        # 出力先パスのセーフティ処理
        $outputPath = $config["output_path"]
        if ([string]::IsNullOrWhiteSpace($outputPath) -or -not (Test-Path $outputPath)) {
            $outputPath = $PSScriptRoot
        }

        if ($radioMP4.Checked -or $radioBoth.Checked) {
            $suffix = if ($config["use_suffix"] -eq "dock") { "_dock" } else { "" }
            $outputMP4 = GetSafeOutputPath("$outputPath\$base$suffix.mp4")
            # $outputMP4 = GetSafeOutputPath("$outputPath\$base`_dock.mp4")
            $durationOption = if ($config["duration_mode"] -eq "trim") { "-shortest" } else { "" }
            $argsMP4 = "-i `"$global:mp4_file`" -i `"$global:wav_file`" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 512k $durationOption `"$outputMP4`""
            # $argsMP4 = "-i `"$global:mp4_file`" -i `"$global:wav_file`" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 512k `"$outputMP4`""
            try {
                Start-Process -FilePath $ffmpeg -ArgumentList $argsMP4 -NoNewWindow -Wait
                [System.Windows.Forms.MessageBox]::Show("MP4処理完了: $outputMP4")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("MP4処理中にエラー:\n$($_.Exception.Message)")
            }
        }

        if ($radioMKV.Checked -or $radioBoth.Checked) {
            $suffix = if ($config["use_suffix"] -eq "dock") { "_dock" } else { "" }
            $outputMKV = GetSafeOutputPath("$outputPath\$base$suffix.mkv")
            $durationOption = if ($config["duration_mode"] -eq "trim") { "-shortest" } else { "" }
            $argsMKV = "-i `"$global:mp4_file`" -i `"$global:wav_file`" -map 0:v -map 1:a -c:v copy -c:a copy $durationOption `"$outputMKV`""
            try {
                Start-Process -FilePath $ffmpeg -ArgumentList $argsMKV -NoNewWindow -Wait
                [System.Windows.Forms.MessageBox]::Show("MKV処理完了: $outputMKV")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("MKV処理中にエラー:\n$($_.Exception.Message)")
            }
        }

        $status.Text = "処理完了。ファイルを確認してください。"
        if ($openFolderCheck.Checked -and (Test-Path $outputPath)) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$outputPath`""
        }

    } else {
        [System.Windows.Forms.MessageBox]::Show("映像と音声ファイルを両方指定してください。")
    }
}

# 出力ファイル名の重複処理
function GetSafeOutputPath($path) {
    if ($script:config["prevent_overwrite"] -eq "true" -and (Test-Path $path)) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $ext = [System.IO.Path]::GetExtension($path)
        $dir = [System.IO.Path]::GetDirectoryName($path)
        $i = 1
        $style = $script:config["overwrite_suffix_style"]
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


# ドラッグ処理
$form.Add_DragEnter({
    if ($_.Data.GetDataPresent("FileDrop")) {
        $_.Effect = "Copy"
    }
})

$form.Add_DragDrop({
    $files = $_.Data.GetData("FileDrop")
    foreach ($file in $files) {
        if ($file.ToLower().EndsWith(".mp4")) {
            $global:mp4_file = $file
            $global:last_video_dir = [System.IO.Path]::GetDirectoryName($file)
            $mp4Label.Text = "映像: " + [System.IO.Path]::GetFileName($file)
            $status.Text = "映像ファイルを指定しました。"
        } elseif ($file.ToLower() -match "\.(wav|flac|m4a|alac|caf|ape|wv)$") {
            $global:wav_file = $file
            $global:last_audio_dir = [System.IO.Path]::GetDirectoryName($file)
            $wavLabel.Text = "音声: " + [System.IO.Path]::GetFileName($file)
            $status.Text = "音声ファイルを指定しました。"
        }
    }
})

$form.ShowDialog()