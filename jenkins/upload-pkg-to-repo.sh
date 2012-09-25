#!/bin/bash

#this script should upload builded package(s) to some host, not bad idea
#to do uploads into reprepro powered server. See README for more info.

#in params:
#<projectname> <reponame>

PROGNAME=$(basename $0)


function usage(){
    echo "this script may accept next params:"
    echo "<projectname> - name of the projects , like frontend.2.0, madmin, and so on (corresponds to git repo)"
    echo "<reponame> - name of the repo, which is configured in ~/.dput.cf, like repo-dev (corresponds to reprepro repo)"
    echo ""
    echo "example:"
    echo "$PROGNAME frontend.2.0 repo-dev"
    echo "$PROGNAME madmin repo-dev"
}

if [ -z $2 ];then
    usage;
    exit 1
fi
PRJNAME=${1:-frontend.2.0}
STATUSFILE="status.${PRJNAME}"
REPONAME="$2"

echo "uploading project $PRJNAME , using $STATUSFILE for data"
read changes < "$STATUSFILE"
echo "using $changes as .changes file"
if ! [ -f "$changes" ];then
    echo "file $changes doesn't exist, exiting"
    exit 1
fi


#we should add predifined repo names here, just make sure not to upload data into some strange repo, like debian ;)
#TODO
dput -f -u "$REPONAME" "$changes"
if [ $? -ne 0 ];then
    echo "dput failed, check config, and .changes file"
    exit 1
fi
