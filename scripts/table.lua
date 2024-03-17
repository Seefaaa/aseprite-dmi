--- Checks if a value exists in a table.
--- @param tbl table The table to search in.
--- @param val any The value to search for.
--- @return boolean boolean Returns true if the value is found in the table, false otherwise.
function table.contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

--- Returns the index of a value in a table.
--- @param tbl table The table to search in.
--- @param val any The value to search for.
--- @return integer integer Returns the index of the value in the table, or 0 if the value is not found.
function table.index_of(tbl, val)
	for i, v in ipairs(tbl) do
		if v == val then
			return i
		end
	end
	return 0
end

--- Concatenates a table with commas and "and".
--- @param tbl table The table to concat.
--- @return string string The concatenated string.
function table.concat_and(tbl)
	if #tbl == 0 then
		return ""
	elseif #tbl == 1 then
		return tbl[1]
	else
		return table.concat(tbl, ", ", 1, #tbl - 1) .. " and " .. tbl[#tbl]
	end
end

--- Returns the length of a table.
--- @param tbl table The table to get the length of.
--- @return integer integer The length of the table.
function table.length(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end
