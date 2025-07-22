-- GUI for SciSolver
-- this ui is built with the principle of single source of truth in mind
-- this source of truth is storage.ui_state and it should only be modified as a reaction to user input.
--
-- Choose mode:
-- A - mode target rate for recipe:
--   1. Select a recipe
--   2, Select available machines and module, Select wanted rate
--   3. View a summary of the needed machines, number of belts per ingredients
-- H - hidden

-- source of truth of the ui
storage.ui_state = {
	mode = "H",
	vars = {
		-- nil or table containing:
		-- - name: a recipe name
		recipe = nil, -- recipe-picker

		-- nil or table[],
		-- containing:
		--  - name: recipe compatible machine
		--  - selected: boolean
		--  - todo quality filter
		--  - todo: forced? isn't used by the solver but assumed to be there
		machines = nil, --machine-picker

		-- nil or int[4] where value is max tier of module allowed, 0 is forbidden
		-- index is speed, efficiency, productivity, quality
		modules = nil, --module-picker

		-- nil or number
		rate = nil, --rate-picker
	},
}

function Destroy_main_frame()
	if storage.main_frame ~= nil then
		storage.main_frame.destroy()
		storage.main_frame = nil
		return
	end
end

local function get_player_gui()
	local player = game.get_player(1)
	if player == nil then
		return
	end
	return player.gui.screen
end

function Make_ui_from_state(s, screen_element)
	Destroy_main_frame()
	local gui = get_player_gui()

	if not gui then
		return
	end

	local gui = gui.add({
		type = "scroll-pane",
		name = "scisolver_main",
		caption = "Science Solver",
		direction = "vertical",
	}).add({ type = "frame" })

	if s.mode == "H" then
		return
	elseif s.mode == "A" then
		if not s.vars then
			s.vars = {}
		end
		if not s.vars.recipe then -- A-1: display inputs
			Make_ui_A1(s.vars, gui)

		-- A-2: display result and a return button
		elseif not s.vars.machines or not s.vars.modules or not s.vars.rate then
			Make_ui_A2(s.vars, gui)
		else -- A-3
			Make_ui_A3(s.vars, gui)
		end
	end
end

function Make_ui_A1(vars, gui)
	gui.add({
		type = "choose-elem-button",
		elem_type = "recipe",
		name = "recipe-picker",
		caption = "Pick a recipe",
	})

	gui.add({ type = "button", caption = "OK", name = "A1OK" })
end

function On_A1_ok(recipe)
	storage.ui_state.vars.recipe = recipe
	Make_ui_from_state(storage.ui_state)
end

function Make_ui_A2(vars, gui)
	gui.add({ type = "label", caption = "recipe chosen: " + tostring(vars.recipe) })
	local machines = vars.machines
	if not machines then
		machines = get_compatible_machines(vars.recipe) -- from the one currently researched?
		if not machines then
			return error("ERROR: get_compatible_machines returned nil.")
		end
		if #machines == 0 then
			return error("ERROR: get_compatible_machines returned empty array.")
		end
		storage.ui_state.machines = machines -- we use it to build the UI so it's fine to modify it here
	end

	local machine_frame = gui.add({ type = "frame", caption = "Machine selection" })
	for i, this_machine in ipairs(machines) do
		local flow = machine_frame.add({ type = "flow", direction = "horizontal" })
		flow.add({ type = "sprite", sprite = this_machine.sprite })
		flow.add({
			type = "checkbox",
			name = "machine-picker-selected",
			state = this_machine.selected,
			tags = { i = i },
		})
	end

	gui.add({ type = "button", caption = "OK", name = "A2OK" })
end

-- index in ui_state.vars.machines
function On_A2_ok(index)
	if not storage.ui_state.vars.machines then
		return error("Tried to make A2 OK but machines is nil")
	end

	storage.ui_state.vars.machines[index].selected = not storage.ui_state.vars.machines[index].selected
	Make_ui_from_state(storage.ui_state)
end

function Make_ui_A3(vars, gui)
	-- todo: compute and display results
end

function On_A3_ok() end

script.on_event("scisolver_toggle_interface", function(event)
	local mode = storage.ui_state.mode
	if mode == "H" then
		mode = "A"
	else
		mode = "H"
	end
	storage.ui_state.mode = mode

	Make_ui_from_state(storage.ui_state)
end)

script.on_event(defines.events.on_gui_click, function(event)
	if event.element.name == "A1OK" and storage.ui_state.vars.recipe then
		On_A1_ok(storage.ui_state.vars.recipe)
	end
	-- if event.element.name == "get-result-button" then
	-- 	local recip = prototypes.recipe[storage.recipe]
	-- 	local rates = Rec_get_rates(recip, storage.rate_ui.text)
	-- 	local sum_rates = Extract_summary(rates)
	-- 	storage.main_frame.clear()

	-- 	local tabs = storage.main_frame.add({ type = "tabbed-pane" })
	-- 	local tab1 = tabs.add({ type = "tab" })
	-- 	Rates_to_ui_summary(rates, sum_rates, tab1)

	-- 	local tab2 = tabs.add({ type = "tab" })
	-- 	Sum_ui_summary(sum_rates, tab2)
	-- end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	-- storage.recipe = event.element.elem_value
	-- storage.main_frame.clear()
	-- local frame = storage.main_frame.add({ type = "frame" })
	-- storage.rate_ui = frame.add({ type = "textfield", name = "rate-selector", numeric = true, text = "1" })
	-- frame.add({ type = "button", name = "get-result-button", caption = "compute" })
end)

script.on_event(defines.events.on_gui_text_changed, function(event) end)

function Rec_get_rates(recipe, rate)
	if recipe == nil then
		return nil
	end
	-- todo select the one needed for up
	local main_product = recipe.main_product
	if main_product == nil then
		main_product = recipe.products[1]
	end

	if main_product == nil then
		return { name = recipe.name, error = "no_main_product" }
	end

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
			local search = prototypes.get_recipe_filtered({
				{ filter = "has-product-item", elem_filters = { { filter = "name", name = this_ing } } },
			})
			ing_recipe = search and search[1]
		end
		-- todo select best recipe.
		ret.ingredients[i] = Rec_get_rates(ing_recipe, rate * this_ing.amount)
		--		end
	end
	return ret
end

function Combine_recipes(t1, t2)
	if t2 == nil then
		return
	end
	if t2.recipe == nil then
		return
	end
	if t1[t2.recipe.name] == nil then
		t1[t2.recipe.name] = {
			count = 1,
			n_machines = t2.n_machines,
			res_rate = t2.res_rate,
		}
	else
		local ref = t1[t2.recipe.name]
		t1[t2.recipe.name] = {
			count = ref.count + 1,
			n_machines = ref.n_machines + t2.n_machines,
			res_rate = ref.res_rate + t2.res_rate,
		}
	end
end

function Extract_summary(rates)
	local res = {} -- recipe name to  {rate : rate, sum_count}
	Combine_recipes(res, rates)
	for index, value in ipairs(rates.ingredients) do
		if value ~= nil then
			Combine_recipes(res, Extract_summary(value))
		end
	end
	return res
end

local style = {
	horizontal_scroll_policy = "auto-and-reserve-space",
	vertical_scroll_policy = "auto-and-reerve-space",
	auto_center = true,
}

function Merge_tables(t1, t2)
	local ret = {}
	for k, v in pairs(t1) do
		ret[k] = v
	end
	for k, v in pairs(t2) do
		ret[k] = v
	end
	return ret
end

function Rates_to_ui_summary(rates, sum_rate, frame)
	local sprite_name = (rates.main_product.type == "fluid") and ("fluid/" .. rates.main_product.name)
		or ("item/" .. rates.main_product.name)

	local ret = frame.add(Merge_tables({
		type = "frame",
		direction = "vertical",
	}, style))

	local duplicated = sum_rate[rates.recipe.name]
	if duplicated ~= nil then
		ret.add(Merge_tables({
			type = "label",
			caption = "recipe: " .. rates.recipe.name .. " is a used many times, see next tab.",
		}, style))

		ret.add({ type = "sprite", sprite = sprite_name })
		return ret
	end
	-- if rates.error ~= nil then
	-- 	ret.add { type = "label", caption = rates.error }
	-- 	return
	-- end
	local first_panel = ret.add(Merge_tables({
		type = "frame",
		direction = "vertical",
		caption = rates.recipe.name,
	}, style))

	local inner_panel = first_panel.add(Merge_tables({
		type = "frame",
		directon = "vertical",
	}, style))

	inner_panel.add({ type = "sprite", sprite = sprite_name })
	inner_panel.add({ type = "label", caption = "Using recipe: " .. rates.recipe.name })
	inner_panel.add({
		type = "label",
		caption = "You need: " .. tostring(rates.n_machines) .. " machines at engineer speed.",
	})
	inner_panel.add({ type = "label", caption = "rate of production is: " .. tostring(rates.res_rate) })

	local second_panel
	for _, v in pairs(rates.ingredients) do
		if v.recipe == nil then
			goto continue
		end
		if second_panel == nil then
			second_panel = ret.add(Merge_tables({
				type = "frame",
				direction = "horizontal",
				caption = "ingredients of " .. rates.name,
			}, style))
		end
		Rates_to_ui_summary(v, sum_rate, second_panel)
		::continue::
	end
	return ret
end

function Sum_ui_summary(rates_summary, frame)
	for index, value in ipairs(rates_summary) do
		Rates_to_ui_summary(value.rate, {}, frame)
	end
end
