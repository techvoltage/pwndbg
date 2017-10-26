#!/bin/bash
set -ex


# Helper functions
ubuntu() {
    python -mplatform | grep -qi Ubuntu
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error with $1" >&2
    fi
    return $status
}
osx() {
    uname | grep -i Darwin &>/dev/null
}
centos() {
    python -mplatform | grep -qi centos
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error with $1" >&2
    fi
    return $status
}

PYTHON=''
INSTALLFLAGS=''

if osx || [ "$1" == "--user" ]; then
    INSTALLFLAGS="--user"
else
    PYTHON="sudo "
fi

if ubuntu; then
    sudo apt-get update || true
    sudo apt-get -y install gdb python-dev python3-dev python-pip python3-pip libglib2.0-dev libc6-dbg

    if uname -m | grep x86_64 > /dev/null; then
        sudo apt-get install libc6-dbg:i386 || true
    fi
fi

if centos; then
    sudo yum update || true
    sudo yum -y install epel-release
    sudo yum -y install gdb python-devel python34-devel python-pip python34-pip libglib2.0-dev glibc-devel yum-utils
    sudo debuginfo-install glibc
    if uname -m | grep x86_64 > /dev/null; then
        sudo yum -y install libc6-dbg:i386 || true
    fi
    #https://github.com/cyrus-and/gdb-dashboard/issues/1
    mkdir -p ~/.gdbinit.d/
    wget 'https://sourceware.org/git/gitweb.cgi?p=binutils-gdb.git;a=blob_plain;f=gdb/python/lib/gdb/FrameDecorator.py' -O ~/.gdbinit.d/FrameDecorator.py
    sed -i '1s/^/python gdb.COMPLETE_EXPRESSION = gdb.COMPLETE_SYMBOL\n/' ~/.gdbinit
cat >>~/.gdbinit <<EOF
python
import imp
gdb.FrameDecorator = imp.new_module('FrameDecorator')
gdb.FrameDecorator.FrameDecorator = FrameDecorator
end
EOF
fi

if ! hash gdb; then
    echo 'Could not find gdb in $PATH'
    exit
fi

# Update all submodules
git submodule update --init --recursive

# Find the Python version used by GDB.
PYVER=$(gdb -batch -q --nx -ex 'pi import platform; print(".".join(platform.python_version_tuple()[:2]))')
PYTHON+=$(gdb -batch -q --nx -ex 'pi import sys; print(sys.executable)')
PYTHON+="${PYVER}"

# Find the Python site-packages that we need to use so that
# GDB can find the files once we've installed them.
if ubuntu && [ -z "$INSTALLFLAGS" ]; then
    SITE_PACKAGES=$(gdb -batch -q --nx -ex 'pi import site; print(site.getsitepackages()[0])')
    INSTALLFLAGS="--target ${SITE_PACKAGES}"
fi

if centos && [ -z "$INSTALLFLAGS" ]; then
    SITE_PACKAGES=$(gdb -batch -q --nx -ex 'pi import site; print(site.getsitepackages()[0])')
    INSTALLFLAGS="--target ${SITE_PACKAGES}"
fi


# Make sure that pip is available
if ! ${PYTHON} -m pip -V; then
    ${PYTHON} -m ensurepip ${INSTALLFLAGS} --upgrade
fi

# Upgrade pip itself
${PYTHON} -m pip install ${INSTALLFLAGS} --upgrade pip

# Install Python dependencies
${PYTHON} -m pip install ${INSTALLFLAGS} -Ur requirements.txt
echo hi
# Load Pwndbg into GDB on every launch.
if ! grep pwndbg ~/.gdbinit &>/dev/null; then
    echo "source $PWD/gdbinit.py" >> ~/.gdbinit
fi
