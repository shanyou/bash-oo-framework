#!/usr/bin/env bash
#set -x
## BOOTSTRAP ##
source "$( cd "${BASH_SOURCE[0]%/*}" && pwd )/oo.sh"
import util/log
import util/buildFun
echo generate a new tag: $(gen_tag)
# using colors:
echo "$(UI.Color.Blue)I'm blue...$(UI.Color.Default)"

# enable basic logging for this file by declaring a namespace
namespace myApp
# make the Log method direct everything in the namespace 'myApp' to the log handler called DEBUG
Log::AddOutput myApp DEBUG

# now we can write with the DEBUG output set
Log "Play me some Jazz, will ya? $(UI.Powerline.Saxophone)"

# redirect error messages to STDERR
Log::AddOutput error STDERR
subject=error Log "Something bad happened."

# reset outputs
Log::ResetAllOutputsAndFilters

# You may also hardcode the use for the StdErr output directly:
Console::WriteStdErr "This will be printed to STDERR, no matter what."
