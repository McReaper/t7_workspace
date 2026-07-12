-- Full rewrite of the cursor-hint icon element (CoD.cursorhint_image, the image
-- inside ZMCursorHint). A map can't re-zone the stock path, so this file is
-- LuiLoad-ed after it and redefines the global (last-loaded-wins). We still
-- require the stock first (case MUST match ZMCursorHint's "MPHudWidgets") so it
-- shares the module cache and ZMCursorHint doesn't reload + clobber this.
--
-- ZMCursorHint reaches into this element's children BY NAME: its cursorHintImage
-- subscriptions call cursorhintimage0.c1x1 / .x1x4 / .c1x2 :setImage(...) (the
-- three aspect variants). Missing them = "attempt to index a nil value / Failed to
-- notify model subscription". So we recreate those three children, all one centered
-- square, and override their setImage to ignore ZMCursorHint's value (the hand) and
-- always draw the zipline icon. ZMCursorHint's clips drive the container's box/alpha
-- so it appears with the hint -- no hand, no poll, no clientfield. Relies on
-- cursor-hint icons being unused elsewhere.

require("ui.uieditor.widgets.MPHudWidgets.cursorhint_image")

-- APE image asset (source texture_assets/_reapy/ximages/trolley_icon.png),
-- zoned image,zipline_hint, Streamable OFF.
local ZIPLINE_HINT_IMAGE = "zipline_hint"
local ZIPLINE_HINT_HALF = 24 -- half-size of the square icon (px), tune

CoD.cursorhint_image = InheritFrom(LUI.UIElement)

function CoD.cursorhint_image.new(menu, controller)
    local self = LUI.UIElement.new(menu, controller)
    self:setUseStencil(false)
    self:setClass(CoD.cursorhint_image)
    self.id = "cursorhint_image"
    self.soundSet = "HUD"

    local function newIcon()
        local icon = LUI.UIImage.new(menu, controller)
        icon:setLeftRight(true, false, 0, 2 * ZIPLINE_HINT_HALF)
        icon:setTopBottom(false, false, -ZIPLINE_HINT_HALF, ZIPLINE_HINT_HALF)
        LUI.UIImage.setImage(icon, RegisterImage(ZIPLINE_HINT_IMAGE))
        -- Ignore whatever ZMCursorHint's subscription pushes (the hand); stay ours.
        icon.setImage = function(element)
            LUI.UIImage.setImage(element, RegisterImage(ZIPLINE_HINT_IMAGE))
        end
        self:addElement(icon)
        return icon
    end

    self.c1x1 = newIcon()
    self.x1x4 = newIcon()
    self.c1x2 = newIcon()

    LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
        element.c1x1:close()
        element.x1x4:close()
        element.c1x2:close()
    end)

    return self
end
