#!/bin/bash -e

# This is a sample to install a private extension using a deploy key from AWS Secrets Manager

# CKAN_EXTENSION_REPO_DEPLOY_KEY is expected to be set in the environment coming from AWS Secrets Manager
# This key must be saved after being base64 decoded if it was stored that way.
# with cat ~/.ssh/ckan_extension_repo_deploy_key | base64 -w 0
# Write key to temp file with correct permissions
TEMP_KEY=$(mktemp)
# If key is base64 encoded, decode it; otherwise handle literal \n
echo "$CKAN_EXTENSION_REPO_DEPLOY_KEY" | base64 -d > "$TEMP_KEY"

chmod 600 "$TEMP_KEY"

# Verify the key file looks valid (optional debug)
echo "SSH key file created, first line: $(head -1 "$TEMP_KEY")"

# Create temporary directory for cloning the extension
TEMP_DIR=$(mktemp -d)

GIT_SSH_COMMAND="ssh -i $TEMP_KEY -o StrictHostKeyChecking=no" git clone --branch main --depth 1 git@github.com:ORG/REPO.git "$TEMP_DIR"

rm -f "$TEMP_KEY"  # Clean up the temp key file

# Find and install the extension from the correct subdirectory
# Adjust the path below to match where setup.py or pyproject.toml is located
EXTENSION_PATH="$TEMP_DIR/ckanext-YOR-PRIVATE-REPO"
pip install "$EXTENSION_PATH"
pip install -r "$EXTENSION_PATH/requirements.txt"

rm -rf "$TEMP_DIR"
