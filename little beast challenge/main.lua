local mod = RegisterMod('Little Beast Challenge', 1)
local game = Game()

-- requires the little beast mod (which loads before this mod)
mod.littleBeastItemId = Isaac.GetItemIdByName('Little Beast')
mod.littleBeastEntityType = Isaac.GetEntityTypeByName('Little Beast')
mod.littleBeastEntityVariant = Isaac.GetEntityVariantByName('Little Beast')
mod.playerHash = nil

function mod:onGameStart(isContinue)
  if not mod:isChallenge() then
    return
  end
  
  if not isContinue then
    game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, true)
    
    local itemPool = game:GetItemPool()
    -- remove items that could change our loadout, are buggy w/ little beast, or could remove little beast
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BROKEN_MODEM)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_CLICKER)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D4)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D100)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D_INFINITY)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_ESAU_JR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_GENESIS)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_LEMEGETON)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_METRONOME)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_MISSING_NO)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_TMTRAINER)
    itemPool:RemoveTrinket(TrinketType.TRINKET_ERROR)
    itemPool:RemoveTrinket(TrinketType.TRINKET_EXPANSION_PACK)
    itemPool:RemoveTrinket(TrinketType.TRINKET_M)
    if mod:isLittleBeastModAvail() then
      -- we already have a little beast, we don't need any more
      itemPool:RemoveCollectible(mod.littleBeastItemId)
    end
  end
  
  if not mod:isLittleBeastModAvail() then
    mod:killAllPlayers()
  end
end

function mod:onGameExit()
  mod.playerHash = nil
end

function mod:onNewRoom()
  if not mod:isChallenge() then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local isCurse = mod:isCurseOfTheLabyrinth()
  
  if not level:IsAscent() then
    if stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B then
      if stage == LevelStage.STAGE1_2 or (isCurse and stage == LevelStage.STAGE1_1) then
        if roomDesc.GridIndex >= 0 then
          mod:removeDoor(GridRooms.ROOM_MIRROR_IDX)
          mod:replaceWhiteFireplace()
        elseif roomDesc.GridIndex == GridRooms.ROOM_SECRET_EXIT_IDX and room:GetType() == RoomType.ROOM_SECRET_EXIT then
          mod:openTrapdoor()
        end
      elseif stage == LevelStage.STAGE2_2 or (isCurse and stage == LevelStage.STAGE2_1) then
        if roomDesc.GridIndex >= 0 then
          if mod:removeDoor(GridRooms.ROOM_MINESHAFT_IDX) then
            mod:removeMinecart()
          end
          mod:removeRailPlate()
        elseif roomDesc.GridIndex == GridRooms.ROOM_SECRET_EXIT_IDX and room:GetType() == RoomType.ROOM_SECRET_EXIT then
          mod:openTrapdoor()
        end
      end
    elseif stage == LevelStage.STAGE8 and room:GetType() == RoomType.ROOM_DUNGEON and roomDesc.Data.Variant == 666 and roomDesc.Data.Name == 'Beast Room' then
      -- make the beast fight a bit more fair
      for i = mod:countLittleBeasts() + 1, 4 do
        local player = game:GetPlayer(0)
        player:AddCollectible(mod.littleBeastItemId, 0, true, ActiveSlot.SLOT_PRIMARY, 0)
      end
    end
  end
end

function mod:onUpdate()
  if not mod:isChallenge() then
    return
  end
  
  if mod:countLittleBeasts() == 0 then
    mod:killAllPlayers()
  end
end

-- filtered to 0-Player
function mod:onPlayerInit(player)
  if not mod:isChallenge() then
    return
  end
  
  if player:GetPlayerType() ~= PlayerType.PLAYER_ISAAC then
    return
  end
  
  if not mod:isLittleBeastModAvail() then
    return
  end
  
  if mod:countLittleBeasts() == 0 then
    -- limit to one little beast
    player:AddCollectible(mod.littleBeastItemId, 0, true, ActiveSlot.SLOT_PRIMARY, 0)
  end
  for _, v in ipairs({ TrinketType.TRINKET_BABY_BENDER, TrinketType.TRINKET_FORGOTTEN_LULLABY }) do
    player:AddTrinket(v)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, false, false, true, false, -1)
  end
  player:AddTrinket(TrinketType.TRINKET_AAA_BATTERY)
  mod.playerHash = GetPtrHash(player)
end

-- filtered to PLAYER_ISAAC
function mod:onPeffectUpdate(player)
  if not mod:isChallenge() then
    return
  end
  
  if mod.playerHash and mod.playerHash == GetPtrHash(player) then
    -- SetPocketActiveItem crashes in onPlayerInit when continuing a run after fully shutting down the game
    player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_PONY, ActiveSlot.SLOT_POCKET, false)
    player:RespawnFamiliars() -- otherwise little beast doesn't show up
    mod.playerHash = nil
  end
end

function mod:getCard(rng, card, includeCards, includeRunes, onlyRunes)
  if not mod:isChallenge() then
    return
  end
  
  -- random dice room effect including D4
  if card == Card.CARD_REVERSE_WHEEL_OF_FORTUNE then
    return Card.CARD_WHEEL_OF_FORTUNE
  end
end

function mod:isLittleBeastModAvail()
  return mod.littleBeastItemId > -1 and mod.littleBeastEntityType > 0 and mod.littleBeastEntityVariant > -1
end

function mod:countLittleBeasts()
  return #Isaac.FindByType(mod.littleBeastEntityType, mod.littleBeastEntityVariant, 0, false, false)
end

function mod:killAllPlayers()
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    player:Die()
  end
end

function mod:removeDoor(targetRoomIdx)
  local room = game:GetRoom()
  local removed = false
  
  for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
    local door = room:GetDoor(i)
    if door and door.TargetRoomIndex == targetRoomIdx then
      room:RemoveDoor(i)
      removed = true
    end
  end
  
  return removed
end

function mod:replaceWhiteFireplace()
  for _, v in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE, 4, -1, false, false)) do -- white fireplace, subtype can be 0 or 2?
    v:Remove()
    Isaac.Spawn(EntityType.ENTITY_FIREPLACE, 2, 0, v.Position, Vector.Zero, nil) -- blue fireplace
  end
end

function mod:openTrapdoor()
  local room = game:GetRoom()
  
  local gridEntity = room:GetGridEntityFromPos(room:GetCenterPos())
  if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR then
    gridEntity.State = 1 -- open w/o knife piece
  end
end

function mod:removeMinecart()
  for _, v in ipairs(Isaac.FindByType(EntityType.ENTITY_MINECART, 10, 0, false, false)) do -- quest minecart
    v:Remove()
  end
end

function mod:removeRailPlate()
  local room = game:GetRoom()
  
  for i = 16, 418 do -- all grid indexes 1x1 - 2x2
    local gridEntity = room:GetGridEntity(i)
    if gridEntity  and gridEntity:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gridEntity:GetVariant() == 3 then -- rail plate
      room:RemoveGridEntity(i, 0, false)
    end
  end
end

function mod:isCurseOfTheLabyrinth()
  local level = game:GetLevel()
  local curses = level:GetCurses()
  local curse = LevelCurse.CURSE_OF_LABYRINTH
  
  return curses & curse == curse
end

function mod:isChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Little Beast Challenge')
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.onPlayerInit, 0) -- 0 is player, 1 is co-op baby
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.onPeffectUpdate, PlayerType.PLAYER_ISAAC)
mod:AddCallback(ModCallbacks.MC_GET_CARD, mod.getCard)