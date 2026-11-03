--- @since 26.5.6
--- Dropbox online-only indicator.
---
--- With the classic Dropbox sync engine, online-only files are 0-byte
--- placeholder stubs on disk — so any empty regular file is marked with a ☁
--- in place of its file-type icon and in the linemode (each toggleable via
--- setup{ icon = false } / { linemode = false }). Purely size-based: no
--- processes, no state, instant, works in every view; the trade-off is that
--- genuinely empty files also show a (harmless) ☁. Downloading stays in
--- Finder — the classic engine has no silent programmatic trigger.

local function setup(_, opts)
	opts = opts or {}
	local sign = opts.sign or "☁"
	local style = ui.Style():fg("cyan")

	local function placeholder(file)
		local cha = file.cha
		return cha.len == 0 and not cha.is_dir and not cha.is_link
	end

	-- Replace the file-type icon with the cloud sign for online-only files
	if opts.icon ~= false then
		local icon = Entity.icon
		Entity.icon = function(self)
			if not placeholder(self._file) then
				return icon(self)
			elseif self._file.is_hovered then
				return ui.Line(sign .. " ")
			else
				return ui.Line(sign .. " "):style(style)
			end
		end
	end

	-- ... and mark them in the linemode (right side) as well
	if opts.linemode ~= false then
		Linemode:children_add(function(self)
			if not placeholder(self._file) then
				return ""
			elseif self._file.is_hovered then
				return ui.Line { " ", sign }
			else
				return ui.Line { " ", ui.Span(sign):style(style) }
			end
		end, opts.order or 1000)
	end
end

return { setup = setup }
