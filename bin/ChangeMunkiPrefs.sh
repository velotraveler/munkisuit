#!/bin/sh

# Change Munki client preferences to control which URL/repo/manifest will
# be used when you run managesoftwareupdate.
# Must be run with root permission

usage="Usage: $0 [plisttag value] [...] # example: SoftwareRepoURL <URL> ClientIdentifier <xxx>"


set -u

NOW=$(date +%Y%m%d-%H%M%S)
PLISTBUDDY=/usr/libexec/PlistBuddy

MUNKIPREFS="/Library/Preferences/ManagedInstalls.plist"
MUNKIPREFSBASE=$(basename $MUNKIPREFS)
BACKUPDIR="${HOME:?homeless error}/tmp/MunkiPreferencesArchive"
MUNKIBACKUPPLIST="$MUNKIPREFSBASE-$NOW"
MUNKIBACKUPTEXT="${MUNKIPREFSBASE%.plist}-$NOW.txt"

if [ $(id -u) != 0 ]
then
	echo "You must be root to use this command."; exit 23
fi

case $# in
0)
	$PLISTBUDDY -c print "$MUNKIPREFS" ;;
*)

declare -a worktags   # tags to operate on
declare -a workvalues # values to set them to

let index=0
while [ $# -gt 0 ]
do
	if [ $# -lt 2 ]; then echo "Missing value, no action taken"; echo $usage; exit 1; fi
	worktags[$index]="$1"; shift
	workvalues[$index]="$1"; shift
	let index=index+1
done

let maxindex=index
let index=0

# start to change things - set error checking to high
set -e
trap 'echo error exit - please send above output to developer' EXIT

# back up existing plist, both binary and text
mkdir -p "$BACKUPDIR"
cp -p "$MUNKIPREFS" "$BACKUPDIR/$MUNKIBACKUPPLIST"
$PLISTBUDDY -c print "$MUNKIPREFS" > "$BACKUPDIR/$MUNKIBACKUPTEXT"

while [ $index -lt $maxindex ]
do
#       the defaults are cached in cfpresd or the like
#       we need to use the system "defaults" instead
#	$PLISTBUDDY -c "set ${worktags[$index]} ${workvalues[$index]}" $MUNKIPREFS
	defaults write "${MUNKIPREFS%.plist}" "${worktags[$index]}" "${workvalues[$index]}"
	let index=index+1
done

;;
esac

#  all done, reset the error trap so we can exit cleanly
trap '' EXIT
