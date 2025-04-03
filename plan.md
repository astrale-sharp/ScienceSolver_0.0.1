ui with search to select recipe with a tab for sciences only
rate <- select rate per second at engineer speed

once selected
recip <- recipe




res_rate <- recip.energy_required/recip.results.amount
res_rate * number of machines = rate
n_main = rate/res_rate


for i,k in ipairs(recip.ingredients)
do
same calculations with rate of parent
end

print the resulting tree as an ui

```lua
function cook_it_astrale(recip, rate)
  local res_rate = recip.energy_required/recip.results.amount
  local n_machines = rate/res_rate
  local ret = {
	res_rate = res_rate,
	n_machines = n_machines,
	ingredients = {},
  }
  for i, this_ing in ipairs(recip.ingredients)
  rate.ingredients[i] = cook_it_astrale(recipes[this_ing.name], rate * this_ing.amount)
  end
end
```

improvment use 
    category = "chemistry",
    category = "crafting",
    category = "oil-processing",
    category = "smelting",
    category = "metallurgy",
machines available and their speed to cook more precisely
