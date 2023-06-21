#!/bin/bash

# create a release archive to be released on GitHub

# archive is created in a separate folder
BaseFolder=./Release

# update gettext translation files
./GetTextExtractMessages.sh

# empty current Release folder recursively
rm $BaseFolder/* -r -d -f

# copy files using rsync
# exclude files that are relevant for development only
rsync -rtv --delete --delete-excluded\
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


# create git archive
git archive --format=zip --output=$BaseFolder/Sources.zip development

# create release archive
cd $BaseFolder
zip -r InitialWorkflowModule.zip InitialWorkflowModule/