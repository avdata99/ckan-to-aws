#!/bin/bash -e

# Fetch private project-specific files from a private Git repository.
#
# ckan-to-aws is a generic CKAN deployment tool. Each project needs custom
# private files (extensions list, private extensions, private entrypoint, etc.)
# that are stored in a separate private repository.
#
# The private repo structure is:
#   {UNIQUE_PROJECT_ID}-{ENVIRONMENT}/
#     ├── extensions.list.txt         -> ${APP_DIR}/extensions/extensions.list.txt
#     ├── private-entrypoint.sh       -> ${APP_DIR}/files/scripts/private/private-entrypoint.sh
#     ├── .env                        -> (used at build time, not copied at runtime)
#     └── private_*/                  -> ${APP_DIR}/extensions/private_*/
#
# Required environment variables:
#   PRIVATE_REPO_URL          - SSH URL of the private overrides repository
#   PRIVATE_REPO_DEPLOY_KEY   - Base64-encoded SSH deploy key for the private repo
#   UNIQUE_PROJECT_ID         - Project identifier (e.g., datos-gestion)
#   ENVIRONMENT               - Environment name (e.g., prod, pre)
#
# Optional:
#   PRIVATE_REPO_BRANCH       - Branch to clone (default: main)
# Create a deploy key:

# ssh-keygen -t ed25519 -C "deploy-key-$(date +%Y%m%d)" -f ~/.ssh/ckan_private_repo_deploy_key -N ""
# Store the private key in AWS Secrets Manager (base64-encoded):
# cat ~/.ssh/ckan_private_repo_deploy_key | base64 -w 0

echo "================================================"
echo "Fetching private project overrides ..."
echo "================================================"

# ---------------------------------------------------------------------------
# Validate required variables
# ---------------------------------------------------------------------------
if [ -z "$PRIVATE_REPO_URL" ]; then
    echo "============================================================"
    echo "ERROR: PRIVATE_REPO_URL is not set."
    echo ""
    echo "ckan-to-aws requires a private repository with project-specific"
    echo "files (extensions list, private extensions, entrypoints, etc.)."
    echo ""
    echo "Set PRIVATE_REPO_URL to the SSH URL of your private overrides repo."
    echo "Example: git@github.com:your-org/ckan-private-overrides.git"
    echo "============================================================"
    exit 1
fi

if [ -z "$UNIQUE_PROJECT_ID" ]; then
    echo "ERROR: UNIQUE_PROJECT_ID is not set."
    exit 1
fi

if [ -z "$ENVIRONMENT" ]; then
    echo "ERROR: ENVIRONMENT is not set."
    exit 1
fi

if [ -z "$PRIVATE_REPO_DEPLOY_KEY" ]; then
    echo "ERROR: PRIVATE_REPO_DEPLOY_KEY is not set."
    echo "This key is required to clone the private overrides repository."
    echo "Store it base64-encoded in AWS Secrets Manager."
    exit 1
fi

PRIVATE_REPO_BRANCH="${PRIVATE_REPO_BRANCH:-main}"
PROJECT_FOLDER="${UNIQUE_PROJECT_ID}-${ENVIRONMENT}"

echo "  Repository: $PRIVATE_REPO_URL"
echo "  Branch: $PRIVATE_REPO_BRANCH"
echo "  Project folder: $PROJECT_FOLDER"

# ---------------------------------------------------------------------------
# Setup SSH key
# ---------------------------------------------------------------------------
TEMP_KEY=$(mktemp)
echo "$PRIVATE_REPO_DEPLOY_KEY" | base64 -d > "$TEMP_KEY"
chmod 600 "$TEMP_KEY"
echo "  SSH key prepared"

# ---------------------------------------------------------------------------
# Clone the private repo
# ---------------------------------------------------------------------------
TEMP_DIR=$(mktemp -d)
echo "  Cloning private overrides repo..."

GIT_SSH_COMMAND="ssh -i $TEMP_KEY -o StrictHostKeyChecking=no" \
    git clone --branch "$PRIVATE_REPO_BRANCH" --depth 1 "$PRIVATE_REPO_URL" "$TEMP_DIR"

rm -f "$TEMP_KEY"

# ---------------------------------------------------------------------------
# Validate project folder exists
# ---------------------------------------------------------------------------
PROJECT_DIR="$TEMP_DIR/$PROJECT_FOLDER"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "ERROR: Project folder '$PROJECT_FOLDER' not found in private repo."
    echo "Available folders:"
    ls -1 "$TEMP_DIR" | grep -v '^\.' | grep -v 'README'
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "  Found project folder: $PROJECT_FOLDER"

# ---------------------------------------------------------------------------
# Copy files to the right locations
# ---------------------------------------------------------------------------

# 1. extensions.list.txt
if [ -f "$PROJECT_DIR/extensions.list.txt" ]; then
    cp "$PROJECT_DIR/extensions.list.txt" "${APP_DIR}/extensions/extensions.list.txt"
    echo "  ✓ extensions.list.txt"
else
    echo "  ⚠ No extensions.list.txt found in private repo"
fi

# 2. Private entrypoint script
if [ -f "$PROJECT_DIR/private-entrypoint.sh" ]; then
    mkdir -p "${APP_DIR}/files/scripts/private"
    cp "$PROJECT_DIR/private-entrypoint.sh" "${APP_DIR}/files/scripts/private/private-entrypoint.sh"
    chmod +x "${APP_DIR}/files/scripts/private/private-entrypoint.sh"
    echo "  ✓ private-entrypoint.sh"
else
    echo "  ⚠ No private-entrypoint.sh found"
fi

# 3. Private extension folders (private_*)
for private_ext_dir in "$PROJECT_DIR"/private_*/; do
    [ ! -d "$private_ext_dir" ] && continue
    ext_name=$(basename "$private_ext_dir")
    cp -r "$private_ext_dir" "${APP_DIR}/extensions/$ext_name"
    echo "  ✓ Extension: $ext_name"
done

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -rf "$TEMP_DIR"

echo "================================================"
echo "Private overrides installed successfully"
echo "================================================"
