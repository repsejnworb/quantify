quantify_loot = {}

local q = quantify

quantify_loot.Session = {}

quantify_loot.MODULE_KEY = "loot"
quantify_loot.INV_TYPE_PREFIX = "inv_type_*"

local ql = quantify_loot

ql.POOR = 0
ql.COMMON = 1
ql.UNCOMMON = 2
ql.RARE = 3
ql.EPIC = 4

ql.VANILLA = 1
ql.BC = 2
ql.WOTLK = 3
ql.CATA = 4
ql.WOD = 5
ql.LEGION = 6
ql.BFA = 7

function quantify_loot.Session:new(o)
  o = o or {total_items_looted = 0, gear_loot = 0, junk_looted = 0, junk_looted_value = 0, poor_loot = 0, common_loot = 0, uncommon_loot = 0, rare_loot = 0, epic_loot = 0, bfa_poor_loot = 0, bfa_common_loot = 0, bfa_uncommon_loot = 0, bfa_rare_loot = 0, bfa_epic_loot = 0, cloth_gear_loot = 0, leather_gear_loot = 0, mail_gear_loot = 0, plate_gear_loot = 0}
  setmetatable(o, self)
  self.__index = self
  return o
end

local session



local item_queue = {}


local function init()
  q.current_segment.stats[ql.MODULE_KEY] = {}
  q.current_segment.stats[ql.MODULE_KEY].raw = ql.Session:new()
  session = q.current_segment.stats[ql.MODULE_KEY].raw
end

local function confirmLootRoll(event, rollId, roll)
  
end

local function processItem(item,amount) 
  if (item.isCraftingReagent) then
    return
  end
  
  --item types
  if (item.itemType == "Armor" or item.itemType == "Weapon") then
    session.gear_loot = session.gear_loot + amount
    if (item.itemSubType == "Cloth") then
      session.cloth_gear_loot = session.cloth_gear_loot + amount
    elseif (item.itemSubType == "Leather") then
      session.leather_gear_loot = session.leather_gear_loot + amount
    elseif (item.itemSubType == "Mail") then
      session.mail_gear_loot = session.mail_gear_loot + amount
    elseif (item.itemSubType == "Plate") then
      session.plate_gear_loot = session.plate_gear_loot + amount
    end
  end
    
  --item subtypes
  if (item.itemSubType == "Junk") then
    session.junk_looted = session.junk_looted + amount
    session.junk_looted_value = session.junk_looted_value + (item.itemSellPrice * amount)
  end
  
  --item slots
  if (item.itemEquipLoc ~= nil and item.itemEquipLoc ~= "") then
    local key = ql.INV_TYPE_PREFIX.._G[item.itemEquipLoc]
    if (session[key] == nil) then
      session[key] = 0
    end
    session[key] = session[key] + amount
  end
  
  --item quality
  if (item.itemRarity == ql.POOR) then
    session.poor_loot = session.poor_loot + amount
    if (item.expacId == ql.BFA) then
      session.bfa_poor_loot = session.bfa_poor_loot + amount
    end
  elseif (item.itemRarity == ql.UNCOMMON) then
    session.uncommon_loot = session.uncommon_loot + amount
    if (item.expacId == ql.BFA) then
      session.bfa_uncommon_loot = session.bfa_uncommon_loot + amount
    end
  elseif (item.itemRarity == ql.COMMON) then
    session.common_loot = session.common_loot + amount
    if (item.expacId == ql.BFA) then
      session.bfa_common_loot = session.bfa_common_loot + amount
    end
  elseif (item.itemRarity == ql.RARE) then
    session.rare_loot = session.rare_loot + amount
    if (item.expacId == ql.BFA) then
      session.bfa_rare_loot = session.bfa_rare_loot + amount
    end
  elseif (item.itemRarity == ql.EPIC) then
    session.epic_loot = session.epic_loot + amount
    if (item.expacId == ql.BFA) then
      session.bfa_epic_loot = session.bfa_epic_loot + amount
    end
  end
end

local function getItemInfoReceived(event, itemId)
  if (item_queue[itemId] ~= nil) then
    local item = q.Item:new(itemId)
    processItem(item,item_queue[itemId].amount)
    quantify_tradeskill:processItem(item,amount)
    item_queue[itemId] = nil
  end
end

local function itemReceived(itemLink,amount)
  local item = q.Item:new(itemLink)
  if (item == nil) then
    local id = q:getItemId(loot)
    if (item_queue[id] == nil) then
      item_queue[id] = {link = loot, amount = 0}
    end
    item_queue[id].amount = item_queue[id].amount + amount
  else
    processItem(item,amount)
    quantify_tradeskill:processItem(item,amount)
  end   
end

local function chatMsgLoot(event, msg, player, chatLineId)
  local loot = string.match(msg,"You receive loot: (.+)x?(%d*).")
  local amount = string.match(msg, "You receive loot: .+x(%d+).")
  amount = tonumber(amount) or 1
  
  if (loot ~= nil) then
    session.total_items_looted = session.total_items_looted + 1
    
    itemReceived(loot,amount)
  end
end

local function questLootReceived(event, questID, itemLink, quantity)
  itemReceived(itemLink,quantity)
end

function quantify_loot:calculateDerivedStats(segment)

end

function quantify_loot:updateStats(segment)

end
 
function quantify_loot:newSegment(previous_seg,new_seg)
  
  init()
  
end

init()

table.insert(quantify.modules, quantify_loot)
  
q:registerEvent("CONFIRM_LOOT_ROLL", confirmLootRoll)
q:registerEvent("CHAT_MSG_LOOT", chatMsgLoot)
q:registerEvent("GET_ITEM_INFO_RECEIVED", getItemInfoReceived)