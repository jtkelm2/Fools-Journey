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

-- Timing Constants
local CARD_MOVE_DELAY = 1.8
local CARD_TELE_DELAY = 1.0
local CARD_FLIP_DELAY = 0.5
local SHUFFLE_DELAY = 0.3
local DEAL_SEQUENCE_DELAY = 0.1

---------------------------------------------------------------
-- GAME STATE
---------------------------------------------------------------

local ready = {false, false}

---------------------------------------------------------------
-- CALLBACK SYSTEM
---------------------------------------------------------------

local Chain = {}
Chain.__index = Chain

function Chain:new()
    local instance = {
        steps = {},
        onComplete = nil
    }
    setmetatable(instance, self)
    return instance
end

function Chain:next(func)
    table.insert(self.steps, {
        type = "sequential",
        func = func
    })
    return self
end

function Chain:parallel(funcs, delay)
    table.insert(self.steps, {
        type = "parallel",
        funcs = funcs,
        delay = delay or 0
    })
    return self
end

function Chain:wait(delay)
    table.insert(self.steps, {
        type = "wait",
        delay = delay
    })
    return self
end

function Chain:complete(callback)
    self.onComplete = callback
    return self
end

function Chain:run()
    self:_executeStep(1)
end

function Chain:_executeStep(index)
    if index > #self.steps then
        if self.onComplete then
            self.onComplete()
        end
        return
    end
    
    local step = self.steps[index]
    
    if step.type == "sequential" then
        step.func(function() self:_executeStep(index + 1) end)
    elseif step.type == "parallel" then
        local completed = 0
        local total = #step.funcs

        if total == 0 then
            self:_executeStep(index + 1)
            return
        end
        
        local checkComplete = function()
            completed = completed + 1
            if completed >= total then
                self:_executeStep(index + 1)
            end
        end
        
        for i, func in ipairs(step.funcs) do
            Wait.time(function()
                func(checkComplete)
            end, step.delay * (i - 1))
        end
    elseif step.type == "wait" then
        Wait.time(function()
            self:_executeStep(index + 1)
        end, step.delay)
    end
end

function chain()
    return Chain:new()
end

---------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------

function onLoad()
    showRefreshButton()
end

function onUpdate()
end

---------------------------------------------------------------
-- ASYNC HELPER FUNCTIONS
---------------------------------------------------------------

function moveZoneToZone(zoneA, zoneB, callback)
    local obj = getFromZone(zoneA)
    if not obj then
        if callback then callback() end
        return
    end
    
    obj.setPositionSmooth(zoneB.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
end

function dealZoneToZone(zoneA, zoneB, flip, callback)
    local obj = getFromZone(zoneA)
    if not obj then
        if callback then callback() end
        return
    end
    
    local card
    if obj.type == "Card" then card = obj end
    if obj.type == "Deck" then card = obj.takeObject() end
    
    if flip then card.flip() end
    card.setPositionSmooth(zoneB.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
end

function shuffleZone(zone, callback)
    local obj = getFromZone(zone)
    if not obj then
        if callback then callback() end
        return
    end
    
    obj.shuffle()
    Wait.time(callback or function() end, SHUFFLE_DELAY)
end

function discardCardSmooth(card, color, callback)
    local discardZone = getObjectFromGUID(DISCARD[color])
    card.setPositionSmooth(discardZone.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
end

function refreshCardSmooth(card, color, callback)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    card.setPositionSmooth(refreshZone.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
end

function flipCard(card, callback)
    card.flip()
    Wait.time(callback or function() end, CARD_FLIP_DELAY)
end

function discardZone(zone, color, callback)
    local discard = getObjectFromGUID(DISCARD[color])
    local obj = getFromZone(zone)
    if obj then 
        obj.setPositionSmooth(discard.getPosition())
        Wait.time(callback or function() end, CARD_MOVE_DELAY)
    else
        if callback then callback() end
    end
end

function dealFromGuardBag(guardBag, targetZone, callback)
    local guard = guardBag.takeObject()
    guard.setPositionSmooth(targetZone.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
end

function refreshCard(card, color, callback)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    card.setPosition(refreshZone.getPosition())
    Wait.time(callback or function() end, CARD_TELE_DELAY)
end

function refreshCardSmooth(card, color, callback)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    card.setPositionSmooth(refreshZone.getPosition())
    Wait.time(callback or function() end, CARD_MOVE_DELAY)
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
        
        chain()
            :parallel({
                function(done) refresh(R, done) end,
                function(done) refresh(B, done) end
            })
            :next(function(done)
                addCallYourShotContext()
                showManipulateButton()
                done()
            end)
            :run()
    end
end

function showRefreshButton()
    local refreshButton = getObjectFromGUID(REFRESH_BUTTON)
    makeButton(refreshButton, CYAN, 'Refresh', 'refreshButtonClicked')
end

function refresh(color, callback)
    deactivateRunButton(color)
    checkEmpress(color)

    chain()
        :next(function(done) returnElusivesFromActions(color, done) end)
        :next(function(done) shuffleRefreshPile(color, done) end)
        :parallel({
            function(done) dealActions(color, 1, done) end,
            function(done) dealHand(other(color), done) end,
            function(done) dealManipulation(other(color), done) end
        })
        :complete(callback)
        :run()
end

function shuffleRefreshPile(color, callback)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    local deckZone = getObjectFromGUID(DECK[color])
    
    chain()
        :next(function(done) moveZoneToZone(refreshZone, deckZone, done) end)
        :next(function(done) shuffleZone(deckZone, done) end)
        :complete(callback)
        :run()
end

function dealActions(color, excepting, callback)
    local deckZone = getObjectFromGUID(DECK[color])
    
    local emptySlots = {}
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(ACTION_SLOT[color][i])
        local slotObj = getFromZone(slotZone)
        
        if not slotObj then table.insert(emptySlots, slotZone) end
    end
    
    local numEmpty = #emptySlots
    local cardsToDeal = math.max(0, numEmpty - excepting)
    
    if cardsToDeal == 0 then
        if callback then callback() end
        return
    end
    
    local dealFunctions = {}
    for i = 1, cardsToDeal do
        table.insert(dealFunctions, function(done)
            dealZoneToZone(deckZone, emptySlots[i], true, done)
        end)
    end
    
    chain()
        :parallel(dealFunctions, DEAL_SEQUENCE_DELAY)
        :complete(callback)
        :run()
end

function dealHand(color, callback)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local deck = getFromZone(deckZone)
    
    local playerColor = (color == R) and "Red" or "Blue"
    
    local currentHandSize = #Player[playerColor].getHandObjects()
    local cardsToDraw = math.max(0, 4 - currentHandSize)

    local ch = chain()
    if deck and cardsToDraw > 0 then
        ch
            :next(function(done) deck.deal(cardsToDraw, playerColor); done() end)
            :wait(CARD_MOVE_DELAY)
    end

    ch
        :next(function(done)
            for _, card in ipairs(Player[playerColor].getHandObjects()) do
                card.clearContextMenu()
                addRefreshContext(card)
                addDiscardContext(card)
            end
            done()
        end)
        :complete(callback)
        :run()
end

function dealManipulation(color, callback)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    
    local dealFunctions = {}
    for i = 1, 2 do
        local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][i])
        table.insert(dealFunctions, function(done)
            dealZoneToZone(deckZone, slotZone, true, done)
        end)
    end
    
    chain()
        :parallel(dealFunctions, DEAL_SEQUENCE_DELAY)
        :complete(callback)
        :run()
end

---------------------------------------------------------------
-- MANIPULATE PHASE (Game Logic Layer)
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
        
        chain()
            :parallel({
                function(done) manipulate(R, done) end,
                function(done) manipulate(B, done) end
            })
            :next(function(done) showRefreshButton() end)
            :run()
    end
end

function showManipulateButton()
    local manipulateButton = getObjectFromGUID(MANIPULATE_BUTTON)
    makeButton(manipulateButton, PURPLE, 'Manipulate', 'manipulateButtonClicked')
end

function manipulate(color, callback)
    chain()
        :parallel({
            function(done) flipManipulationCards(color, done) end,
            function(done) sendFourthCard(color, done) end,
            function(done) returnElusivesFromHand(color, done) end
        })
        :next(function(done) mixAndSendManipulationCards(color, done) end)
        :next(function(done) 
            activateRunButton(color)
            done()
        end)
        :complete(callback)
        :run()
end

function flipManipulationCards(color, callback)
    local flipFunctions = {}
    for i = 1, 2 do
        local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][i])
        local card = getFromZone(slotZone)
        if card then
            table.insert(flipFunctions, function(done)
                flipCard(card, done)
            end)
        end
    end
    
    chain()
        :parallel(flipFunctions, CARD_FLIP_DELAY)
        :complete(callback)
        :run()
end

function sendFourthCard(color, callback)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][3])
    dealZoneToZone(deckZone, slotZone, false, callback)
end

function mixAndSendManipulationCards(color, callback)
    local fourthSlotZone = getObjectFromGUID(MANIPULATION_SLOT[color][3])
    local otherRefreshZone = getObjectFromGUID(REFRESH[other(color)])
    local otherDeckZone = getObjectFromGUID(DECK[other(color)])

    chain()
        :parallel({
            function(done) 
                local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][1])
                dealZoneToZone(slotZone, fourthSlotZone, false, done)
            end,
            function(done)
                local slotZone = getObjectFromGUID(MANIPULATION_SLOT[color][2])
                dealZoneToZone(slotZone, fourthSlotZone, false, done)
            end
        })
        :next(function(done)
            local equipment = getFlippedEquipment(color)
            if equipment then
                discardCardSmooth(equipment, color)
                Wait.time(done, SHUFFLE_DELAY)
            else
                shuffleZone(fourthSlotZone, done)
            end
        end)
        :next(function(done)
            local emptyActionSlots = countEmptyActionSlots(other(color))
            local dealFunctions = {}
            
            for j = 1, emptyActionSlots do
                table.insert(dealFunctions, function(dealDone)
                    dealZoneToZone(fourthSlotZone, otherDeckZone, false, dealDone)
                end)
            end
            
            table.insert(dealFunctions, function(dealDone) moveZoneToZone(fourthSlotZone, otherRefreshZone, dealDone) end)

            chain()
                :parallel(dealFunctions, DEAL_SEQUENCE_DELAY)
                :next(function(actionDone)
                    dealActions(other(color), 0, actionDone)
                end)
                :complete(done)
                :run()
        end)
        :complete(callback)
        :run()
end

---------------------------------------------------------------
-- RUN PHASE
---------------------------------------------------------------

function runButtonClicked(clicked_object, player_color)
    clicked_object.clearButtons()
    local color = (player_color == "Red") and R or B
    
    chain()
        :parallel({
            function(done) run(color, done) end,
            function(done) prepRun(other(color), done) end
        })
        :run()
end

function activateRunButton(color)
    local runButton = getObjectFromGUID(RUN_BUTTON[color])
    makeButton(runButton, RED, 'Run', 'runButtonClicked')
end

function deactivateRunButton(color)
    local runButton = getObjectFromGUID(RUN_BUTTON[color])
    runButton.clearButtons()
end

function run(color, callback)
    local refreshZone = getObjectFromGUID(REFRESH[color])
    local moveFunctions = {}
    
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(ACTION_SLOT[color][i])
        table.insert(moveFunctions, function(done)
            dealZoneToZone(slotZone, refreshZone, true, done)
        end)
    end
    
    chain()
        :parallel(moveFunctions, DEAL_SEQUENCE_DELAY)
        :complete(callback)
        :run()
end

function prepRun(color, callback)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local dealFunctions = {}

    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        table.insert(dealFunctions, function(done)
            dealZoneToZone(deckZone, slotZone, true, done)
        end)
    end

    chain()
        :parallel(dealFunctions, DEAL_SEQUENCE_DELAY)
        :next(function(done) makeRunDecisionButtons(color); done() end)
        :complete(callback)
        :run()
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

    chain()
        :next(function(done)
            clicked_object.clearButtons()
            clicked_object.flip()
            clicked_object.setPositionSmooth(refreshZone.getPosition())
            done()
        end)
        :wait(CARD_FLIP_DELAY)
        :next(function(done) dealRecycledCards(color, done) end)
        :run()
end

function dealRecycledCards(color, callback)
    local deckZone = getObjectFromGUID(DECK[other(color)])
    local dealFunctions = {}
    
    for i = 1, 4 do
        local slotZone = getObjectFromGUID(MISC_SLOT[color][i])
        local card = getFromZone(slotZone)
        if not card then
            table.insert(dealFunctions, function(done)
                dealZoneToZone(deckZone, slotZone, false, done)
            end)
        end
    end
    
    if #dealFunctions == 0 then
        if callback then callback() end
        return
    end
    
    chain()
        :parallel(dealFunctions)
        :complete(callback)
        :run()
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

    chain()
        :wait(CARD_FLIP_DELAY)
        :next(function(done) mixAndSendMiscCards(color, done) end)
        :run()
end

function mixAndSendMiscCards(color, callback)
    local fourthSlotZone = getObjectFromGUID(MISC_SLOT[color][4])
    local otherRefreshZone = getObjectFromGUID(REFRESH[other(color)])
    local otherDeckZone = getObjectFromGUID(DECK[other(color)])

    chain()
        :parallel({
            function(done)
                local slotZone = getObjectFromGUID(MISC_SLOT[color][1])
                dealZoneToZone(slotZone, fourthSlotZone, false, done)
            end,
            function(done)
                local slotZone = getObjectFromGUID(MISC_SLOT[color][2])
                dealZoneToZone(slotZone, fourthSlotZone, false, done)
            end,
            function(done)
                local slotZone = getObjectFromGUID(MISC_SLOT[color][3])
                dealZoneToZone(slotZone, fourthSlotZone, false, done)
            end
        })
        :next(function(done) shuffleZone(fourthSlotZone, done) end)
        :next(function(done)
            local emptyActionSlots = countEmptyActionSlots(other(color))
            local dealFunctions = {}
            
            for j = 1, emptyActionSlots do
                table.insert(dealFunctions, function(dealDone)
                    dealZoneToZone(fourthSlotZone, otherDeckZone, false, dealDone)
                end)
            end
            
            chain()
                :parallel(dealFunctions, DEAL_SEQUENCE_DELAY)
                :next(function(moveDone) moveZoneToZone(fourthSlotZone, otherRefreshZone, moveDone) end)
                :next(function(actionDone) dealActions(other(color), 0, actionDone) end)
                :complete(done)
                :run()
        end)
        :complete(callback)
        :run()
end

---------------------------------------------------------------
-- SPECIAL CARD MECHANICS
---------------------------------------------------------------

function checkEmpress(color)
    local hpCounter = getObjectFromGUID(HP_COUNTER[color])
    
    local eqZones = {getObjectFromGUID(EQUIPMENT_SLOT[color][1]), getObjectFromGUID(EQUIPMENT_SLOT[color][2])}
    local foundEmpress = checkZonesForTag(eqZones, "Empress")
    
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

function returnElusivesFromHand(color, callback)
    local playerColor = (color == R) and "Red" or "Blue"
    local elusiveFunctions = {}
    
    for _, card in ipairs(Player[playerColor].getHandObjects()) do
        if card.hasTag("Elusive") then
            table.insert(elusiveFunctions, function(done)
                chain()
                    :next(function(flipDone) flipCard(card, flipDone) end)
                    :next(function(refreshDone) refreshCard(card, other(color), refreshDone) end)
                    :complete(done)
                    :run()
            end)
        end
    end
    
    chain()
        :parallel(elusiveFunctions)
        :complete(callback)
        :run()
end

function returnElusivesFromActions(color, callback)
    local funcs = {}
    for i = 1, 4 do
        local actionSlot = getObjectFromGUID(ACTION_SLOT[color][i])
        local card = getFromZone(actionSlot)
        if card and card.hasTag("Elusive") then
            table.insert(funcs,function(done) card.flip(); refreshCardSmooth(card,color,done) end)
        end
    end

    chain()
        :parallel(funcs)
        :complete(callback)
        :run()
end

-- Guards & Witness Cards
function disarm(color, callback)
    local weaponSlot = getObjectFromGUID(WEAPON[color])
    local killSlot = getObjectFromGUID(KILL_SLOT[color])

    chain()
        :parallel({
            function(done) discardZone(weaponSlot, color, done) end,
            function(done) discardZone(killSlot, color, done) end
        })
        :complete(callback)
        :run()
end

function callGuardsOn(color, callback)
    chain()
        :next(function(done) disarm(color, done) end)
        :next(function(done)
            local guardBag = getObjectFromGUID(GUARDBAG)
            local guardFunctions = {}
            
            for i = 1, 4 do
                local actionSlot = getObjectFromGUID(ACTION_SLOT[color][i])
                table.insert(guardFunctions, function(guardDone)
                    dealFromGuardBag(guardBag, actionSlot, guardDone)
                end)
            end
            
            chain()
                :parallel(guardFunctions, CARD_FLIP_DELAY)
                :complete(done)
                :run()
        end)
        :complete(callback)
        :run()
end

function addCallYourShotContext()
    for pcolor = 1, 2 do
        for i = 1, 2 do
            local zone = getObjectFromGUID(EQUIPMENT_SLOT[pcolor][i])
            local card = getFromZone(zone)
            if card and card.hasTag("Good") then
                card.clearContextMenu()
                card.addContextMenuItem("Call your shot!", function(player_color)
                    local color = (player_color == "Red") and R or B
                    chain()
                        :next(function(done) discardCardSmooth(card, color, done) end)
                        :next(function(done) callGuardsOn(other(color), done) end)
                        :run()
                end)
            end
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
           chain()
               :next(function(done) flipCard(card, done) end)
               :next(function(done) 
                   card.setPosition(discardZone.getPosition()) 
                   done()
               end)
               :wait(CARD_TELE_DELAY)
               :run()
        end)
    end
end

function addRefreshContext(card)
    card.addContextMenuItem("Send to refresh", function(player_color)
        local color = (player_color == "Red") and R or B
        local refreshZone = getObjectFromGUID(REFRESH[other(color)])
        chain()
            :next(function(done) flipCard(card, done) end)
            :next(function(done)
                card.setPosition(refreshZone.getPosition())
                done()
            end)
            :wait(CARD_TELE_DELAY)
            :run()
    end)
end

---------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------

function makeButton(obj, color, label, func)
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

function checkZoneForTag(zone, tag)
    local obj = getFromZone(zone)
    if not obj then return false end
    
    return obj.hasTag(tag)
end

function checkZonesForTag(zones, tag)
    for _, zone in ipairs(zones) do
        if checkZoneForTag(zone, tag) then
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