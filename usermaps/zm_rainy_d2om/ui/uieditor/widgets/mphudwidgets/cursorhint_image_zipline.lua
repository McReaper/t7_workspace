-- Rewrite of CoD.cursorhint_image (the icon inside ZMCursorHint). LuiLoad-ed after
-- the stock (require case MUST match ZMCursorHint's "MPHudWidgets" to share the
-- module cache). ZMCursorHint indexes children c1x1/x1x4/c1x2 by name, so we keep
-- them, no-op their setImage, and drive the picture from the cursorHintImage model.
--
-- Every HINT_ACTIVATE pushes the same image ("hud_grenadethrowback_glow"), so we
-- tell the zipline apart by its hint text. The model text and Engine.Localize(ref)
-- render identically but differ byte-wise (resolved key vs "[{+activate}]", caret/
-- space encodings), so we reduce both to letters-only and test containment. The
-- zipline draws the trolley icon; every other interaction draws interact_icon.

require("ui.uieditor.widgets.MPHudWidgets.cursorhint_image")

local ZIPLINE_HINT_IMAGE = "zipline_hint"
local INTERACT_IMAGE = "interact_icon"
local ACTIVATE_IMG = "hud_grenadethrowback_glow"
local ZIPLINE_REF = "ZIPLINE_USE"

local ICON_HALF = 24

-- Reduce a hint string to comparable content: drop the [{+bind}] token (so
-- "activate" doesn't leak in), then keep ASCII letters and every non-ASCII byte
-- (CJK/Cyrillic/accented text) while dropping ASCII non-letters (caret color codes,
-- digits, the various space encodings). Works for all 12 languages, not just Latin.
local function letters(s)
    return ((s or ""):gsub("%[{%+%w+}%]", ""):gsub("[^%a\128-\255]", ""))
end

CoD.cursorhint_image = InheritFrom(LUI.UIElement)

function CoD.cursorhint_image.new(menu, controller)
    local self = LUI.UIElement.new(menu, controller)
    self:setUseStencil(false)
    self:setClass(CoD.cursorhint_image)
    self.id = "cursorhint_image"
    self.soundSet = "HUD"

    local icons = {}
    local function newIcon()
        local icon = LUI.UIImage.new(menu, controller)
        icon:setLeftRight(true, false, 0, 2 * ICON_HALF)
        icon:setTopBottom(false, false, -ICON_HALF, ICON_HALF)
        icon.setImage = function() end
        self:addElement(icon)
        icons[#icons + 1] = icon
        return icon
    end

    self.c1x1 = newIcon()
    self.x1x4 = newIcon()
    self.c1x2 = newIcon()

    local ziplineLetters = letters(Engine.Localize(ZIPLINE_REF))
    local lastImg = ""
    local isZipline = false
    local function decide()
        local img = lastImg
        if lastImg == ACTIVATE_IMG then
            img = isZipline and ZIPLINE_HINT_IMAGE or INTERACT_IMAGE
        end
        if img and img ~= "" then
            for i = 1, #icons do
                LUI.UIImage.setImage(icons[i], RegisterImage(img))
            end
        end
    end

    self:subscribeToGlobalModel(menu, "HUDItems", "cursorHintImage", function(model)
        lastImg = Engine.GetModelValue(model) or ""
        decide()
    end)
    self:subscribeToGlobalModel(menu, "HUDItems", "cursorHintText", function(model)
        isZipline = ziplineLetters ~= "" and letters(Engine.GetModelValue(model)):find(ziplineLetters, 1, true) ~= nil
        decide()
    end)

    LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
        element.c1x1:close()
        element.x1x4:close()
        element.c1x2:close()
    end)

    return self
end
