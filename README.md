I'm lazy and like to install software with a single console command.  This
repo contains the installers I've written to help me do this.

Usage Instructions
==================

 1. Pick an installer.  For example: __gitflow__.
 2. Work out the link to the raw file on GitHub, which should be something like: <br/>
    http://github.com/rickosborne/one-line-install/raw/master/__installer__.sh <br/>
    For the __gitflow__ example, that link becomes: <br/>
    <http://github.com/rickosborne/one-line-install/raw/master/gitflow.sh> <br/>
 3. Use __wget__ to pipe the raw file into your shell interpreter: <br/>
        wget -q -O - http://github.com/rickosborne/one-line-install/raw/master/gitflow.sh | sudo sh
 4. Some installers may open a text editor to let you input some default options.  Others will just do the damned thing.

Available Installers
====================
 * gitflow : <http://github.com/nvie/gitflow>
        wget -q -O - http://github.com/rickosborne/one-line-install/raw/master/gitflow.sh | sudo sh
