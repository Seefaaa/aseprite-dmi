--- Checks if a string ends with a specified suffix.
--- @param str string The string to check.
--- @param suffix string The suffix to check.
--- @return boolean boolean Returns true if the string ends with the specified suffix, false otherwise.
function string.ends_with(str, suffix)
	return str:sub(- #suffix) == suffix
end

--- Checks if a string starts with a specific prefix.
--- @param str string The string to check.
--- @param prefix string The prefix to compare with.
--- @return boolean boolean True if the string starts with the prefix, false otherwise.
function string.starts_with(str, prefix)
	return str:sub(1, #prefix) == prefix
end

--- Splits a string into a table of substrings based on a separator.
--- If no separator is provided, it defaults to whitespace characters.
--- @param str string The string to split.
--- @param sep string (optional) The separator pattern to split the string. Defaults to "%s" (whitespace characters).
--- @return (string)[] string_array A table containing the substrings.
function string.split(str, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in str.gmatch(str, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

--- Splits a string into lines, ensuring that each line does not exceed a maximum length.
--- @param str string The string to split.
--- @param max_length number The maximum length of each line.
function string.split_lines(str, max_length)
	local result = {}
	for line in str:gmatch("[^\n]+") do
			local line_length = #line
			if line_length > max_length then
					local words = {}
					for word in line:gmatch("%S+") do
							table.insert(words, word)
					end
					local new_line = ""
					for _, word in ipairs(words) do
							if #new_line + #word > max_length then
									table.insert(result, new_line)
									new_line = ""
							end
							new_line = new_line .. word .. " "
					end
					if #new_line > 0 then
							table.insert(result, new_line)
					end
			else
					table.insert(result, line)
			end
	end
	return result
end
