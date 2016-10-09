#!/bin/sh

set -u

PREREQFILEDEFAULT="$(dirname $0)/prereq-pkg-urls.txt"
BINDIR="$(dirname $0)/../MunkiLand/bin"
TMPDIR=$(mktemp -d /var/tmp/install-prereqs-XXXXXXX)

if [ ! -d "$TMPDIR" ]
then
	bomb "mktemp fails, cannot create temp directory"
fi

if [ ${DEBUG:-no} = YES ]
then
	set -x
fi

#################

bomb(){
	echo "${1:-error...}"; exit 23
}

cleanup(){
	set -u
	rm -rf "$TMPDIR"
}


# destination target
rootdir=/

inputfile=${1:-$PREREQFILEDEFAULT}

if [ ! -r $inputfile ]; then bomb "Cannot read $inputfile"; fi

trap 'echo install of $urlpath failed: $?; cleanup' EXIT
set -e

while read pkgid urlpath
do

	case $pkgid in
	"#"*) continue ;;
	BIN) ;;
	/*)
		if [ -e $pkgid ]
		then 
			echo "Application '$pkgid' already installed, skipping:"
			ls -ld "$pkgid" | sed -e 's/^/    /'
			continue
		fi
		;;
	*)
		if pkgutil --pkgs="$pkgid" > /dev/null
		then 
			echo "Package '$pkgid' already installed, skipping:"
			pkgutil --pkg-info "$pkgid" | sed -e 's/^/    /'
			echo
			continue
		fi
		;;
	esac

	pkgfile="${urlpath##*/}"
	suffix="${pkgfile##*.}"
	pkgname="${pkgfile%.$suffix}"

	if ! curl --fail --silent -L -o "$TMPDIR/$pkgfile" "$urlpath"
	then
		echo "ERROR: failed to download: $urlpath"
		echo "ERROR: skipping this package"
		continue
	fi

	case $suffix in
	pkg)
		sudo installer -pkg "$TMPDIR/$pkgfile"  -target $rootdir
		;;
	dmg)
		newmount=$(hdiutil attach "$TMPDIR/$pkgfile" | tail -1 | awk '{print $3}')
		if [ ! -d "$newmount" ]
		then
			bomb "ERROR - cannot mount $TMPDIR/$pkgfile - aborting"
		fi
		pkgfile=$(find $newmount -name "*.pkg" 2>/dev/null| sed -e 's:^$newmount::' | head -1)
		if [ -f "$pkgfile" ]
		then # WARNING, NOT TESTED YET
			echo "Installing $pkgfile found in DMG from $urlpath ..."
			sudo installer -pkg "$pkgfile" -target $rootdir
		elif ( cd $newmount; test -e *.app )
		then
			appname=$(basename $(ls -d "$newmount"/*.app))
			echo "Installing $appname found in DMG from $urlpath ..."
			ditto "$newmount/$appname" "$rootdir/Applications/$appname"
		fi
		hdiutil detach "$newmount"
		;;
	*)
		# assumed to be freestanding script or binary
		echo "copying $pkgfile to $BINDIR"
		mkdir -p "$BINDIR"
		cp -p "$TMPDIR/$pkgfile" "$BINDIR"
		chmod +x "$BINDIR/$(basename $pkgfile)"
		;;
	esac


done < $inputfile
set +e

trap 'echo installation completed; cleanup' EXIT

