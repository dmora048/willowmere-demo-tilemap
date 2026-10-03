# Willowmere

A cozy spring farming RPG built in Godot. Travel between Willowmere, your farm, and your house; grow turnips, potatoes, and carrots; sell your harvest; and fulfill crop requests from the townsfolk.

## Gameplay

- Start with **60 gold**, an empty seed/crop inventory, and the Hoe, Seed Bag, Watering Can, and Harvest Knife.
- Meet Rowan at the **Seeds · Produce** shop in town. Buy seeds and sell harvested crops from the shop menu.
- Use the path at the bottom of town to reach your farm. Hoe a patch, plant a seed, water the crop, then sleep in your house to advance the day and grow watered crops.
- Mira requests 3 turnips, Bram requests 2 potatoes, and Juno requests 3 carrots. Accept a request, grow the crop, then deliver it to that villager for gold.
- Turnips take 2 watered days to mature, potatoes 3, and carrots 4. Crops do not grow on days when they were not watered.

## Controls

- **Enter / Space** — Start from the title screen
- **WASD / Arrow keys** — Move
- **E** — Talk, use a tool, enter a building, sleep, or travel
- **I** — Open / close the backpack inventory
- **1–9** — Select a hotbar slot (the first four hold your tools)
- **Q** — Cycle through seed types in your satchel
- **Esc** — Close the backpack, dialogue, shop, or settings

The nine-slot hotbar stays visible at the bottom of the screen. In the backpack, select a hotbar slot and click a stored item to assign it there. Item stacks show their counts and use icons from `asset_pack/Objects/Interior.png` and `asset_pack/Objects/Spring Crops.png`.

Talk to the village NPCs for crop requests. Their free-form conversations can also use Google AI Studio: add a key through **Gemini settings** on the title screen or **Settings** in-game.

## Editing the scenes

Open `Main.tscn` to see the game setup. The authored town map is in `World.tscn`; the outdoor farm and house interior are separate scenes in `Farm.tscn` and `House.tscn`. `Main.gd` handles movement, crop and quest progression, shop transactions, and runtime UI.
