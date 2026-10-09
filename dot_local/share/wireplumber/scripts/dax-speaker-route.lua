-- WirePlumber 0.5 - ASUS TUF DAX3 Speaker Route Monitor
-- Automatically enables the upstream DAX3 smart filter when the active physical route is analog-output-speaker,
-- and disables it when the active physical route is analog-output-headphones (3.5mm wired headphones) or when user-disabled.
--
-- Headphone / Bluetooth / USB / HDMI bypass is 100% transparent and native.

cutils = require ("common-utils")
log = Log.open_topic ("s-dax-route")

local metadata_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "filters" },
  }
}

local node_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", "effect_input.Dolby_Speaker" },
  }
}

local device_om = ObjectManager {
  Interest {
    type = "device",
    Constraint { "device.name", "=", "alsa_card.pci-0000_00_1f.3" },
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

local function syncFilterState()
  local meta = metadata_om:lookup()
  local node = node_om:lookup()
  local dev = device_om:lookup()

  if not meta or not node or not dev then
    return
  end

  local bound_id = node["bound-id"]
  local route_name = getActiveOutputRoute(dev)

  local user_disabled = false
  local user_val = meta:find(bound_id, "filter.smart.user_disabled")
  if user_val ~= nil then
    local j = Json.Raw(user_val)
    if j:is_boolean() then
      user_disabled = j:parse()
    end
  end

  local should_disable = true
  if route_name == "analog-output-speaker" and not user_disabled then
    should_disable = false
  end

  local current_disabled = false
  local val_str = meta:find(bound_id, "filter.smart.disabled")
  if val_str ~= nil then
    local j = Json.Raw(val_str)
    if j:is_boolean() then
      current_disabled = j:parse()
    end
  end

  if val_str == nil or current_disabled ~= should_disable then
    log:info(string.format("Route is %s (user_disabled: %s) -> setting filter.smart.disabled = %s for bound_id %s",
      tostring(route_name), tostring(user_disabled), tostring(should_disable), tostring(bound_id)))
    meta:set(bound_id, "filter.smart.disabled", "Spa:String:JSON", tostring(should_disable))
  end
end

device_om:connect("installed", function()
  local dev = device_om:lookup()
  if dev then
    dev:connect("params-changed", function(d, param_name)
      if param_name == "Route" then
        syncFilterState()
      end
    end)
    syncFilterState()
  end
end)

node_om:connect("installed", function()
  syncFilterState()
end)

metadata_om:connect("installed", function()
  local meta = metadata_om:lookup()
  if meta then
    meta:connect("changed", function(m, subject, key, type, value)
      if key == "filter.smart.user_disabled" then
        syncFilterState()
      end
    end)
    syncFilterState()
  end
end)

device_om:activate()
node_om:activate()
metadata_om:activate()
