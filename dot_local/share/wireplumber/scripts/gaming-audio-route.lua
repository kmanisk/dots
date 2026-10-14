-- WirePlumber 0.5 - Gaming Audio Automatic Route Policy
lutils = require ("linking-utils")
cutils = require ("common-utils")
log = Log.open_topic ("s-gaming-route")

local ALSA_SINK_NAME = "alsa_output.pci-0000_00_1f.3.analog-stereo"
local last_target_name = nil

local metadata_default_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "default" },
  }
}

local function getDefaultSinkName()
  local meta = metadata_default_om:lookup()
  if not meta then
    meta = cutils.get_default_metadata_object()
  end
  if not meta then return nil end
  local val = meta:find(0, "default.audio.sink")
  if not val then return nil end
  if Json and Json.Raw then
    local j = Json.Raw(val)
    if j:is_object() then
      local obj = j:parse()
      if obj and obj["name"] then return obj["name"] end
    end
  end
  return val:match('"name"%s*:%s*"([^"]+)"')
end

-- Hook 1: Dynamic target selection for playback.peace_gaming
SimpleEventHook {
  name = "linking/find-peace-playback-target",
  after = "linking/get-filter-from-target",
  before = "linking/prepare-link",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
      Constraint { "event.session-item.interface", "=", "linkable" },
    },
  },
  execute = function (event)
    local _, om, si, si_props, si_flags, target =
        lutils:unwrap_select_target_event (event)

    local node_name = si_props ["node.name"] or ""
    if node_name ~= "playback.peace_gaming" then
      return
    end

    local def_sink = getDefaultSinkName()
    if not def_sink or def_sink == "sink.peace_gaming" or def_sink:match("^effect_") then
      def_sink = ALSA_SINK_NAME
    end

    local chosen_target = nil
    local target_desc = def_sink

    -- 1. Match current user-selected default output sink
    for lnkbl in om:iterate { type = "SiLinkable" } do
      local props = lnkbl.properties
      if props ["item.node.direction"] == "input" and
         props ["media.class"] == "Audio/Sink" and
         props ["node.name"] == def_sink and
         lutils.canLink (si_props, lnkbl) then
        chosen_target = lnkbl
        break
      end
    end

    -- 2. Fallback to ALSA Analog Stereo if def_sink not available
    if not chosen_target and def_sink ~= ALSA_SINK_NAME then
      for lnkbl in om:iterate { type = "SiLinkable" } do
        local props = lnkbl.properties
        if props ["item.node.direction"] == "input" and
           props ["media.class"] == "Audio/Sink" and
           props ["node.name"] == ALSA_SINK_NAME and
           lutils.canLink (si_props, lnkbl) then
          chosen_target = lnkbl
          target_desc = ALSA_SINK_NAME .. " (Fallback)"
          break
        end
      end
    end

    -- 3. Emergency fallback: any available physical Audio/Sink
    if not chosen_target then
      for lnkbl in om:iterate { type = "SiLinkable" } do
        local props = lnkbl.properties
        local nname = props ["node.name"] or ""
        if props ["item.node.direction"] == "input" and
           props ["media.class"] == "Audio/Sink" and
           nname ~= "sink.peace_gaming" and
           not nname:match("^effect_") and
           lutils.canLink (si_props, lnkbl) then
          chosen_target = lnkbl
          target_desc = nname .. " (Emergency Fallback)"
          break
        end
      end
    end

    if chosen_target then
      local t_name = chosen_target.properties ["node.name"]
      if t_name ~= last_target_name then
        log:notice (string.format ("Peace gaming target changed: %s -> %s (%s)",
          tostring (last_target_name), tostring (t_name), target_desc))
        last_target_name = t_name
      end
      si_flags.has_defined_target = true
      si_flags.has_node_defined_target = true
      event:set_data ("target", chosen_target)
    end
  end
}:register ()

-- Hook 2: Route competitive games to sink.peace_gaming
SimpleEventHook {
  name = "linking/find-gaming-target",
  after = "linking/find-defined-target",
  before = "linking/find-default-target",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
      Constraint { "event.session-item.interface", "=", "linkable" },
    },
  },
  execute = function (event)
    local _, om, si, si_props, si_flags, target =
        lutils:unwrap_select_target_event (event)

    if target then
      return
    end

    if si_props ["media.class"] ~= "Stream/Output/Audio" then
      return
    end

    local app_name = si_props ["application.name"] or ""
    local bin_name = si_props ["application.process.binary"] or ""
    local node_name = si_props ["node.name"] or ""

    local is_game = false
    -- Counter-Strike 2 (Native Linux / SDL3)
    if bin_name == "cs2" or app_name == "cs2" or node_name == "cs2" or
       app_name:match ("[Cc]ounter%-[Ss]trike") then
      is_game = true
    -- ARC Raiders (Embark / Proton)
    elseif bin_name:lower ():match ("arc.*raiders") or app_name:match ("ARC.*Raiders") then
      is_game = true
    -- The Finals (Embark / Proton)
    elseif bin_name == "Discovery.exe" or app_name:match ("THE FINALS") then
      is_game = true
    -- Hunt: Showdown (CryEngine / Proton)
    elseif bin_name == "HuntGame.exe" or app_name:lower ():match ("hunt.*showdown") then
      is_game = true
    -- PUBG (Proton)
    elseif bin_name == "TslGame.exe" or app_name:match ("PUBG") then
      is_game = true
    -- Apex Legends (Proton)
    elseif bin_name == "r5apex.exe" or app_name:match ("Apex Legends") then
      is_game = true
    end

    if not is_game then
      return
    end

    local si_target = om:lookup {
      type = "SiLinkable",
      Constraint { "item.factory.name", "c", "si-audio-adapter", "si-node" },
      Constraint { "node.name", "=", "sink.peace_gaming" },
    }
    if not si_target then
      si_target = om:lookup {
        type = "SiLinkable",
        Constraint { "node.name", "=", "sink.peace_gaming" },
      }
    end

    if si_target and lutils.canLink (si_props, si_target) then
      log:info (si, string.format ("Gaming stream detected (%s / %s) -> routed to sink.peace_gaming",
        tostring (node_name), tostring (bin_name)))
      si_flags.has_defined_target = true
      si_flags.has_node_defined_target = true
      event:set_data ("target", si_target)
    end
  end
}:register ()

metadata_default_om:activate ()

