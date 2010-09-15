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
MODULES_ORIG=".gitmodules"
MODULES_HTTP=".gitmodules-http"
MODULES_BAK=".gitmodules-backup"
CONFIG_ORIG=".git/config"
CONFIG_HTTP=".gitconfig-http"
CONFIG_BAK=".gitconfig-backup"
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
			if [ ! -f "$SUBMODULE_FILE" ] ; then
				sed -e 's/git:/http:/g' "./$MODULES_ORIG" > "./$MODULES_HTTP"
				sed -e 's/git:/http:/g' "./$CONFIG_ORIG" > "./$CONFIG_HTTP"
				echo "It looks like the submodule update failed."
				MOD_DIFF=`diff -q "./$MODULES_ORIG" "./$MODULES_HTTP"`
				CONF_DIFF=`diff -q "./$CONFIG_ORIG" "./$CONFIG_HTTP"`
				if [ -z "$MOD_DIFF$CONF_DIFF" ] ; then
					echo " ... and it appears to be an unrecoverable problem.  Sorry!"
					rm "http-$MODULES_FILE"
					cd "$lastcwd"
					exit
				fi
				echo "Trying to update submodules with http:// instead of git://"
				echo " ... updating your .gitmodules and .git/config files for a moment"
				cp "./$MODULES_ORIG" "./$MODULES_BAK"
				mv "./$MODULES_HTTP" "./$MODULES_ORIG"
				cp "./$CONFIG_ORIG" "./$CONFIG_BAK"
				mv "./$CONFIG_HTTP" "./$CONFIG_ORIG"
				echo " ... trying the update again"
				git submodule update
				echo " ... reverting back to your original .gitmodules and .git/config files"
				mv "./$MODULES_BAK" "./$MODULES_ORIG"
				mv "./$CONFIG_BAK" "./$CONFIG_ORIG"
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
