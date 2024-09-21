local du = require 'lib/dtutils'

local Helper = {}

function Helper.Init(_dt, _LogHelper, _TranslationHelper, _ModuleName)
  dt = _dt
  LogHelper = _LogHelper
  TranslationHelper = _TranslationHelper
  ModuleName = _ModuleName
end

-- return translation from local .po / .mo file
local function _(msgid)
  return TranslationHelper.t(msgid)
end

-- return translation from darktable
local function _dt(msgid)
  return TranslationHelper.tdt(msgid)
end

-- add quote marks
function Helper.Quote(text)
  return '"' .. text .. '"'
end

function Helper.ThreadSleep(milliseconds)
  dt.control.sleep(milliseconds)
end

function Helper.CheckApiVersion()
  -- check Darktable API version
  -- new API of DT 4.8 is needed to use pixelpipe-processing-complete event
  local apiCheck, err = pcall(function() du.check_min_api_version('9.3.0', ModuleName) end)
  if (apiCheck) then
    LogHelper.Info(string.format(_("darktable version with appropriate lua API detected: %s"),
      'dt' .. dt.configuration.version))
  else
    LogHelper.Info(_("this script needs at least darktable 4.8 API to run"))
    return false
  end

  return true
end


-- get Darktable workflow setting
-- read preference 'auto-apply chromatic adaptation defaults'
function Helper.CheckDarktableModernWorkflowPreference()
  local modernWorkflows =
  {
    _dt("scene-referred (filmic)"),
    _dt("scene-referred (sigmoid)"),
    _dt("modern")
  }

  local workflow = dt.preferences.read('darktable', 'plugins/darkroom/workflow', 'string')

  return Helper.Contains(modernWorkflows, _(workflow))
end


-- check, if given array contains a certain value
function Helper.Contains(table, value)
  for i, element in ipairs(table) do
    if element == value then
      return true
    end
  end
  return false
end

-- word wrapping, e.g. used for tooltips
-- based on http://lua-users.org/wiki/StringRecipes
function Helper.Wordwrap(str, limit)
  limit = limit or 50
  local here = 1
  local function check(sp, st, word, fi)
    if fi - here > limit then
      here = st
      return '\n' .. word
    end
  end
  return str:gsub('(%s+)()(%S+)()', check)
end

-- debug helper function to dump preference keys
-- helps you to find out strings like plugins/darkroom/chromatic-adaptation
-- darktable -d lua > ~/keys.txt
-- local function DumpPreferenceKeys()
--   local keys = dt.preferences.get_keys()
--   LogHelper.Info(string.format(_.t("number of %d preference keys retrieved"), #keys))
--   for _, key in ipairs(keys) do
--     LogHelper.Info(key .. ' = ' .. dt.preferences.read('darktable', key, 'string'))
--   end
-- end

-- convert given number to string
function Helper.NumberToString(number, nilReplacement, nanReplacement)
  -- convert given number to string
  -- return 'not a number' and 'nil' as '0/0'
  -- log output equals to dt.gui.action command and parameters
  if (number ~= number) then
    return nanReplacement or '0/0'
  end

  if (number == nil) then
    return nilReplacement or '0/0'
  end

  -- some digits with dot
  local result = string.format('%.4f', number)
  result = string.gsub(result, ',', '.')

  return result
end

return Helper
