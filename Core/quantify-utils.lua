local q = quantify

function q:printTable(t)
    for k,v in pairs(t) do
      print(string.format("%s: %s", k, tostring(v)))
    end
end

function q:printModule(mod, segment)
  local m = segment.stats[mod]
  print(mod)
  for statgrouptitle,statgroup in pairs(m) do
    print(string.format("    %s", statgrouptitle))
    for k,v in pairs(statgroup) do
      print(string.format("        %s: %f", k, v))
    end
  end
end

function q:printSegment(segment)
  for title, m in pairs(segment.stats) do
    print(title)
    for statgrouptitle,statgroup in pairs(m) do
      print(string.format("    %s", statgrouptitle))
      for k,v in pairs(statgroup) do
        print(string.format("        %s: %f", k, v))
      end
    end
  end
end

function q:calculateSegmentRates(segment, segment_stats)
  local duration
  if (segment:duration() ~= nil) then
    duration = segment:duration()
  else
    local start = segment.start_time or GetTime()
    local endt = segment.end_time or GetTime()
    duration = endt - start
  end
  
  local session_rates = {}
  for k,v in pairs(segment_stats) do
    session_rates[k] = (v/duration) * 3600
  end
  
  return session_rates
end

function q:addTables(a,b)
  --b expected to be the most up to date in the case of missing keys
  for k,v in pairs(b) do
    if (a[k] == nil) then
      a[k] = 0
    end
    a[k] = a[k] + v
  end
  
  return a
end


function q:shallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function q:getSegmentList()
  local segments = {}
  if (qDb ~= nil) then
    for k,v in pairs(qDb) do
      segments[k] = v
    end
  end
  
  for i,v in ipairs(q.segments) do
    segments["Segment "..i] = v
  end
  
  return segments
end

--flattens stat table
function q:getAllStats(segment)
  local stats = {}
  for _,group in pairs(segment.stats) do
    for stattypek,stattype in pairs(group) do
      for k,v in pairs(stattype) do
        stats[stattypek..":"..k] = v
      end
    end
  end
     
  return stats
end

function q:convertSavedSegment(segment)
  local cseg = q.Segment:new()
  cseg._duration = segment.time
  
  for k,v in pairs(segment.stats) do
    cseg.stats[k] = {}
    cseg.stats[k].raw = v
  end
  
  for _,m in ipairs(q.modules) do
    m:updateStats(cseg)
  end
  
  return cseg
end

function q:getSingleModuleSegment(key,segment)
  local new_seg = q:shallowCopy(segment)
  
  new_seg.stats = {}
  new_seg.stats[key] = segment.stats[key]
  
  return new_seg 
end

function q:getModuleKeys()
  local keys = {}
  
  for _,m in ipairs(q.modules) do
    table.insert(keys, m.MODULE_KEY)
  end
  
  return keys
end

function q:getShorthandInteger(n,precision)
  precision = precision or 1
  
  local format = "%." .. tostring(precision) .. "f"
  
  local res
  n = math.floor(n)
  if (n > 1000 and n < 1000000) then
    n = (n * 1.0) / 1000
    res = string.format(format,n).."k"
  elseif (n > 1000000) then
    n = (n * 1.0) / 1000000
    res = string.format(format,n).."m"
  else
    res = n
  end  
  
  return res
end

function q:getFormattedUnit(n,units)
  if (q:isInf(n) or q:isNan(n)) then
    n = 0
  end
  
  local res
  if (units == "integer") then
    res = q:getShorthandInteger(n)
  elseif (units == "time") then
    local min,sec,hour
    if (n < 60) then
      n = math.floor(n)
      res = tostring(n).."s"
    elseif (n >= 60 and n < 3600) then
      min = math.floor(n/60)
      sec = math.floor(n) % 60
      res = tostring(min).."m"..tostring(sec).."s"
    elseif (n >= 3600) then
      hour = math.floor(n/3600)
      min = math.floor(n/60)
      sec = math.floor(n) % 60
      res = tostring(hour).."h"..tostring(min).."m"..tostring(sec).."s"
    end
  elseif (units == "decimal") then
    res = string.format("%.2f",n)
  elseif (units == "integer/hour") then
    res = q:getShorthandInteger(n)
  elseif (units == "decimal/hour") then
    res = q:getShorthandInteger(n,2)
  elseif (units == "percentage") then
    res = tostring(math.floor(n)).."%"
  end

  return res
end

function q:isInf(n)
  return n == math.huge or n == -math.huge
end

function q:isNan(n)
  return n ~= n
end