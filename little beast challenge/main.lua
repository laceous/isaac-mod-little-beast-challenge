local mod = RegisterMod('Little Beast Challenge', 1)
local game = Game()

-- requires the little beast mod
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
    -- these items could remove little beast, which is a failure scenario
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D4)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D100)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR)
    -- buggy when used with little beast
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BROKEN_MODEM)
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
          for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
            local door = room:GetDoor(i)
            if door and door.TargetRoomIndex == GridRooms.ROOM_MIRROR_IDX then
              door:TryBlowOpen(false, nil) -- no knife pieces
            end
          end
        elseif roomDesc.GridIndex == GridRooms.ROOM_SECRET_EXIT_IDX and room:GetType() == RoomType.ROOM_SECRET_EXIT then
          mod:openTrapdoor()
        end
      elseif stage == LevelStage.STAGE2_2 or (isCurse and stage == LevelStage.STAGE2_1) then
        if roomDesc.GridIndex == GridRooms.ROOM_SECRET_EXIT_IDX and room:GetType() == RoomType.ROOM_SECRET_EXIT then
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
    mod.playerHash = GetPtrHash(player)
  end
  for _, v in ipairs({ TrinketType.TRINKET_BABY_BENDER, TrinketType.TRINKET_FORGOTTEN_LULLABY }) do
    player:AddTrinket(v)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, false, false, true, false, -1)
  end
  player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_PONY, ActiveSlot.SLOT_POCKET, false)
  player:AddTrinket(TrinketType.TRINKET_AAA_BATTERY)
end

-- filtered to PLAYER_ISAAC
function mod:onPeffectUpdate(player)
  if not mod:isChallenge() then
    return
  end
  
  if mod.playerHash and mod.playerHash == GetPtrHash(player) then
    player:RespawnFamiliars() -- otherwise little beast doesn't show up
    mod.playerHash = nil
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

function mod:openTrapdoor()
  local room = game:GetRoom()
  
  local gridEntity = room:GetGridEntityFromPos(room:GetCenterPos())
  if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR then
    gridEntity.State = 1 -- open w/o knife piece
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