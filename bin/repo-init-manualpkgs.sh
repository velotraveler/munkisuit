#!/bin/sh

# load packages from staging dir into Munki repo

set -u
if [ ${DEBUG:-NO} = YES ]; then set -x; fi

#####################

bomb(){
	echo "${1:?huh?}"; exit 23
}

direxists(){
	if [ ! -d "${1:?oops}" ]; then bomb "$0: ${2:-required} directory does not exist: ${1}"; fi
}

#####################

usage="Usage: $(basename -a $0) [--staging <stagedir> ]"

umask 022 # everything should be world-readable

UTILDIR=$(dirname "$0")
STAGEDIR="$UTILDIR/../staging"
PATCHDIR="$UTILDIR/../patches"
NOTES="imported from manual staging"

PATH="$PATH:/usr/local/munki"

while [ $# != 0 ]
do
case "$1" in
--stagedir) STAGEDIR="${2:?$usage}"; shift; shift ;;
--notes)    NOTES="${2:?$usage}"; shift; shift ;;
--help|-?|-h)     echo $USAGE; exit 0 ;;
*) break ;;
esac
done

repodir=$(defaults read com.github.autopkg MUNKI_REPO)

direxists "$STAGEDIR" "package staging"
direxists "$repodir" "destination repository"

# initialize repo structure
for subdir in catalogs manifests pkgs pkgsinfo
do
	mkdir -p "$repodir/$subdir"
done

# import the packages into Munki
for subtype in install_pkgs update_pkgs update_only_no_install_pkgs
do for pkg in "${STAGEDIR}/${subtype}/"*; do
	if [ ! -f "$pkg" ]; then continue; fi  # could be empty dir
	base=$(echo $(basename -a $pkg))
	if [ -s "$repodir/pkgs/$base" ]
	then
		echo "*** $pkg already imported, ignoring..."
		continue
	fi
	munkiimport --nointeractive --catalog testing --catalog $subtype --notes "$NOTES" "$pkg"
	echo
done; done

# apply any plist patches
find $repodir/pkgsinfo -type f |
while read pkgsinfo
do
	base=$(echo $(basename -a ${pkgsinfo%.plist}))
	patchfile="$PATCHDIR/$base.plistpatch"
	if [ -f "$patchfile" ]
	then
		echo "*** patching $pkgsinfo ..."
		"$UTILDIR/plistpatcher" "$pkgsinfo" "$patchfile"
	fi
done

makecatalogs

