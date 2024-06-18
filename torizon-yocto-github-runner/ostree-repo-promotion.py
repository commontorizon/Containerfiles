#!/usr/bin/python3
#
# This script moves a ostree commit from one repo to an other
# migration icludes commit message and meta data
#
# Script requires
# * Ostree installed
#
# Remark: Script was tested with repos of archive type
##

import gi
gi.require_version('OSTree', '1.0')
from gi.repository import GLib, Gio, OSTree
import argparse
import sys
import os

filter = ["ostree.ref-binding"]

def fatal(msg):
    print >>sys.stderr, msg
    sys.exit(1)

parser = argparse.ArgumentParser(prog=sys.argv[0])
parser.add_argument("--srcRepo", help="Source ostree repository path",
            action='store', required=True)
parser.add_argument("--targetRepo", help="Target ostree repository path",
            action='store', required=True)
parser.add_argument("--ref", help="OSTree REF to which we commit",
            action='store', required=True)
parser.add_argument("--commit", help="Commit ostree has to publish",
            action='store', required=True)
args = parser.parse_args()


def getCommitParameter():
    srcRepo = OSTree.Repo.new(Gio.File.new_for_path(args.srcRepo))
    srcRepo.open(None)
    _, commitData, _ = srcRepo.load_commit(args.commit)
    commitMeta = commitData.get_child_value(0)
    commitSubject = str(commitData.get_child_value(3)).strip("'")
    commitMetaDict = dict(commitMeta)
    res = ""
    for key in commitMetaDict.keys():
        if key not in filter:
            res += "--add-metadata-string=\"%s=%s\" " % (key, commitMetaDict[key])
    if commitData:
        res += '--subject="%s" ' % commitSubject
    return res

def runCommand(cmd):
    stream = os.popen(cmd)
    print(cmd)
    print(stream.read())
    res = stream.close()
    if (res != None):
        os._exit(os.EX_USAGE)


def doPromotion():
    commitParameters = getCommitParameter()
    runCommand("ostree --repo=%s pull-local --untrusted  %s %s" % (args.targetRepo, args.srcRepo, args.commit))
    runCommand("ostree --repo=%s commit -b %s --tree=ref=%s --add-metadata-string=\"tezi-source-commit=%s\" %s" % (args.targetRepo, args.ref, args.commit, args.commit, commitParameters))

if __name__ == "__main__":
    doPromotion()
