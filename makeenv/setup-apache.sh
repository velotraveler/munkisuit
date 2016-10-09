#!/bin/sh

set -u

if [ ${DEBUG:-no} = YES ]; then set -x; fi

bomb(){
	tput smso
	echo ${1:?unknown error}
	tput rmso
	exit 23
}

sharedir="${MUNKISUIT_REPO_PARENTDIR:-/Users/Shared}"
webdir="${MUNKISUIT_WEBDIR:-/Library/WebServer/Documents}"
munkidir="$sharedir/munki_repo"

DIRS="munki_repo munki_repo/catalogs munki_repo/manifests munki_repo/pkgs munki_repo/pkgsinfo"

echo "creating Munki dirs ..."
for d in $DIRS
do
	dir="$sharedir/$d"
	mkdir -p "$dir"
	if [ ! -d "$dir" ]; then bomb "ERROR - failed to create directory: $dir"; fi
done

echo "setting permissions on Munki dirs ..."
chmod -R a+rX "$munkidir"

echo "calling sudo to create symlink to Apache's home dir ..."
sudo ln -i -s "$munkidir" "$webdir/"

echo "calling sudo to start Apache ..."
sudo apachectl start

echo "testing Apache ..."
if ! curl -I --silent http://localhost:80/ >/dev/null
then
	bomb "Apache not serving web pages, test to http://localhost:80 fails"
else
	echo "Apache tests OK"
fi
