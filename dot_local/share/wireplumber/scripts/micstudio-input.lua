-- Select only physical capture devices for the single MicStudio capture stream.
-- The existing WirePlumber settings store persists preference across restarts.
local lutils = require ("linking-utils")

local function physical (props)
  local name = props["node.name"] or ""
  return props["media.class"] == "Audio/Source" and
      props["device.id"] ~= nil and name ~= "ghelper-audio" and
      not name:match ("^bluez_") and props["node.virtual"] ~= "true"
end

SimpleEventHook {
  name = "linking/micstudio-input",
  after = "linking/get-filter-from-target",
  before = "linking/prepare-link",
  interests = {
    EventInterest { Constraint { "event.type", "=", "select-target" } },
  },
  execute = function (event)
    local _, om, _, props, flags = lutils:unwrap_select_target_event (event)
    if props["node.name"] ~= "capture.ghelper-audio" then return end
    local preferred = Settings.get_string ("micstudio.input")
    local selected, best_rank, best_name = nil, -1, ""
    for candidate in om:iterate { type = "SiLinkable" } do
      local target_props = candidate.properties
      if physical (target_props) and lutils.canLink (props, candidate) then
        local name = target_props["node.name"]
        -- Preserve the laptop microphone as automatic fallback; USB remains selectable.
        local rank = name == preferred and 3 or
            (name:match ("^alsa_input%.pci%-.*analog") and 2 or 1)
        if rank > best_rank or (rank == best_rank and name < best_name) then
          selected, best_rank, best_name = candidate, rank, name
        end
      end
    end
    if selected then
      flags.has_defined_target = true
      flags.has_node_defined_target = false
      event:set_data ("target", selected)
    else
      -- Never fall through to the default virtual source and feed it into itself.
      event:set_data ("target", nil)
      event:stop_processing ()
    end
  end,
}:register ()

Settings.subscribe ("micstudio.input", function ()
  local source = Plugin.find ("standard-event-source")
  if source then source:call ("schedule-rescan", "linking") end
end)
