#!/bin/bash

# 1. Login
gh auth status || gh auth login

# 2. Setup Git & Ignore Junk
git init -b main
echo ".DS_Store" >> .gitignore
echo ".terraform/" >> .gitignore
echo "*.tfstate*" >> .gitignore
git add .
git commit -m "Initial commit"

# 3. Create & Push (Fixed Quotes)
gh repo create "aws-tailscale-exit-node" \
  --description "Tailscale EC2 Exit Node" \
  --license apache-2.0 \
  --public \
  --source=. \
  --remote=upstream \
  --push
