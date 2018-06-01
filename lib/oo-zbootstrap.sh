#!/usr/bin/env bash
# bootstrap script for tar gzip files
#
###########################
### BOOTSTRAP FUNCTIONS ###
###########################

if [[ -n "${__INTERNAL_LOGGING__:-}" ]]
then
  alias DEBUG=":; "
else
  alias DEBUG=":; #"
fi


System::SourceTarFile() {
  local tarFile=$1
  local script=$2
  tar -tvf $tarFile $script 1>/dev/null
  if [ "$?" != "0" ]; then
    cat <<< "script file $script no exists" 1>&2
    exit 1
  fi
  local tmpFile=$(mktemp)
  tar -xOf $tarFile $script > $tmpFile
  builtin source $tmpFile
  rm -f $tmpFile
}

System::Bootstrap() {
  ## note: aliases are visible inside functions only if
  ## they were initialized AFTER they were created
  ## this is the reason why we have to load files in a specific order
  if ! System::Import Array/Contains
  then
    cat <<< "FATAL ERROR: Unable to bootstrap (missing lib directory?)" 1>&2
    exit 1
  fi
}

declare -g __oo_payload=oo.tar.gz
set -o pipefail
shopt -s expand_aliases

System::ImportOne() {
  local requestedPath=lib/$1.sh
  System::SourceTarFile $__oo_payload $requestedPath
}

System::Import() {
  local libPath
  for libPath in "$@"
  do
    System::ImportOne "$libPath"
  done
}

namespace() { :; }
throw() { eval 'cat <<< "Exception: $e ($*)" 1>&2; read -s;'; }

alias import="System::Import"
alias source="System::ImportOne"

declare -g __oo__bootstrapped=true
