#!/usr/bin/env pwsh
# Quick Integration Script for VA Chat Widget
# This script copies the widget files to your website directory

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to your website directory")]
    [string]$WebsiteDir,
    
    [Parameter(Mandatory=$false, HelpMessage="Include search integration (default: true)")]
    [bool]$IncludeSearch = $true
)

$WidgetDir = $PSScriptRoot

Write-Host "🚀 VA Chat Widget Integration Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Validate website directory
if (-not (Test-Path $WebsiteDir)) {
    Write-Host "❌ Error: Website directory not found: $WebsiteDir" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Website Directory: $WebsiteDir" -ForegroundColor Green
Write-Host "📦 Widget Source: $WidgetDir" -ForegroundColor Green
Write-Host ""

# Copy widget files
Write-Host "📋 Copying widget files..." -ForegroundColor Yellow

try {
    # Copy CSS
    Copy-Item "$WidgetDir\va-chat-widget.css" -Destination "$WebsiteDir\va-chat-widget.css" -Force
    Write-Host "  ✓ va-chat-widget.css" -ForegroundColor Green
    
    # Copy JS
    Copy-Item "$WidgetDir\va-chat-widget.js" -Destination "$WebsiteDir\va-chat-widget.js" -Force
    Write-Host "  ✓ va-chat-widget.js" -ForegroundColor Green
    
    # Copy search integration if requested
    if ($IncludeSearch) {
        Copy-Item "$WidgetDir\va-search-integration.js" -Destination "$WebsiteDir\va-search-integration.js" -Force
        Write-Host "  ✓ va-search-integration.js" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "✅ Widget files copied successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Display integration instructions
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Add to your HTML <head> section:" -ForegroundColor Yellow
    Write-Host "   <link rel=`"stylesheet`" href=`"va-chat-widget.css`">" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Add before closing </body> tag:" -ForegroundColor Yellow
    Write-Host "   <script src=`"va-chat-widget.js`"></script>" -ForegroundColor White
    
    if ($IncludeSearch) {
        Write-Host "   <script src=`"va-search-integration.js`"></script>" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "3. (Optional) Configure API endpoint:" -ForegroundColor Yellow
    Write-Host "   <script>" -ForegroundColor White
    Write-Host "     window.VAChatWidget.apiBaseUrl = 'https://your-api.com';" -ForegroundColor White
    Write-Host "   </script>" -ForegroundColor White
    Write-Host ""
    Write-Host "📖 See INTEGRATION-GUIDE.md for detailed instructions" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "❌ Error copying files: $_" -ForegroundColor Red
    exit 1
}
