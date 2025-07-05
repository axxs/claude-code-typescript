#!/bin/bash
# Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual values

# Add your GitHub repository as origin
git remote add origin https://github.com/axxs/claude-code-typescript.git

# Rename branch to main (GitHub's default)
git branch -M main

# Push to GitHub
git push -u origin main

echo "Repository pushed to GitHub!"
echo "Don't forget to:"
echo "1. Add a LICENSE file (MIT, Apache 2.0, etc.)"
echo "2. Update the README with the actual repository URL"
echo "3. Consider adding GitHub Actions for automated testing"