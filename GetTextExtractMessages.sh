#!/bin/bash

# use gettext utilities to update translation file (.po, .mo)
# execute the following commands from the directory that contains the script

# extract messages from source code into InitialWorkflowModuleExtracted.po
xgettext InitialWorkflowModule.lua -d InitialWorkflowModuleExtracted --from-code=UTF-8 --language=Lua

# merge new messages into existing translation files:
msgmerge -U locale/de/LC_MESSAGES/InitialWorkflowModule.po InitialWorkflowModuleExtracted.po

# create binary .mo file
msgfmt -v locale/de/LC_MESSAGES/InitialWorkflowModule.po -o locale/de/LC_MESSAGES/InitialWorkflowModule.mo