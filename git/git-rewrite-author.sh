#!/bin/sh
# git-author-rewrite.sh
# This script replace author/committer name/email in a git repo commit history

#SOURCES:
#https://gist.github.com/octocat/0831f3fbd83ac4d46451
#https://gist.github.com/frz-dev/adf8c2c7275da1369e0cc340feda0ba0
#https://gist.github.com/octocat/0831f3fbd83ac4d46451#gistcomment-2178506

# use script like this > git rewrite-author your-old-email@example.com your-name your-new-email@example.com

# changes to ~/.gitconfig below lins
	# [alias]
	#     ...
	#     rewrite-author = !/<path-to-script>/git-rewrite-author.sh
# Note: Change the <path-to-script> with the actual path of the script



OLD_EMAIL=$1
CORRECT_NAME=$2
CORRECT_EMAIL=$3
shift 3
if [ -z "$OLD_EMAIL" ]; then
	echo "old email is missing"
	exit 1
fi
if [ -z "$CORRECT_NAME" ]; then
	echo "correct name is missing"
	exit 2
fi
if [ -z "$CORRECT_EMAIL" ]; then
	echo "correct email is missing"
	exit 3
fi
echo "re-writing history of '${OLD_EMAIL}' to '${CORRECT_NAME}'(${CORRECT_EMAIL})"
git filter-branch --env-filter "
	if [ \"\$GIT_COMMITTER_EMAIL\" = \"${OLD_EMAIL}\" ]
	then
	    export GIT_COMMITTER_NAME=\"${CORRECT_NAME}\"
	    export GIT_COMMITTER_EMAIL=\"${CORRECT_EMAIL}\"
	fi
	if [ \"\$GIT_AUTHOR_EMAIL\" = \"${OLD_EMAIL}\" ]
	then
	    export GIT_AUTHOR_NAME=\"${CORRECT_NAME}\"
	    export GIT_AUTHOR_EMAIL=\"${CORRECT_EMAIL}\"
	fi
	" $@ --tag-name-filter cat -- --branches --tags