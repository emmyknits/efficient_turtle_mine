-- SMART MINER WITH BLACKLIST CHECK

-- Enums
local EMineAttemptResult = {
    IsTrash = 0,
    NoRoom = 1,
    Mined = 2,
    EmptySpace = 3
}

local EMineDirection = {
    Forward = 0,
    Left = 1,
    Below = 2,
    Right = 3,
    Above = 4
}

local EBreadcrumbMode = {
    Placing = 0,
    Eating = 1,
}

local EFacingDirection = {
    Forward = 1,
    Right = 2,
    Backward = 3,
    Left = 4,
	MAX = 4,
	MIN = 1
}

-- Config
local args = { ... }
local distance = tonumber(args[1]) or 3
local rowCount = tonumber(args[2]) or 2

-- Mutable State
local pointAlongRowToReturnTo = -1
local remainingRows = rowCount
local recentMinedDirection = 0
local currentFacingDirection = EFacingDirection.Forward
local currentRowLocation = 0
local currentBreadcrumbMode = EBreadcrumbMode.Placing
local breadcrumbList = {}

local blacklist = {
  ["minecraft:bedrock"] = true,
  ["minecraft:barrier"] = true
}

local trashlist = {
  ["minecraft:stone"] = true,
  ["minecraft:cobblestone"] = true,
  ["quark:limestone"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:gravel"] = true,
  ["minecraft:sand"] = true,
  ["chisel:basalt2"] = true,
  ["biomesoplenty:dirt"] = true,
  ["minecraft:clay_ball"] = true,
}

local fuellist = {
  ["minecraft:coal"] = true,
  ["minecraft:planks"] = true,
  ["natura:overworld_planks"] = true,
  ["biomesoplenty:planks_0"] = true,
  ["thaumcraft:planks_silverwood"] = true,
}

local function isPlacingBreadcrumbs()
	return currentBreadcrumbMode == EBreadcrumbMode.Placing
end

local function isEatingBreadcrumbs()
	return currentBreadcrumbMode == EBreadcrumbMode.Eating
end

local function turnRight()
	turtle.turnRight()
	currentFacingDirection = currentFacingDirection + 1
	while currentFacingDirection > EFacingDirection.MAX do
		currentFacingDirection = currentFacingDirection - EFacingDirection.MAX
	end
end

local function turnLeft()
	turtle.turnLeft()
	currentFacingDirection = currentFacingDirection - 1
	while currentFacingDirection < EFacingDirection.MIN do
		currentFacingDirection = currentFacingDirection + EFacingDirection.MAX
	end
end

local function turnAround()
	turnRight()
	turnRight()
end

local function faceForward()
	if currentFacingDirection == EFacingDirection.Forward then
		-- already facing forward!
		return
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnAround()
	end
end

local function faceBackward()
	if currentFacingDirection == EFacingDirection.Backward then
		-- already facing backward!
		return
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnAround()
	end
end

local function faceRight()
	if currentFacingDirection == EFacingDirection.Right then
		-- already facing right!
		return
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnAround()
	end
end

local function faceLeft()
	if currentFacingDirection == EFacingDirection.Left then
		-- already facing left!
		return
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnAround()
	end
end

local function faceDirection(directionToFace)
	facingDirectionDelta = directionToFace - currentFacingDirection
	if facingDirectionDelta == 0 then
		-- no change needed
		return
	end
	if facingDirectionDelta == 2 or facingDirectionDelta == -2 then
		turnAround()
	end
	if facingDirectionDelta == 1 or facingDirectionDelta == -3 then
		turnLeft()
	end
	if facingDirectionDelta == 3 or facingDirectionDelta == -1 then
		turnLeft()
	end
end

local function getRowCountFullyMined()
  return rowCount - remainingRows 
end

local function isBlacklisted(name)
  return blacklist[name] == true
end

local function isTrashlisted(name)
  return trashlist[name] == true
end

local function isFuel(name)
  return fuellist[name] == true
end

local function isInventoryFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

local function hasRoomInInventoryFor(itemName)
    for slot = 1, 16 do
        turtle.select(slot)

        local itemInSlot = turtle.getItemDetail(slot)
        if not itemInSlot then
			-- empty slot, of course we have room
			return true
        end
		if itemName == itemInSlot.name then
			local maxStack = itemInSlot.maxCount or 64
            if itemInSlot.count < maxStack then
                return true
            end
		end
    end
	return false
end

local function dumpInventoryFilter(filterFunctor)
    faceBackward()
    
    local filler_needed = pointAlongRowToReturnTo - 1
    local filler_reserved = 0

    -- First pass: count available filler items
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and isTrashlisted(item.name) then
            filler_reserved = filler_reserved + turtle.getItemCount(slot)
        end
    end

    -- Clamp to needed amount
    filler_reserved = math.min(filler_reserved, filler_needed)

    -- Second pass: dump everything except what we want to keep
    for slot = 1, 16 do
        turtle.select(slot)
        local item = turtle.getItemDetail(slot)

        if item then
            local is_filler = isTrashlisted(item.name)

            if filterFunctor(item.name) then
                -- keep via filter
            elseif is_filler and filler_reserved > 0 then
                -- reserve filler
                local keep = math.min(turtle.getItemCount(slot), filler_reserved)
                filler_reserved = filler_reserved - keep
            else
                turtle.drop()
            end
        end
    end
end

local function dumpInventoryAll()
    dumpInventoryFilter(function(itemName) return false end)
end

local function dumpInventoryNonFuels()
    dumpInventoryFilter(function(itemName) return isFuel(itemName) end)
end

local function placeTrashBehind()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and isTrashlisted(item.name) then
            turtle.select(slot)
			faceForward()
            turtle.place()
			faceBackward()
            return true
        end
    end
    return false
end

local function tryMoveForward()
	success = turtle.forward()
	if success == true then

		end
	end
end

local function mineInDirection(mineDirection, skipTrashBlocks)
	recentMinedDirection = mineDirection

	local mineFunction = turtle.dig
	local inspectFunction = turtle.inspect
	local preMineTurnFunction = function() end
	local postMineTurnFunction = function() end

	if mineDirection == EMineDirection.Below then
		mineFunction = turtle.digDown
		inspectFunction = turtle.inspectDown
	elseif mineDirection == EMineDirection.Above then
		mineFunction = turtle.digUp
		inspectFunction = turtle.inspectUp
	elseif mineDirection == EMineDirection.Right then
		preMineTurnFunction = faceRight
		postMineTurnFunction = faceForward
	elseif mineDirection == EMineDirection.Left then
		preMineTurnFunction = faceLeft
		postMineTurnFunction = faceForward
	end

	preMineTurnFunction()

	local has_block, data = inspectFunction()
	if not has_block then
        if mineDirection == EMineDirection.Forward then
            turtle.forward()
        end
		postMineTurnFunction()
		return EMineAttemptResult.EmptySpace
	end

	if skipTrashBlocks == true then
		if isBlacklisted(data.name) or isTrashlisted(data.name) then
			postMineTurnFunction()
			return EMineAttemptResult.IsTrash
		end
	end

	if not hasRoomInInventoryFor(data.name) then
		postMineTurnFunction()
		return EMineAttemptResult.NoRoom
	end

	mineFunction()

	postMineTurnFunction()

	if mineDirection == EMineDirection.Forward then 
		if turtle.detect() then
			-- something fell in place - mine thru it too
			skipTrashBlocks = (mineDirection ~= EMineDirection.Forward)
    		return mineInDirection(mineDirection, skipTrashBlocks)
		else
			turtle.forward()
		end
	end

	return EMineAttemptResult.Mined
end

local function shiftToNextRow()
	--support going back in the middle of shifting to next row
    faceLeft()
    for i = 1, 2 do
		result = mineInDirection(EMineDirection.Forward, false)
		if result == EMineAttemptResult.NoRoom then
			-- need to dump inventory before we can continue shifting rows
			print("no room to shift rows")
			if i == 2 then
				faceRight()
				-- undo the one move we had done
				turtle.forward()
			end

			shiftToHomeRow()
			faceBackward()
			dumpInventoryNonFuels()
			shiftToCurrentMiningRow()
			-- recursing...
			return
		end
    end

    while not turtle.down() do
		result = mineInDirection(EMineDirection.Below, false)
		if result == EMineAttemptResult.NoRoom then
			-- need to dump inventory before we can continue shifting rows
			print("no room to shift rows")

			break
		end
    end
    currentRowLocation = currentRowLocation + 1
end

local function shiftToPreviousRow()
    faceRight()
	while not turtle.up() do
        turtle.digUp()
    end

    for i = 1, 2 do
        while not turtle.forward() do
            turtle.dig()
        end
    end
    currentRowLocation = currentRowLocation - 1
end

local function shiftToHomeRow()
	while currentRowLocation > 0 do
        shiftToPreviousRow()
    end
end

local function shiftToCurrentMiningRow()
	while currentRowLocation < getRowCountFullyMined() do
        shiftToNextRow()
    end
end

local function mineRow()
	local isRowFinished = false
	recentMinedDirection = EMineDirection.Forward
	pointAlongRowToReturnTo = 1
	while not isRowFinished do
        shiftToCurrentMiningRow()
		faceForward()
		local hadToPauseRowToEmptySelf = false
		for i = pointAlongRowToReturnTo, distance do
			-- mine in direction order
			for mineDirection = recentMinedDirection, EMineDirection.Above do
				skipTrashBlocks = (mineDirection ~= EMineDirection.Forward)
				local result = mineInDirection(mineDirection, skipTrashBlocks)
				if result == EMineAttemptResult.NoRoom then
					if mineDirection == EMineDirection.Forward then
						pointAlongRowToReturnTo = i - 1
					end
					hadToPauseRowToEmptySelf = true
                    print("no room")
					break-- SMART MINER WITH BLACKLIST CHECK

-- Enums
local EMineAttemptResult = {
    IsTrash = 0,
    NoRoom = 1,
    Mined = 2,
    EmptySpace = 3
}

local EMineDirection = {
    Forward = 0,
    Left = 1,
    Below = 2,
    Right = 3,
    Above = 4
}

local EFacingDirection = {
    Forward = 1,
    Right = 2,
    Backward = 3,
    Left = 4,
	MAX = 4,
	MIN = 1
}

-- Config
local args = { ... }
local distance = tonumber(args[1]) or 3
local rowCount = tonumber(args[2]) or 2

-- Mutable State
local pointAlongRowToReturnTo = -1
local remainingRows = rowCount
local recentMinedDirection = 0
local currentFacingDirection = EFacingDirection.Forward
local currentRowLocation = 0

local blacklist = {
  ["minecraft:bedrock"] = true,
  ["minecraft:barrier"] = true
}

local trashlist = {
  ["minecraft:stone"] = true,
  ["minecraft:cobblestone"] = true,
  ["quark:limestone"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:gravel"] = true,
  ["minecraft:sand"] = true,
  ["chisel:basalt2"] = true,
  ["biomesoplenty:dirt"] = true,
  ["minecraft:clay_ball"] = true,
}

local fuellist = {
  ["minecraft:coal"] = true,
  ["minecraft:planks"] = true,
  ["natura:overworld_planks"] = true,
  ["biomesoplenty:planks_0"] = true,
  ["thaumcraft:planks_silverwood"] = true,
}

local function turnRight()
	turtle.turnRight()
	currentFacingDirection = currentFacingDirection + 1
	while currentFacingDirection > EFacingDirection.MAX do
		currentFacingDirection = currentFacingDirection - EFacingDirection.MAX
	end
end

local function turnLeft()
	turtle.turnLeft()
	currentFacingDirection = currentFacingDirection - 1
	while currentFacingDirection < EFacingDirection.MIN do
		currentFacingDirection = currentFacingDirection + EFacingDirection.MAX
	end
end

local function turnAround()
	turnRight()
	turnRight()
end

local function faceForward()
	if currentFacingDirection == EFacingDirection.Forward then
		-- already facing forward!
		return
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnAround()
	end
end

local function faceBackward()
	if currentFacingDirection == EFacingDirection.Backward then
		-- already facing backward!
		return
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnAround()
	end
end

local function faceRight()
	if currentFacingDirection == EFacingDirection.Right then
		-- already facing right!
		return
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Left then
		turnAround()
	end
end

local function faceLeft()
	if currentFacingDirection == EFacingDirection.Left then
		-- already facing left!
		return
	end
	if currentFacingDirection == EFacingDirection.Forward then
		turnLeft()
	end
	if currentFacingDirection == EFacingDirection.Backward then
		turnRight()
	end
	if currentFacingDirection == EFacingDirection.Right then
		turnAround()
	end
end

local function faceDirection(directionToFace)
	facingDirectionDelta = directionToFace - currentFacingDirection
	if facingDirectionDelta == 0 then
		-- no change needed
		return
	end
	if facingDirectionDelta == 2 or facingDirectionDelta == -2 then
		turnAround()
	end
	if facingDirectionDelta == 1 or facingDirectionDelta == -3 then
		turnLeft()
	end
	if facingDirectionDelta == 3 or facingDirectionDelta == -1 then
		turnLeft()
	end
end

local function getRowCountFullyMined()
  return rowCount - remainingRows 
end

local function isBlacklisted(name)
  return blacklist[name] == true
end

local function isTrashlisted(name)
  return trashlist[name] == true
end

local function isFuel(name)
  return fuellist[name] == true
end

local function isInventoryFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

local function hasRoomInInventoryFor(itemName)
    for slot = 1, 16 do
        turtle.select(slot)

        local itemInSlot = turtle.getItemDetail(slot)
        if not itemInSlot then
			-- empty slot, of course we have room
			return true
        end
		if itemName == itemInSlot.name then
			local maxStack = itemInSlot.maxCount or 64
            if itemInSlot.count < maxStack then
                return true
            end
		end
    end
	return false
end

local function dumpInventoryFilter(filterFunctor)
    faceBackward()
    
    local filler_needed = pointAlongRowToReturnTo - 1
    local filler_reserved = 0

    -- First pass: count available filler items
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and isTrashlisted(item.name) then
            filler_reserved = filler_reserved + turtle.getItemCount(slot)
        end
    end

    -- Clamp to needed amount
    filler_reserved = math.min(filler_reserved, filler_needed)

    -- Second pass: dump everything except what we want to keep
    for slot = 1, 16 do
        turtle.select(slot)
        local item = turtle.getItemDetail(slot)

        if item then
            local is_filler = isTrashlisted(item.name)

            if filterFunctor(item.name) then
                -- keep via filter
            elseif is_filler and filler_reserved > 0 then
                -- reserve filler
                local keep = math.min(turtle.getItemCount(slot), filler_reserved)
                filler_reserved = filler_reserved - keep
            else
                turtle.drop()
            end
        end
    end
end

local function dumpInventoryAll()
    dumpInventoryFilter(function(itemName) return false end)
end

local function dumpInventoryNonFuels()
    dumpInventoryFilter(function(itemName) return isFuel(itemName) end)
end

local function placeTrashBehind()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)

        if item and isTrashlisted(item.name) then
            turtle.select(slot)
			faceForward()
            turtle.place()
			faceBackward()
            return true
        end
    end
    return false
end

local function mineInDirection(mineDirection, skipTrashBlocks)
	recentMinedDirection = mineDirection

	local mineFunction = turtle.dig
	local inspectFunction = turtle.inspect
	local preMineTurnFunction = function() end
	local postMineTurnFunction = function() end

	if mineDirection == EMineDirection.Below then
		mineFunction = turtle.digDown
		inspectFunction = turtle.inspectDown
	elseif mineDirection == EMineDirection.Above then
		mineFunction = turtle.digUp
		inspectFunction = turtle.inspectUp
	elseif mineDirection == EMineDirection.Right then
		preMineTurnFunction = faceRight
		postMineTurnFunction = faceForward
	elseif mineDirection == EMineDirection.Left then
		preMineTurnFunction = faceLeft
		postMineTurnFunction = faceForward
	end

	preMineTurnFunction()

	local has_block, data = inspectFunction()
	if not has_block then
        if mineDirection == EMineDirection.Forward then
            turtle.forward()
        end
		postMineTurnFunction()
		return EMineAttemptResult.EmptySpace
	end

	if skipTrashBlocks == true then
		if isBlacklisted(data.name) or isTrashlisted(data.name) then
			postMineTurnFunction()
			return EMineAttemptResult.IsTrash
		end
	end

	if not hasRoomInInventoryFor(data.name) then
		postMineTurnFunction()
		return EMineAttemptResult.NoRoom
	end

	mineFunction()

	postMineTurnFunction()

	if mineDirection == EMineDirection.Forward then 
		if turtle.detect() then
			-- something fell in place - mine thru it too
			skipTrashBlocks = (mineDirection ~= EMineDirection.Forward)
    		return mineInDirection(mineDirection, skipTrashBlocks)
		else
			turtle.forward()
		end
	end

	return EMineAttemptResult.Mined
end

local function shiftToNextRow()
	--supports going back in the middle of shifting to next row
	-- next row is always to the left 
    faceLeft()
    for i = 1, 2 do
		result = mineInDirection(EMineDirection.Forward, false)
		if result == EMineAttemptResult.NoRoom then
			-- need to dump inventory before we can continue shifting rows
			print("no room to shift rows")
			if i == 2 then
				faceRight()
				-- undo the one move we had done
				turtle.forward()
			end

			shiftToHomeRow()
			faceBackward()
			dumpInventoryNonFuels()
			shiftToCurrentMiningRow()
			-- recursing...
			return
		end
    end

    while not turtle.down() do
		result = mineInDirection(EMineDirection.Below, false)
		if result == EMineAttemptResult.NoRoom then
			-- need to dump inventory before we can continue shifting rows
			print("no room to shift rows")

			break
		end
    end
    currentRowLocation = currentRowLocation + 1
end

local function shiftToPreviousRow()
    faceRight()
	while not turtle.up() do
        turtle.digUp()
    end

    for i = 1, 2 do
        while not turtle.forward() do
            turtle.dig()
        end
    end
    currentRowLocation = currentRowLocation - 1
end

local function shiftToHomeRow()
	while currentRowLocation > 0 do
        shiftToPreviousRow()
    end
end

local function shiftToCurrentMiningRow()
	while currentRowLocation < getRowCountFullyMined() do
        shiftToNextRow()
    end
end

local function mineRow()
	local isRowFinished = false
	recentMinedDirection = EMineDirection.Forward
	pointAlongRowToReturnTo = 1
	while not isRowFinished do
        shiftToCurrentMiningRow()
		faceForward()
		local hadToPauseRowToEmptySelf = false
		for i = pointAlongRowToReturnTo, distance do
			-- mine in direction order
			for mineDirection = recentMinedDirection, EMineDirection.Above do
				skipTrashBlocks = (mineDirection ~= EMineDirection.Forward)
				local result = mineInDirection(mineDirection, skipTrashBlocks)
				if result == EMineAttemptResult.NoRoom then
					if mineDirection == EMineDirection.Forward then
						pointAlongRowToReturnTo = i - 1
					end
					hadToPauseRowToEmptySelf = true
                    print("no room")
					break
				end

				if mineDirection >= EMineDirection.Forward then
			if hadToPauseRowToEmptySelf == true then
				break
			end
            
            -- mined all directions successfully - reset for next.
            recentMinedDirection = EMineDirection.Forward
		end

		-- go back
		faceBackward()
		for i = 1, pointAlongRowToReturnTo do
			turtle.forward()
			if not hadToPauseRowToEmptySelf then
				placeTrashBehind()
			end
		end
        
        -- now align to home row
        shiftToHomeRow()

		-- will need to add handling here once we have more than one row

		if not hadToPauseRowToEmptySelf then
    		isRowFinished = true
    		remainingRows = remainingRows - 1
    		pointAlongRowToReturnTo = 1
		else
            print("dumping inv")
			dumpInventoryNonFuels()
			faceForward()
            
            print("pointAlongRowToReturnTo: %d", pointAlongRowToReturnTo)

			-- get back to where we left off
			for i = 1, pointAlongRowToReturnTo do
				print("trying to go forward")
				turtle.forward()
			end
		end
	end
end

local function mineLayer()
	for i = 1, rowCount do
		-- note that mineRow is all encapsulating - if we need to go back to dump stuff
		-- in the middle of a row, it will handle that and return us to the correct spot to continue mining
		mineRow()
		if i < rowCount then
			-- note that shiftToNextRow is all encapsulating - if we need to go back to dump stuff
			-- in the middle of the transition, it will handle that and return us to the correct spot to continue mining
			shiftToNextRow()

			-- face the new wall we want to mine
			faceForward()
		end
	end
end

local function main()
	mineLayer()
	
	-- final dump
	dumpInventoryAll()
	faceForward()
	print("Ending Smart Mine Sequence.")
end

main()