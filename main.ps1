
##====================================================================================##
## This program is open-source. You can redistribute and/or modify it under the terms ##
## of the GNU GPL v3 license as published by the Free Software Foundation, either v3  ##
## of the License, or (your option) any later version.                                ##
##                                                                                    ##
## Copyright 2024 © Winux. All rights reserved.                                       ##
##====================================================================================##

# Define constants & a few functions
$Title = "Winux's HashGeek"
$Links = @{VT = "https://virustotal.com/gui/file/" ; Triage = "https://tria.ge/" ; GitHub = "https://github.com/ItsWinuxYT/HashGeek"}

function IsEmpty {param ($String) ; return [string]::IsNullOrEmpty($String)}
function Show-MsgBox {param ($Message, $Options, $Type) ; [System.Windows.MessageBox]::Show($Message, $Title, $Options, $Type)}
function Set-Visibility {param ($Element, $Visibility) ; Get-Variable $Element | ForEach-Object {try {$_.Visibility = [System.Windows.Visibility]::$Visibility} catch {throw}}}
function Get-FormVariables {Write-Host "`nFound the following interactable elements from your form" -ForegroundColor Cyan ; Get-Variable WPF*}

# Loads dependencies & loads the UI's XAML
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
$XAML = Get-Content '.\ui.xaml' #(I put the contents of the XAML here when i compiled it into an EXE)#

# Checks if dark mode is enabled for apps (Current User)
$IsDarkModeEnabled = (Get-ItemProperty Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize).AppsUseLightTheme -eq 0
if ($IsDarkModeEnabled) {$XAML = $XAML -replace '#BackgroundColor','#FF202020' -replace '#ForegroundColor','White'}
else {$XAML = $XAML -replace '#BackgroundColor','White' -replace '#ForegroundColor','Black'}

[xml]$XAML = $XAML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*','<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"'
$Reader = (New-Object System.Xml.XmlNodeReader $XAML)
try {$Form = [Windows.Markup.XamlReader]::Load($Reader)}
catch {
    Write-Warning "We were unable to load the UI's XAML code, with error: $($Error[0]). The error details has been copied to your clipboard.
    `nPlease contact our Discord support for further assistance, and make a bug report if the problem persists." ; Set-Clipboard $Error[0] ; exit
}

# Load XAML Objects in PowerShell
$XAML.SelectNodes("//*[@Name]") | ForEach-Object {try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop} catch {throw}}

# Add Event Handlers
$WPFSelectFile.Add_Click({
    $Global:InputFile = New-Object Windows.Forms.OpenFileDialog
    $Global:InputFile.Filter = 'All files|*.*'
    $Global:InputFile.Multiselect = $false
    [void]$InputFile.ShowDialog()
    Set-Visibility WPFProgBar* -Visibility Visible
    Start-Sleep 1
    try {$WPFInputHash.Text = (Get-FileHash $InputFile.FileName -Algorithm ($WPFHashType.SelectedItem -replace 'System.Windows.Controls.ComboBoxItem: ','')).Hash} catch {}
    Set-Visibility WPFProgBar* -Visibility Hidden
})

$WPFVerifyHash.Add_Click({
    if (IsEmpty $WPFInputHash.Text -or IsEmpty $WPFExpectedHash.Text) {Show-MsgBox "Please enter both an input hash and expected hash." OK -Type Error ; return}
    if ($WPFInputHash.Text.Length -ile 12 -or $WPFExpectedHash.Text.Length -ile 12) {Show-MsgBox "lol did u think thats a valid hash" YesNo -Type Information ; return}
    if ($WPFInputHash.Text -eq $WPFExpectedHash.Text) {
        $Answer = Show-MsgBox "The input file/hash matches the expected hash. Good to go!`nOptionally, you can also search/scan this file on VirusTotal.
                               `nDo you want to open VirusTotal?" YesNo -Type Information
        if ($Answer -eq "Yes") {Start-Process ($Links.VT + $WPFInputHash.Text)}
    } else {
        $Answer = Show-MsgBox "WARNING: The input file/hash doesn't match the expected hash!`n`nThe file might have been unknowingly tampered.
                               `nThis can also happen because of file corruption.`nScan/search this file on VirusTotal?" YesNo -Type Warning
        if ($Answer -eq "Yes") {Start-Process ($Links.VT + $WPFInputHash.Text)}
    }
})

$WPFVT.Add_Click({
    if ((IsEmpty $InputFile.FileName) -and (IsEmpty $WPFInputHash.Text)) {Show-MsgBox "Please enter a hash/select a file." OK -Type Error ; return}
    if ((IsEmpty $InputFile.FileName) -and ($WPFHashType.SelectedItem -notcontains 'SHA256')) {Show-MsgBox "Please enter an SHA256 hash." OK -Type Error ; return}
    if (IsEmpty $WPFInputHash.Text) {
        $WPFInputHash.Text = (Get-FileHash $InputFile.FileName -Algorithm SHA256).Hash
        $WPFHashType.SelectedIndex = 1 ; Remove-Variable $InputFile
    }
    Start-Process ($Links.VT + $WPFInputHash.Text)
})

$WPFTriage.Add_Click({Start-Process $Links.Triage}) ; $WPFGitHub.Add_Click({Start-Process $Links.GitHub})

# Shows the UI
$Form.ShowDialog() | Out-Null