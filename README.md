The Munki Sysadmin Usability Improvement Toolkit
================================================

These command-line tools let you build and maintain a simplified but
mostly automated Munki repository integrated with autopkg/AutoPkgr.

The 'catalogutil' tool lets you edit a package's membership in
catalogs, schedule a daily launchd job to perform an operation
such as autopromote, and display an inventory of the repository.

Most Munki tasks that require editing a plist file can be automated
(or documented) using these scripts.

##FEATURES
* Can automatically promote applications from one catalog to another
based on the age of the application.  This "autopromote" functionality
gives you a "hands off" repository where AutoPkgr/autopkg installs
updates into a "testing" catalog that is used by your site's more
technical users who act as the guinea pigs for the rest of the users.
If the "testers" don't see any problems with the latest version of
the applications, the updates migrate automatically into the "production"
catalog after a specified number of days.  If the testers find an issue
they can mark that version of the application as "suspended" and it will
not be promoted until the "suspension" is removed.

* Manipulate the catalogs of an application on the command line, and
display catalog contents in a human-friendly manner.

* All changes made to application's catalog memberships are logged in
the pkgsinfo file, and can be easily reviewed.  Additionally, logs of
all actions are sent to syslog.

* The "plistpatcher" command automates edits to plists.  Using
this command with a "plistpatchfile" lets you document and automate
any one-off plist changes instead of editing them by hand.  See
the "patches" directory for some examples.

##SOFTWARE INSTALLATION - EXISTING REPOSITORY

* Log in as the same user that manages autopkg/AutoPkgr/munki.  The
Munki admin preferences should already point to your repository.  This
user is assumed to be able to sudo to root when needed in order to
schedule autopromote jobs (see below).
* Clone the munksuit tools from Github into your directory.  If the Munki
tools are already in your path, copy "catalogutil" and "launchdsimple.py"
into /usr/local/munki .
* Fool around with catalogutil to get a feel for how it works:
```
   catalogutil listcat
   catalogutil listcat <CATALOG-NAME>
   catalogutil repolist
```
* Assuming you already have "testing" and "production" catalogs, schedule
some jobs to autopromote your apps.  For example, if you have AutoPkgr set
to update at 2:00 AM and you figure it will be done by 3:00 AM:
```
   # check for Flash and Silverlight updates in "testing"  more than 3 days old
   catalogutil schedule WebPlugins 03:15 "autopromote testing production 3 AdobeFlashPlayer,Silverlight"
   # check for Firefox and MS Office updates  in "testing" more than 6 days old
   catalogutil schedule Apps 03:30 "autopromote testing production 6 Firefox,Office2011_update"
```
Since we want these jobs to run even when the user is not logged in, we
need administrative privileges.  "catalogutil" uses "sudo" (which will
ask you for your password) to call "launchctl".  The job will run as the
regular user that invokes "catalogutil".  (Running "catalogutil" as root
is not recommended.)
* To see what jobs have been scheduled:
```
   catalogutil schedule
```
Note that the job name, once installed, has the hour and minute appended
to show when it is scheduled to run.  In the example above, the "Apps" job
will display as "Apps.3.30".  To remove it from launchd, you would do:

```
   catalogutil unschedule Apps.3.30
```

##Monitoring AutoPkgr/autopkg/catalogutil activities
* If you're interested in what has changed recently for a particular
application:
```
   catalogutil history [<APP-NAME> [<VERSION>]]
```
Omitting _APP-NAME_ lists out all of catalogutil's change history in the
repository.  Specifiying _VERSION_ will show history just for that
particular version of the application.
* If a scheduled job changes anything, notices from catalogtuil
will appear in syslog, including the output of makecatalogs.
* To see previously logged events in syslog:
```
egrep -i -e '(autopkg|catalogutil)' /var/log/system.log
```
to see any events in the last 100 lines of syslog and monitor for any
future ones:
```
syslog -w 100 | egrep -i -e '(autopkg|catalogutil)'
```
###Sierra or later MacOS
Munkisuit has not yet been tested on Sierra or later versions.
if it seems to work and you are trying to find log information,
try something like this (but substitute "TimeMachine" with "catalogutil"
or "autopkg" or "AutoPkgr")
```
log show --style syslog --predicate 'senderImagePath contains[cd] "TimeMachine"' --info
```

##SOFTWARE INSTALLATION - NEW REPOSITORY

If you are building a new Munki server, use these scripts to speed
things up:

####install prerequisites - Xcode, autopkg, AutoPkgr, Munki tools
```
./makeenv/install-xcode-cli-tools.sh
./makeenv/install-prereqs.sh  prereq-pkg-urls.txt
```

####if this host will also be your MunkiServer, turn on Apache
```
./makeenv/setup-apache.sh
```

####tell Munki to use the same repository being served by Apache
```
./bin/set-repo.sh /Users/Shared/munki_repo
```

##Setting up AutoPkgr
Start up the AutoPkgr application:
```
open -a AutoPkgr
```
On the first run, AutoPkgr will ask for your password and install
its "helper" application.  Then you will need to make the following
changes in each of these AutoPkgr sections:

####Install section
If desired, update to the latest Autopkg and Munki tools
####Repos & Recipes section
In the upper pane titled "Repositories":
*   check the first "Repo Clone URL", github.com/autopkg/recipes.git
In the lower pane titled "Recipes":
*   type "munki" in the search filter box titled "Filter recipes"      
*   select the recipes that import the products you want into Munki,
for example:
..* AdobeFlashPlayer.munki
..* Firefox.munki
..* MSOffice2011Updates.munki
..* Silverlight.munki
..* (etc. etc.)
If you don't see everything you need, search online for a recipe for
your desired app, then check to see if that recipe repository is already
in AutoPkgr's option in the "Repositories" pane, or add it manually if
you trust that source.
####Schedule section
*   select "Enable scheduled AutoPkg runs"
After you select this box, you will be prompted for your password.
*   change run time as desired, such as "Daily at 1:00 AM"
*   optionally select "Update all repos before each AutoPkg run" (see AutoPkgr docs for details)
####Notifications - set up email or chat notifications if desired
####Folders & Integrations
*   Configure AutoPkg - select "Verbose AutoPkg Run"
*   Configure Munki Tools
..* - should already have correct Munki repo
..* - select "Enable MunkiSetDefaultCatalogProcessor"
###Start the Downloads
* go back to "Repos & Recipes" pane, and click on "Run Recipes Now" in middle of pane
* you should see a status display as each recipe runs

###Create your manifests
* Follow the standard Munki documentation for creating a manifest.  A
simple installation will have two manifests, one named "production"
that serves software from one catalog named "production", and another
manifest named "testing" that serves software from both the "testing"
catalog and the "production" catalog.

