#!/bin/bash

#partially borrowed from http://www.debian-administration.org/articles/286

PROGNAME=$(basename $0)
CONFIGDIR=configs
LOGGER='logger -t pkg-uploader --'


function mylog() {
    if [ -z "$1" ];then return 0;fi #exiting if msg is empty
    if [ "x$1" == "x-e" ];then
        echo "$2"
        $LOGGER "$2"
    else
        $LOGGER "$1"
    fi
}

function myexit() {
    extcode="$1"
    if [ -z "$1" ];then extcode=0;fi
    #doing some cleanup
    if ! [ "x$2" == "xNO" ];then
        mylog "removing lockfile $LOCKFILE";rm -rf $LOCKFILE
    fi
    exit $extcode
}



function setlock() {
    #setting lock
    mylog "setting lockfile $LOCKFILE"
    exec 200<> $LOCKFILE
    flock -n -x 200
    if [ $? -ne 0 ];then
        mylog -e "setting lock on $LOCKFILE failed, exiting"
        myexit 1 "NO"
    fi
    echo $$ >&200
}

function removepkg() {
    #accepts path to .changes file, parses it and removes according packages
    local i pkglist CHANGESFILE
    CHANGESFILE="$1"
    pkglist=$(awk '
        /^Source:/{print $2}
        /^Description:/{
            while (1) {
                if (getline <= 0) { break }
                if (substr($0,1,1) != " ") { break }
                print $1
            }
        }' "${CHANGESFILE}" | sort | uniq)
    for i in $pkglist
    do
        mylog "removing package $i"
        CMD="reprepro --ignore=wrongdistribution -Vb "${CFG["repreproroot"]}" remove ${DISTRIBUTION} $i"
        rep_result=$($CMD)
        rep_code=$?
        if [ $rep_code -ne 0 ];then
            mylog -e "failed to remove package $i"
            myexit 1
        fi
    done
}

function print_usage() {
    echo "Usage: $PROGNAME -D <distribution> [-c <configpath>] [-S <sleeptimeout>]"
    echo ""
    echo "-c     contains path to config file. default file is $CONFFILE"
    echo "-D     specifies distribution you want add packages to"
    echo "-S     specifies sleep timeout in seconds before taking actions, to be used with incron"
    echo "use -h to show this help"
}                                                                                                 
function print_help() {
    echo ""
    print_usage
    echo ""
    echo "this script should scan certain directory for .changes files and do import packages into specified distribution"
}

function getconfigdir() {
    echo $(dirname $(readlink -f "$0"))
}


# parsing arguments

while getopts ":hD:c:S:" Option; do
  case $Option in
    h)
      print_help
      exit 0
      ;;
    c)
      CONFFILE=${OPTARG}
      ;;
    D)
      DISTRIBUTION=${OPTARG}
      ;;
    S)
      SLEEPTIME=${OPTARG}
      ;;
    *)
      print_help
      exit 0
      ;;
  esac
done
shift $(($OPTIND - 1))


#checking if running under root
if [[ $EUID -eq 0 ]];then
    mylog -e "this script shouldn't be run under root account!"
    mylog -e "starting it under root is possible, but veeeeery expensive!"
    myexit 2
fi

DISTRIBUTION=${DISTRIBUTION:-NONE}

cfgdir=$(getconfigdir)/${CONFIGDIR}

#validating options

#distribution, as described in /srv/reprepro-dev/conf/distributions
if [[ ${DISTRIBUTION} == "NONE" ]]; then
    mylog -e "distribution parameter is missing or wrong"
    print_help
    myexit 1
fi

#sleeping if needed
if [[ $SLEEPTIME -gt 0 ]];then
    mylog "sleeping for $SLEEPTIME seconds as requested"
    #read -t $SLEEPTIME || true
    sleep $SLEEPTIME || true
fi

LOCKFILE="/tmp/uploader.${DISTRIBUTION}.lock"

#including config file
declare -A CFG
#should be read from configs/config.$distribution.cfg file

#checking for config file existance:
configfile="$cfgdir/config.${DISTRIBUTION}.cfg"

#overriding from cmd line params, if exist:
configfile=${CONFFILE:-$configfile}

if ! [[ -r "$configfile" ]];then
    mylog -e "config file $configfile is not readable"
    myexit 1
fi

#including config file as variables
mylog "including config file $configfile"
(. $configfile)
if [[ $? -ne 0 ]];then
    mylog -e "test of config file $configfile failed";myexit 1
fi
. $configfile

do_exit=0
for i in "incomingpath" "repreproroot";do
    if [[ ${CFG["$i"]} == "" ]];then
        mylog -e "$i parameter is not set"
        do_exit=1
    fi
done
if [ $do_exit -ne 0 ];then
    mylog -e "exiting because of configuration error, check your config file"
    myexit 1
fi

INCOMING=${CFG["incomingpath"]}
mylog "processing $INCOMING directory..."

#
#  See if we found any new packages
#
found=0
for i in $INCOMING/*.changes; do
  if [ -e $i ]; then
    found=`expr $found + 1`
  fi
done


#
#  If we found none then exit
#
if [ "$found" -lt 1 ]; then
    mylog "no packages found, exiting"
    exit 0
fi

#setting lock
setlock

#
#  Now import each new package that we *did* find
#
for i in $INCOMING/*.changes; do

    #removing packages first
    removepkg "$i"
    # Import package into distribution.
    mylog "adding $i into ${DISTRIBUTION}"
    rep_result=$(reprepro --ignore=wrongdistribution -Vb "${CFG["repreproroot"]}" include "${DISTRIBUTION}" "$i")
    rep_code=$?
    if [ $rep_code -ne 0 ];then
        mylog -e "failed to add $i"
        myexit 1
    fi

    # Delete the referenced files
    sed '1,/Files:/d' $i | sed '/BEGIN PGP SIGNATURE/,$d' \
        | while read MD SIZE SECTION PRIORITY NAME; do

        if [ -z "$NAME" ]; then
           continue
        fi

        #
        #  Delete the referenced file
        #
        if [ -f "$INCOMING/$NAME" ]; then
            rm "$INCOMING/$NAME"  || exit 1
        fi
    done

    # Finally delete the .changes file itself.
    rm  $i
done
myexit 0
