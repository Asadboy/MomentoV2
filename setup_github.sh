#!/bin/bash
# Script to create GitHub repository and push code

REPO_NAME="Momento"
GITHUB_USER=$(git config user.name 2>/dev/null || echo "")

echo "Setting up GitHub repository for $REPO_NAME"
echo "=========================================="
echo ""

# Check if remote already exists
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' already exists:"
    git remote get-url origin
    echo ""
    read -p "Do you want to push to existing remote? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push -u origin main
        exit 0
    fi
fi

echo "To create the repository on GitHub, you have two options:"
echo ""
echo "OPTION 1: Create via GitHub website (Recommended)"
echo "  1. Go to https://github.com/new"
echo "  2. Repository name: $REPO_NAME"
echo "  3. Make it Private or Public (your choice)"
echo "  4. DO NOT initialize with README, .gitignore, or license"
echo "  5. Click 'Create repository'"
echo "  6. Then run: git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
echo "  7. Then run: git push -u origin main"
echo ""
echo "OPTION 2: Create via GitHub CLI (if you have 'gh' installed)"
echo "  Run: gh repo create $REPO_NAME --private --source=. --remote=origin --push"
echo ""
echo "Current git remotes:"
git remote -v
echo ""
