#!/bin/bash

#this script should build pypi pkg from specified branch and revision

#common debian reqs:
#devscripts fakeroot build-essential debhelper

#in params:
#<projectname> <branch> [revisionid] [reposerver]

PROGNAME=$(basename $0)

#PRJNAME="frontend.2.0"

function print_usage(){
    echo "this script may accept next params"
    echo "-P projectname - name of the project we are building, like frontend2.0, search, tornado and such. should be the same as github repo name."
    echo "-B branch - branch to checkout"
    echo "-R revision id - revision to check out"
    echo "-S reposerver - ssh servername in format user@host, like git@github.com"
    echo "-E environment"
    echo ""
    echo "example:"
    echo "$PROGNAME -P apilib -B master -R fcd3d2c172d244bf3355efff86ee7800702ce69f -S git@github.com -E dev"
}
print_help() {
    echo ""
    print_usage
    echo ""
}

if [ -z $2 ];then
    print_usage;
    exit 1
fi

# parsing arguments

while getopts ":hP:B:R:S:L:E:" Option; do
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
    E)
      ENVIRONMENT="${OPTARG}"
      ;;
    *)
      print_help
      exit 1
      ;;
  esac
done
shift $(($OPTIND - 1))

REVID=${REVID_PARAM:-NONE}
REPOSERVER=${REPOSERVER_PARAM:-github-${PRJNAME}}
REPOURL="${REPOSERVER}:kupishoes/${PRJNAME}.git"
ENVIRONMENT=${ENVIRONMENT:-dev}

BUILDDIR=$(mktemp -d -p . -t ${PRJNAME}-XXXXXX)
pushd -n $PWD
cd ${BUILDDIR} 
bdir="$PWD"
(
git clone "${REPOURL}" "${PRJNAME}" && \
cd "${PRJNAME}" && \
BRANCHCUR=$(git branch|grep '^*'|cut -f 2 -d ' ') && \
if [ $BRANCH != "$BRANCHCUR" ];then
    git checkout -b $BRANCH origin/$BRANCH
else
    echo "branch is specified as $BRANCH, skipping additional checkout"
fi && \
if [ "$REVID" != "NONE" ];then
    git reset --hard "$REVID"
fi
)
if [ $? -ne 0 ];then
    echo "git operations failed, exiting"
    exit 1
fi

pwd && ls -la
#--suppress-packaging-version=True
cd "${PRJNAME}" &&\
python setup.py sdist || exit 1

ssh pypi.moda.local mkdir /data/pypi/local/${ENVIRONMENT}/${PRJNAME}
scp dist/*.tar.gz pypi.moda.local:/data/pypi/local/${ENVIRONMENT}/${PRJNAME}/ || exit 1
cat ${PRJNAME}.egg-info/PKG-INFO
