#!/usr/bin/env python

import argparse, os, subprocess, plistlib
from sys import argv
from fnmatch import fnmatch
from tempfile import NamedTemporaryFile

myprefix = "com.github.velotraveler.pseudocron."
launchd_dir = "/Library/LaunchDaemons"

class PseudoCrontabException(Exception):
    '''Exception for launchctl errors and other errors from
    this module.'''
    pass


class PseudoCrontab(object):
    '''
    Simulate adding/removing user crontab entries under MacOS. Since we
    want to simulate a real crontab's ability to run jobs under a specific
    user ID even when the user is not logged in, we need to put this job
    in /Library/LaunchDaemons and thus require root privilege.  We use sudo
    to get root access and thus the user will need to type in their
    password when sudo runs if it is not already cached.

    To prevent accidental damage to system launchd jobs, this module
    will only list, install or remove jobs that begin with our
    app-specific prefix (see "myprefix" above).

    Only one type of job can be created, one that runs once a day at
    a specified hour and minute.  As there doesn't seem to be an easy
    way to find the of an existing job, we append the time of the job
    to the job's name.  The caller needs to specify the full name when
    deleting the job.
    '''

    def __init__(self, debug=False, prefix=myprefix):
        self.username = os.getlogin()
        if len(set("[]*?").intersection(set(prefix))) > 0:
            raise PseudoCrontabException("prefix must not contain any of the shell wildcard matching characters '*', '[', ']', or '?'")
        self.prefix = prefix
        self.debug = debug

    def list(self, labelmatch="*"):
        '''
        run "launchctl list" and return list of jobs that match the shell-
        style wildcard <labelmatch>

        since all jobs have our app-specific prefix, and have their
        run time appended to their names, caller should terminate
        <labelmatch> with ".*" unless they already have an exact name.
        '''
        results = []
        try:
            output = subprocess.check_output(["sudo", "launchctl", "list"])
            for line in output.split("\n"):
                if len(line) == 0:
                    break
                fields= line.split(None,3)
                if len(fields) < 3:
                    self.bomb("unexpected output from 'sudo launchctl list: %s'" % line)
                job= fields[2]
                if fnmatch(job, self.prefix + labelmatch):
                    results.append(job[len(self.prefix):])
        except (subprocess.CalledProcessError) as error:
            self.bomb("running 'sudo launchctl list'", error)
        return results


    def install(self, label=None, command=None, hour=None, minute=None):
        '''
        create a pseudo-crontab job by loading it into launchd
        '''
        # check args
        if label is None or command is None or hour is None or minute is None:
            self.bomb("required args missing: label, command, hour, minute")
        if len(label) == 0:
            self.bomb("label must not be empty string")
        if not hour.isdigit() or not minute.isdigit():
            self.bomb("hour and minute args must be numeric digits only")
        if type(command) == type("string") and "," in command:
            command= command.split(",")

        if not type(command) == type([]):
            self.bomb("command arg must be a list")
        hour = int(hour)
        minute = int(minute)
        if hour >= 24 or minute >= 60:
            self.bomb("hour or minute args are out of range, see 'man launchd.plist'")
        joblabel = self.prefix + label + ".%d.%d" % (hour, minute)
        agentfilename = os.path.join(launchd_dir, joblabel + ".plist")

        # create temporary file with plist from args
        plistfile = NamedTemporaryFile()
        plistdata= dict(
           Label = joblabel,
           ProgramArguments = command,
           StartCalendarInterval = dict(
               Hour = hour,
               Minute = minute,
           ),
           UserName = self.username
        )
        plistlib.writePlist(plistdata, plistfile)
        plistfile.flush()
        # call sudo to call launchctl to install plist
        launchargs = ["sudo", "sh", "-c", "cp '%s' '%s' && launchctl load -w %s" % (plistfile.name, agentfilename, agentfilename)]
        try:
            output = subprocess.check_output(launchargs)
        except (subprocess.CalledProcessError) as error:
            self.bomb("running 'sudo' with args: " % launchargs, error)
        if  not os.path.isfile(agentfilename):
            self.bomb("plist file missing even though sudo didn't fail: %s" % agentfilename)
        return [joblabel[len(self.prefix):], launchargs, output]

    def uninstall(self, label=""):
        '''
        remove scheduled entry from launchd - <label> must be exact match
        '''
        joblabel = self.prefix + label
        agentfilename = os.path.join(launchd_dir, joblabel + ".plist")
        launchargs = ["sudo", "sh", "-c", "launchctl remove '%s' && rm -f '%s'" % (joblabel, agentfilename)]
        try:
            output = subprocess.check_output(launchargs)
            return [launchargs, output]
        except (subprocess.CalledProcessError) as error:
            self.bomb("running 'sudo' with args: " % launchargs, error)

    def bomb(self, msg, error=None):
        msg = "ERROR: " + msg
        if self.debug:
            print msg
            print error
        else:
            if error is None:
                error = msg
            raise PseudoCrontabException(error)

def main(args):

    parser = argparse.ArgumentParser(description='test the module')
    parser.add_argument("--prefix")
    parser.add_argument("--debug", action='store_true', default=False)
    parser.add_argument("--list", nargs=1)
    parser.add_argument("--install", nargs=4)
    parser.add_argument("--uninstall", nargs=1)

    args = parser.parse_args(args[1:])

    initargs={}
    if vars(args)['debug'] != None:
        print args
        initargs['debug']= True

    if vars(args)['prefix'] != None:
       initargs['prefix']= vars(args)['prefix']

    print "initargs: %s" % initargs

    pc = PseudoCrontab(**initargs)
    for command in ['list', 'install', 'list', 'uninstall', 'list']:
        if vars(args)[command] != None:
            classargs= vars(args)[command]
            result = getattr(pc, command)(*classargs)
            print "%s(%s): %s" % (command, classargs, result)

# sample test:
# ./launchdsimple.py --debug --install foo "touch,junk" 3 4 --list foo.3.4 --uninstall foo.3.4
# (lists out schedule before and after each install/uninstall call)


if __name__ == '__main__':
    main(argv)
