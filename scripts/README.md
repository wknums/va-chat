# Docker Build and Push Scripts

This directory contains automated scripts for building and pushing the VA Chat Docker image to Azure Container Registry.

## Scripts

### `build-and-push.ps1` (Windows/PowerShell)

Automated Docker build and push script for Windows environments.

**Basic Usage:**
```powershell
.\build-and-push.ps1
```

**Advanced Usage:**
```powershell
# Build and push with specific tag
.\build-and-push.ps1 -ImageTag "v1.0.0"

# Use specific ACR
.\build-and-push.ps1 -AcrName "myacr" -ImageTag "v1.0.0"

# Only build (skip push)
.\build-and-push.ps1 -SkipPush

# Only push existing image (skip build)
.\build-and-push.ps1 -SkipBuild

# Custom image name
.\build-and-push.ps1 -ImageName "my-custom-backend" -ImageTag "v2.0"
```

**Parameters:**
- `-AcrName` - Azure Container Registry name (auto-detected from Terraform if not specified)
- `-ImageName` - Docker image name (default: `va-chat-backend`)
- `-ImageTag` - Image tag (default: `latest`)
- `-TerraformDir` - Path to Terraform directory (default: `../terraform`)
- `-SkipBuild` - Skip Docker build step
- `-SkipPush` - Skip ACR push step

### `build-and-push.sh` (Linux/macOS/Bash)

Automated Docker build and push script for Unix-like environments.

**Basic Usage:**
```bash
./build-and-push.sh
```

**Advanced Usage:**
```bash
# Build and push with specific tag
./build-and-push.sh --image-tag v1.0.0

# Use specific ACR
./build-and-push.sh --acr-name myacr --image-tag v1.0.0

# Only build (skip push)
./build-and-push.sh --skip-push

# Only push existing image (skip build)
./build-and-push.sh --skip-build

# Custom image name
./build-and-push.sh --image-name my-custom-backend --image-tag v2.0

# Show help
./build-and-push.sh --help
```

**Options:**
- `--acr-name NAME` - Azure Container Registry name
- `--image-name NAME` - Docker image name (default: `va-chat-backend`)
- `--image-tag TAG` - Image tag (default: `latest`)
- `--skip-build` - Skip Docker build step
- `--skip-push` - Skip ACR push step
- `-h, --help` - Show help message

## How It Works

Both scripts follow the same workflow:

1. **Detect Configuration**
   - Attempts to read ACR name from Terraform output
   - Falls back to reading `terraform.tfvars`
   - Prompts user if not found

2. **Build Docker Image**
   - Runs `docker build` from project root
   - Tags image locally
   - Verifies build success

3. **Authenticate to Azure**
   - Checks Azure CLI authentication
   - Logs in to ACR using `az acr login`

4. **Push to ACR**
   - Tags image for ACR
   - Pushes to registry
   - Verifies image was uploaded

5. **Verification**
   - Lists available tags in ACR
   - Provides next steps

## ACR Auto-Detection

The scripts automatically detect the ACR name from:

1. **Terraform Output** (preferred)
   ```powershell
   terraform output -raw container_registry_login_server
   ```

2. **terraform.tfvars File**
   ```hcl
   container_registry_name = "vachatacr"
   ```

3. **User Prompt**
   If both methods fail, the script will ask you to enter the ACR name.

## Examples

### Development Workflow

```powershell
# Initial deployment
.\build-and-push.ps1

# After code changes, build new version
.\build-and-push.ps1 -ImageTag "v1.1.0"

# Update Terraform
cd ..\terraform
notepad terraform.tfvars  # Update container_image_tag = "v1.1.0"
terraform apply
```

### CI/CD Integration

```powershell
# Build and push with build number from CI pipeline
.\build-and-push.ps1 -ImageTag "build-$env:BUILD_NUMBER"
```

### Rollback Scenario

```powershell
# Push previous version without rebuilding
.\build-and-push.ps1 -ImageTag "v1.0.0" -SkipBuild
```

## Troubleshooting

### "ACR name not found"
- Run `terraform init` and `terraform apply` first
- Or manually specify: `-AcrName "your-acr-name"`

### "Docker build failed"
- Check Dockerfile syntax
- Ensure all required files exist
- Verify Docker is running

### "ACR login failed"
- Run `az login` to authenticate
- Verify you have permissions to the ACR
- Check if ACR exists: `az acr show --name <acr-name>`

### "Image push failed"
- Ensure ACR admin is enabled (for Terraform-created ACRs, it's automatic)
- Verify network connectivity to Azure
- Check ACR storage quota

## Integration with Terraform

After pushing a new image:

1. Update `terraform/terraform.tfvars`:
   ```hcl
   container_image_tag = "your-new-tag"
   ```

2. Apply Terraform changes:
   ```powershell
   cd terraform
   terraform apply
   ```

This will update the Container App to use the new image.

## Notes

- Both scripts require Docker to be installed and running
- Azure CLI must be installed and authenticated
- The scripts are idempotent - safe to run multiple times
- Images are tagged with both local and ACR tags
- Failed builds/pushes will exit with non-zero status codes

