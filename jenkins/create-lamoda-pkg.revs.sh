#!/bin/bash

#this script should build frontend from specified branch and revision

#common debian reqs:
#devscripts fakeroot build-essential debhelper

#in params:
#<projectname> <branch> [revisionid] [reposerver]

PROGNAME=$(basename $0)

#PRJNAME="frontend.2.0"

function print_usage(){
    echo "this script may accept next params"
    echo "projectname - name of the project we are builing, like frontend2.0, search, tornado and such. should be the same as github repo name."
    echo "branch - branch to checkout"
    echo "revision id - revision to check out"
    echo "reposerver - ssh servername in format user@host, like git@github.com"
    echo ""
    echo "example:"
    echo "$PROGNAME frontend2.0 release fcd3d2c172d244bf3355efff86ee7800702ce69f"
}
print_help() {
    echo ""
    print_usage
    echo ""
}

if [ -z $2 ];then
    usage;
    exit 1
fi

# parsing arguments

while getopts ":hP:B:R:S:L:" Option; do
  case $Option in
    h)
      print_help
      exit 0
      ;;
    P)
      PRJNAME="${OPTARG}"
      ;;
    B)
      BRANCH="${OPTARG}"
      ;;
    R)
      REVID_PARAM="${OPTARG}"
      ;;
    S)
      REPOSERVER_PARAM="${OPTARG}"
      ;;
    L)
      LOCALDIR_PARAM="${OPTARG}"
      ;;
    *)
      print_help
      exit 0
      ;;
  esac
done
shift $(($OPTIND - 1))

#PRJNAME="$1"
#BRANCH="$2"
REVID=${REVID_PARAM:-NONE}
REPOSERVER=${REPOSERVER_PARAM:-github-${PRJNAME}}
REPOURL="${REPOSERVER}:mycompany/${PRJNAME}.git"
LOCALDIR=${LOCALDIR_PARAM:-NONE} #for such non-lucky soft which doesn't have own repo ;(

STATUSFILE="status.${PRJNAME}"
BUILDDIR=$(mktemp -d -p . -t ${PRJNAME}-XXXXXX)
pushd -n $PWD
cd ${BUILDDIR} 
bdir="$PWD"
if [[ "x${LOCALDIR}" != "xNONE" ]];then
    bdir=$(dirname "$bdir/${PRJNAME}/${LOCALDIR}")
fi
(
git clone "${REPOURL}" "${PRJNAME}" && \
cd "${PRJNAME}" && \
BRANCHCUR=$(git branch|grep '^*'|cut -f 2 -d ' ') && \
if [ $BRANCH != "$BRANCHCUR" ];then
    git checkout -b $BRANCH origin/$BRANCH
else
    echo "branch is specified as master, skipping additional checkout"
fi && \
if [ "$REVID" != "NONE" ];then
    git reset --hard "$REVID"
fi
)
if [ $? -ne 0 ];then
    echo "git operations failed, exiting"
    exit 1
fi
#buildscripts/debbuild.sh 2>&1 |tee -a ../buildlog.log
pwd && ls -la
if [[ "x${LOCALDIR}" = "xNONE" ]];then
    cd "${PRJNAME}" && buildscripts/debbuild.sh 1>../buildlog.log 2>&1
    bcode=$?
else
    cd "${PRJNAME}" && cd "${LOCALDIR}" && buildscripts/debbuild.sh 1>../buildlog.log 2>&1
    bcode=$?

fi
if [ $bcode -eq 0 ];then
    echo "your packages should be available in $BUILDDIR"
else
    echo "buildpackage failed, check buildlog.log in $bdir"
    exit 1
fi
lcount=$(egrep '^ dpkg-genchanges.*\.changes$' ../buildlog.log|wc -l)

popd
#echo $PWD
if [ $lcount -ne 1 ];then
    echo "looks like no changes file was generated (or overgenerated ;)"
    exit 1
else
    echo "changes should be in:$bdir"
    changes=("$bdir"/*.changes)
    echo "writing path to changes '$changes' file into status file '$STATUSFILE'"
    echo "$changes" > "$STATUSFILE"
fi
