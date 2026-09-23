$targetDir = "C:\Users\Admin\AndroidStudioProjects\parishserve\lib\features\sacramental_records"
$outputFile = "C:\Users\Admin\AndroidStudioProjects\parishserve\sacramental_records_code.txt"
$projectRoot = "C:\Users\Admin\AndroidStudioProjects\parishserve"

$files = Get-ChildItem -Path $targetDir -Recurse -Filter "*.dart" | Sort-Object FullName

$sb = [System.Text.StringBuilder]::new()

foreach ($file in $files) {
    $relPath = $file.FullName.Replace("$projectRoot\", "").Replace("\", "/")
    [void]$sb.AppendLine("+++++++++++++++++++++++")
    [void]$sb.AppendLine($relPath)
    [void]$sb.AppendLine("+++++++++++++++++++++++")
    [void]$sb.AppendLine("")
    $content = [System.IO.File]::ReadAllText($file.FullName)
    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine("")
}

[System.IO.File]::WriteAllText($outputFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Updated $outputFile with $($files.Count) Dart files."
