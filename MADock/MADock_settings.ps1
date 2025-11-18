# MADock 設定ウインドウGUI スクリプト(MADock_setings.ps1)

# ← dot-sourceで別スクリプトの関数を読み込む
. "$PSScriptRoot\MADock_core.ps1"   # 共通関数

Add-Type -AssemblyName System.Windows.Forms

function ShowSettingsWindow {
    param (
        [hashtable]$config,
        [string]$ffmpeg
    )

    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.FormBorderStyle = 'FixedDialog'
    $settingsForm.MaximizeBox = $false
    $settingsForm.Text = "MADock設定"
    $settingsForm.Size = '500,400'
    $settingsForm.StartPosition = 'CenterParent'

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
        $saveButton
    ))

    $settingsForm.ShowDialog()
}
