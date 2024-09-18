local LogHelper = {}

local log = require 'lib/dtutils.log'
log.log_level(log.info) -- log.info or log.warn or log.debug

LogHelper.SummaryMessages = {}
LogHelper.MajorMax = 1
LogHelper.MajorNr = 1
LogHelper.CurrentStep = ''

function LogHelper.GetLogInfoText(text)
    return '[' .. LogHelper.MajorNr .. '/' .. LogHelper.MajorMax .. '] ' .. LogHelper.CurrentStep .. ': ' .. text
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
