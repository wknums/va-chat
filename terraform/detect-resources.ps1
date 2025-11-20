# Detect existing Azure resources and update terraform.tfvars flags
# This script queries Azure to determine which resources exist and updates the creation flags

param(
    [string]$ResourceGroup = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== Azure Resource Detection for Terraform ===" -ForegroundColor Cyan
Write-Host ""

# Load .env file if ResourceGroup not provided
if (-not $ResourceGroup) {
    $EnvFile = Join-Path $PSScriptRoot ".." ".env"
    if (Test-Path $EnvFile) {
        $envContent = Get-Content $EnvFile
        $rgLine = $envContent | Where-Object { $_ -match "^WCG_RESOURCE_GROUP=" }
        if ($rgLine) {
            $ResourceGroup = ($rgLine -split "=", 2)[1].Trim()
            Write-Host "✓ Using resource group from .env: $ResourceGroup" -ForegroundColor Green
        }
    }
    
    if (-not $ResourceGroup) {
        Write-Error "Resource group not found. Provide -ResourceGroup parameter or set WCG_RESOURCE_GROUP in .env"
        exit 1
    }
}

Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "✓ Authenticated as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Error "Not authenticated with Azure CLI. Run: az login"
    exit 1
}

Write-Host ""
Write-Host "Detecting existing resources in: $ResourceGroup" -ForegroundColor Cyan
Write-Host ""

$findings = @{
    "create_container_registry" = $true
    "create_log_analytics" = $true
    "create_container_app_environment" = $true
    "existing_acr_name" = ""
    "existing_log_analytics_name" = ""
    "existing_container_app_env_name" = ""
}

# Check for Container Registry
Write-Host "Checking for Container Registry..." -ForegroundColor Yellow
try {
    $acrList = az acr list --resource-group $ResourceGroup 2>&1 | ConvertFrom-Json
    if ($acrList -and $acrList.Count -gt 0) {
        $findings["create_container_registry"] = $false
        $findings["existing_acr_name"] = $acrList[0].name
        Write-Host "  ✓ Found existing ACR: $($acrList[0].name)" -ForegroundColor Green
        if ($acrList.Count -gt 1) {
            Write-Host "  ⚠ Multiple ACRs found. Using first one. Others:" -ForegroundColor Yellow
            $acrList[1..($acrList.Count-1)] | ForEach-Object {
                Write-Host "    - $($_.name)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ℹ No existing ACR found. Will create new one." -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ℹ No existing ACR found (or error checking). Will create new one." -ForegroundColor Cyan
}

# Check for Log Analytics Workspace
Write-Host "Checking for Log Analytics Workspace..." -ForegroundColor Yellow
try {
    $lawList = az monitor log-analytics workspace list --resource-group $ResourceGroup 2>&1 | ConvertFrom-Json
    if ($lawList -and $lawList.Count -gt 0) {
        $findings["create_log_analytics"] = $false
        $findings["existing_log_analytics_name"] = $lawList[0].name
        Write-Host "  ✓ Found existing Log Analytics: $($lawList[0].name)" -ForegroundColor Green
        if ($lawList.Count -gt 1) {
            Write-Host "  ⚠ Multiple workspaces found. Using first one. Others:" -ForegroundColor Yellow
            $lawList[1..($lawList.Count-1)] | ForEach-Object {
                Write-Host "    - $($_.name)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ℹ No existing Log Analytics found. Will create new one." -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ℹ No existing Log Analytics found (or error checking). Will create new one." -ForegroundColor Cyan
}

# Check for Container App Environment
Write-Host "Checking for Container App Environment..." -ForegroundColor Yellow
try {
    $envList = az containerapp env list --resource-group $ResourceGroup 2>&1 | ConvertFrom-Json
    if ($envList -and $envList.Count -gt 0) {
        $findings["create_container_app_environment"] = $false
        $findings["existing_container_app_env_name"] = $envList[0].name
        Write-Host "  ✓ Found existing Container App Environment: $($envList[0].name)" -ForegroundColor Green
        if ($envList.Count -gt 1) {
            Write-Host "  ⚠ Multiple environments found. Using first one. Others:" -ForegroundColor Yellow
            $envList[1..($envList.Count-1)] | ForEach-Object {
                Write-Host "    - $($_.name)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ℹ No existing Container App Environment found. Will create new one." -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ℹ No existing Container App Environment found (or error checking). Will create new one." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Detection Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Creation Flags:" -ForegroundColor Yellow
Write-Host "  create_container_registry        = $($findings['create_container_registry'].ToString().ToLower())"
if (-not $findings['create_container_registry']) {
    Write-Host "    → Use existing: $($findings['existing_acr_name'])" -ForegroundColor Gray
}
Write-Host "  create_log_analytics             = $($findings['create_log_analytics'].ToString().ToLower())"
if (-not $findings['create_log_analytics']) {
    Write-Host "    → Use existing: $($findings['existing_log_analytics_name'])" -ForegroundColor Gray
}
Write-Host "  create_container_app_environment = $($findings['create_container_app_environment'].ToString().ToLower())"
if (-not $findings['create_container_app_environment']) {
    Write-Host "    → Use existing: $($findings['existing_container_app_env_name'])" -ForegroundColor Gray
}

if ($DryRun) {
    Write-Host ""
    Write-Host "⚠ DRY RUN MODE - No files modified" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To apply these settings, run without -DryRun flag" -ForegroundColor Cyan
    exit 0
}

# Update terraform.tfvars
$tfvarsPath = Join-Path $PSScriptRoot "terraform.tfvars"
if (Test-Path $tfvarsPath) {
    Write-Host ""
    Write-Host "Updating terraform.tfvars..." -ForegroundColor Yellow
    
    $content = Get-Content $tfvarsPath -Raw
    
    # Update flags
    $content = $content -replace 'create_container_registry\s*=\s*(true|false)', "create_container_registry        = $($findings['create_container_registry'].ToString().ToLower())"
    $content = $content -replace 'create_log_analytics\s*=\s*(true|false)', "create_log_analytics             = $($findings['create_log_analytics'].ToString().ToLower())"
    $content = $content -replace 'create_container_app_environment\s*=\s*(true|false)', "create_container_app_environment = $($findings['create_container_app_environment'].ToString().ToLower())"
    
    # Update resource names if found
    if ($findings['existing_acr_name']) {
        $content = $content -replace 'container_registry_name\s*=\s*"[^"]*"', "container_registry_name = `"$($findings['existing_acr_name'])`""
    }
    if ($findings['existing_log_analytics_name']) {
        $content = $content -replace 'log_analytics_workspace_name\s*=\s*"[^"]*"', "log_analytics_workspace_name = `"$($findings['existing_log_analytics_name'])`""
    }
    if ($findings['existing_container_app_env_name']) {
        $content = $content -replace 'container_app_environment_name\s*=\s*"[^"]*"', "container_app_environment_name = `"$($findings['existing_container_app_env_name'])`""
    }
    
    $content | Out-File -FilePath $tfvarsPath -Encoding utf8 -NoNewline
    
    Write-Host "✓ Updated terraform.tfvars with detected resources" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠ terraform.tfvars not found. Run parse-env.ps1 first to generate it." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Review terraform.tfvars to verify settings"
Write-Host "2. Run: terraform plan"
Write-Host "3. Run: terraform apply"
Write-Host ""
Write-Host "✓ Resource detection complete!" -ForegroundColor Green
