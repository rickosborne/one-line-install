#!/bin/sh

# git-flow make-less installer for *nix systems, by Rick Osborne
# Based on the git-flow core Makefile:
# http://github.com/nvie/gitflow/blob/master/Makefile

# Licensed under the same restrictions as git-flow:
# http://github.com/nvie/gitflow/blob/develop/LICENSE

# Does this need to be smarter for each host OS?
if [ -z "$INSTALL_PREFIX" ] ; then
	INSTALL_PREFIX="/usr/local/bin"
fi

if [ -z "$REPO_NAME" ] ; then
	REPO_NAME="gitflow"
fi

if [ -z "$REPO_HOME" ] ; then
	REPO_HOME="http://github.com/nvie/gitflow.git"
fi

EXEC_FILES="git-flow"
SCRIPT_FILES="git-flow-init git-flow-feature git-flow-hotfix git-flow-release git-flow-support git-flow-version gitflow-common gitflow-shFlags"
SUBMODULE_FILE="shFlags/src/shflags"
MODULES_FILE=".gitmodules"
SUDO="sudo"

echo "### gitflow no-make installer ###"

case "$1" in
	uninstall)
		echo "Uninstalling git-flow from $INSTALL_PREFIX"
		if [ -d "$INSTALL_PREFIX" ] ; then
			for script_file in $SCRIPT_FILES $EXEC_FILES ; do
				echo "rm -vf $INSTALL_PREFIX/$script_file"
				rm -vf "$INSTALL_PREFIX/$script_file"
			done
		else
			echo "The '$INSTALL_PREFIX' directory was not found."
			echo "Do you need to set INSTALL_PREFIX ?"
		fi
		exit
		;;
	help)
		echo "Usage: [environment] gitflow-installer.sh [install|uninstall]"
		echo "Environment:"
		echo "   INSTALL_PREFIX=$INSTALL_PREFIX"
		echo "   REPO_HOME=$REPO_HOME"
		echo "   REPO_NAME=$REPO_NAME"
		exit
		;;
	*)
		echo "Installing git-flow to $INSTALL_PREFIX"
		if [[ -d "$REPO_NAME" && -d "$REPO_NAME/.git" ]] ; then
			echo "Using existing repo: $REPO_NAME"
		else
			echo "Cloning repo from GitHub to $REPO_NAME"
			git clone "$REPO_HOME" "$REPO_NAME"
		fi
		if [ -f "$REPO_NAME/$SUBMODULE_FILE" ] ; then
			echo "Submodules look up to date"
		else
			echo "Updating submodules"
			lastcwd=$PWD
			cd "$REPO_NAME"
			git submodule init
			git submodule update
			# Since submodules use git:// this may have failed - try http://
			if [ ! -f "-$SUBMODULE_FILE" ] ; then
				sed -e 's/git:/http:/g' "$MODULES_FILE" > "http-$MODULES_FILE"
				echo "It looks like the submodule update failed."
				MOD_DIFF=`diff "$MODULES_FILE" "http-$MODULES_FILE"`
				if [ -z "$MOD_DIFF" ] ; then
					echo " ... and it appears to be an unrecoverable problem.  Sorry!"
					rm "http-$MODULES_FILE"
					cd "$lastcwd"
					exit
				fi
				echo "Trying to update submodules with http:// instead of git://"
				echo " ... updating your .gitmodules file for a moment"
				cp "$MODULES_FILE" "original-$MODULES_FILE"
				mv "http-$MODULES_FILE" "$MODULES_FILE"
				git submodule update
				echo " ... reverting back to your original .gitmodules file"
				mv "original-$MODULES_FILE" "$MODULES_FILE"
				if [ ! -f "$SUBMODULE_FILE" ] ; then
					echo "Sorry, but that didn't appear to work, either."
					cd "$lastcwd"
					exit
				else
					echo "That worked.  Submodules look good."
				fi
			fi
			cd "$lastcwd"
		fi
		echo "###"
		echo "### Installing files.  You may get prompted for your '$SUDO' password."
		echo "###"
		"$SUDO" install -v -d -m 0755 "$INSTALL_PREFIX"
		for exec_file in $EXEC_FILES ; do
			"$SUDO" install -v -m 0755 "$REPO_NAME/$exec_file" "$INSTALL_PREFIX"
		done
		for script_file in $SCRIPT_FILES ; do
			"$SUDO" install -v -m 0644 "$REPO_NAME/$script_file" "$INSTALL_PREFIX"
		done
		exit
		;;
esac
