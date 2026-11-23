local Catalog = {}

local PAGE_SIZE = 12
local CATEGORIES_PER_PAGE = 10

local function pageIndex(value, last)
	if type(value) ~= "number" or value ~= value then return 1 end
	return math.clamp(math.floor(value), 1, last)
end

function Catalog.build(items)
	local groups = {}
	for _, item in items do
		local label = item.category
		local group = groups[label]
		if not group then
			group = {}
			groups[label] = group
		end
		table.insert(group, item)
	end
	local labels = {}
	for label in groups do table.insert(labels, label) end
	table.sort(labels, function(a, b) return string.lower(a) < string.lower(b) end)
	table.sort(items, function(a, b)
		local first, second = string.lower(a.name), string.lower(b.name)
		return if first == second then a.key < b.key else first < second
	end)
	for label, group in groups do
		table.sort(group, function(a, b)
			local first, second = string.lower(a.name), string.lower(b.name)
			return if first == second then a.key < b.key else first < second
		end)
	end
	return { items = items, groups = groups, categories = labels }
end

function Catalog.page(index, filters, decorate)
	filters = if type(filters) == "table" then filters else {}
	local group = if type(filters.category) == "string" then index.groups[filters.category] else nil
	local category = if group then filters.category else ""
	local query = if type(filters.query) == "string" then string.lower(string.sub(filters.query, 1, 64)) else ""
	local pool = group or index.items
	if query ~= "" then
		local matches = {}
		for _, item in pool do
			if string.find(string.lower(item.name), query, 1, true) then table.insert(matches, item) end
		end
		pool = matches
	end

	local pages = math.max(1, math.ceil(#pool / PAGE_SIZE))
	local page = pageIndex(filters.page, pages)
	local rows = {}
	for id = (page - 1) * PAGE_SIZE + 1, math.min(#pool, page * PAGE_SIZE) do
		table.insert(rows, decorate(pool[id]))
	end

	local categories = index.categories
	local categoryPages = math.max(1, math.ceil(#categories / CATEGORIES_PER_PAGE))
	local categoryPage = pageIndex(filters.categoryPage, categoryPages)
	local choices = {}
	for id = (categoryPage - 1) * CATEGORIES_PER_PAGE + 1, math.min(#categories, categoryPage * CATEGORIES_PER_PAGE) do
		table.insert(choices, categories[id])
	end
	return {
		items = rows, page = page, pages = pages, count = #pool, category = category,
		categories = choices, categoryPage = categoryPage, categoryPages = categoryPages,
	}
end

return Catalog
