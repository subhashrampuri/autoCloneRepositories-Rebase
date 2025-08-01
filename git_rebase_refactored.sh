#!/bin/bash

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

# Function to clone repositories
clone_repos() {
  echo ""
  echo "📦 Starting repository cloning process"
  echo "========================================================================="
  for REPO_URL in "${REPO_URLS[@]}"; do
    REPO_NAME=$(basename "$REPO_URL" .git)
    CLONE_DIR="$WORK_DIR/$REPO_NAME"

    if [ ! -d "$CLONE_DIR/.git" ]; then
      echo "  Cloning $REPO_NAME..."
      if ! git clone --quiet "$REPO_URL" "$CLONE_DIR"; then
        echo "  ❌ Failed to clone $REPO_URL"
      else
        echo "  ✅ Cloned $REPO_NAME"
      fi
    else
      echo "  ✅ $REPO_NAME already cloned"
    fi
  done
  echo "========================================================================="
  echo "✅ Repository cloning process completed."
}

# --- Main Script Execution ---
clone_repos





# Function to compare branches and list changes
compare_and_list_changes() {
  echo ""
  echo "🔁 Starting branch comparison and listing changes"
  echo "========================================================================="
  echo "| Repository                                    | Src   | Tgt   | Changes |
  echo "-------------------------------------------------------------------------"

  CHANGED_REPOS=()

  for REPO_URL in "${REPO_URLS[@]}"; do
    REPO_NAME=$(basename "$REPO_URL" .git)
    CLONE_DIR="$WORK_DIR/$REPO_NAME"

    if [ ! -d "$CLONE_DIR/.git" ]; then
      continue
    fi

    cd "$CLONE_DIR" || { echo "❌ Failed to enter 	'$CLONE_DIR'"; continue; }

    git reset --hard &>/dev/null
    git clean -fd &>/dev/null
    git fetch --all &>/dev/null

    git rev-parse --verify "origin/$SOURCE_BRANCH" &>/dev/null
    SRC_EXISTS=$?
    git rev-parse --verify "origin/$TARGET_BRANCH" &>/dev/null
    TGT_EXISTS=$?

    SRC_COL="No"
    TGT_COL="No"
    CHG_COL="N/A"

    if [ $SRC_EXISTS -eq 0 ]; then SRC_COL="Yes"; fi
    if [ $TGT_EXISTS -eq 0 ]; then TGT_COL="Yes"; fi

    if [ "$SRC_COL" == "Yes" ] && [ "$TGT_COL" == "Yes" ]; then
      DIFF=$(git diff origin/$TARGET_BRANCH..origin/$SOURCE_BRANCH)
      
      JENKINSFILE_IGNORE_REPOS=(
        "product-search-api-impl"
        "rate-schedule-api-impl"
      )

      IGNORE_JENKINSFILE=false
      for IGNORE_REPO in "${JENKINSFILE_IGNORE_REPOS[@]}"; do
        if [ "$REPO_NAME" == "$IGNORE_REPO" ]; then
          IGNORE_JENKINSFILE=true
          break
        fi
      done

      if [ "$IGNORE_JENKINSFILE" == "true" ]; then
        DIFF_NO_JENKINSFILE=$(git diff origin/$TARGET_BRANCH..origin/$SOURCE_BRANCH -- ":!Jenkinsfile")
        if [ -z "$DIFF_NO_JENKINSFILE" ]; then
          DIFF=""
        fi
      fi

      if [ -n "$DIFF" ]; then
        CHG_COL="Yes"
        CHANGED_REPOS+=("$REPO_NAME")
      else
        CHG_COL="No"
      fi
    fi

    REPO_COL=$(printf "%-45s" "$REPO_NAME")
    SRC_COL=$(printf "%-6s" "$SRC_COL")
    TGT_COL=$(printf "%-6s" "$TGT_COL")
    CHG_COL=$(printf "%-8s" "$CHG_COL")

    echo "| $REPO_COL | $SRC_COL | $TGT_COL | $CHG_COL |"

    cd "$WORK_DIR"
  done

  echo "========================================================================="
  if [ ${#CHANGED_REPOS[@]} -eq 0 ]; then
    echo "✅ No repositories have changes."
    exit 0
  fi
  echo "✅ Found changes in the following repositories:"
  for REPO in "${CHANGED_REPOS[@]}"; do
    echo "  - $REPO"
  done
  echo ""

  # Return the list of changed repos
  echo "${CHANGED_REPOS[@]}"
}

CHANGED_REPOS_LIST=$(compare_and_list_changes)




# Function to perform rebase and merge
perform_rebase_and_merge() {
  local repos_to_process=("$@")

  if [ ${#repos_to_process[@]} -eq 0 ]; then
    echo "No repositories to process for rebase/merge."
    return
  fi

  echo ""
  echo "🚀 Starting rebase and merge process for selected repositories"
  echo "========================================================================="
  echo "| Repository                                    | Action               |"
  echo "-------------------------------------------------------------------------"

  for REPO_NAME in "${repos_to_process[@]}"; do
    CLONE_DIR="$WORK_DIR/$REPO_NAME"

    echo "📂 Navigating into directory 	'$CLONE_DIR'...
    cd "$CLONE_DIR" || { echo "❌ Failed to enter 	'$CLONE_DIR'"; continue; }

    # Clean up any existing changes
    git reset --hard &>/dev/null
    git clean -fd &>/dev/null

    # Fetch all branches
    echo "🔄 Fetching latest updates..."
    git fetch --all &>/dev/null

    ACTION="Skipped"

    echo "🌿 Checking out feature branch 	'$FEATURE_BRANCH'...
    if git show-ref --quiet "refs/heads/$FEATURE_BRANCH"; then
      git checkout "$FEATURE_BRANCH" &>/dev/null
    elif git show-ref --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
      git checkout -b "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH" &>/dev/null
    else
      echo "🚫 Feature branch 	'$FEATURE_BRANCH' does not exist locally or remotely. Creating from 	'$TARGET_BRANCH'...
      git checkout -b "$FEATURE_BRANCH" "origin/$TARGET_BRANCH" &>/dev/null
    fi

    echo "🔀 Merging 	'$SOURCE_BRANCH' into 	'$FEATURE_BRANCH'...
    git fetch origin "$SOURCE_BRANCH" &>/dev/null
    git merge origin/"$SOURCE_BRANCH" --no-edit &>/dev/null

    if [ $? -ne 0 ]; then
      echo "⚠️ Conflict detected during merge in 	'$REPO_NAME'. Manual resolution required."
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

    REPO_COL=$(printf "%-45s" "$REPO_NAME")
    ACTION_COL=$(printf "%-20s" "$ACTION")

    echo "| $REPO_COL | $ACTION_COL |"

    # Return to base directory
    cd "$WORK_DIR"
  done
  echo "========================================================================="
  echo "✅ All selected repositories processed."
}

# Ask user for confirmation
if [ -n "$CHANGED_REPOS_LIST" ]; then
  echo "Do you want to proceed with creating feature branches and rebasing the code for the above listed repositories? (yes/no)"
  read -r USER_CONFIRMATION

  if [[ "$USER_CONFIRMATION" =~ ^[Yy][Ee][Ss]$ ]]; then
    perform_rebase_and_merge ${CHANGED_REPOS_LIST[@]}
  else
    echo "Operation cancelled by user."
  fi
else
  echo "No changes detected, no rebase/merge needed."
fi


