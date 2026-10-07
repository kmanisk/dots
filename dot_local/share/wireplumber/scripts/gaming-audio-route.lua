-- WirePlumber 0.5 - Gaming Audio Automatic Route Policy
-- Automatically targets allowlisted competitive games to sink.peace_gaming
-- (Peace EQ + LoudMax LADSPA) while preserving speaker/headphone transparency
-- for all desktop streams.
--
-- Invariants:
-- 1. Matches ONLY Stream/Output/Audio playback streams.
-- 2. Runs BEFORE linking/find-default-target to intercept game streams before default sink assignment.
-- 3. Sets has_defined_target = true to prevent get-filter-from-target
--    from wrapping the game stream in sink.asus_speakers.
-- 4. Never touches microphone / voice capture streams (Stream/Input/Audio).

lutils = require ("linking-utils")
cutils = require ("common-utils")
log = Log.open_topic ("s-gaming-route")

SimpleEventHook {
  name = "linking/find-gaming-target",
  after = "linking/find-defined-target",
  before = "linking/find-default-target",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "select-target" },
    },
  },
  execute = function (event)
    local _, om, si, si_props, si_flags, target =
        lutils:unwrap_select_target_event (event)

    -- If target was already picked by explicit target.object from application, don't override
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
