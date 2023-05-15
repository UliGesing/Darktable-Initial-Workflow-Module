#!/bin/bash

xgettext InitialWorkflowModule.lua -d InitialWorkflowModuleExtracted --from-code=UTF-8 --language=Lua

msgmerge -U locale/de/LC_MESSAGES/InitialWorkflowModule.po InitialWorkflowModuleExtracted.po

msgfmt -v locale/de/LC_MESSAGES/InitialWorkflowModule.po -o locale/de/LC_MESSAGES/InitialWorkflowModule.mo