#!/bin/bash

# this does git compare and check if we have any changes present, if changes found, it will create a feature branch from target branch,
# do the fetch for the feature branch and merge from source branch and commit the same to feature branch.
# === Variables ===
REPO_URLS=(
  "https://bitbucket.fis.dev/scm/epodep/account-api.git"
  "https://bitbucket.fis.dev/scm/epodep/checking-and-savings-account-api.git"
  "https://bitbucket.fis.dev/scm/epodep/dp-acct-trans-api.git"
  "https://bitbucket.fis.dev/scm/epodep/dp-acct-trans-search-api.git"
  "https://bitbucket.fis.dev/scm/epodep/external-transfers-api.git"
  "https://bitbucket.fis.dev/scm/epodep/flex-transfers-api.git"
  "https://bitbucket.fis.dev/scm/epodep/internal-transfers-api.git"
  "https://bitbucket.fis.dev/scm/epodep/package-api.git"
  "https://bitbucket.fis.dev/scm/epodep/term-deposit-account-api.git"
  "https://bitbucket.fis.dev/scm/epodep/retirement-savings-api.git"
  "https://bitbucket.fis.dev/scm/epoorg/organization-api.git"
  "https://bitbucket.fis.dev/scm/epocape/product-api.git"
  "https://bitbucket.fis.dev/scm/epocape/product-search-api.git"
  "https://bitbucket.fis.dev/scm/epocape/rate-schedule-api.git"  
  "https://bitbucket.fis.dev/scm/epodep/account-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/checking-and-savings-account-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/dp-acct-trans-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/dp-acct-trans-search-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/external-transfers-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/flex-transfers-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/internal-transfers-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/package-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/term-deposit-account-api-impl.git"
  "https://bitbucket.fis.dev/scm/epodep/retirement-savings-api-impl.git"
  "https://bitbucket.fis.dev/scm/epoorg/organization-api-impl.git"
  "https://bitbucket.fis.dev/scm/epocape/product-api-impl.git"
  "https://bitbucket.fis.dev/scm/epocape/product-search-api-impl.git"
  "https://bitbucket.fis.dev/scm/epocape/rate-schedule-api-impl.git"  
  # Add more repos here
)

SOURCE_BRANCH="milestone"
TARGET_BRANCH="master"
FEATURE_BRANCH="feature/SP14MLToMAS"

# === Work Directory ===
WORK_DIR="$(pwd)"

# === Table Header ===
echo ""
echo "🔁 Starting branch comparison and merge process"
echo "========================================================================="
echo "| Repository                                    | Src   | Tgt   | Changes | Action               |"
echo "-----------------------------------------------------------------------------------------------"

for REPO_URL in "${REPO_URLS[@]}"; do
  REPO_NAME=$(basename "$REPO_URL" .git)
  CLONE_DIR="$WORK_DIR/$REPO_NAME"

  # Check if repo is already cloned locally
  if [ ! -d "$CLONE_DIR/.git" ]; then
    echo "📦 Cloning $REPO_NAME..."
    if ! git clone --quiet "$REPO_URL" "$CLONE_DIR"; then
      echo "❌ Failed to clone $REPO_URL"
      continue
    fi
  fi

  echo "📂 Navigating into directory '$CLONE_DIR'..."
  cd "$CLONE_DIR" || { echo "❌ Failed to enter '$CLONE_DIR'"; continue; }

  # Clean up any existing changes
  git reset --hard &>/dev/null
  git clean -fd &>/dev/null

  # Fetch all branches
  echo "🔄 Fetching latest updates..."
  git fetch --all &>/dev/null

  # Check if both branches exist
  git rev-parse --verify "origin/$SOURCE_BRANCH" &>/dev/null
  SRC_EXISTS=$?
  git rev-parse --verify "origin/$TARGET_BRANCH" &>/dev/null
  TGT_EXISTS=$?

  SRC_COL="No"
  TGT_COL="No"
  CHG_COL="N/A"
  ACTION="Skipped"

  if [ $SRC_EXISTS -eq 0 ]; then SRC_COL="Yes"; fi
  if [ $TGT_EXISTS -eq 0 ]; then TGT_COL="Yes"; fi

  if [ "$SRC_COL" == "Yes" ] && [ "$TGT_COL" == "Yes" ]; then
    DIFF=$(git diff origin/$TARGET_BRANCH..origin/$SOURCE_BRANCH)
    
    # Define repositories to ignore Jenkinsfile changes
    JENKINSFILE_IGNORE_REPOS=(
      "product-search-api-impl"
      "rate-schedule-api-impl"
    )

    # Check if the current repository is in the ignore list
    IGNORE_JENKINSFILE=false
    for IGNORE_REPO in "${JENKINSFILE_IGNORE_REPOS[@]}"; do
      if [ "$REPO_NAME" == "$IGNORE_REPO" ]; then
        IGNORE_JENKINSFILE=true
        break
      fi
    done

    if [ "$IGNORE_JENKINSFILE" == "true" ]; then
      # Filter out Jenkinsfile changes from the diff
      DIFF_NO_JENKINSFILE=$(git diff origin/$TARGET_BRANCH..origin/$SOURCE_BRANCH -- ":!Jenkinsfile")
      if [ -z "$DIFF_NO_JENKINSFILE" ]; then
        # If only Jenkinsfile changes, treat as no changes
        DIFF=""
      fi
    fi    if [ -n "$DIFF" ]; then
      CHG_COL="Yes"

      echo "🌿 Checking out feature branch '$FEATURE_BRANCH'..."
      if git show-ref --quiet "refs/heads/$FEATURE_BRANCH"; then
        git checkout "$FEATURE_BRANCH" &>/dev/null
      elif git show-ref --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
        git checkout -b "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH" &>/dev/null
      else
        echo "🚫 Feature branch '$FEATURE_BRANCH' does not exist locally or remotely. Creating from '$TARGET_BRANCH'..."
        git checkout -b "$FEATURE_BRANCH" "origin/$TARGET_BRANCH" &>/dev/null
      fi

      echo "🔀 Merging '$SOURCE_BRANCH' into '$FEATURE_BRANCH'..."
      git fetch origin "$SOURCE_BRANCH" &>/dev/null
      git merge origin/"$SOURCE_BRANCH" --no-edit &>/dev/null

      if [ $? -ne 0 ]; then
        echo "⚠️ Conflict detected during merge in '$REPO_NAME'. Manual resolution required."
        ACTION="Conflict"
        cd "$WORK_DIR"
        continue
      else
        echo "✅ Merge completed successfully."

        # Push the feature branch
        if git push origin "$FEATURE_BRANCH" &>/dev/null; then
          ACTION="Merged & Pushed"
        else
          ACTION="Merged but Push Failed"
        fi
      fi
    else
      CHG_COL="No"
      ACTION="No changes"
    fi
  fi

  # Format output using fixed-width spacing
  REPO_COL=$(printf "%-45s" "$REPO_NAME")
  SRC_COL=$(printf "%-6s" "$SRC_COL")
  TGT_COL=$(printf "%-6s" "$TGT_COL")
  CHG_COL=$(printf "%-8s" "$CHG_COL")
  ACTION_COL=$(printf "%-20s" "$ACTION")

  echo "| $REPO_COL | $SRC_COL | $TGT_COL | $CHG_COL | $ACTION_COL |"

  # Return to base directory
  cd "$WORK_DIR"
done

echo "========================================================================="
echo "✅ All repositories processed."
