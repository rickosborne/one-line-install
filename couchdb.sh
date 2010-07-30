#!/bin/sh -ex
# Couch-Builder
# Downloads, Install Erlang & CouchDB into a package
# Copyright 2009 Jan Lehnardt <jan@apache.org>
# Apache 2.0 Licensed
# Modifications by Rick Osborne for <http://github.com/rickosborne/one-line-install>

COUCHDB_DEFAULT="./couchdb.default"
COUCHDB_DEFAULT_SRC="http://github.com/rickosborne/one-line-install/raw/master/etc/default/couchdb"

if [ ! -e "$COUCHDB_DEFAULT" ]; then
	wget -q -O $COUCHDB_DEFAULT $COUCHDB_DEFAULT_SRC
fi

if [ -z "$EDITOR" ]; then
	echo "You don't have an EDITOR set, so I'm going to go with nano."
	EDITOR="nano"
fi

# open an editor
$EDITOR $COUCHDB_DEFAULT

if [ -r "$COUCHDB_DEFAULT" ]; then
	. $COUCHDB_DEFAULT
fi

# The following config options should now be set by the default file above

# Valid repos: "git", "github", "svn" (default)
if [ -z "$COUCHDB_REPO" ]; then
    COUCHDB_REPO="git"
fi

# use just version number like "0.9.x" or "trunk"
if [ -z "$COUCHDB_VERSION" ]; then
    COUCHDB_VERSION="trunk"
fi

# use full svn path for branches like "branches/0.9.x" or "trunk"
if [ -z "$COUCHDB_SVNPATH" ]; then
    COUCHDB_SVNPATH="trunk"
fi

# or R12B-5
if [ -z "$ERLANG_VERSION" ]; then
    ERLANG_VERSION="R13B04"
fi

# or 1.7.0
if [ -z "$JS_VERSION" ]; then
    JS_VERSION="1.8.0-rc1"
fi

# to force a build of 32- or 64-bit, set this to 32 or 64, or leave blank for default
if [ -z "$BUILD_BITS"]; then
	BUILD_BITS=""
fi

# We may need a package manager to get build dependencies
if [ -z "$PACKAGE_MANAGER"]; then
	PACKAGE_MANAGER=""
fi

# make options
MAKE_OPTS="-j4"

# stop customising

# internal vars
DIRS="src dist"
WORKDIR=`pwd`

MBITS=""
BITSUFFIX=""
ERLANGBUILDARCH=""
if [ "$BUILD_BITS" = "32" ]; then
  echo "\n\n  Forcing 32-bit build\n\n"
  CC="gcc -m32"
  CXX="g++ -m32"
  ERLANGBUILDARCH="--enable-m32-build --enable-darwin-universal"
  MBITS='-m32'
  BITSUFFIX="_32"
fi
if [ "$BUILD_BITS" = "64" ]; then
  echo "\n\n  Forcing 64-bit build\n\n"
  CC="gcc -m64"
  CXX="g++ -m64"
  ERLANGBUILDARCH="--enable-m64-build --enable-darwin-64bit"
  MBITS='-m64'
  BITSUFFIX="_64"
fi

ERLANGSRCDIR="erlang_$ERLANG_VERSION"
ERLANGDISTDIR="$ERLANGSRCDIR$BITSUFFIX"

COUCHDBSRCDIR="couchdb_$COUCHDB_VERSION"
COUCHDBDISTDIR="$COUCHDBSRCDIR$BITSUFFIX"

HOST_OS="`uname`"

# Clean up
# rm -rf .js-*installed
# Work around a bug where a failed build leaves erlang, which then breaks further builds
# TODO: Make the erlang build be more calm
rm -rf .erlang-*-installed
rm -rf dist/couchdb_*
rm -rf dist/erlang*

#functions

find_package_manager()
{
	if [ -z "$PACKAGE_MANAGER" ]; then
		PACKAGE_MANAGER_DEFAULT="echo"
		PACKAGE_MANAGER="$PACKAGE_MANAGER_DEFAULT"
		if [ "$HOST_OS" = "Linux" ]; then
			for pkgmgr in "apt-get" "yum" "rpm" ; do
				if [ "$PACKAGE_MANAGER" = "$PACKAGE_MANAGER_DEFAULT" ]; then
					echo "Looking for $pkgmgr"
					PACKAGE_MANAGER_WHICH=`which $pkgmgr`
					if [ ! "$PACKAGE_MANAGER_WHICH" = "" ]; then
						PACKAGE_MANAGER="$PACKAGE_MANAGER_WHICH"
					fi
				fi
			done
		fi
		if [ "$HOST_OS" = "Darwin" ]; then
			for pkgmgr in "port" "fink" ; do
				echo "Looking for $pkgmgr"
				if [ "$PACKAGE_MANAGER" = "$PACKAGE_MANAGER_DEFAULT" ]; then
					PACKAGE_MANAGER_WHICH=`which $pkgmgr`
					if [ ! "$PACKAGE_MANAGER_WHICH" = "" ]; then
						PACKAGE_MANAGER="$PACKAGE_MANAGER_WHICH"
					fi
				fi
			done
		fi
	fi
}

build_deps()
{
	if [ -z "$PACKAGE_MANAGER" ]; then
		echo "No package manager was found, so dependencies won't be checked."
	else
		if [ -z "`which libtool`" ]; then
			sudo $PACKAGE_MANAGER install libtool
		fi
	fi
}

erlang_download()
{
  if [ ! -e .erlang-$ERLANG_VERSION-downloaded ]; then
    FILE_NAME="otp_src_$ERLANG_VERSION"
    BASE_URL="http://www.csd.uu.se/ftp/mirror/erlang/download"
    cd src
    if [ ! -e $FILE_NAME.tar.gz ]; then
      wget $BASE_URL/$FILE_NAME.tar.gz
    fi
    tar xzf $FILE_NAME.tar.gz
    mv $FILE_NAME $ERLANGSRCDIR
    cd ..
    touch .erlang-$ERLANG_VERSION-downloaded
  fi
}

erlang_install()
{
  if [ ! -e .erlang-$ERLANG_VERSION-installed ]; then
    cd src/$ERLANGSRCDIR
    ./configure \
      --prefix=$WORKDIR/dist/$ERLANGDISTDIR \
      --enable-hipe \
      --enable-dynamic-ssl-lib \
      --with-ssl=/usr \
      --without-java $ERLANGBUILDARCH
    # skip wxWidgets
    touch lib/wx/SKIP
    make # can't have -jN so no $MAKEOPTS
    make install
    cd ../../
    cd dist
    rm -rf erlang

    if [ -d "erlang" ]; then
      rm -rf erlang
    fi

    cp -r $ERLANGDISTDIR erlang
    cd ..
    touch .erlang-$ERLANG_VERSION-installed
  fi
}

erlang_post_install()
{
  cd dist/$ERLANGDISTDIR
  # change absolute paths to relative paths
  perl -pi -e "s@$WORKDIR/dist@\`pwd\`@" bin/erl
  # add quotes for paths with spaces
  perl -pi -e \
    's@`pwd`/erlang/lib/erlang@"`pwd`/erlang/lib/erlang"@' \
    bin/erl
  perl -pi -e 's@\$BINDIR/erlexec@"\$BINDIR/erlexec"@' bin/erl

  cd ../../
}

strip_erlang_dist()
{

  # backup erlang build tree
  if [ ! -d "$WORKDIR/dist/erlang" ]; then
    cp -r $WORKDIR/dist/$ERLANGDISTDIR $WORKDIR/dist/erlang
  fi

  # strip unused erlang crap^Wlibs
  cd $WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/lib
  rm -rf \
    appmon-*/ \
    asn1-*/ \
    common_test-*/ \
    compiler-*/ \
    cosEvent-*/ \
    cosEventDomain-*/ \
    cosFileTransfer-*/ \
    cosNotification-*/ \
    cosProperty-*/ \
    cosTime-*/ \
    cosTransactions-*/ \
    debugger-*/ \
    dialyzer-*/ \
    docbuilder-*/ \
    edoc-*/ \
    erl_interface-*/ \
    erts-*/ \
    et-*/ \
    eunit-*/ \
    gs-*/ \
    hipe-*/ \
    ic-*/ \
    inviso-*/ \
    jinterface-*/ \
    megaco-*/ \
    mnesia-*/ \
    observer-*/ \
    odbc-*/ \
    orber-*/ \
    os_mon-*/ \
    otp_mibs-*/ \
    parsetools-*/ \
    percept-*/ \
    pman-*/ \
    public_key-*/ \
    reltool-*/ \
    runtime_tools-*/ \
    snmp-*/ \
    ssh-*/ \
    syntax_tools-*/ \
    test_server-*/ \
    toolbar-*/ \
    tools-*/ \
    tv-*/ \
    typer-*/ \
    webtool-*/ \
    wx-*/

    find . -name "src" | xargs rm -rf
    cd ../../../../../

    rm -f js/lib/libjs.a
    rm -rf js/bin
    rm -rf Darwin_DBG.OBJ
}

erlang()
{
  erlang_download
  erlang_install
}

couchdb_download()
{
    cd src
    if [ "$COUCHDB_REPO" = "github" ] || [ "$COUCHDB_REPO" = "git" ]; then
      COUCHDBSRCDIR="couchdb_$COUCHDB_REPO"
      if [ ! -d "$COUCHDBSRCDIR" ]; then
        if [ "$COUCHDB_REPO" = "github" ]; then
          git clone git://github.com/apache/couchdb.git "$COUCHDBSRCDIR"
        else
          git clone git://git.apache.org/couchdb.git "$COUCHDBSRCDIR"
        fi
      fi
      cd "$COUCHDBSRCDIR"
      git pull
      git checkout "$COUCHDB_VERSION"
      if [ "$COUCHDB_VERSION" = "trunk" ] || [ "$COUCHDB_VERSION" = "master" ]; then
        COUCHDB_VERSION=`git log -n1 --date=short --format='%cd_%h'`
        COUCHDBDISTDIR="couchdb_$COUCHDB_VERSION$BITSUFFIX"
      fi
      cd ..
    else
      if [ ! -d "$COUCHDBSRCDIR" ]; then
        svn checkout http://svn.apache.org/repos/asf/couchdb/$COUCHDB_SVNPATH $COUCHDBSRCDIR
      fi
      svn up $COUCHDBSRCDIR
      if [ "$COUCHDB_VERSION" = "trunk" ]; then
        COUCHDB_VERSION=${COUCHDB_SVNPATH}_`svnversion $COUCHDBSRCDIR`
        COUCHDBDISTDIR="couchdb_$COUCHDB_VERSION$BITSUFFIX"
      fi
    fi
    cd ..
}

couchdb_install()
{
  # if [ ! -e .couchdb-installed ]; then
    cd src/$COUCHDBSRCDIR

    # remove icu-config call
    perl -pi -e "s@command=\"\`%ICU_CONFIG% --invoke\`@command=\"@" bin/couchdb.tpl.in

    # PATH hack for jan's machine
    PATH=/usr/bin:$PATH ./bootstrap
    export ERLC_FLAGS="+native"
    export ERL=$WORKDIR/dist/$ERLANGDISTDIR/bin/erl
    export ERLC=$WORKDIR/dist/$ERLANGDISTDIR/bin/erlc
    ./configure \
      --prefix=$WORKDIR/dist/$COUCHDBDISTDIR \
      --with-erlang=$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
      --with-js-include=$WORKDIR/dist/js/include \
      --with-js-lib=$WORKDIR/dist/js/lib
    unset ERL_EXECUTABLE
    unset ERLC_EXECUTABLE

    make $MAKE_OPTS
    make install
    couchdb_post_install
    cd ../../
  #   touch .couchdb-installed
  # fi
}

couchdb_link_erl_driver()
{

  if [ -d "src/couchdb/priv/icu_driver/" ]; then # we're on trunk
    cd src/couchdb/priv/icu_driver/
      gcc -I$WORKDIR/src/icu -I/usr/include -L/usr/lib \
          -I$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
          -lpthread -lm -licucore \
          -flat_namespace -undefined suppress -bundle $MBITS \
          -o couch_icu_driver.so couch_icu_driver.c -fPIC
      mv couch_icu_driver.so \
        ../../../../../../dist/$COUCHDBDISTDIR/lib/couchdb/erlang/lib/couch-*/priv/lib
      cd ../../../../
  else # we're on 0.10 or earlier
    cd src/couchdb
      gcc -I$WORKDIR/src/icu -I/usr/include -L/usr/lib \
          -I$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
          -lpthread -lm -licucore \
          -flat_namespace -undefined suppress -bundle $MBITS \
          -o couch_erl_driver.so couch_erl_driver.c -fPIC
      mv couch_erl_driver.so \
        ../../../../dist/$COUCHDBDISTDIR/lib/couchdb/erlang/lib/couch-*/priv/lib
      cd ../../
  fi
}

couchdb_post_install()
{
  if [ "$HOST_OS" = "Darwin" ]; then
    # build couch_erl_driver.so against bundled ICU
    couchdb_link_erl_driver
  fi

  cd ../../dist/$COUCHDBDISTDIR
  # replace absolute to relative paths
  perl -pi -e "s@$WORKDIR/dist/@@g" bin/couchdb bin/couchjs etc/couchdb/default.ini

  cd ../../src/$COUCHDBSRCDIR
}

couchdb()
{
  couchdb_download
  couchdb_install
}

create_dirs()
{
  mkdir -p $DIRS
}

download_js()
{
  if [ ! -e .js-$JS_VERSION-downloaded ]; then
    cd src
    if [ ! -e js-$JS_VERSION.tar.gz ]; then
      wget http://ftp.mozilla.org/pub/mozilla.org/js/js-$JS_VERSION.tar.gz
    fi
    rm -Rf ./js
    tar xzf js-$JS_VERSION.tar.gz
    if [ "$HOST_OS" = "Darwin" ]; then
      cd js/src
      if [ ! -e "patch-jsprf.c" ]; then
        wget -q -O patch-jsprf.c https://trac.macports.org/raw-attachment/ticket/25467/patch-jsprf.c
      fi
      patch -N -p0 < patch-jsprf.c
      cd ../..
    fi
    cd ..
    touch .js-$JS_VERSION-downloaded
  fi
}

install_js()
{
  if [ ! -e .js-$JS_VERSION-installed ]; then
    if [ "$HOST_OS" = "Darwin" ]; then
      soext="dylib"
    else
      soext="so"
    fi
    cd src/js/src
    make $MAKEOPTS -f Makefile.ref
    JS_DIST=$WORKDIR/dist/js make -f Makefile.ref export
    cd ../../../
    touch .js-$JS_VERSION-installed
  fi
}

js()
{
  download_js
  install_js
}

package()
{
  PACKAGEDIR="couchdbx-core-$ERLANG_VERSION-$COUCHDB_VERSION"
  rm -rf $PACKAGEDIR
  mkdir $PACKAGEDIR
  cp -r dist/$ERLANGDISTDIR \
      dist/$COUCHDBDISTDIR \
      src/js \
      $PACKAGEDIR
  install_name_tool -change Darwin_DBG.OBJ/libjs.dylib js/lib/libjs.dylib \
  $PACKAGEDIR/$COUCHDBDISTDIR/lib/couchdb/bin/couchjs
  cd $PACKAGEDIR
  ln -s $COUCHDBDISTDIR couchdb
  cd ..
  tar czf $PACKAGEDIR.tar.gz $PACKAGEDIR

  cd dist/
  rm -rf $ERLANGDISTDIR
  mv erlang $ERLANGDISTDIR
  cd ..
}

build_app()
{
  cd ../couchdbx-app
  xcodebuild
  cd ../couchdbx-core
}

bundle_app()
{
  cp -r ../couchdbx-app/build/Release/CouchDBX.app .

  cp -r $PACKAGEDIR CouchDBX.app/Contents/Resources/couchdbx-core
  cd CouchDBX.app/Contents/Resources/couchdbx-core/
  rm -rf couchdb
  ln -s $COUCHDBDISTDIR couchdb
  cd ../../../../

  DEST_APP_PATH="CouchDBX-$ERLANG_VERSION-$COUCHDB_VERSION$BITSUFFIX.app"
  mv CouchDBX.app $DEST_APP_PATH
  mkdir bundle
  mv $DEST_APP_PATH bundle
  ditto -c -k --sequesterRsrc bundle \
    $DEST_APP_PATH.zip
  rm -rf bundle
}

# main:
find_package_manager
build_deps
create_dirs
erlang
js
couchdb
erlang_post_install
strip_erlang_dist
# package
# build_app
# bundle_app

echo "Done."
