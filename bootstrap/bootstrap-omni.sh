#!/bin/bash
##############################################################################
# Bootstrap script for chef to be run on the remote server
# Version for OMNI
##############################################################################

. $(dirname $0)/config.sh

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

GIT=/usr/bin/git

mkdir -p $CHEF_ROOT

msg "Moving key in place"
safe mv $BOOTSTRAP_PATH/$KEY $CHEF_ROOT
safe chmod 600 $CHEF_ROOT/$KEY

if [[ -n $GIT_HOST ]]; then
    msg "Populating known hosts file"
    safe mkdir -p /root/.ssh/
    safe chmod 700 /root/.ssh/
    safe touch /root/.ssh/known_hosts
    safe chmod 600 /root/.ssh/known_hosts
    grep "$GIT_HOST" /root/.ssh/known_hosts > /dev/null ||
        safe ssh-keyscan -t rsa,dsa $GIT_HOST >> /root/.ssh/known_hosts
fi

msg "Making temporary git ssh wrapper to use the chef key"
# Git uses the GIT_SSH environment variable to decide what to do when sshing
export GIT_SSH="$BOOTSTRAP_PATH/git-ssh-wrapper.sh"
echo "ssh -i $CHEF_ROOT/$KEY \"\$@\"" > $GIT_SSH
chmod +x $GIT_SSH

pushd $CHEF_ROOT > /dev/null
if [[ -n $CONFIG_REPO ]]; then
    msg "Cloning config repository"
    safe $GIT clone $CONFIG_REPO config
fi
if [[ -n $COMMON_REPO ]]; then
    msg "Cloning common repository"
    safe $GIT clone $COMMON_REPO common
fi
if [[ -n $SCRIPTS_REPO ]]; then
    msg "Cloning scripts repository"
    safe $GIT clone $SCRIPTS_REPO scripts
fi
popd > /dev/null

msg "Creating local config"
cat > $CHEF_ROOT/scripts/config.sh <<EOT
# Fix various paths to get chef-solo working
export PATH=\$PATH:/opt/omni/lib/ruby/gems/1.9/gems/chef-0.10.8/bin
export GEM_PATH=/opt/omni/lib/ruby/gems/1.9
export GEM_HOME=/opt/omni/lib/ruby/gems/1.9

# Set path so git works
export PATH=\$PATH:/opt/omni/bin
EOT

msg "Running chef for the first time"
pushd $CHEF_ROOT/scripts > /dev/null
safe ./run_chef.sh -onv
popd > /dev/null
