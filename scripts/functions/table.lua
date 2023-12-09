--- Finds the index of an element in a table.
--- @param tbl table The table to search in.
--- @param predicate any The element to find.
--- @return number index The index of the element if found, or 0 if not found.
function table.index_of(tbl, predicate)
	for i, v in ipairs(tbl) do
		if v == predicate then
			return i
		end
	end
	return 0
end

--- Returns the number of keys in a table.
--- @param tbl table table The table to count the keys of.
--- @return number length The number of keys in the table.
function table.keys_len(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end
