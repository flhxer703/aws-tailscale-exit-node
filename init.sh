#!/bin/bash

# 1. Login check
gh auth status || gh auth login

# 2. Git Setup (Silent if already done)
git init -b main 2>/dev/null
git add .
git commit -m "Initial commit"

# 3. Create & Push (Fix: Removed --license flag)
gh repo create "aws-tailscale-exit-node" \
  --description "Tailscale EC2 Exit Node" \
  --public \
  --source=. \
  --remote=upstream \
  --push
