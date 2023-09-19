local paintLib

do -- Paint Library Code
	local function paintLib.Background(width, height, panel, color, rounded_corner_radius)
		if rounded_corner_radius != nil then
			draw.RoundedBox(rounded_corner_radius, 0, 0, width, height, color)
		else
			surface.SetDrawColor(color)
			surface.DrawRect(0, 0, width, height)
		end
	end

	local function paintLib.Outline(width, height, panel, color, thickness, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0
		thickness = thickness or 1

		surface.SetDrawColor(color)
		surface.DrawOutlinedRect(0 + vertical_padding, 0 + horizontal_padding, width - (horizontal_padding * 2), height - (vertical_padding * 2), thickness)
	end

	local function paintLib.BackgroundHover(width, height, panel, alpha, color, rounded_corner_radius)
		color = ColorAlpha(color, color.a * alpha)

		paintLib.Background(width, height, panel, color, rounded_corner_radius)
	end

	local function paintLib.OutlineHover(width, height, panel, alpha, color, thickness, vertical_padding, horizontal_padding)
		color = ColorAlpha(color, color.a * alpha)

		paintLib.Outline(width, height, panel, color, thickness, vertical_padding, horizontal_padding)
	end

	local function paintLib.SideBlock(width, height, panel, color, side, thickness, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0
		thickness = thickness or 1

		surface.SetDrawColor(color)
		if side == TOP then -- Top
			surface.DrawRect(0 + horizontal_padding, 0 + vertical_padding, width - (horizontal_padding * 2), thickness)
		elseif side == RIGHT then -- Right
			surface.DrawRect((width - thickness) + horizontal_padding, 0 + vertical_padding, thickness, height - (horizontal_padding * 2))
		elseif side == BOTTOM then -- Bottom
			surface.DrawRect(0 + horizontal_padding, (height - thickness) + vertical_padding, width - (horizontal_padding * 2), thickness)
		elseif side == LEFT then -- Left
			surface.DrawRect(0 + horizontal_padding, 0 + vertical_padding, thickness, height - (vertical_padding * 2))
		end
	end

	local function paintLib.Text(width, height, panel, str, color, font, align, vertical_padding, horizontal_padding)
		align = align or TEXT_ALIGN_CENTER
		draw.SimpleText(str, font, (width * 0.5) + horizontal_padding or 0, (height * 0.5) + vertical_padding or 0, color, align, TEXT_ALIGN_CENTER)
	end

	J_TEXT_CORNER_TOP_LEFT = 1
	J_TEXT_CORNER_TOP_RIGHT = 2
	J_TEXT_CORNER_BOTTOM_LEFT = 3
	J_TEXT_CORNER_BOTTOM_RIGHT = 4

	local function paintLib.CornerText(width, height, panel, str, color, font, corner, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0

		if corner == J_TEXT_CORNER_TOP_LEFT then -- Top Left
			draw.SimpleText(str, font, 0 + horizontal_padding, 0 + vertical_padding, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		elseif corner == J_TEXT_CORNER_TOP_RIGHT then -- Top Right
			draw.SimpleText(str, font, width + horizontal_padding, 0 + vertical_padding, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		elseif corner == J_TEXT_CORNER_BOTTOM_LEFT then -- Bottom Left
			draw.SimpleText(str, font, 0 + horizontal_padding, height + vertical_padding, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		elseif corner == J_TEXT_CORNER_BOTTOM_RIGHT then -- Bottom Right
			draw.SimpleText(str, font, width + horizontal_padding, height + vertical_padding, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	local blurscreen_material = Material("pp/blurscreen")

	local function paintLib.Blur(width, height, panel, amount)
		local x, y = panel:LocalToScreen(0, 0)

		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(blurscreen_material)

		for i=0.33, 1, 0.33 do
			blurscreen_material:SetFloat("$blur", i * (amount or 8))
			blurscreen_material:Recompute()

			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
		end
	end

	local function paintLib.CheckBox(width, height, panel, color)
	end

	local function paintLib.TextboxHover(width, height, panel, color)
	end

	local function paintLib.TextboxPlacerholder(width, height, panel, str, string)
	end

	local function paintLib.TextboxSideBar()
	end
end