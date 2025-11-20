#!/bin/bash
# Quick Integration Script for VA Chat Widget
# This script copies the widget files to your website directory

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Get script directory
WIDGET_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <website-directory> [--no-search]${NC}"
    echo ""
    echo "Example:"
    echo "  $0 /var/www/mysite"
    echo "  $0 /var/www/mysite --no-search"
    exit 1
fi

WEBSITE_DIR="$1"
INCLUDE_SEARCH=true

# Check for --no-search flag
if [ "$2" == "--no-search" ]; then
    INCLUDE_SEARCH=false
fi

echo -e "${CYAN}🚀 VA Chat Widget Integration Script${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Validate website directory
if [ ! -d "$WEBSITE_DIR" ]; then
    echo -e "${RED}❌ Error: Website directory not found: $WEBSITE_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}📁 Website Directory: $WEBSITE_DIR${NC}"
echo -e "${GREEN}📦 Widget Source: $WIDGET_DIR${NC}"
echo ""

# Copy widget files
echo -e "${YELLOW}📋 Copying widget files...${NC}"

# Copy CSS
cp "$WIDGET_DIR/va-chat-widget.css" "$WEBSITE_DIR/va-chat-widget.css"
echo -e "${GREEN}  ✓ va-chat-widget.css${NC}"

# Copy JS
cp "$WIDGET_DIR/va-chat-widget.js" "$WEBSITE_DIR/va-chat-widget.js"
echo -e "${GREEN}  ✓ va-chat-widget.js${NC}"

# Copy search integration if requested
if [ "$INCLUDE_SEARCH" = true ]; then
    cp "$WIDGET_DIR/va-search-integration.js" "$WEBSITE_DIR/va-search-integration.js"
    echo -e "${GREEN}  ✓ va-search-integration.js${NC}"
fi

echo ""
echo -e "${GREEN}✅ Widget files copied successfully!${NC}"
echo ""

# Display integration instructions
echo -e "${CYAN}📝 Next Steps:${NC}"
echo ""
echo -e "${YELLOW}1. Add to your HTML <head> section:${NC}"
echo -e "${WHITE}   <link rel=\"stylesheet\" href=\"va-chat-widget.css\">${NC}"
echo ""
echo -e "${YELLOW}2. Add before closing </body> tag:${NC}"
echo -e "${WHITE}   <script src=\"va-chat-widget.js\"></script>${NC}"

if [ "$INCLUDE_SEARCH" = true ]; then
    echo -e "${WHITE}   <script src=\"va-search-integration.js\"></script>${NC}"
fi

echo ""
echo -e "${YELLOW}3. (Optional) Configure API endpoint:${NC}"
echo -e "${WHITE}   <script>${NC}"
echo -e "${WHITE}     window.VAChatWidget.apiBaseUrl = 'https://your-api.com';${NC}"
echo -e "${WHITE}   </script>${NC}"
echo ""
echo -e "${CYAN}📖 See INTEGRATION-GUIDE.md for detailed instructions${NC}"
echo ""
