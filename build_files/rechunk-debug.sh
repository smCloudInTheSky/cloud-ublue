#!/usr/bin/env bash
# Replays the exact `rpm` query that chunkah runs when loading the rpmdb, but
# writes to files instead of a pipe.
#
# chunkah pipes `rpm -qa --queryformat ...` into a Rust parser. If that parser
# bails early it drops the reader, which closes the pipe and sends SIGPIPE
# (signal 13) to `rpm`, masking the real error. Writing to a file avoids the
# pipe so the genuine exit code and stderr are captured.
#
# Expected to run inside the chunkah container with:
#   - the target rootfs mounted at /chunkah
#   - a writable directory mounted at /run/out
set -x

echo "==> rpm version"
rpm --version

echo "==> basic: rpm -qa (package list)"
rpm --root /chunkah --dbpath /usr/lib/sysimage/rpm -qa \
    > /run/out/packages.txt 2> /run/out/basic.err
echo "basic rc=$?" | tee /run/out/basic.rc

echo "==> full: rpm -qa --queryformat (exactly what chunkah parses)"
QF='@@PKG@@\t%{NAME}\t%{VERSION}\t%{RELEASE}\t%{EPOCH}\t%{ARCH}\t%{LICENSE}\t%{SIZE}\t%{BUILDTIME}\t%{INSTALLTIME}\t%{SOURCERPM}\t%{FILEDIGESTALGO}\n[@@FILE@@\t%{FILENAMES}\t%{FILESIZES}\t%{FILEMODES}\t%{FILEMTIMES}\t%{FILEDIGESTS}\t%{FILEFLAGS}\t%{FILEUSERNAME}\t%{FILEGROUPNAME}\t%{FILELINKTOS}\n][@@CL@@\t%{CHANGELOGTIME}\n]'
rpm --root /chunkah --dbpath /usr/lib/sysimage/rpm -qa --queryformat "$QF" \
    > /run/out/queryformat.txt 2> /run/out/full.err
echo "full rc=$?" | tee /run/out/full.rc
