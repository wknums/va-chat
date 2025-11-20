# Script to inject VA Chat Widget into all HTML pages in site directory

$siteDir = Join-Path $PSScriptRoot "..\site"
$widgetCode = @"

<!-- WCG Chat Widget -->
<link rel="stylesheet" href="va-chat-widget.css">
<script src="va-chat-widget.js"></script>
"@

# Get all HTML files that don't already have the widget
$htmlFiles = Get-ChildItem -Path $siteDir -Filter "*.html" | Where-Object {
    $content = Get-Content $_.FullName -Raw
    $content -notmatch "va-chat-widget" -and $content -match "</body>"
}

Write-Host "Found $($htmlFiles.Count) HTML files to update" -ForegroundColor Cyan

foreach ($file in $htmlFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $file.FullName -Raw
    
    # Insert widget code before closing </body> tag
    $updatedContent = $content -replace "</body>", "$widgetCode`r`n</body>"
    
    # Save the file
    Set-Content -Path $file.FullName -Value $updatedContent -NoNewline
    
    Write-Host "  ✓ Updated" -ForegroundColor Green
}

Write-Host "`nComplete! Updated $($htmlFiles.Count) files." -ForegroundColor Green
