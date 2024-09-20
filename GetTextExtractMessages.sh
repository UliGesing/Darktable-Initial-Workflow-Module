#!/bin/bash

# use gettext utilities to update translation file (.po, .mo)
# execute the following commands from the directory that contains the script

# extract messages from source code into InitialWorkflowModuleExtracted.po
xgettext InitialWorkflowModule.lua ./Modules/Helper.lua ./Modules/EventHelper.lua -d InitialWorkflowModuleExtracted --from-code=UTF-8 --language=Lua


# GERMAN de
# merge new messages into existing translation files:
msgmerge -U locale/de/LC_MESSAGES/InitialWorkflowModule.po InitialWorkflowModuleExtracted.po
# create binary .mo file
msgfmt -v locale/de/LC_MESSAGES/InitialWorkflowModule.po -o locale/de/LC_MESSAGES/InitialWorkflowModule.mo


# SPANISH es
# merge new messages into existing translation files:
msgmerge -U locale/es/LC_MESSAGES/InitialWorkflowModule.po InitialWorkflowModuleExtracted.po
# create binary .mo file
msgfmt -v locale/es/LC_MESSAGES/InitialWorkflowModule.po -o locale/es/LC_MESSAGES/InitialWorkflowModule.mo