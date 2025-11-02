#!/bin/bash
# Quick script to push to GitHub after creating the repo

REPO_NAME="Momento"
GITHUB_USER=$(git config user.name 2>/dev/null || echo "YOUR_USERNAME")

echo "?? Pushing Momento to GitHub"
echo "============================"
echo ""

# Check if remote exists
if git remote get-url origin &>/dev/null; then
    REMOTE_URL=$(git remote get-url origin)
    echo "? Remote 'origin' is already set to:"
    echo "   $REMOTE_URL"
    echo ""
    echo "?? Pushing code to GitHub..."
    git push -u origin main
    if [ $? -eq 0 ]; then
        echo ""
        echo "? Successfully pushed to GitHub!"
        echo "?? View your repo at: $(echo $REMOTE_URL | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')"
    else
        echo ""
        echo "? Push failed. Make sure:"
        echo "   1. The GitHub repository exists"
        echo "   2. You have permission to push"
        echo "   3. You're authenticated (check: git config credential.helper)"
    fi
else
    echo "??  No remote 'origin' configured yet."
    echo ""
    echo "First, create the repository on GitHub:"
    echo "   1. Go to: https://github.com/new"
    echo "   2. Repository name: $REPO_NAME"
    echo "   3. Choose Private or Public"
    echo "   4. DO NOT initialize with README/gitignore/license"
    echo "   5. Click 'Create repository'"
    echo ""
    echo "Then add the remote and push:"
    echo "   git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
    echo "   git push -u origin main"
    echo ""
    echo "Or run this script again after adding the remote."
fi
