--- states
--- 1. Select a recipe
--- 2. Select a target rate
--- 3. View a summary of the needed machines

function destroy_main_frame()
	if storage.main_frame ~= nil then
		storage.main_frame.destroy()
		storage.main_frame = nil
		return
	end
end

script.on_event("scisolver_toggle_interface", function(event)
	if storage.main_frame ~= nil then
		destroy_main_frame()
		return
	end
	local player = game.get_player(1)
	if player == nil then
		return
	end
	local screen_element = player.gui.screen
	storage.main_frame = screen_element.add { type = "scroll-pane", name = "scisolver_main", caption = "Science Solver", direction = "vertical" }
	---
	--if true then return hack(storage.main_frame) end
	---
	storage.main_frame.add { type = "frame" }.add { type = "choose-elem-button", elem_type = "recipe", name = "choose-recipe-button", caption = "Pick a recipe" }
end)

script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == "get-result-button" then
		local recip = prototypes.recipe[storage.recipe]
		local rates = rec_get_rates(recip, storage.rate_ui.text)

		storage.main_frame.clear()
		rates_to_ui(rates, storage.main_frame)
	end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	storage.recipe = event.element.elem_value
	storage.main_frame.clear()
	local frame = storage.main_frame.add { type = "frame" }
	storage.rate_ui = frame.add { type = "textfield", name = "rate-selector", numeric = true, text = "1" }
	frame.add { type = "button", name = "get-result-button", caption = "compute" }
end)


script.on_event(defines.events.on_gui_text_changed, function(event) end)

-- @parameters recip: { name : string }
function rec_get_rates(recipe, rate)
	if recipe == nil then error("recipe cannot be nil") end
	-- todo select the one needed for up
	local main_product = recipe.main_product
	if main_product == nil then
		main_product = recipe.products[1]
	end

	if main_product == nil then return { name = recipe.name, error = "no_main_product" } end

	local res_rate = main_product.amount / recipe.energy

	-- n machine * rate = res_rate
	local n_machines = rate / res_rate
	if n_machines ~= math.floor(n_machines) then
		n_machines = math.floor(n_machines) + 1
	end
	local ret = {
		main_product = main_product,
		recipe = recipe,
		name = main_product.name,
		res_rate = res_rate * n_machines,
		n_machines = n_machines,
		ingredients = {},
	}
	for i, this_ing in ipairs(recipe.ingredients) do
		local ing_recipe = prototypes.recipe[this_ing.name]
		if ing_recipe == nil then
			local search = prototypes.get_recipe_filtered { { filter = "has-product-item", elem_filters = { { filter = "name", name = this_ing } } } }
			ing_recipe = search and search[1]
		end
		-- todo select best recipe.
		ret.ingredients[i] = rec_get_rates(ing_recipe, rate * this_ing.amount)
		--		end
	end
	return ret
end

local style = {
	horizontal_scroll_policy = "auto-and-reserve-space",
	vertical_scroll_policy = "auto-and-reerve-space",
	auto_center = true,
}

function rates_to_ui(rates, frame)
	local function merge (t1,t2)
		local ret = {}
		for k,v in pairs(t1) do ret[k] = v end
		for k,v in pairs(t2) do ret[k] = v end
		return ret
	 end
	local sprite_name = "icons/" .. rates.recipe.name
	-- (rates.main_product.type == "fluid") and ("fluid/" .. rates.main_product.name) or
	--	("item/" .. rates.main_product.name)

	local ret = frame.add(
		merge({
				type = "frame",
				direction = "vertical",
			},
			style
		))
	
	if rates.error ~= nil then
		ret.add { type = "label", caption = rates.error }
		return
	end
	local first_panel = ret.add(
		merge({
				type = "frame",
				direction = "vertical",
				caption = rates.recipe.name,
			},
			style
		))

	local inner_panel = first_panel.add(
		merge({
				type = "frame",
				directon = "vertical",
			},
			style
		))

	local icon = prototypes
	if icon ~= nil then
		inner_panel.add { type = "sprite", sprite = sprite_name }
	end

	inner_panel.add { type = "label", caption = "Using recipe: " .. rates.recipe.name --.. " of type: " ..  rates.recipe.caory
	}
	inner_panel.add { type = "label", caption = "You need: " .. tostring(rates.n_machines) .. " machines at engineer speed." }
	inner_panel.add { type = "label", caption = "rate of production is: " .. tostring(rates.res_rate) }

	local second_panel
	for k, v in pairs(rates.ingredients) do
		if v.recipe == nil then goto continue end
		if second_panel == nil then
			second_panel = ret.add(
				merge({
					type = "frame",
					direction = "horizontal",
					caption = "ingredients of " .. rates.name,
				},
				style
				))
		end
		rates_to_ui(v, second_panel)
		::continue::
	end
	return ret
end

function hack(frame)
	local table = frame.add { type = "table", caption = "ALL", column_count = 25 }
	local list = prototypes.get_recipe_filtered { { filter = "has-product-item", elem_filters = { { filter = "name", name = "iron-plate" } } } }
	for k, v in pairs(list) do
		if not string.find(k, "recycling") then
			table.add { type = "label", caption = tostring(k) }
		end
	end
end
