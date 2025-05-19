local lfs = require("lfs")
local json = require("dkjson") -- Make sure dkjson is installed (luarocks install dkjson)
local io = require("io")
local os = require("os")

local function get_os()
	local handle = io.popen("uname")
	local result = handle:read("*a"):gsub("\n", "")
	handle:close()
	if result == "Darwin" then
		return "macos"
	elseif result == "Linux" then
		return "linux"
	else
		error("Unsupported OS: " .. result)
	end
end

---@class FontScanner
---@field dir string
local function scan_fonts(dir)
	local fonts = {}
	for file in lfs.dir(dir) do
		if file ~= "." and file ~= ".." then
			local fullpath = dir .. "/" .. file
			local attr = lfs.attributes(fullpath)
			if attr.mode == "directory" then
				for _, f in ipairs(scan_fonts(fullpath)) do
					table.insert(fonts, f)
				end
			elseif file:match("%.ttf$") or file:match("%.otf$") then
				table.insert(fonts, fullpath)
			end
		end
	end
	return fonts
end

---@param filename string
local function load_installed_fonts(filename)
	local f = io.open(filename, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	return json.decode(content) or {}
end

---@param filename string
---@param fonts table
local function save_installed_fonts(filename, fonts)
	local f = io.open(filename, "w")
	f:write(json.encode(fonts, { indent = true }))
	f:close()
end

---@param font_path string
---@param os_type string
local function copy_font_to_user_dir(font_path, os_type)
	local dest_dir = os_type == "macos" and os.getenv("HOME") .. "/Library/Fonts"
		or os.getenv("HOME") .. "/.local/share/fonts"
	os.execute("mkdir -p " .. dest_dir)
	os.execute(string.format('cp "%s" "%s"', font_path, dest_dir))
end

local function main()
	local os_type = get_os()
	local json_file = "installed_fonts.json"
	local installed = load_installed_fonts(json_file)
	local installed_set = {}
	for _, f in ipairs(installed) do
		installed_set[f] = true
	end

	local all_fonts = scan_fonts(".")
	local newly_installed = {}

	for _, font_path in ipairs(all_fonts) do
		if not installed_set[font_path] then
			print("Installing font: " .. font_path)
			copy_font_to_user_dir(font_path, os_type)
			table.insert(installed, font_path)
			table.insert(newly_installed, font_path)
		end
	end

	if os_type == "linux" and #newly_installed > 0 then
		print("Refreshing font cache...")
		os.execute("fc-cache -f")
	end

	save_installed_fonts(json_file, installed)

	if #newly_installed == 0 then
		print("All fonts already installed.")
	else
		print("Installed " .. #newly_installed .. " new fonts.")
	end
end

main()
