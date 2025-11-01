local sprite = app.sprite
if not sprite then return app.alert("Error: Sprite not found.") end

local outlineLayerName = "Outline"
local dialog = Dialog { title = "Auto-Outline" }
local state = {
    enabled = false,
    strokeWidth = 1,
    outlineLayer = nil,
}

local directions = {
    { x = -1, y = -1 }, { x = 0, y = -1 }, { x = 1, y = -1 },
    { x = -1, y = 0 }, { x = 1, y = 0 },
    { x = 1, y = 1 }, { x = 0, y = 1 }, { x = -1, y = 1 },
}

local function getOrCreateLayer(name)
    for _, layer in ipairs(sprite.layers) do
        if layer.name == name then return layer end
    end
    local layer = sprite:newLayer()
    layer.name = name
    return layer
end

local function isTransparent(px)
    return app.pixelColor.rgbaA(px) == 0
end

local function outlineImage(src)
    local width, height = src.width, src.height
    local outline = Image(width + (state.strokeWidth * 2), height + (state.strokeWidth * 2), sprite.colorMode)
    outline:clear()

    local color = Color { r = 0, g = 0, b = 0, a = 255 }

    for pixel in src:pixels() do
        local value = pixel()

        if not isTransparent(value) then
            for _, dir in ipairs(directions) do
                local dx = pixel.x + state.strokeWidth + dir.x
                local dy = pixel.y + state.strokeWidth + dir.y

                local sx = dx - state.strokeWidth
                local sy = dy - state.strokeWidth

                if dx >= 0 and dy >= 0 and dx < outline.width and dy < outline.height and sx >= 0 and sy >= 0 and sx < width and sy < height then
                    local neighborValue = src:getPixel(sx, sy) -- Check if neighbor pixel in source image is transparent
                    if isTransparent(neighborValue) then
                        outline:drawPixel(dx, dy, color)
                    end
                end
            end
        end
    end

    return outline
end

sprite.events:on("change",
    function(ev)
        if state.enabled and state.outlineLayer and not ev.fromUndo then
            app.transaction("Generate Outline", function()
                for frameIndex = 1, #sprite.frames do
                    local frame = sprite.frames[frameIndex]
                    local comp = Image(sprite.spec)
                    comp:clear()

                    for _, layer in ipairs(sprite.layers) do -- Add each layer's image to comp
                        if layer.isImage and layer.isVisible and layer ~= state.outlineLayer then
                            local cel = layer:cel(frame)
                            if cel and cel.image then
                                comp:drawImage(cel.image, cel.position)
                            end
                        end
                    end

                    local outImg = outlineImage(comp)
                    sprite:newCel(state.outlineLayer, frame, outImg,
                        Point { x = -state.strokeWidth, y = -state.strokeWidth }) -- Offset outline image by stroke width
                end
            end)

            app.refresh()
        end
    end)


local function toggleAutoOutline()
    state.enabled = not state.enabled

    if state.enabled then -- Create outline layer the first time
        state.outlineLayer = getOrCreateLayer(outlineLayerName)
    end

    dialog:modify {
        id = "toggle",
        text = state.enabled and "Auto-Outline (Enabled)" or "Auto-Outline (Disabled)"
    }
end

dialog:slider {
    id = "stroke",
    label = "Stroke Width",
    min = 1, max = 10, value = state.strokeWidth,
    onchange = function()
        state.strokeWidth = dialog.data.stroke
    end
}

dialog:button {
    id = "toggle",
    text = "Auto-Outline (Disabled)",
    onclick = function() toggleAutoOutline() end
}

dialog:show { wait = false }
