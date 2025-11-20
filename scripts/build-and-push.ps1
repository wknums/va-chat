<#
.SYNOPSIS
    Build and push Docker image to Azure Container Registry

.DESCRIPTION
    This script builds the VA Chat backend Docker image and pushes it to Azure Container Registry.
    It can read configuration from Terraform outputs or accept parameters directly.

.PARAMETER AcrName
    Name of the Azure Container Registry. If not provided, will attempt to read from Terraform output.

.PARAMETER ImageName
    Name of the Docker image. Default: va-chat-backend

.PARAMETER ImageTag
    Tag for the Docker image. Default: latest

.PARAMETER TerraformDir
    Path to the Terraform directory. Default: ../terraform

.PARAMETER SkipBuild
    Skip the Docker build step and only push existing image.

.PARAMETER SkipPush
    Skip the push step and only build the image.

.EXAMPLE
    .\build-and-push.ps1
    Builds and pushes using Terraform output for ACR name

.EXAMPLE
    .\build-and-push.ps1 -AcrName "vachatacr" -ImageTag "v1.0.0"
    Builds and pushes with specific ACR name and tag

.EXAMPLE
    .\build-and-push.ps1 -SkipBuild
    Only pushes existing image without rebuilding
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$AcrName,

    [Parameter(Mandatory=$false)]
    [string]$ImageName = "va-chat-backend",

    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",

    [Parameter(Mandatory=$false)]
    [string]$TerraformDir = "..\terraform",

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,

    [Parameter(Mandatory=$false)]
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

Write-Info "=== VA Chat - Docker Build and Push Script ==="
Write-Info ""

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Info "Project Root: $ProjectRoot"

# Determine ACR name
if (-not $AcrName) {
    Write-Info "ACR name not provided, attempting to read from Terraform..."
    
    $TerraformPath = Join-Path $ProjectRoot $TerraformDir
    
    if (Test-Path $TerraformPath) {
        Push-Location $TerraformPath
        try {
            # Check if Terraform state exists
            if (Test-Path ".terraform") {
                Write-Info "Reading ACR login server from Terraform output..."
                $acrLoginServer = terraform output -raw container_registry_login_server 2>$null
                
                if ($LASTEXITCODE -eq 0 -and $acrLoginServer) {
                    # Extract ACR name from login server (format: acrname.azurecr.io)
                    $AcrName = $acrLoginServer -replace '\.azurecr\.io$', ''
                    Write-Success "Found ACR from Terraform: $AcrName"
                } else {
                    Write-Warning "Could not read Terraform output. Have you run 'terraform apply' yet?"
                }
            } else {
                Write-Warning "Terraform not initialized in $TerraformPath"
            }
        } finally {
            Pop-Location
        }
    }
    
    # If still no ACR name, try to read from tfvars file
    if (-not $AcrName) {
        $tfvarsPath = Join-Path $TerraformPath "terraform.tfvars"
        if (Test-Path $tfvarsPath) {
            Write-Info "Reading from terraform.tfvars..."
            $tfvarsContent = Get-Content $tfvarsPath -Raw
            if ($tfvarsContent -match 'container_registry_name\s*=\s*"([^"]+)"') {
                $AcrName = $Matches[1]
                Write-Success "Found ACR in terraform.tfvars: $AcrName"
            }
        }
    }
    
    # If still no ACR name, prompt user
    if (-not $AcrName) {
        Write-Warning "Could not determine ACR name automatically."
        $AcrName = Read-Host "Please enter your Azure Container Registry name"
    }
}

if (-not $AcrName) {
    Write-Error "ERROR: ACR name is required. Use -AcrName parameter or ensure Terraform is configured."
    exit 1
}

$LocalImageTag = "${ImageName}:${ImageTag}"
$AcrImageTag = "${AcrName}.azurecr.io/${ImageName}:${ImageTag}"

Write-Info ""
Write-Info "Configuration:"
Write-Info "  ACR Name:       $AcrName"
Write-Info "  Image Name:     $ImageName"
Write-Info "  Image Tag:      $ImageTag"
Write-Info "  Local Tag:      $LocalImageTag"
Write-Info "  ACR Tag:        $AcrImageTag"
Write-Info ""

# Build Docker image
if (-not $SkipBuild) {
    Write-Info "=== Building Docker Image ==="
    Write-Info "Running: docker build -t $LocalImageTag $ProjectRoot"
    Write-Info ""
    
    Push-Location $ProjectRoot
    try {
        docker build -t $LocalImageTag .
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ERROR: Docker build failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
        
        Write-Success "✓ Docker build completed successfully"
        Write-Info ""
    } finally {
        Pop-Location
    }
} else {
    Write-Info "Skipping Docker build (--SkipBuild specified)"
    Write-Info ""
}

# Push to ACR
if (-not $SkipPush) {
    Write-Info "=== Pushing to Azure Container Registry ==="
    
    # Check if logged in to Azure
    Write-Info "Checking Azure CLI authentication..."
    $azAccount = az account show 2>$null | ConvertFrom-Json
    
    if (-not $azAccount) {
        Write-Warning "Not logged in to Azure. Running 'az login'..."
        az login
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ERROR: Azure login failed"
            exit 1
        }
    } else {
        Write-Success "✓ Logged in as: $($azAccount.user.name)"
    }
    
    # Login to ACR
    Write-Info "Logging in to ACR: $AcrName"
    az acr login --name $AcrName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: ACR login failed. Ensure the ACR exists and you have permissions."
        exit $LASTEXITCODE
    }
    
    Write-Success "✓ ACR login successful"
    Write-Info ""
    
    # Tag image for ACR
    Write-Info "Tagging image for ACR..."
    Write-Info "Running: docker tag $LocalImageTag $AcrImageTag"
    docker tag $LocalImageTag $AcrImageTag
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: Docker tag failed"
        exit $LASTEXITCODE
    }
    
    Write-Success "✓ Image tagged"
    Write-Info ""
    
    # Push image
    Write-Info "Pushing image to ACR..."
    Write-Info "Running: docker push $AcrImageTag"
    Write-Info ""
    docker push $AcrImageTag
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: Docker push failed"
        exit $LASTEXITCODE
    }
    
    Write-Success "✓ Image pushed successfully"
    Write-Info ""
} else {
    Write-Info "Skipping push to ACR (--SkipPush specified)"
    Write-Info ""
}

# Summary
Write-Success "=== Deployment Complete ==="
Write-Info ""
Write-Info "Image Location: $AcrImageTag"
Write-Info ""

# Check if we should update Terraform
if (Test-Path (Join-Path $ProjectRoot $TerraformDir "terraform.tfvars")) {
    Write-Info "Next steps:"
    Write-Info "  1. If you used a new tag, update terraform/terraform.tfvars:"
    Write-Info "     container_image_tag = `"$ImageTag`""
    Write-Info ""
    Write-Info "  2. Apply Terraform to deploy the new image:"
    Write-Info "     cd terraform"
    Write-Info "     terraform apply"
    Write-Info ""
}

# Verify image in ACR
Write-Info "Verifying image in ACR..."
$images = az acr repository show-tags --name $AcrName --repository $ImageName --output json 2>$null | ConvertFrom-Json

if ($images -and $images -contains $ImageTag) {
    Write-Success "✓ Image verified in ACR repository"
    Write-Info ""
    Write-Info "Available tags for ${ImageName}:"
    $images | ForEach-Object { Write-Info "  - $_" }
} else {
    Write-Warning "Could not verify image in ACR (might need to wait a moment)"
}

Write-Info ""
Write-Success "Script completed successfully! 🎉"

