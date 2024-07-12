#!/usr/bin/python3

from gi.repository import GLib
import json
import requests
import os, sys
import datetime as DT
import time
import re
import difflib
from urllib.request import url2pathname
from threading import Thread
import unhandled_exit

unhandled_exit.activate()

# cribbed from https://stackoverflow.com/questions/10123929/fetch-a-file-from-a-local-url-with-python-requests
class LocalFileAdapter(requests.adapters.BaseAdapter):
    @staticmethod
    def _chkpath(method, path):
        """Return an HTTP status for the given filesystem path."""
        if method.lower() in ('put', 'delete'):
            return 501, "Not Implemented"  # TODO
        elif method.lower() not in ('get', 'head'):
            return 405, "Method Not Allowed"
        elif os.path.isdir(path):
            return 400, "Path Not A File"
        elif not os.path.isfile(path):
            return 404, "File Not Found"
        elif not os.access(path, os.R_OK):
            return 403, "Access Denied"
        else:
            return 200, "OK"

    def send(self, req, **kwargs):
        path = os.path.normcase(os.path.normpath(url2pathname(req.path_url)))
        response = requests.Response()

        response.status_code, response.reason = self._chkpath(req.method, path)
        if response.status_code == 200 and req.method.lower() != 'head':
            try:
                response.raw = open(path, 'rb')
            except (OSError, IOError) as err:
                response.status_code = 500
                response.reason = str(err)

        if isinstance(req.url, bytes):
            response.url = req.url.decode('utf-8')
        else:
            response.url = req.url

        response.request = req
        response.connection = self

        return response

    def close(self):
        pass

# set up requests to support file:// urls
requests_session = requests.session()
requests_session.mount('file://', LocalFileAdapter())

# Fetches a commit (by commit ID) from an OSTree repo, and returns it as a python object
def get_raw_commit (commit_id):
    commit_url = f"{REPO_BASEURL}objects/{commit_id[:2]}/{commit_id[2:]}.commit"
    commit_resp=requests_session.get(commit_url, stream=True)
    # print("Response " + str(commit_resp.status_code) + " in " + str(commit_resp.elapsed.microseconds/1000) + "ms for URL " + commit_url)
    if commit_resp.status_code != 200:
        return None
    commit_bytes=commit_resp.content
    raw_commit=GLib.Variant.new_from_bytes(GLib.VariantType("(a{sv}aya(say)sstayay)"), GLib.Bytes.new(commit_bytes), True).unpack()
    return raw_commit

# commits, hashes, etc. are represented by a list of ints when deserialized from the GObject.
# This is a convenience function to stringify them
def b2h (bytelist):
    try:
        r=bytes(bytelist).hex()
    except:
        r=bytelist
    return r

# /**
#  * OSTREE_COMMIT_GVARIANT_FORMAT: (a{sv}aya(say)sstayay)
#  *
#  * - a{sv} - Metadata
#  * - ay - parent checksum (empty string for initial)
#  * - a(say) - Related objects
#  * - s - subject
#  * - s - body
#  * - t - Timestamp in seconds since the epoch (UTC, big-endian)
#  * - ay - Root tree contents
#  * - ay - Root tree metadata
#  */
#
# Takes a raw commit object (and a commit_id, because the commit doesn't know its own ID)
def commit_to_target (raw_commit, commit_id, refname=""):

    # dates come out as ints, but they are big-endian, so we have to convert to bytes, reverse, and then convert
    # back to the "real" date int (seconds since epoch, UTC)
    date=DT.datetime.utcfromtimestamp(int.from_bytes(raw_commit[5].to_bytes(8,'little'),'big')).isoformat() + "Z"

    # there should be metadata with every commit, telling us all the info we need.
    # But sometimes there isn't, so we use some fallback values
    base = raw_commit[0].get('oe.distro-codename', refname.split("/")[0])
    machine = raw_commit[0].get('oe.machine', refname.split("/")[1])
    variant = raw_commit[0].get('oe.distro', refname.split("/")[2]) # e.g. torizon-upstream-rt
    image = raw_commit[0].get('oe.image', refname.split("/")[3])
    build_type = raw_commit[0].get('oe.tdx-build-purpose', refname.split("/")[4]) # e.g. nightly, monthly, etc
    name = '/'.join([base, machine, variant, image, build_type])
    version = raw_commit[0].get('version', commit_id)
    hardware_id = raw_commit[0].get('oe.sota-hardware-id', machine)

    # uptane target format
    target={
        'hashes': {
            'sha256': commit_id
        },
        'length': 0,
        'custom': {
            "cliUploaded": False,
            "name": name,
            "version": version,
            "hardwareIds": [
                hardware_id
            ],
            "targetFormat": "OSTREE",
            "createdAt": date,
            "updatedAt": date,
            "uri": REPO_HOST_BASEURL
        }
    }

    return target


# Refs only point to their current head; to get a log you have to recurse through
# the parents of everything on the branch until you find an orphan. We're passing
# in and mutating a container object (targets_container) that will hold
# the targets. It's structured so that it can be used directly as targets metadata
# when written out as JSON.
def ref_to_targets (commit_id, targets_container, ref_name=""):
    commit=get_raw_commit(commit_id)
    if not commit:
        # this is one completion case: if we try to fetch the parent and it doesn't exist,
        # it's been pruned (e.g. with nightlies that we only keep a certain amount)
        print(ref_name + " complete")
        return
    target=commit_to_target(commit, commit_id, ref_name)

    if commit[6]:
        target_key = target['custom']['name'] + "-" + target['custom']['version']
        targets_container[target_key] = target
    if commit[1]:
        ref_to_targets(b2h(commit[1]), targets_container, ref_name)
    else:
        # this is the other completion case: we found a commit with no parent, i.e. the first
        # commit of this ref.
        print(ref_name + " complete")

def generate_all_targets(targets_object):
    # Grab summary file, unpack the list of refs
    #
    # The summary file is a GVariant with typestring (a(s(taya{sv}))a{sv}). We just want to unpack
    # the refs portion of it (a(s(taya{sv}))) into a python object
    # /**
    #  * OSTREE_SUMMARY_GVARIANT_FORMAT:
    #  *
    #  * - a(s(taya{sv})) - Map of ref name -> (latest commit size, latest commit checksum, additional metadata), sorted by ref name
    #  * - a{sv} - Additional metadata, at the current time the following are defined:
    #  *   - key: "ostree.static-deltas", value: a{sv}, static delta name -> 32 bytes of checksum
    #  *   - key: "ostree.summary.last-modified", value: t, timestamp (seconds since
    #  *     the Unix epoch in UTC, big-endian) when the summary was last regenerated
    #  *     (similar to the HTTP `Last-Modified` header)
    #  *   - key: "ostree.summary.expires", value: t, timestamp (seconds since the
    #  *     Unix epoch in UTC, big-endian) after which the summary is considered
    #  *     stale and should be re-downloaded if possible (similar to the HTTP
    #  *     `Expires` header)
    #  *
    #  * The currently defined keys for the `a{sv}` of additional metadata for each commit are:
    #  *  - key: `ostree.commit.timestamp`, value: `t`, timestamp (seconds since the
    #  *    Unix epoch in UTC, big-endian) when the commit was committed
    #  */
    #
    summary_bytes=requests_session.get(REPO_BASEURL + "summary", stream=True).content
    REFS=GLib.Variant.new_from_bytes(GLib.VariantType("(a(s(taya{sv}))a{sv})"),
                                     GLib.Bytes.new(summary_bytes), False).unpack()[0]

    # Now we need to find out where the tip of each branch is pointing
    REF_HEADS={}
    for ref in REFS:
        head_commit_id=b2h(ref[1][1])
        ref_name=ref[0]
        REF_HEADS[ref_name]=head_commit_id

    # Finally, recurse through each ref until we find all commits in the ref. We do this
    # multithreaded because otherwise it's slow. Yes, we're passing in and mutating a shared
    # variable. But it's a dict, and there will never be more than one thread operating on
    # any one key.
    threads = []
    for key in REF_HEADS:
        t = Thread(target=ref_to_targets, args=(REF_HEADS[key], targets_object, key))
        threads.append(t)
        time.sleep(0.1) # requests errors without this
        print(key + " started")
        t.start()

    for t in threads:
        t.join()

def generate_metadata_files(name, regex_includes, regex_excludes, glob, targets_object):
    delegated_targets={}
    # Apply the specified regexes. This will become .signed.targets in the output
    for regex in regex_includes:
        delegated_targets.update({k:v for (k,v) in targets_object.items() if re.search(regex, k)})
    for regex in regex_excludes:
        delegated_targets={k:v for (k,v) in targets_object.items() if not re.search(regex, k)}

    resp=requests_session.get("https://commontorizon.dev/delegations/" + name + ".json", stream=True)
    status=resp.status_code
    if status == 404:
        print("Could not find https://commontorizon.dev/delegations/" + name + ".json. Generating metadata file at version 1")
        new_version=1
    else:
        current_delegation=json.loads(resp.content)

        # If there aren't any changes, don't bother bumping anything.
        if current_delegation["signed"]["targets"] == delegated_targets:
            print("No changes in delegation " + name)
            return

        #print the diff, if there is one
        print("Changes in " + name + ":")
        current_lines = '\n'.join(['%s:%s' % (key, value) for (key, value) in sorted(current_delegation["signed"]["targets"].items())])
        new_lines = '\n'.join(['%s:%s' % (key, value) for (key, value) in sorted(delegated_targets.items())])
        for diffs in difflib.context_diff(current_lines.splitlines(), new_lines.splitlines(), fromfile='old_metadata', tofile='new_metadata', n=0):
                print(diffs)

        new_version=current_delegation["signed"]["version"] + 1

    unsigned_delegation={
        "expires": "2025-01-01T00:01:00Z",
        "targets": delegated_targets,
        "version": new_version,
        "_type": "Targets"
    }
    if "nightly" in name:
        unsigned_delegation["expires"] = (DT.datetime.utcnow() + DT.timedelta(days=30)).isoformat(timespec="seconds")+'Z'
    with open(name + ".unsigned.json", "w") as outfile:
        json.dump(unsigned_delegation, outfile)

    delegation_info={
        "keys":
        [
            {
            "keyval":
                {
                    "public": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2BhdXWlm4p8CBOSum/KQ\nNOUEowMCARXFmmtHCM7ySY6k5IxiLKPjAq1+nx6gCv+NQHiiJaj6w2JvU5Udmdic\nxZg6FDLGAO8YXKjapo67Qtgjd+Clv75yR1p6RaWh1jlpM35jMsNuml9NSTIxIow4\n7qRLUcMlTNRJR88dJISmvYiSWFAlwAG+8O7neo1sd/8XdQI4pIKDi4A+MYg6inOn\nr0hJhoB/uX5w2Wi5f6D+pSskj9Mk9FabJauyiGxtZJ/PjRc9ybswVy/Rur5SWMoH\nsWNQnbXJOcowsQWiTeRU46WnYTJrnnE/fhYes/Bky7xjws1tcPrdM7Rds51lzkqx\nxwIDAQAB\n-----END PUBLIC KEY-----\n"
                },
                "keytype": "RSA"
            }
        ],
        "delegationMetadata":
        {
            "name": name,
            "keyids":
            [
                "7af0882cd04c34d2801dead7402e8bd2327d3648788cca406fe78ac09e568681"
            ],
            "paths":
            [
                glob
            ],
            "threshold": 1,
            "terminating": True
        },
        "fetchUrl":
        {
            "uri": "https://commontorizon.dev/delegations/" + name + ".json",
            "delegationName": name
        }
    }
    with open("add-" + name + ".json", "w") as outfile:
        json.dump(delegation_info, outfile)

REPO_BASEURL="https://commontorizon.dev/ostree-repo/"
REPO_HOST_BASEURL="https://commontorizon.dev/ostree-repo/"

BLACKLISTED_RELEASES=[
    "0\\.0\\.0",
]

OUTPUT_DELEGATIONS=[
    {
        'name':'tdx-common',
        'regex_includes': [
            'release'
        ],
        'regex_excludes': [],
        'glob':'*/release-*'
    }
]

MACHINES=[
    "beaglebone-yocto",
    "beagleplay",
    "genericx86-64",
    "intel-corei7-64",
    "nezha-allwinner-d1",
    "qemuarm64",
    "qemux86-64",
    "raspberrypi0-2w-64",
    "raspberrypi0-wifi",
    "raspberrypi3-64",
    "raspberrypi4-64",
]

all_targets={}
start_time=time.time()
generate_all_targets(all_targets)
end_time=time.time()
elapsed_time = end_time - start_time
print('Generated all targets in ', elapsed_time, ' seconds')


for regex in BLACKLISTED_RELEASES:
    all_targets={k:v for (k,v) in all_targets.items() if not re.search(regex, k)}

for delegation in OUTPUT_DELEGATIONS:

    # Generate main delegations
    generate_metadata_files(
        delegation['name'],
        delegation['regex_includes'],
        delegation['regex_excludes'],
        delegation['glob'],
        all_targets
        )
    for machine in MACHINES:
        # For each main delegation, generate a delegation specific to one machine
        generate_metadata_files(
            delegation['name'] + '-' + machine,
            ['/' + machine + '/.+' + rx for rx in delegation['regex_includes']],
            delegation['regex_excludes'],
            '*/' + machine + '/' + delegation['glob'],
            all_targets
            )
