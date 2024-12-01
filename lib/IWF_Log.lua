--[[
  This lua file is part of Darktable Initial Workflow Module

  copyright (c) 2022 Ulrich Gesing

  For more details see Readme.md in
  https://github.com/UliGesing/Darktable-Initial-Workflow-Module

  This script is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This script is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details
  at <http://www.gnu.org/licenses/>.
]]

-- This file provides helper functions to show some information during script run.

local LogHelper = {}

local log = require 'lib.dtutils.log'

function LogHelper.Init()
    log.log_level(log.info) -- log.info or log.warn or log.debug

    LogHelper.SummaryMessages = {}

    LogHelper.CurrentStep = ''
    LogHelper.MajorNr = 0
    LogHelper.MajorMax = 0
end

function LogHelper.GetLogInfoText(text)
    local prefix = ''
    if ((LogHelper.MajorNr ~= 0) or (LogHelper.MajorMax ~= 0)) then
        prefix = '[' .. LogHelper.MajorNr .. '/' .. LogHelper.MajorMax .. '] '
    end
    return prefix .. LogHelper.CurrentStep .. ': ' .. text
end

function LogHelper.Info(text)
    log.msg(log.info, LogHelper.GetLogInfoText(text))
end

function LogHelper.Screen(text)
    log.msg(log.screen, text)
end

function LogHelper.SummaryClear()
    for k, v in pairs(LogHelper.SummaryMessages) do
        LogHelper.SummaryMessages[k] = nil
    end
end

function LogHelper.SummaryMessage(text)
    table.insert(LogHelper.SummaryMessages, LogHelper.GetLogInfoText(text))
end

return LogHelper
