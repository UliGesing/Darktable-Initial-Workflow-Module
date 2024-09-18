local _ = {}
_.gettext = nil

local ModuleName = 'InitialWorkflowModule'

---------------------------------------------------------------
-- Translations with gettext, see documentation for details:
-- https://docs.darktable.org/lua/stable/lua.api.manual/darktable/darktable.gettext/

-- use bash script GetTextExtractMessages.sh to update the .mo file

-- used to save translated words or sentences
local TranslationIndex = {}

-- used to get back the original text from translated text
-- used to address internal darktable API values
local ReverseTranslationIndex = {}


-- return translation from given context
local function GetTranslation(context, msgid)
    if (msgid == nil or msgid == '') then
        return ''
    end

    -- get already known translation
    local translation = TranslationIndex[msgid]
    if (translation ~= nil) then
        return translation
    end

    -- call gettext to get previously unknown translation
    translation = _.gettext.dgettext(context, msgid)

    -- save translated words or sentences
    -- save the other way round
    TranslationIndex[msgid] = translation
    ReverseTranslationIndex[translation] = msgid

    return translation
end

-- return translation from local .po / .mo file
function _.t(msgid)
    return GetTranslation(ModuleName, msgid)
  end
  
-- return translation from darktable
function _.dt(msgid)
    return GetTranslation('darktable', msgid)
  end
  

-- return concatenated translated words from darktable
-- darktable provides many translated text elements
-- combine these elements to new ones
function _.dtConcat(msgids)
    -- concat given message parts
    local message = ''
    for i, msgid in ipairs(msgids) do
      message = message .. msgid
    end
  
    -- get already known translation
    local translation = TranslationIndex[message]
    if (translation ~= nil) then
      return translation
    end
  
    -- concat previously unknown translation
    translation = ''
    for i, msgid in ipairs(msgids) do
      translation = translation .. _.dt(msgid)
    end
  
    -- save translated words or sentences
    -- save the other way round
    TranslationIndex[message] = translation
    ReverseTranslationIndex[translation] = message
  
    return translation
  end
  

  -- return reverse translation, the other way round
function _.GetReverseTranslation(text)
    local reverse = ReverseTranslationIndex[text]
  
    if (reverse ~= nil) then
      return reverse
    end
  
    return text
  end
  
  return _
