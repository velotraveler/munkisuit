#!/bin/sh

# set the current Munki repo for development

set -u
if [ ${DEBUG:-no} = YES ]; then set -x; fi

usage="Usage: $0 <repo-path>"
PATH=$PATH:$(dirname $0)
MUNKIPREFS="$HOME/Library/Preferences/com.googlecode.munki.munkiimport.plist"
AUTOPKGDOMAIN=com.github.autopkg
PLISTBUDDY="/usr/libexec/PlistBuddy -x"

repo=${1:?$usage}

bomb(){
	echo "${1:?huh?}"; exit 23
}

if [ ! -d $repo ]
then
	if mkdir $repo
	then :
	else bomb "aborting, cannot create directory: $repo"
	fi
fi

if [ ! -w $repo ]
then
	bomb  "aborting, repo directory not writeable, status $?: $repo"
fi


if defaults write "$AUTOPKGDOMAIN" MUNKI_REPO "$repo"
then :
else bomb "aborting, setting autopkg defaults for MUNKI_REPO failed, status $?"
fi

# initialize Munki settings
# some Munki tools won't work if the plist is in binary format
# so we use PlistBuddy for initial creation

now=$(date +%Y-%m-%d-%H-%M-%S)
if [ -f "$MUNKIPREFS" ]
then
	echo "Renaming existing munkiimport preferences file to: $MUNKIPREFS.$now"
	if ! mv "$MUNKIPREFS" "$MUNKIPREFS.$now"
	then bomb "ERROR: cannot rename existing munkiimport preferences: $?"
	fi
fi

for keypair in default_catalog:testing pkginfo_extension:.plist editor: repo_url:
do
	key=${keypair%%:*}
	value=${keypair#*:}
	$PLISTBUDDY -c "add :$key String \"$value\"" "$MUNKIPREFS"
done

if $PLISTBUDDY -c "add :repo_path String \"$repo\"" "$MUNKIPREFS"
then :
else bomb "Setting Munki repo_path failed, status $?"
fi

echo "repo configuration complete"
exit 0
