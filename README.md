# efficient_turtle_mine

A smart mining program for CC: Tweaked turtles in Minecraft.

## Description

This Lua script automates mining operations for turtles equipped with tools. It mines in a structured pattern, manages inventory by dropping trash items, and refuels when necessary.

## Features

- Mines in rows and layers
- Automatically drops trash items (stone, dirt, etc.)
- Manages inventory space
- Avoids blacklisted blocks (bedrock, barriers)
- Refuels from fuel items in inventory

## Usage

1. Place the turtle in the starting position.
2. Ensure the turtle has a pickaxe or shovel equipped.
3. Run the script with optional parameters:

   ```
   smartMiner.lua [distance] [rowCount]
   ```

   - `distance`: Number of blocks to mine forward in each row (default: 3)
   - `rowCount`: Number of rows to mine (default: 2)

   Example: `smartMiner.lua 5 3` mines 5 blocks forward per row, for 3 rows.

## Configuration

The script includes configurable lists:

- **Blacklist**: Blocks to never mine (e.g., bedrock)
- **Trashlist**: Blocks to mine but drop immediately
- **Fuellist**: Items that can be used as fuel

Modify these tables in the script to customize behavior.

## API Reference

For more information on turtle functions, see the [CC: Tweaked Turtle API](https://tweaked.cc/module/turtle.html).

## Requirements

- CC: Tweaked mod
- Turtle with mining tool
- Fuel in inventory or accessible