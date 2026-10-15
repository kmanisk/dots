-- WirePlumber 0.5 - ASUS TUF DAX3 Output Mode Route Monitor
-- Invariants:
-- 1. Default sink == Bluetooth:
--    - Dolby_Headphones filter.smart.target = Bluetooth sink node name
--    - Dolby_Headphones filter.smart.disabled = false
--    - Dolby_Speaker filter.smart.disabled = true
-- 2. Default sink == ALSA (Built-in Audio):
--    - Route == analog-output-speaker:
--      - Dolby_Speaker filter.smart.target = alsa_output
--      - Dolby_Speaker filter.smart.disabled = false
--      - Dolby_Headphones filter.smart.disabled = true
--    - Route == analog-output-headphones (3.5mm wired jack):
--      - Dolby_Headphones filter.smart.target = alsa_output
--      - Dolby_Headphones filter.smart.disabled = false
--      - Dolby_Speaker filter.smart.disabled = true
-- 3. Strict Mutual Exclusion:
--    - Speaker FIR NEVER touches Bluetooth or Headphones.
--    - Headphone chain NEVER touches Internal Speakers.

cutils = require ("common-utils")
log = Log.open_topic ("s-dax-route")

local ALSA_CARD_NAME = "alsa_card.pci-0000_00_1f.3"
local ALSA_SINK_NAME = "alsa_output.pci-0000_00_1f.3.analog-stereo"
local BT_ADDRESS = "B0:38:E2:78:9B:FE"

local metadata_filters_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "filters" },
  }
}

local metadata_default_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "default" },
  }
}

local speaker_node_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", "effect_input.Dolby_Speaker" },
  }
}

local hp_node_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", "effect_input.Dolby_Headphones" },
  }
}

local hp_playback_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", "effect_output.Dolby_Headphones" },
  }
}

local spk_playback_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", "effect_output.Dolby_Speaker" },
  }
}

local alsa_device_om = ObjectManager {
  Interest {
    type = "device",
    Constraint { "device.name", "=", ALSA_CARD_NAME },
  }
}

local bt_sink_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "media.class", "=", "Audio/Sink" },
    Constraint { "device.api", "=", "bluez5" },
  }
}

local function getActiveOutputRoute(device)
  for p in device:iterate_params("Route") do
    local route = cutils.parseParam(p, "Route")
    if route and route.direction == "Output" then
      return route.name
    end
  end
  return nil
end

local function getDefaultSinkName(meta)
  if not meta then return nil end
  local val = meta:find(0, "default.audio.sink")
  if val then
    local j = Json.Raw(val)
    if j:is_object() then
      local obj = j:parse()
      return obj["name"]
    end
  end
  return nil
end

local last_hp_target = nil

local function syncFilterStates()
  local meta_filters = metadata_filters_om:lookup()
  local meta_default = metadata_default_om:lookup()
  local dev = alsa_device_om:lookup()

  if not meta_filters or not meta_default then
    return
  end

  local def_sink = getDefaultSinkName(meta_default)
  local bt_sink = bt_sink_om:lookup()
  local bt_sink_name = bt_sink and bt_sink.properties["node.name"]

  local is_bluetooth = (def_sink ~= nil and (def_sink:match("^bluez_output") ~= nil or (bt_sink_name ~= nil and def_sink == bt_sink_name)))
  local route_name = dev and getActiveOutputRoute(dev) or "analog-output-speaker"
  local is_wired_headphone = (not is_bluetooth and route_name == "analog-output-headphones")
  local is_internal_speaker = (not is_bluetooth and not is_wired_headphone)

  -- 1. Sync Dolby Speaker filter
  local spk_node = speaker_node_om:lookup()
  if spk_node then
    local bound_id = spk_node["bound-id"]
    if bound_id then
      local should_disable_spk = not is_internal_speaker
      local cur_val = meta_filters:find(bound_id, "filter.smart.disabled")
      local cur_disabled = false
      if cur_val ~= nil then
        local j = Json.Raw(cur_val)
        if j:is_boolean() then cur_disabled = j:parse() end
      end

      if cur_val == nil or cur_disabled ~= should_disable_spk then
        log:notice(string.format("Route '%s', DefSink '%s': Dolby_Speaker disabled = %s",
          tostring(route_name), tostring(def_sink), tostring(should_disable_spk)))
        meta_filters:set(bound_id, "filter.smart.disabled", "Spa:String:JSON", tostring(should_disable_spk))
      end
    end

    local spk_pb = spk_playback_om:lookup()
    if spk_pb and meta_default then
      local pb_id = spk_pb["bound-id"]
      if pb_id then
        meta_default:set(pb_id, "target.object", "Spa:String", ALSA_SINK_NAME)
      end
    end
  end

  -- 2. Sync Dolby Headphones filter
  local hp_node = hp_node_om:lookup()
  local hp_pb = hp_playback_om:lookup()
  if hp_node then
    local bound_id = hp_node["bound-id"]
    local hp_target_sink = is_bluetooth and (bt_sink_name or def_sink) or ALSA_SINK_NAME
    local should_disable_hp = is_internal_speaker

    if bound_id then
      -- Update filter.smart.target rule on effect_input.Dolby_Headphones
      local target_rule = string.format('{\n  node.name = "%s"\n}', hp_target_sink)
      local cur_target_val = meta_filters:find(bound_id, "filter.smart.target")
      if cur_target_val ~= target_rule then
        meta_filters:set(bound_id, "filter.smart.target", "Spa:String:JSON", target_rule)
      end

      local cur_val = meta_filters:find(bound_id, "filter.smart.disabled")
      local cur_disabled = false
      if cur_val ~= nil then
        local j = Json.Raw(cur_val)
        if j:is_boolean() then cur_disabled = j:parse() end
      end

      if cur_val == nil or cur_disabled ~= should_disable_hp then
        log:notice(string.format("Route '%s', DefSink '%s': Dolby_Headphones disabled = %s (target: %s)",
          tostring(route_name), tostring(def_sink), tostring(should_disable_hp), tostring(hp_target_sink)))
        meta_filters:set(bound_id, "filter.smart.disabled", "Spa:String:JSON", tostring(should_disable_hp))
      end
    end

    -- Update target.object on effect_output.Dolby_Headphones so playback stream targets correct device
    if hp_pb and meta_default then
      local pb_id = hp_pb["bound-id"]
      if pb_id and hp_target_sink ~= last_hp_target then
        log:notice(string.format("Dolby_Headphones output target changed: %s -> %s",
          tostring(last_hp_target), tostring(hp_target_sink)))
        last_hp_target = hp_target_sink
        meta_default:set(pb_id, "target.object", "Spa:String", hp_target_sink)
      end
    end
  end
end

alsa_device_om:connect("installed", function()
  local dev = alsa_device_om:lookup()
  if dev then
    dev:connect("params-changed", function(d, param_name)
      if param_name == "Route" then
        syncFilterStates()
      end
    end)
    syncFilterStates()
  end
end)

speaker_node_om:connect("installed", function() syncFilterStates() end)
speaker_node_om:connect("object-added", function() syncFilterStates() end)
speaker_node_om:connect("object-removed", function() syncFilterStates() end)

hp_node_om:connect("installed", function() syncFilterStates() end)
hp_node_om:connect("object-added", function() syncFilterStates() end)
hp_node_om:connect("object-removed", function() syncFilterStates() end)

hp_playback_om:connect("installed", function() syncFilterStates() end)
hp_playback_om:connect("object-added", function() syncFilterStates() end)
hp_playback_om:connect("object-removed", function() syncFilterStates() end)

spk_playback_om:connect("installed", function() syncFilterStates() end)
spk_playback_om:connect("object-added", function() syncFilterStates() end)
spk_playback_om:connect("object-removed", function() syncFilterStates() end)

bt_sink_om:connect("installed", function() syncFilterStates() end)
bt_sink_om:connect("object-added", function() syncFilterStates() end)
bt_sink_om:connect("object-removed", function() syncFilterStates() end)

metadata_filters_om:connect("installed", function() syncFilterStates() end)
metadata_default_om:connect("installed", function()
  local meta = metadata_default_om:lookup()
  if meta then
    meta:connect("changed", function(m, subject, key, type, value)
      if key == "default.audio.sink" then
        syncFilterStates()
      end
    end)
    syncFilterStates()
  end
end)

alsa_device_om:activate()
speaker_node_om:activate()
hp_node_om:activate()
hp_playback_om:activate()
spk_playback_om:activate()
bt_sink_om:activate()
metadata_filters_om:activate()
metadata_default_om:activate()
