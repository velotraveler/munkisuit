The Munki Sysadmin Usability Improvement Toolkit
================================================

These command-line tools let you build and maintain a simplified but
mostly automated Munki repository integrated with autopkg/AutoPkgr.

The 'catalogutil' tool lets you edit a package's membership in
catalogs, schedule a daily launchd job to perform an operation
such as autopromote, and display an inventory of the repository.

Most Munki tasks that require editing a plist file can be automated
(or documented) using these scripts.

##Features
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

##Software Installation - Existing Repository
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
As shown above, you can promote multiple applications at the same time
by separating them with commas.  If the application name has a space in
it, like "Power Manager", use standard shell escapes such as adding a
backslash ("Power\ Manager") or adding single quotes around each affected
application name.

## Catalogutil - Command Summary
###Options

  -n, --dry-run         show actions but do not change anything

  -v, --verbose         show more output for some operations

  -T, --fake-time       for testing autopromote - use supplied time instead of current time

###Subcommands

autopromote     _from-catalog_ _to-catalog_ _days_ _app-name[,app-name ...]_

Conditionally change catalog of an app if older than _days_, which can
be a floating-point number if desired.  _app-name_ can be a single name
or a comma-separated list of names.  All versions of the application
that are present in the specified _from-catalog_ will be moved into
_to-catalog_ if they were installed into the Munki repository longer
than _days_ ago.  Applications marked as "suspended" see below will
be skipped.

history         [app-name [app-version]]

Show an app's modification history.  This history is stored in the pkgsinfo
file of the app, under the plist key "_catalogutil_operations".  If the
application version is not specified, all versions are shown.  If the
application version is specified as "latest", the most recent version
added to the repository (based on the key "_metadata.creation_date")
will be shown.

listcat         [catalog-name]

Lists out contents of the specified catalog, or of all catalogs if none
specified.

repolist

List out all catalogs and applications in the repository.

schedule        _JOBNAME_ HH:MM "<subcommand> <args> [AND <subcommand>] ..."

Create a launchd job to run catalogutil with the specified command string
at the specified time every day.  _JOBNAME_ combined with the specified
time will be used to name the job so it can be viewed or deleted later.
The command string must be quoted so the shell parses it as one argument.
With no arguments, "schedule" lists all currently configured jobs.  With
just a _JOBNAME_ argument, jobs that match that string are listed.

setcat          catalog-name[,catalog-name] _app-name_ [_app-version_]

Set the catalog(s) of an application.  If the _app-version_ is omitted,
either a list of eligible apps and their versions will be printed or
if there is only one version of the app present, that app will be acted
on.  Specifying "latest" as the _app-version_ will choose the most recent
version.

suspend         app-name version

Marks an app as ineligible for autopromotion (see _autopromote_ above)

suspensions

Lists out all apps marked as suspended.

unschedule      _FULL-JOBNAME_

Remove the scheduled job named _FULL-JOBNAME_ (the original name
plus the scheduled time).  To see the names of all jobs, use the
"schedule" subcommand.

unsuspend       app-name version

Allow an app to be autopromoted again after suspending it.

AND

Not really a subcommand, but if used tells _catalogutil_ to run the
subsequent arguments as another subcommand.  This can be used to
schedule multiple commands to run in the same job.  If for some
strange reason this feature conflicts with an application name
or version, you can assign a different keyword for this purpose
using the otherwise undocumented "--conjunction" option.

##Monitoring AutoPkgr/autopkg/catalogutil activities
* If you're interested in what has changed recently for a particular
application:
```
   catalogutil history [<APP-NAME> [<VERSION>]]
```
Omitting _APP-NAME_ lists out all of catalogutil's change history in the
repository.  Specifiying _VERSION_ will show history just for that
particular version of the application.
* If a scheduled job changes anything, notices from catalogutil
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
  * AdobeFlashPlayer.munki
  * Firefox.munki
  * MSOffice2011Updates.munki
  * Silverlight.munki
  * (etc. etc.)
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

    - should already have correct Munki repo

    - select "Enable MunkiSetDefaultCatalogProcessor"

####Start the Downloads
* go back to "Repos & Recipes" pane, and click on "Run Recipes Now" in middle of pane
* you should see a status display as each recipe runs

####Confirm that AutoPkgr will wake up automatically
To confirm that you've told AutoPkgr to schedule unattended runs on a daily
basis, make sure its launchd job is on the system:
```
$ sudo launchctl list | grep schedule
Password:
-	0	com.lindegroup.AutoPkgr.schedule
```

###Create your manifests
* Follow the standard Munki documentation for creating a manifest.  A
simple installation will have two manifests, one named "production"
that serves software from one catalog named "production", and another
manifest named "testing" that serves software from both the "testing"
catalog and the "production" catalog.

