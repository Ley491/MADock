# MADock GUI スクリプト(MADock_gui.ps1)
# このスクリプトは ffmpeg.exe を用いて任意の映像と音声を結合するツールです。
# config.txt の設定でffmpeg.exe の場所を指定して動作します（GUIから設定可能）。

# ← dot-sourceで別スクリプトの関数を読み込む
. "$PSScriptRoot\MADock_core.ps1"   # 共通関数
. "$PSScriptRoot\MADock_settings.ps1"  # 設定ウインドウ
. "$PSScriptRoot\MADock_utils.ps1"  # コーデック判定処理ロジック
. "$PSScriptRoot\MADock_main.ps1"   # 音声結合処理ロジック
. "$PSScriptRoot\MADock_sub.ps1"  # 音声分離処理ロジック





# UI設定
Add-Type -AssemblyName System.Windows.Forms

$global:video_file = $null
$global:audio_file = $null
$global:last_video_dir = $null
$global:last_audio_dir = $null

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'FixedDialog'	# ウインドウサイズの固定
$form.MaximizeBox = $false	# 最大化ボタン非表示
$form.Text = "MADock"
$form.Size = '440,365'  # 横, 縦（ウインドウの全体サイズ）
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
$settingsButton.Add_Click({
    ShowSettingsWindow -config $config -ffmpeg $ffmpeg
})
$form.Controls.Add($settingsButton)

# 出力形式選択
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "出力形式"
$groupBox.Dock = 'Top'
$groupBox.Height = 60

$radioMP4 = New-Object System.Windows.Forms.RadioButton
$radioMP4.Text = "MP4"
$radioMP4.Location = '20,20'
$radioMP4.Checked = $true

$radioMKV = New-Object System.Windows.Forms.RadioButton
$radioMKV.Text = "MKV"
$radioMKV.Location = '150,20'

$radioMOV = New-Object System.Windows.Forms.RadioButton
$radioMOV.Text = "MOV"
$radioMOV.Location = '280,20'

# $radioBoth = New-Object System.Windows.Forms.RadioButton
# $radioBoth.Text = "MP4 + MKV"
# $radioBoth.Location = '400,20'

$groupBox.Controls.Add($radioMP4)
$groupBox.Controls.Add($radioMKV)
$groupBox.Controls.Add($radioMOV)
# $groupBox.Controls.Add($radioBoth)
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
    # $dialog.Filter = "音声ファイル|*.wav;*.flac;*.m4a;*.alac;*.caf;*.ape;*.wv"  # 入力ファイル対応はここで
    $dialog.Filter = "音声ファイル|*.wav;*.flac;*.m4a;*.alac;*.aac;*.mp3"  # 入力ファイル対応はここで
    # 初期ディレクトリの選択ロジック
    if ($global:last_audio_dir -and (Test-Path $global:last_audio_dir)) {
        $dialog.InitialDirectory = $global:last_audio_dir
    } elseif ($config["audio_open_path"] -and (Test-Path $config["audio_open_path"])) {
        $dialog.InitialDirectory = $config["audio_open_path"]
    } else {
        $dialog.InitialDirectory = $PSScriptRoot
    }

    if ($dialog.ShowDialog() -eq "OK") {
        $global:audio_file = $dialog.FileName
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
    $dialog.Filter = "映像ファイル|*.mp4;*.mkv;*.mov"   # 入力ファイル対応はここで
    # 初期ディレクトリの選択ロジック
    if ($global:last_video_dir -and (Test-Path $global:last_video_dir)) {
        $dialog.InitialDirectory = $global:last_video_dir
    } elseif ($config["video_open_path"] -and (Test-Path $config["video_open_path"])) {
        $dialog.InitialDirectory = $config["video_open_path"]
    } else {
        $dialog.InitialDirectory = $PSScriptRoot
    }

    if ($dialog.ShowDialog() -eq "OK") {
        $global:video_file = $dialog.FileName
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
$label.Text = "ファイルを選択するか、映像・音声ファイルをドラッグしてください"
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




# 出力オプションパネル
$outputOptionsPanel = New-Object System.Windows.Forms.Panel
$outputOptionsPanel.Height = 45 # チェックボックス部のサイズ
$outputOptionsPanel.Dock = 'Bottom'

# 入力ファイルと同じ場所に出力するチェックボックス
$sameFolderCheck = New-Object System.Windows.Forms.CheckBox
$sameFolderCheck.Text = "入力ファイルと同じフォルダに出力する"
$sameFolderCheck.Location = New-Object System.Drawing.Point(10, 2)
$sameFolderCheck.Size = '300,20'
$sameFolderCheck.Checked = $false

# 出力後フォルダを開くチェックボックス
$openFolderCheck = New-Object System.Windows.Forms.CheckBox
$openFolderCheck.Text = "出力完了後にフォルダを開く"
$openFolderCheck.Location = New-Object System.Drawing.Point(10, 24)
$openFolderCheck.Size = '200,20'
$openFolderCheck.Checked = $false   # 初期状態（必要なら true）

# MP4同時出力チェックボックス（初期状態は非表示）
$checkMP4Also = New-Object System.Windows.Forms.CheckBox
$checkMP4Also.Text = "MP4同時出力"
$checkMP4Also.Location = New-Object System.Drawing.Point(220, 24)
$checkMP4Also.Size = '350,20'
$checkMP4Also.Visible = $false
$checkMP4Also.Enabled = $false

# 表示制御（ラジオボタンに連動）
$radioMKV.Add_CheckedChanged({
    $checkMP4Also.Visible = $radioMKV.Checked
    $checkMP4Also.Enabled = $radioMKV.Checked
})
$radioMOV.Add_CheckedChanged({
    $checkMP4Also.Visible = $radioMOV.Checked
    $checkMP4Also.Enabled = $radioMOV.Checked
})
$radioMP4.Add_CheckedChanged({
    $checkMP4Also.Visible = $false
    $checkMP4Also.Enabled = $false
})

# パネルに追加
$outputOptionsPanel.Controls.Add($sameFolderCheck)
$outputOptionsPanel.Controls.Add($openFolderCheck)
$outputOptionsPanel.Controls.Add($checkMP4Also)
$form.Controls.Add($outputOptionsPanel)


# 設定ファイルからUI状態を復元（前回の設定を引き継ぐ）
$sameFolderCheck.Checked = ($global:config["output_to_same_folder"] -eq "true")
$openFolderCheck.Checked = ($global:config["open_folder_after_export"] -eq "true")
$checkMP4Also.Checked    = ($global:config["mp4_also_export"] -eq "true")

switch ($global:config["selected_output_format"]) {
    "mp4"  { $radioMP4.Checked  = $true }
    "mkv"  { $radioMKV.Checked  = $true }
    "mov"  { $radioMOV.Checked  = $true }
}

# ラジオボタン状態に応じて MP4同時出力チェックの表示を更新
if ($radioMKV.Checked -or $radioMOV.Checked) {
    $checkMP4Also.Visible = $true
    $checkMP4Also.Enabled = $true
} else {
    $checkMP4Also.Visible = $false
    $checkMP4Also.Enabled = $false
}


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
    $global:video_file = $null
    $global:audio_file = $null
    $mp4Label.Text = "映像: 未指定"
    $wavLabel.Text = "音声: 未指定"
    $status.Text = "ファイル指定をリセットしました。"
})
$form.Controls.Add($resetButton)

$spacerBelowReset = New-Object System.Windows.Forms.Label
$spacerBelowReset.Height = 8  # お好みで調整可能
$spacerBelowReset.Dock = 'Bottom'
$form.Controls.Add($spacerBelowReset)





# ドラッグ処理
$form.Add_DragEnter({
    if ($_.Data.GetDataPresent("FileDrop")) {
        $_.Effect = "Copy"
    }
})

$form.Add_DragDrop({
    $files = $_.Data.GetData("FileDrop")
    foreach ($file in $files) {
        # if ($file.ToLower().EndsWith(".mp4")) {   # ドラッグで対応する入力形式
        if ($file.ToLower() -match "\.(mp4|mkv|mov)$") {
            $global:video_file = $file
            $global:last_video_dir = [System.IO.Path]::GetDirectoryName($file)
            $mp4Label.Text = "映像: " + [System.IO.Path]::GetFileName($file)
            $status.Text = "映像ファイルを指定しました。"
        # } elseif ($file.ToLower() -match "\.(wav|flac|m4a|alac|caf|ape|wv)$") {   # ドラッグで対応する入力形式
        } elseif ($file.ToLower() -match "\.(wav|flac|m4a|alac|aac|mp3)$") {
            $global:audio_file = $file
            $global:last_audio_dir = [System.IO.Path]::GetDirectoryName($file)
            $wavLabel.Text = "音声: " + [System.IO.Path]::GetFileName($file)
            $status.Text = "音声ファイルを指定しました。"
        }
    }
})

$form.ShowDialog()
