local Helper = {}

function Helper.Init(_dt)
  Helper.dt = _dt
end

-- get path, where the main script was started from
function Helper.ScriptFilePath()
    local str = debug.getinfo(2, 'S').source:sub(2)
    return str:match('(.*[/\\])')
end

-- add quote marks
function Helper.Quote(text)
  return '"' .. text .. '"'
end

function Helper.ThreadSleep(milliseconds)
  Helper.dt.control.sleep(milliseconds)
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
