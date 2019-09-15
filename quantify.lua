local sframe = CreateFrame("FRAME")

local event_map = {}
local next_frame_callbacks = {}
local timer_callbacks = {}

local qevent_map = {}

local segment_snapshot = nil

--alias namespace
local q = quantify

q.modules = {}

q.player_login_time = nil
q.segments = {q.Segment:new()}
q.current_segment = q.segments[1]

local last_totals_update = 0
local TOTALS_UPDATE_WINDOW = 300

function sframe:OnEvent(event, ...)

  local fired = {}                            --I think there is a better way to do this but this should stop the next_frame_callbacks table from getting cleared before the callback fires
  for id,c in pairs(next_frame_callbacks) do
    table.insert(fired,id)
    c.callback(unpack(c.args))
  end
  
  for _,id in pairs(fired) do
    next_frame_callbacks[id] = nil
  end
  
  local exhausted = {}
  for id,c in pairs(timer_callbacks) do
    if (GetTime() - c.start > c.seconds) then
      table.insert(exhausted,id)            --remove after loop so iterator isn't affected
      c.callback(unpack(c.args))
    end
  end
  
  --remove expired timeres
  for _,id in pairs(exhausted) do
    timer_callbacks[id] = nil
  end
  
  if (event_map[event] ~= nil) then
    for _, f in pairs(event_map[event]) do
      f(event, ...)
    end
  end
  
  if (GetTime() - last_totals_update > TOTALS_UPDATE_WINDOW) then
    q:updateTotals(q.current_segment)
  end
end

function quantify:registerNextFrame(callback, ...)
  local uuid = q:generateUUID()
  next_frame_callbacks[uuid] = {callback = callback, args = {...}}
end

function quantify:registerTimer(callback, seconds, ...)
  local uuid = q:generateUUID()  --for random access deletes
  timer_callbacks[uuid] = {callback = callback, seconds = seconds, args = {...}, start = GetTime()}
end

function quantify:registerQEvent(event,func)
  if (qevent_map[event] == nil) then
    qevent_map[event] = {}
  end
    
  table.insert(qevent_map[event], func)  
end

function quantify:triggerQEvent(event, ...)
  if (qevent_map[event] ~= nil) then
    for _, f in pairs(qevent_map[event]) do
      f(event, ...)
    end
  end  
end

function q:getSnapshotSegment()
  return segment_snapshot
end

function q:updateTotals(in_segment)

  local segment = in_segment
  if (segment_snapshot) then
    for k, statgroup in pairs(segment.stats) do
        if (segment_snapshot.stats[k] == nil) then
          segment_snapshot.stats[k] = {}
          segment_snapshot.stats[k].raw = {}
        end
        segment_snapshot.stats[k].raw = q:subtractTables(statgroup.raw,segment_snapshot.stats[k].raw)
    end
    
    segment = segment_snapshot
  end
  
  local duration
  local start_time = segment.total_start_time or segment.start_time
  if (start_time == nil and segment.end_time == nil) then
    duration = segment._duration or 0
  elseif (segment.end_time ~= nil) then
    duration = segment.end_time - start_time
  else
    duration = GetTime() - start_time
  end
  
  segment.total_start_time = GetTime()
  
  qDb.account.time = qDb.account.time + duration
  qDb[q.TotalSegment:characterKey()].time = qDb[q.TotalSegment:characterKey()].time + duration
  
  for k, statgroup in pairs(segment.stats) do
    if (qDb.account.stats[k] == nil) then
      qDb.account.stats[k] = {}
    end
    q:addTables(qDb.account.stats[k], statgroup.raw)

    
    if (qDb[q.TotalSegment:characterKey()].stats[k] == nil) then
      qDb[q.TotalSegment:characterKey()].stats[k] = {}
    end
    q:addTables(qDb[q.TotalSegment:characterKey()].stats[k], statgroup.raw)

  end

  last_totals_update = GetTime()
  
  segment_snapshot = q:createSegmentSnapshot(in_segment)
end

function quantify:registerEvent(event, func)
  if not sframe:IsEventRegistered(event) then
    sframe:RegisterEvent(event)
  end
  
  if (event_map[event] == nil) then
    event_map[event] = {}
  end
    
  table.insert(event_map[event], func)
end

function quantify:unregisterEvent(event, func)
  if (event_map[event] ~= nil) then
    for i,f in ipairs(event_map[event]) do
      if (f == func) then
        event_map[event][i] = nil
        break
      end
    end
  end
end

local function init(event, ...)
  local addon = ...
  if (event == "ADDON_LOADED" and addon == q.ADDON_NAME) then
    print(quantify.LOADED_TEXT)
    
    if (qDb ~= nil) then
      q:runMigrations()
    else
      qDb = {account = q.TotalSegment:new(), [q.TotalSegment:characterKey()] = q.TotalSegment:new()}
    end
    
    if (qDb[quantify.TotalSegment:characterKey()] == nil) then
      qDb[q.TotalSegment:characterKey()] = q.TotalSegment:new()
    end
    
    
    if (qDbOptions == nil) then
      qDbOptions = {profile = {minimap = {hide = false}}}
    end
    
    qDbOptions.version = GetAddOnMetadata("quantify", "Version")
    
    local classicDebugMode = GetAddOnMetadata("quantify", "X-Classic")
    
    local clientVersion,_,_,tocVersion = GetBuildInfo()
    qDbOptions.clientVersion = clientVersion
    q.isClassic = tocVersion < 80000 or classicDebugMode
    q.isRetail = not q.isClassic --just for more readable checks
    
    local addon = LibStub("AceAddon-3.0"):NewAddon("quantify")
    local bunnyLDB = LibStub("LibDataBroker-1.1"):NewDataObject("quantify", {
      type = "data source",
      text = "quantify",
      icon = "Interface\\addons\\quantify\\Textures\\noun_calculate.tga",
      OnClick = function() q:toggleUi() end,
      OnTooltipShow = function(tooltip) tooltip:SetText("quantify\n\n|cFFFFFF00Click |cFFFFFFFFto toggle UI") end
    })
    local icon = LibStub("LibDBIcon-1.0")
    icon:Register("quantify", bunnyLDB, qDbOptions.profile.minimap)
    
    quantify:initializeUi()
  end
end

local function logout(event, ...)
  for _,m in ipairs(q.modules) do
    m:updateStats(q.current_segment)
  end
  q:updateTotals(q.current_segment)
end

local function playerLogin(event, ...)
  q.player_login_time = GetTime()
  q.current_segment.start_time = q.player_login_time
end

function q:createNewSegment()
  local new_segment = q.Segment:new()
  new_segment.start_time = GetTime()
  q.current_segment.end_time = GetTime()
  
  
  --process any rates or derived stats
  for _,m in ipairs(q.modules) do
    m:updateStats(q.current_segment)
  end
  
  q:updateTotals(q.current_segment)
  segment_snapshot = nil
  
  q.current_segment = new_segment
  
  --initialize modules for the new segment
  for _,m in ipairs(q.modules) do
    m.newSegment()
  end

  table.insert(q.segments, q.current_segment)
end

local function qtySlashCmd(msg, editbox)
  local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
  
  if (cmd == "mod" and args ~= nil) then
    for _,m in ipairs(q.modules) do
      m:updateStats(q.current_segment)
    end
    q:printModule(args, q.current_segment)
  elseif (cmd == "segment" and args =="new") then
    q:createNewSegment()
    print("Created new segment", table.maxn(q.segments))
  elseif (cmd == "segment" and tonumber(args) ~= nil) then
    q:printSegment(q.segments[tonumber(args)])
  elseif (cmd == "show" or cmd == "hide") then
    q:showUi(cmd == "show")
  elseif (cmd == "state")  then
    q:printTable(quantify_state.state)
  elseif (cmd == "log" and (args == "0" or args == "1")) then
    quantify.logging_enabled = args == "1"
  elseif (cmd == "debug") then
    print(quantify.DEBUG_OPTIONS)
  elseif (cmd == "classic") then
    quantify.isClassic = 1
    quantify.isRetail = 0
  elseif (cmd == "clear" and args ~= nil) then
    if (args == "all") then
      qDb = nil
    else
      qDb[args] = nil
    end
    
    if (qDb == nil) then
      qDb = {account = q.TotalSegment:new(), [q.TotalSegment:characterKey()] = q.TotalSegment:new()}
    elseif (qDb[q.TotalSegment:characterKey()] == nil) then
      qDb[q.TotalSegment:characterKey()] = q.TotalSegment:new()
    end
  else
    print(quantify.HELP_TEXT)
  end
end


quantify:registerEvent("ADDON_LOADED", init)
quantify:registerEvent("PLAYER_LOGIN", playerLogin)
quantify:registerEvent("PLAYER_LEAVING_WORLD", logout)

sframe:SetScript("OnEvent", sframe.OnEvent)
SlashCmdList["quantify"] = qtySlashCmd