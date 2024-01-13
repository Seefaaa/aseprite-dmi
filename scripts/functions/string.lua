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
