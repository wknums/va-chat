#!/bin/bash
###############################################################################
# VA Chat - Docker Build and Push Script (Linux/macOS)
###############################################################################
#
# This script builds the VA Chat backend Docker image and pushes it to 
# Azure Container Registry.
#
# Usage:
#   ./build-and-push.sh [OPTIONS]
#
# Options:
#   --acr-name NAME       Azure Container Registry name
#   --image-name NAME     Docker image name (default: va-chat-backend)
#   --image-tag TAG       Docker image tag (default: latest)
#   --skip-build          Skip Docker build step
#   --skip-push           Skip push to ACR step
#   -h, --help            Show this help message
#
# Examples:
#   ./build-and-push.sh
#   ./build-and-push.sh --acr-name vachatacr --image-tag v1.0.0
#   ./build-and-push.sh --skip-build
#
###############################################################################

set -e

# Default values
ACR_NAME=""
IMAGE_NAME="va-chat-backend"
IMAGE_TAG="latest"
SKIP_BUILD=false
SKIP_PUSH=false
TERRAFORM_DIR="../terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${CYAN}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

show_help() {
    head -n 30 "$0" | grep "^#" | sed 's/^# \?//'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --acr-name)
            ACR_NAME="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-push)
            SKIP_PUSH=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info "=== WCG Chat - Docker Build and Push Script ==="
echo ""

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info "Project Root: $PROJECT_ROOT"

# Determine ACR name if not provided
if [ -z "$ACR_NAME" ]; then
    log_info "ACR name not provided, attempting to read from Terraform..."
    
    TERRAFORM_PATH="$PROJECT_ROOT/$TERRAFORM_DIR"
    
    if [ -d "$TERRAFORM_PATH" ]; then
        cd "$TERRAFORM_PATH"
        
        # Check if Terraform state exists
        if [ -d ".terraform" ]; then
            log_info "Reading ACR login server from Terraform output..."
            ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null || echo "")
            
            if [ -n "$ACR_LOGIN_SERVER" ]; then
                # Extract ACR name from login server (format: acrname.azurecr.io)
                ACR_NAME="${ACR_LOGIN_SERVER%.azurecr.io}"
                log_success "Found ACR from Terraform: $ACR_NAME"
            else
                log_warning "Could not read Terraform output. Have you run 'terraform apply' yet?"
            fi
        else
            log_warning "Terraform not initialized in $TERRAFORM_PATH"
        fi
        
        cd - > /dev/null
    fi
    
    # If still no ACR name, try to read from tfvars file
    if [ -z "$ACR_NAME" ]; then
        TFVARS_PATH="$TERRAFORM_PATH/terraform.tfvars"
        if [ -f "$TFVARS_PATH" ]; then
            log_info "Reading from terraform.tfvars..."
            ACR_NAME=$(grep -E '^\s*container_registry_name\s*=' "$TFVARS_PATH" | sed -E 's/.*"([^"]+)".*/\1/')
            if [ -n "$ACR_NAME" ]; then
                log_success "Found ACR in terraform.tfvars: $ACR_NAME"
            fi
        fi
    fi
    
    # If still no ACR name, prompt user
    if [ -z "$ACR_NAME" ]; then
        log_warning "Could not determine ACR name automatically."
        read -p "Please enter your Azure Container Registry name: " ACR_NAME
    fi
fi

if [ -z "$ACR_NAME" ]; then
    log_error "ERROR: ACR name is required. Use --acr-name parameter or ensure Terraform is configured."
    exit 1
fi

LOCAL_IMAGE_TAG="${IMAGE_NAME}:${IMAGE_TAG}"
ACR_IMAGE_TAG="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
log_info "Configuration:"
log_info "  ACR Name:       $ACR_NAME"
log_info "  Image Name:     $IMAGE_NAME"
log_info "  Image Tag:      $IMAGE_TAG"
log_info "  Local Tag:      $LOCAL_IMAGE_TAG"
log_info "  ACR Tag:        $ACR_IMAGE_TAG"
echo ""

# Build Docker image
if [ "$SKIP_BUILD" = false ]; then
    log_info "=== Building Docker Image ==="
    log_info "Running: docker build -t $LOCAL_IMAGE_TAG $PROJECT_ROOT"
    echo ""
    
    cd "$PROJECT_ROOT"
    docker build -t "$LOCAL_IMAGE_TAG" .
    
    log_success "✓ Docker build completed successfully"
    echo ""
else
    log_info "Skipping Docker build (--skip-build specified)"
    echo ""
fi

# Push to ACR
if [ "$SKIP_PUSH" = false ]; then
    log_info "=== Pushing to Azure Container Registry ==="
    
    # Check if logged in to Azure
    log_info "Checking Azure CLI authentication..."
    if az account show &> /dev/null; then
        AZ_USER=$(az account show --query user.name -o tsv)
        log_success "✓ Logged in as: $AZ_USER"
    else
        log_warning "Not logged in to Azure. Running 'az login'..."
        az login
    fi
    
    # Login to ACR
    log_info "Logging in to ACR: $ACR_NAME"
    az acr login --name "$ACR_NAME"
    
    log_success "✓ ACR login successful"
    echo ""
    
    # Tag image for ACR
    log_info "Tagging image for ACR..."
    log_info "Running: docker tag $LOCAL_IMAGE_TAG $ACR_IMAGE_TAG"
    docker tag "$LOCAL_IMAGE_TAG" "$ACR_IMAGE_TAG"
    
    log_success "✓ Image tagged"
    echo ""
    
    # Push image
    log_info "Pushing image to ACR..."
    log_info "Running: docker push $ACR_IMAGE_TAG"
    echo ""
    docker push "$ACR_IMAGE_TAG"
    
    log_success "✓ Image pushed successfully"
    echo ""
else
    log_info "Skipping push to ACR (--skip-push specified)"
    echo ""
fi

# Summary
log_success "=== Deployment Complete ==="
echo ""
log_info "Image Location: $ACR_IMAGE_TAG"
echo ""

# Check if we should update Terraform
if [ -f "$PROJECT_ROOT/$TERRAFORM_DIR/terraform.tfvars" ]; then
    log_info "Next steps:"
    log_info "  1. If you used a new tag, update terraform/terraform.tfvars:"
    log_info "     container_image_tag = \"$IMAGE_TAG\""
    echo ""
    log_info "  2. Apply Terraform to deploy the new image:"
    log_info "     cd terraform"
    log_info "     terraform apply"
    echo ""
fi

# Verify image in ACR
log_info "Verifying image in ACR..."
if az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output json 2>/dev/null | grep -q "\"$IMAGE_TAG\""; then
    log_success "✓ Image verified in ACR repository"
    echo ""
    log_info "Available tags for ${IMAGE_NAME}:"
    az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output tsv 2>/dev/null | sed 's/^/  - /'
else
    log_warning "Could not verify image in ACR (might need to wait a moment)"
fi

echo ""
log_success "Script completed successfully! 🎉"

