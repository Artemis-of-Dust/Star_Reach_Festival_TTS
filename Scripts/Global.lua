
setUninteractables = true

--  EVENT TRIGGER FUNCTIONS
-- =========================
function onLoad()
    if setUninteractables then
        for _, obj in pairs(getObjectsWithTag("Uninteractable")) do
            obj.interactable = false
        end
    end
    
    -- Setup functions to create functionality for tagged objects.
    setupSideBoard()
    registerDeckSort()
    setupCharSlot()
    
    -- Fix any erroneously unset use_hands in case our moveToObj functions got caught mid-passage (very unlikely).
    resetCardsUseHands()
    
    -- Shuffle decks
    loadShuffleDecks()
end

function onObjectCollisionEnter( registered_object, collision_info)
    deckSorter(registered_object, collision_info)
end 



--  UTILITY FUNCTIONS
-- ===================
-- Creates a list of all Card objects with all given tags (optional).
-- If a card is inside a Deck, it will first remove it from the Deck.
function getCardsByTagsGlobal(tagList)
    local foundCards = {}
    for _, obj in ipairs(getObjects()) do
        -- Individual cards
        if obj.type == "Card" then
            local cardValid = true
            for _, tag in pairs(tagList) do
                if obj.hasTag(tag) == false then
                    cardValid = false
                end
            end
            if cardValid then
                table.insert(foundCards, obj)
            end
        
        -- Search decks for valid cards contained within
        elseif obj.type == "Deck" then
            for _, card in pairs(obj.getObjects()) do
                local searchValid = true
                
                for _, tag in pairs(tagList) do
                    local foundTag = false
                    for _, cardTag in pairs(card.tags) do
                        if cardTag == tag then
                            foundTag = true
                        end
                    end
                    if foundTag == false then
                        searchValid = false
                    end
                end
                
                if searchValid then
                    local cardObj = obj.remainder
                    if cardObj == nil then
                        cardObj = obj.takeObject({position=obj.getPosition(), guid=card.guid})
                    end
                    
                    table.insert(foundCards, cardObj)
                end
            end
        end
    end
    
    return foundCards
end

-- Moves one object to another object's position.
function moveToObj(moveObj, slotObj, offset, rotOffset, lockedTime)
    destinationSlotObj = slotObj

    if moveObj and destinationSlotObj then
        moveObj.use_hands = false
        moveObj.locked = true
        -- We *very* briefly disable the ability for the card to be put into your hand to avoid issues of collision with hand zones.
            Wait.time(
            function()  
                if moveObj.type == "Card" then
                    moveObj.use_hands = true
                end
                moveObj.locked = false
            end,
            lockedTime or 0.6)
        
        moveObj.setRotation({
            x = destinationSlotObj.getRotation().x + (rotOffset and rotOffset.x or 0),
            y = destinationSlotObj.getRotation().y + (rotOffset and rotOffset.y or 0),
            z = destinationSlotObj.getRotation().z + (rotOffset and rotOffset.z or 0),
        })
        moveObj.setPositionSmooth({
            x = destinationSlotObj.getPosition().x + 0.0 + (offset and offset.x or 0),
            y = destinationSlotObj.getPosition().y + 0.1 + (offset and offset.y or 0),
            z = destinationSlotObj.getPosition().z + 0.0 + (offset and offset.z or 0),
            }, false, false)
    end
end
-- GM Notes variant
function moveToObjNote(moveObj, slotName, offset, rotOffset, lockedTime)
    destinationSlotObj = nil
    for _, obj in ipairs(getObjects()) do
        if obj.getGMNotes() == slotName then
            destinationSlotObj = obj
        end
    end

    moveToObj(moveObj, destinationSlotObj, offset, rotOffset, lockedTime)
end

-- [→onLoad()]: Shuffles the Audience and Song decks when the module is loaded, but
-- only if players haven't removed any cards yet.
function loadShuffleDecks()
    local deckObj = getAudienceDeck()
    if deckObj and deckObj.getQuantity() == 27 then
        deckObj.shuffle()
    end
    
    local deckObj = nil
    for _, obj in ipairs(getObjectsWithTag("SongCard")) do
        if obj.type == "Deck" then
            deckObj = obj
        end
    end
    if deckObj.getQuantity() == 8 then
        deckObj.shuffle()
    end
end


--  AUDIENCE LINE FUNCTIONS
-- =========================
function dealAudienceCards()
    local cardDealoffset = 0.01
    local audienceDeck = nil
    for _, obj in pairs(getObjectsWithTag("Audience")) do
        if obj.type == "Deck" then
            audienceDeck = obj
            break
        end
    end
    
    local audienceLines = {"A", "B", "C", "D"}
    for i, line in ipairs(audienceLines) do
        Wait.time(
            function()
                -- Find the first open slot.
                local audienceSlot = nil
                for i=1,7 do
                    if getObjAboveObj(getAudienceSlotObj(line .. i), "Card") == nil then
                        audienceSlot = getAudienceSlotObj(line .. i)
                        break
                    end
                end
                if audienceSlot then
                    local dealCardObj = getAudienceDeck()
                    if dealCardObj then
                        if dealCardObj.type == "Deck" then 
                            dealCardObj = dealCardObj.takeObject()
                        end
                        if dealCardObj then
                            moveToObj(dealCardObj, audienceSlot, {x=0, y=0.1, z=0})
                        end
                    end
                end
            end,
            cardDealoffset * (i-1))
    end
    
end

function getAudienceDeck()
    local audienceDeckObj = nil

    local drawPileObj = nil
    for _, obj in pairs(getObjects()) do
        if obj.getGMNotes() == "DrawPile_Audience" then
            drawPileObj = obj
        end
    end
    
    local searchMin = {
        x = drawPileObj.getPosition().x - 0.2,
        y = drawPileObj.getPosition().y - 0.0,
        z = drawPileObj.getPosition().z - 0.2,
        }
    local searchMax = {
        x = drawPileObj.getPosition().x + 0.2,
        y = drawPileObj.getPosition().y + 2.0,
        z = drawPileObj.getPosition().z + 0.2,
        }
    
    -- Prioritise checking for decks
    for _, obj in pairs(getObjectsWithTag("Audience")) do
        if obj.type == "Deck" and isInRange(obj, searchMin, searchMax) then
            audienceDeckObj = obj
            return audienceDeckObj
        end
    end
    -- Then check for a lone card which is NOT the final Audience card.
    for _, obj in pairs(getObjectsWithTag("Audience")) do
        if obj.type == "Card" and isInRange(obj, searchMin, searchMax) and not obj.hasTag("AudienceFinal") then
            audienceDeckObj = obj
            return audienceDeckObj
        end
    end
    -- Then check for the final Audience card.
    for _, obj in pairs(getObjectsWithTag("Audience")) do
        if obj.type == "Card" and isInRange(obj, searchMin, searchMax) and obj.hasTag("AudienceFinal") then
            audienceDeckObj = obj
            return audienceDeckObj
        end
    end
    
    return nil
end

function getAudienceSlotObj(slotID)
    for _, obj in pairs(getObjectsWithTag("Audience")) do
        if obj.type == "Block" and obj.getGMNotes() == slotID then
            return obj
        end
    end
    
    return nil
end

function getObjAboveObj(slotObj, objType)
    local searchArea = {
        xMin = slotObj.getPosition().x - 0.2,
        xMax = slotObj.getPosition().x + 0.2,
        yMin = slotObj.getPosition().y - 0.0,
        yMax = slotObj.getPosition().y + 0.3,
        zMin = slotObj.getPosition().z - 0.2,
        zMax = slotObj.getPosition().z + 0.2,
    }
    for _, obj in pairs(getObjects()) do
        if obj.getPosition().x <= searchArea.xMax and obj.getPosition().x >= searchArea.xMin and
           obj.getPosition().y <= searchArea.yMax and obj.getPosition().y >= searchArea.yMin and
           obj.getPosition().z <= searchArea.zMax and obj.getPosition().z >= searchArea.zMin then
            if objType == nil or obj.type == objType then
                return obj
            end
        end
    end

    return nil
end

function isInRange(checkObj, posMin, posMax)
    local checkPos = checkObj.getPosition()
    if checkPos.x <= posMax.x and checkPos.x >= posMin.x and
       checkPos.y <= posMax.y and checkPos.y >= posMin.y and
       checkPos.z <= posMax.z and checkPos.z >= posMin.z and
       checkObj.getPositionSmooth() == nil then
        return true
    else
        return false
    end
end


--  SIDE BOARD FUNCTIONS
-- ======================
-- [→onLoad()]
function setupSideBoard()
    local sideBoardObj = nil
    for _, obj in pairs(getObjectsWithTag("Tool_SideBoard")) do
        sideBoardObj = obj
        break
    end
    
    if sideBoardObj then
        sideBoardObj.createButton({
          label="Reset Audience\nand Song cards",
          click_function="resetAudience",
          function_owner=self,
          position={x=-4, y=1, z=0},
          height=500,
          width=2000,
          font_size=200,
          font_color={r=0, g=0, b=0, a=1},
          color={r=255, g=255, b=255, a=1}
          })
        
        sideBoardObj.createButton({
          label="Deal Audience\ncards",
          click_function="dealAudienceCards",
          function_owner=self,
          position={x=4, y=1, z=0},
          height=500,
          width=2000,
          font_size=200,
          font_color={r=0, g=0, b=0, a=1},
          color={r=255, g=255, b=255, a=1}
          })
    end
end
-- [→clickEvent]
function resetAudience()
    resetDeck("AudienceFinal", nil,             "DrawPile_Audience",       {x=0,y=0.4,z=0}, {x=0,y=0,z=0})
    resetDeck("Audience",      "AudienceFinal", "DrawPile_Audience",       {x=0,y=0.7,z=0}, {x=0,y=0,z=180})
    resetDeck("SongCard",      nil,             "DrawPile_SongCard",       {x=0,y=0.1,z=0}, {x=0,y=0,z=180})
    
    -- Return the Pick Up Marker to the center. Add a short delay to unlock it since the object gains physics before the deck would finish reforming.
    for _, obj in pairs(getObjectsWithTag("PickUpMarker")) do
        moveToObjNote(obj, "DrawPile_Audience",  {x=0,y=4,z=0}, {x=0,y=0,z=0}, 2.7)
        break
    end

    -- Shuffle decks after a short delay
    Wait.time(
        function()  
            for _, obj in ipairs(getObjectsWithTag("Audience")) do
                if obj.type == "Deck" then
                    obj.shuffle()
                end
            end
            
            for _, obj in ipairs(getObjectsWithTag("SongCard")) do
                if obj.type == "Deck" then
                    obj.shuffle()
                end
            end
        end,
        3.6)
end

function resetDeck(cardTag, excludeTag, moveSlot, offset, rotOffset)
    local verticalOffsetIndex = 0
    
    -- Find each card and move it to the correct location
    for _, obj in ipairs(getObjects()) do
        if obj.type == "Card" and obj.hasTag(cardTag) then
            if excludeTag == nil or obj.hasTag(excludeTag) == false then
                cardResetByIndex(obj, moveSlot, offset, rotOffset, verticalOffsetIndex)
                verticalOffsetIndex = verticalOffsetIndex + 1
            end
            
        elseif obj.type == "Deck" then
            for _, card in pairs(obj.getObjects()) do
                local searchValid = false
                local searchExcluded = false
                for _, tag in pairs(card.tags) do
                    if tag == cardTag then
                        searchValid = true
                    elseif tag == excludeTag then
                        searchExcluded = true
                    end
                end
                if searchValid and not searchExcluded then
                    local cardObj = obj.remainder
                    if cardObj == nil then
                        cardObj = obj.takeObject({guid=card.guid})
                        cardObj.locked = true
                    end
                    
                    cardResetByIndex(cardObj, moveSlot, offset, rotOffset, verticalOffsetIndex)
                    verticalOffsetIndex = verticalOffsetIndex + 1
                end
            end
        end
    end
end

function cardResetByIndex(cardObj, moveSlot, offset, rotOffset, dealtIndex)
    local verticalOffsetDistance = 0.1 * dealtIndex
    local verticalOffsetTime = 0.04 * dealtIndex
    Wait.time(
        function()  
            cardObj.locked = true
            moveToObjNote(
                cardObj,
                moveSlot,
                {
                    x = offset.x,
                    y = offset.y + verticalOffsetDistance,
                    z = offset.z
                    },
                rotOffset,
                1.5)
        end,
        (0 + verticalOffsetTime))
        
    return dealtIndex + 1
end

--  CHARACTER RETURN FUNCTIONS
-- ============================
-- [→onLoad()]
function setupCharSlot()
    for _, obj in pairs(getObjects()) do
        if obj.hasTag("Tool_CharSlot") then
            local charName = ""
            for _, tag in ipairs(obj.getTags()) do
                if string.find(tag, "Char_") then
                    charName =  string.sub(tag, 6)
                end
            end
            
            obj.createButton({
                label="Return\n" .. charName .. "\nto backstage",
                click_function="onClick_ReturnChar" .. obj.getGUID(),
                function_owner=self,
                position={x=0, y=0.1, z=0},
                height=1000,
                width=2000,
                font_size=300,
                scale={x=0.2, y=1, z=0.11},
                font_color={r=255, g=255, b=255, a=80},
                color={r=0, g=0, b=0, a=0}
                })
                
            -- Wrapper function to allow buttons to pass arguments
            local btnFunction = function(obj, player, alt_click)
                returnChar(charName)
            end
            
            _G["onClick_ReturnChar" .. obj.getGUID()] = btnFunction
        end
    end
end
-- [→clickEvent]
function returnChar(charName)
    local searchTag = "Char_" .. charName
    
    -- Return the Character Card to its slot.
    local charSlot = getObjectsWithAllTags({"Tool_CharSlot", searchTag})[1]
    if charSlot then
        local charCard = getCardsByTagsGlobal({searchTag, "CharacterCard"})[1]
        if charCard then
            resetCardSize(charCard)
            moveToObj(charCard, charSlot, {x=0, y=0, z=0}, {x=0, y=0, z=0})
        end
    end
    
    -- Return the Produce cards to the respective slot.
    local charSlot = getObjectsWithAllTags({"Tool_DeckSort", searchTag})[1]
    if charSlot then
        local cardsToMove = getCardsByTagsGlobal({searchTag, "PlayingCard"})
        for _, cardObj in pairs(cardsToMove) do
            resetCardSize(cardObj)
            moveToObj(cardObj, charSlot, {x=0, y=0, z=0}, {x=0, y=0, z=0})
        end
    end
end

function resetCardSize(resizeObj)
    local sizeScale = {
        x = 1.0,
        y = 1.0,
        z = 1.0,
    }
    
    if resizeObj.hasTag("CharacterCard") then
        sizeScale = {
        x = 1.4,
        y = 1.0,
        z = 1.4,
    }
    end
    
    resizeObj.setScale(sizeScale)
end
-- [→onLoad()]: Globally resets cards to be used in hand zones, just in case a rewind state was really badly timed.
function resetCardsUseHands()
    for _, obj in pairs(getObjectsWithAnyTags({"PlayingCard", "CharacterCard", "Audience"})) do
        if obj.type == "Card" then
            obj.use_hands = true
        end
    end
end



--  DECK SORTING FUNCTIONS 
-- ========================
-- [→onLoad()]
function registerDeckSort()
    for _, obj in pairs(getObjectsWithTag("Tool_DeckSort")) do
        obj.registerCollisions()
    end
end
-- [→onObjctCollisionEnter()]
function deckSorter(regObj, col_info)
    if regObj.hasTag("Tool_DeckSort") and col_info.collision_object.type == "Deck" then
        local baseRotation = regObj.getRotation()
        local basePosition = regObj.getPosition()
        local sortCriteria = {"R", "2", "3", "4", "5", "SP"}
        local deckObj = col_info.collision_object
        local cardOffset = 0.15
        
        -- We have an unsorted deck that can be sorted!
        if deckIsValidToSort(deckObj, sortCriteria) and (not deckIsSorted(deckObj, sortCriteria)) then
            for _, card in pairs(deckObj.getObjects()) do
                for i, value in ipairs(sortCriteria) do
                    if card.gm_notes == value then
                        cardObj = nil
                        if deckObj.remainder ~= nil then
                            cardObj = deckObj.remainder
                        else
                            cardObj = deckObj.takeObject({position=basePosition, guid=card.guid})
                        end
                        
                        cardObj.setRotation(baseRotation)
                        cardObj.setPositionSmooth({
                            x = basePosition.x,
                            y = basePosition.y + (cardOffset * i) + 0.01,
                            z = basePosition.z,},
                            false,
                            false)
                    end
                end
            end
        end
    end
end

function deckIsValidToSort(deckObj, sortCriteria)
    local deckValid = true
    
    -- Checks no non-valid cards are mixed in
    for _, card in pairs(deckObj.getObjects()) do
        local noteValid = false
        for _, value in pairs(sortCriteria) do
            if card.gm_notes == value then
                noteValid = true
            end
        end
        if noteValid == false then
            deckValid = false
            return deckValid
        end
    end
    
    -- Checks each criteria can be found once
    for _, value in pairs(sortCriteria) do
        local noteValid = false
        for _, card in pairs(deckObj.getObjects()) do
            if card.gm_notes == value and noteValid == false then
                noteValid = true
            elseif card.gm_notes == value and noteValid == true then
                -- Duplicate found, so it sets back to false
                noteValid = false
                break
            end
        end
        
        -- There is no matching card for a criteria, or a duplicate exists
        if noteValid == false then
            deckValid = false
            return deckValid
        end
    end
    
    return deckValid
end

function deckIsSorted(deckObj, sortCriteria)
    local deckSorted = true
    
    for i, card in ipairs(deckObj.getObjects()) do
        local searchValue = sortCriteria[i]
        if not(card.gm_notes == searchValue) then
            deckSorted = false
            break
        end
    end
    
    return deckSorted
end