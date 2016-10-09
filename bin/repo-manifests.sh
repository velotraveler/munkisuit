#!/bin/sh

# create manifests using predefined catalogs for sections

usage="Usage: $(basename $0) [--catalog <catalog>] <manifest-name>"

set -u
if [ ${DEBUG:-NO} = YES ]; then set -x; fi

PATH="$PATH:/usr/local/munki"

#####################

bomb(){
	echo "${1:?huh?}"; exit 23
}

direxists(){
	if [ ! -d "${1:?oops}" ]; then bomb "$0: ${2:-required} directory does not exist: ${1}"; fi
}

#####################

TMPFILE=$(mktemp  /tmp/repo-manifests.XXXXXX)
if [ ! -f $TMPFILE ]
then
	echo "cannot create $TMPFILE - help!"; exit 24
fi
trap 'rm -f $TMPFILE' 0

umask 002 # everything should be world-readable


catalog=testing
while [ $# != 0 ]
do
case "$1" in
--catalog) catalog=${2?$usage}; shift; shift ;;
--help) echo $usage; exit 0 ;;
*) break;;
esac
done

manifest=${1:?$usage}

if manifestutil display-manifest "$manifest"
then :
else manifestutil new-manifest "$manifest"
fi

if manifestutil display-manifest "$manifest" | grep -q "^[	 ]$catalog"
then :
else manifestutil add-catalog "$catalog" --manifest "$manifest"
fi

# update-only pkgs
manifestutil list-catalog-items update_only_no_install_pkgs > $TMPFILE
while read pkgname
do
	manifestutil add-pkg "$pkgname" --manifest "$manifest" --section managed_updates
done < $TMPFILE

manifestutil list-catalog-items $catalog |
while read pkgname
do
	if grep -q "^${pkgname}\$" $TMPFILE
	then :
	else
		manifestutil add-pkg "$pkgname" --manifest "$manifest" --section managed_installs
	fi
done


