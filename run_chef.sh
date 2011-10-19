#!/bin/bash
# Script to run chef-solo with the right options

# Hack for when running under rvm (for testing)
[[ -f .rvmrc ]] && . .rvmrc

# Fix various paths to get chef-solo working
export PATH=$PATH:/opt/omni/lib/ruby/gems/1.8/gems/chef-0.10.4/bin
export GEM_PATH=/opt/omni/lib/ruby/gems/1.8
export GEM_HOME=/opt/omni/lib/ruby/gems/1.8

MYDIR=$PWD/`dirname $BASH_SOURCE[0]`
# Defaults
NODENAME=$(hostname)
#LOGFILE=/var/log/chef/solo.log
LOGFILE=$PWD/chef-solo.log
INTERVAL=10
SPLAY=30 # Random interval to inititally sleep to stagger chef runs
NO_GIT=
RUN_ONCE=

# Use a custom wrapper for ssh with git
export GIT_SSH=$MYDIR/scripts/git-ssh-wrapper.sh

log() {
    echo "$0: $@"
    echo "$0: $@" >> $LOGFILE
}

usage() {
    echo "Usage: $0 [options]"
    echo "Updates a chef repository from git, and runs chef-solo"
    echo
    echo "Options:"
    echo "    -h    -- help"
    echo "    -n    -- don't update using git before running chef-solo"
    echo "    -o    -- only run once"
    echo "    -i    -- override default interval ($INTERVAL)"
    echo "    -s    -- override default splay ($SPLAY)"
    echo "    -l    -- override the default logfile ($LOGFILE)"
    exit 1
}

while getopts ":hnoi:s:l:" opt; do
    case $opt in
        h)  usage
            ;;
        n)  NO_GIT=1
            ;;
        o)  RUN_ONCE=1
            ;;
        i)  INTERVAL=$OPTARG
            ;;
        s)  SPLAY=$OPTARG
            ;;
        l)  LOGFILE=$OPTARG
            ;;
        *)  echo "Invalid option -- '$OPTARG'"
            usage
            ;;
    esac
done
shift $(($OPTIND-1))

# If we're running multiple times, then have an initial random delay
if [[ -z $RUN_ONCE ]]; then
    DELAY=$((RANDOM % SPLAY))
    log "Sleeping for $DELAY seconds (inital stagger)..."
    sleep $DELAY
fi

while true; do
    # Update git
    [[ -z $NO_GIT ]] && git pull
    # Run chef-solo
    chef-solo -c $MYDIR/solo.rb \
        -j $MYDIR/nodes/$NODENAME.json \
        -N $NODENAME \
        -L $LOGFILE
    # Quit if we're only running once
    [[ -n $RUN_ONCE ]] && exit
    # Otherwise, wait and do it all over
    log "Sleeping for $INTERVAL seconds..."
    sleep $INTERVAL
done