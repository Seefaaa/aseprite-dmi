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
