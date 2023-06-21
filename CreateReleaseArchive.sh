#!/bin/bash

# archive is created in a separate folder
BaseFolder=./Release

echo -e "=================================================="
echo -e "create a release archive and a git sources archive"
echo -e "=================================================="

echo -e "\nupdate gettext translation files"
./GetTextExtractMessages.sh

echo -e "\nempty current Release folder recursively"
rm $BaseFolder/* -r -d -f

echo -e "\ncopy files using rsync"
# exclude files that are relevant for development only
rsync -rtq --delete --delete-excluded\
 --exclude=Release/\
 --exclude=.git/\
 --exclude=*.po\
 --exclude=*.po~\
 --exclude=.gitignore\
 --exclude=.gitattributes\
 --exclude=CreateReleaseArchive.sh\
 --exclude=GetTextExtractMessages.sh\
 --exclude=main.lqa\
 --exclude=TestCustomCode.lua\
 --exclude=TestFlag.txt\
 ./ $BaseFolder/InitialWorkflowModule


echo -e "\ncreate git archive"
stashName=`git stash create`;
git archive --format=zip --output=$BaseFolder/Sources.zip $stashName
git gc --prune=now

echo -e "\ncreate release archive"
cd $BaseFolder
zip -rq InitialWorkflowModule.zip InitialWorkflowModule/