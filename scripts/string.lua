--- Checks if a string ends with a specified suffix.
--- @param str string The string to check.
--- @param suffix string The suffix to check.
--- @return boolean boolean Returns true if the string ends with the specified suffix, false otherwise.
function string.ends_with(str, suffix)
	return str:sub(- #suffix) == suffix
end
