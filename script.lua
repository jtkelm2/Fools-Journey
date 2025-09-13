---------------------------------------------------------------
-- CONSTANTS & CONFIGURATION
---------------------------------------------------------------

-- Colors
local CYAN = Color(77/255, 172/255, 219/255)
local RED = Color(222/255, 72/255, 64/255)
local GREEN = Color(160/255, 224/255, 150/255)
local PURPLE = Color(83/255, 54/255, 133/255)
local YELLOW = Color(214/255, 195/255, 49/255)

-- Player Indices
local R = 1
local B = 2

-- GUI Object IDs
local REFRESH_BUTTON = "b93b10"
local MANIPULATE_BUTTON = "dd467f"
local RUN_BUTTON = {"6b7538","da8a3a"}
local CONFIRM_BUTTON = {"88fdc8","d39970"}

-- Zone IDs
local DECK = {"7252cd","33ebb4"}
local REFRESH = {"99fcf1","dff599"}
local DISCARD = {"a9f9a1","dd5372"}
local ACTION_SLOT = {{"025a8f","cd47b4","257ff7","6f6869"},{"6fc3f9","88f2d3","bc9185","d83d04"}}
local MANIPULATION_SLOT = {{"e4cd71","254ac7","ca7b5e"},{"037e0d","9f3b44","15affc"}}
local MISC_SLOT = {{"e4cd71","254ac7","ca7b5e","8771a2"},{"037e0d","9f3b44","15affc","1eefb8"}}
local EQUIPMENT_SLOT = {{"4b9aab","a9d81a"},{"f24971","1d6ff8"}}
local WEAPON = {"88ba3b","502518"}
local KILL_SLOT = {"a3159f","f90292"}

-- Counter IDs
local HP_COUNTER = {"66d824","2b0791"}
local ATK_COUNTER = {"fbcd06",""}

-- Special Card IDs
local GUARDBAG = "63b0e8"
local WITNESS_CARDS = {"07cba6","2892ae"}

---------------------------------------------------------------
-- GAME STATE
---------------------------------------------------------------

local ready = {false, false}

---------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------

function onLoad()
    showRefreshButton()
end

function onUpdate()
    -- Empty update function
end

---------------------------------------------------------------
-- REFRESH PHASE
---------------------------------------------------------------

function refreshButtonClicked(clicked_object, player_color, rightClick)
    local color = (player_color == "Red") and R or B
    if not rightClick then ready[color] = true else ready[other(color)] = true end
    updateRefreshButton()
end

function updateRefreshButton()
    local refreshButton = getObjectFromGUID(REFRESH_BUTTON)
    local label = ""
    
    if ready[R] and not ready[B] then
        label = "(X) Refresh"
    elseif not ready[R] and ready[B] then
        label = "Refresh (X)"
    else
        label = "Refresh"
    end
    
    refreshButton.editButton({index=0, label=label})
    
    if ready[R] and ready[B] then
        ready = {false, false}
        refreshButton.clearButtons()
        refresh(R)
        refresh(B)
        addCallYourShotContext()
        Wait.time(function() showManipulateButton() end, 3)
    end
end

function showRefreshButton()
    local refreshButton = getObjectFromGUID(REFRESH_BUTTON)
    makeButton(refreshButton,CYAN,'Refresh','refreshButtonClicked')
end

function refresh(color)
    deactivateRunButton(color)
    checkEmpress(color)
    returnElusivesFromActions(color)
    Wait.time(function() shuffleRefreshPile(color) end, 1.5)
    Wait.time(function()
        dealActions(color,1)
        dealHand(color)
        dealManipulation(color)
    end, 3.5)
end

function shuffleRefreshPile(color)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    local deckZone = getObjectFromGUID(DECK[color])
    
    moveZoneToZone(refreshZone,deckZone)
    Wait.time(function() shuffleZone(deckZone) end,1.5)
end

function dealActions(color,excepting)
    local deckZone = getObjectFromGUID(DECK[color])
    
    local emptySlots = {}
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(ACTION_SLOT[color][i])
        local slotObj = getFromZone(slotZone)
        
        if not slotObj then table.insert(emptySlots, slotZone) end
    end
    
    local numEmpty = #emptySlots
    local cardsToDeal = math.max(0, numEmpty - excepting)
    
    for i = 1, cardsToDeal do
        Wait.time(function()
            dealZoneToZone(deckZone,emptySlots[i],true)
        end, i * 0.2)
    end
end

function dealHand(color)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local deck = getFromZone(deckZone)
    
    local playerColor = (color == R) and "Red" or "Blue"
    
    local currentHandSize = #Player[playerColor].getHandObjects()
    local cardsToDraw = math.max(0, 4 - currentHandSize)
    
    if deck and cardsToDraw > 0 then
        deck.deal(cardsToDraw, playerColor)
    end

    Wait.time(function()
            for _, card in ipairs(Player[playerColor].getHandObjects()) do
                card.clearContextMenu()
                addRefreshContext(card)
                addDiscardContext(card)
            end
        end, 1)
end

function dealManipulation(color)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    
    for i = 1, 2 do
        local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][i])
        Wait.time(function()
            dealZoneToZone(deckZone,slotZone,true)
        end, i * 0.2)
    end
end

---------------------------------------------------------------
-- MANIPULATE PHASE
---------------------------------------------------------------

function manipulateButtonClicked(clicked_object, player_color, rightClick)
    local color = (player_color == "Red") and R or B
    if not rightClick then ready[color] = true else ready[other(color)] = true end
    updateManipulateButton()
end

function updateManipulateButton()
    local manipulateButton = getObjectFromGUID(MANIPULATE_BUTTON)
    local label = ""
    
    if ready[R] and not ready[B] then
        label = "(X) Manipulate"
    elseif not ready[R] and ready[B] then
        label = "Manipulate (X)"
    else
        label = "Manipulate"
    end
    
    manipulateButton.editButton({index=0, label=label})
    
    if ready[R] and ready[B] then
        ready = {false, false}
        manipulateButton.clearButtons()
        manipulate(R)
        manipulate(B)
        Wait.time(function() showRefreshButton() end, 6)
    end
end

function showManipulateButton()
    local manipulateButton = getObjectFromGUID(MANIPULATE_BUTTON)
    makeButton(manipulateButton,PURPLE,'Manipulate','manipulateButtonClicked')
end

function manipulate(color)
    flipManipulationCards(color)
    sendFourthCard(color)
    returnElusivesFromHand(color)
    Wait.time(function()
        mixAndSendManipulationCards(color)
        Wait.time(function() activateRunButton(color) end, 3)
    end,1.7)
end

function flipManipulationCards(color)
    for i = 1, 2 do
        local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][i])
        local card = getFromZone(slotZone)
        if card then
            Wait.time(function() card.flip() end, 0.3*i)
        end
    end
end

function sendFourthCard(color)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][3])
    dealZoneToZone(deckZone,slotZone,false)
end

function mixAndSendManipulationCards(color)
    local fourthSlotZone = getObjectFromGUID(MANIPULATION_SLOT[color][3])
    local otherRefreshZone = getObjectFromGUID(REFRESH[other(color)])
    local otherDeckZone = getObjectFromGUID(DECK[other(color)])

    for i = 1, 2 do
        local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][i])
        dealZoneToZone(slotZone,fourthSlotZone,false)
    end
    
    Wait.time(function()
        local equipment = getFlippedEquipment(color)
        if equipment then
            discardCardSmooth(equipment,color)
        else
            shuffleZone(fourthSlotZone)
        end

        local emptyActionSlots = countEmptyActionSlots(other(color))

        for j = 1, emptyActionSlots do
            Wait.time(function() dealZoneToZone(fourthSlotZone,otherDeckZone,false) end, 0.1*j)
        end
        Wait.time(function() moveZoneToZone(fourthSlotZone,otherRefreshZone) end, 0.6)
        Wait.time(function() dealActions(other(color),0) end, 2.5)
    end, 2.1)
end

---------------------------------------------------------------
-- RUN PHASE
---------------------------------------------------------------

function runButtonClicked(clicked_object, player_color)
    clicked_object.clearButtons()
    local color = (player_color == "Red") and R or B
    run(color)
    prepRun(other(color))
end

function activateRunButton(color)
    local runButton = getObjectFromGUID(RUN_BUTTON[color])
    makeButton(runButton,RED,'Run','runButtonClicked')
end

function deactivateRunButton(color)
    local runButton = getObjectFromGUID(RUN_BUTTON[color])
    runButton.clearButtons()
end

function run(color)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(ACTION_SLOT[color][i])
        Wait.time(function()
            dealZoneToZone(slotZone,refreshZone,true)
        end, i * 0.1)
    end
end

function prepRun(color)
    local deckZone = getObjectFromGUID(DECK[other(color)])

    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        Wait.time(function ()
            dealZoneToZone(deckZone,slotZone,true)
        end, i*0.1)
    end

    Wait.time(function() makeRunDecisionButtons(color) end, 1)
end

function makeRunDecisionButtons(color)
    local confirmButton = getObjectFromGUID(CONFIRM_BUTTON[color])
    makeButton(confirmButton, YELLOW, 'Confirm', 'confirmButtonClicked')

    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        local card = getFromZone(slotZone)
        if card then
            card.createButton(
                {click_function = 'recycleButtonClicked',
                label = 'Recycle',
                width = 800, height = 300, font_size = 150,
                color = GREEN,
                position = {0, 1, 2}})
        end
    end
end

function recycleButtonClicked(clicked_object, player_color)
    local color = (player_color == "Red") and R or B
    local refreshZone = getObjectFromGUID(REFRESH[other(color)])

    clicked_object.clearButtons()
    clicked_object.flip()
    clicked_object.setPositionSmooth(refreshZone.getPosition())

    Wait.time(function() dealRecycledCards(color) end, 0.5)
end

function dealRecycledCards(color)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        local card = getFromZone(slotZone)
        if not card then
            dealZoneToZone(deckZone,slotZone,false)
        end
    end
end

function confirmButtonClicked(clicked_object, player_color)
    clicked_object.clearButtons()

    local color = (player_color == "Red") and R or B
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        local card = getFromZone(slotZone)
        if card then
            card.clearButtons()
            if not isFlipped(card) then card.flip() end
        end
    end

    Wait.time(function() mixAndSendMiscCards(color) end, 1)
end

function mixAndSendMiscCards(color)
    local fourthSlotZone = getObjectFromGUID(MISC_SLOT[color][4])
    local otherRefreshZone = getObjectFromGUID(REFRESH[other(color)])
    local otherDeckZone = getObjectFromGUID(DECK[other(color)])

    for i = 1, 3 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        dealZoneToZone(slotZone,fourthSlotZone,false)
    end
    
    Wait.time(function()
        shuffleZone(fourthSlotZone)

        local emptyActionSlots = countEmptyActionSlots(other(color))

        for j = 1, emptyActionSlots do
            Wait.time(function() dealZoneToZone(fourthSlotZone,otherDeckZone,false) end, 0.1*j)
        end
        Wait.time(function() moveZoneToZone(fourthSlotZone,otherRefreshZone) end, 0.6)
        Wait.time(function() dealActions(other(color),0) end, 2.5)
    end, 2.1)
end

---------------------------------------------------------------
-- SPECIAL CARD MECHANICS
---------------------------------------------------------------

-- Equipment Effects
function checkEmpress(color)
    local hpCounter = getObjectFromGUID(HP_COUNTER[color])
    
    local eqZones = {getObjectFromGUID(EQUIPMENT_SLOT[color][1]), getObjectFromGUID(EQUIPMENT_SLOT[color][2])}
    local foundEmpress = checkZonesForTag(eqZones,"Empress")
    
    if foundEmpress and hpCounter.Counter.getValue() < 20 then
        hpCounter.Counter.increment()
    end
end

function getFlippedEquipment(color)
    for i = 1, 2 do
        local equipmentZone = getObjectFromGUID(EQUIPMENT_SLOT[color][i])
        local equipment = getFromZone(equipmentZone)
        if equipment and isFlipped(equipment) then
            return equipment
        end
    end
end

-- Elusive Cards
function returnElusivesFromHand(color)
    local playerColor = (color == R) and "Red" or "Blue"
    for _, card in ipairs(Player[playerColor].getHandObjects()) do
        if card.hasTag("Elusive") then
            card.flip()
            Wait.time(function() refreshCard(card,other(color)) end, 0.5)
        end
    end
end

function returnElusivesFromActions(color)
    for i = 1, 4 do
        local actionSlot = getObjectFromGUID(ACTION_SLOT[color][i])
        local card = getFromZone(actionSlot)
        if card and card.hasTag("Elusive") then
            card.flip()
            refreshCardSmooth(card,color)
        end
    end
end

-- Guards & Witness Cards
function disarm(color)
    local weaponSlot = getObjectFromGUID(WEAPON[color])
    local killSlot = getObjectFromGUID(KILL_SLOT[color])

    discardZone(weaponSlot,color)
    discardZone(killSlot,color)
end

function callGuardsOn(color)
    disarm(color)

    local guardBag = getObjectFromGUID(GUARDBAG)
    for i = 1, 4 do
        local actionSlot = getObjectFromGUID(ACTION_SLOT[color][i])
        Wait.time(function()
            local guard = guardBag.takeObject()
            guard.setPositionSmooth(actionSlot.getPosition())
        end, 0.3*i)
    end
end

function addCallYourShotContext()
    for _, cardId in ipairs(WITNESS_CARDS) do
        local card = getObjectFromGUID(cardId)
        if card then
            card.clearContextMenu()
            card.addContextMenuItem("Call your shot!", function(player_color)
                local color = (player_color == "Red") and R or B
                discardCardSmooth(card,color)
                callGuardsOn(other(color)) end)
        end
    end
end

---------------------------------------------------------------
-- CARD CONTEXT MENUS
---------------------------------------------------------------

function addDiscardContext(card)
    if not card then return end
    if card.hasTag("Elusive") then
        card.addContextMenuItem("Cannot discard!", function(_) end)
    else
        card.addContextMenuItem("Send to discard", function(player_color)
           local color = (player_color == "Red") and R or B
           local discardZone = getObjectFromGUID(DISCARD[other(color)])
           card.flip()
           Wait.time(function() card.setPosition(discardZone.getPosition()) end, 0.5)
    end)
    end
end

function addRefreshContext(card)
    card.addContextMenuItem("Send to refresh", function(player_color)
        local color = (player_color == "Red") and R or B
        local refreshZone = getObjectFromGUID(REFRESH[other(color)])
        card.flip()
        Wait.time(function() card.setPosition(refreshZone.getPosition()) end, 0.5)
    end)
end

---------------------------------------------------------------
-- ZONE MANAGEMENT
---------------------------------------------------------------

function moveZoneToZone(zoneA,zoneB)
    local obj = getFromZone(zoneA)
    if not obj then return end
    
    obj.setPositionSmooth(zoneB.getPosition())
end

function dealZoneToZone(zoneA,zoneB,flip)
    local obj = getFromZone(zoneA)
    if not obj then return end
    
    local card
    if obj.type == "Card" then card = obj end
    if obj.type == "Deck" then card = obj.takeObject() end
    
    if flip then card.flip() end
    
    card.setPositionSmooth(zoneB.getPosition())
end

function shuffleZone(zone)
    local obj = getFromZone(zone)
    if not obj then return end

    obj.shuffle()
end

-- Discard Zone Operations
function discardCard(card,color)
    local discardZone = getObjectFromGUID(DISCARD[color])
    card.setPosition(discardZone.getPosition())
end

function discardCardSmooth(card,color)
    local discardZone = getObjectFromGUID(DISCARD[color])
    card.setPositionSmooth(discardZone.getPosition())
end

function discardZone(zone,color)
    local discard = getObjectFromGUID(DISCARD[color])
    local obj = getFromZone(zone)
    if obj then obj.setPositionSmooth(discard.getPosition()) end
end

-- Refresh Zone Operations
function refreshCard(card,color)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    card.setPosition(refreshZone.getPosition())
end

function refreshCardSmooth(card,color)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    card.setPositionSmooth(refreshZone.getPosition())
end

---------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------

function makeButton(obj,color,label,func)
    obj.createButton(
        {click_function = func,
        label = label,
        width = 5500, height = 1700, font_size = 1200,
        color = color,
        position = {0, 1, 0}})
    obj.setColorTint({0,0,0,0})
    obj.locked = true
end

---------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------

function getFromZone(zone)
    for _, obj in ipairs(zone.getObjects()) do
        if obj.type == "Card" or obj.type == "Deck" then
            return obj
        end
    end
end

function checkZoneForTag(zone,tag)
    local obj = getFromZone(zone)
    if not obj then return false end
    
    return obj.hasTag(tag)
end

function checkZonesForTag(zones,tag)
    for _, zone in ipairs(zones) do
        if checkZoneForTag(zone,tag) then
            return true
        end
    end
    return false
end

function countEmptyActionSlots(color)
    local emptySlots = 0

    for i = 1, 4 do
        local slotZone = getObjectFromGUID(ACTION_SLOT[color][i])
        local slotObj = getFromZone(slotZone)
        
        if not slotObj then emptySlots = emptySlots + 1 end
    end
    
    return emptySlots
end

function isFlipped(card)
    local rot = card.getRotation()
    return rot[3] > 90 and rot[3] < 270
end

function other(color)
    return 3-color
end

---------------------------------------------------------------
-- CARD DATA
---------------------------------------------------------------

local cardData = {
    ["1 of Wands"] = {
        class = "Weapon",
        val = 1
    },
    ["2 of Wands"] = {
        class = "Weapon",
        val = 2
    },
    ["3 of Wands"] = {
        class = "Weapon",
        val = 3
    },
    ["4 of Wands"] = {
        class = "Weapon",
        val = 4
    },
    ["5 of Wands"] = {
        class = "Weapon",
        val = 5
    },
    ["6 of Wands"] = {
        class = "Weapon",
        val = 6
    },
    ["7 of Wands"] = {
        class = "Weapon",
        val = 7
    },
    ["8 of Wands"] = {
        class = "Weapon",
        val = 8
    },
    ["9 of Wands"] = {
        class = "Weapon",
        val = 9
    },
    ["10 of Wands"] = {
        class = "Weapon",
        val = 10
    },
    ["Strength"] = {
        class = "Weapon",
        val = 8
    }
}