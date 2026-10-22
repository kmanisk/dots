-- nvim-java / jdtls tuning.
--
-- nvim-java launches jdtls with a hardcoded "-Xms1G" heap floor and, by
-- default, a second JVM for the Spring Boot language server. With one small
-- file open that came to ~1.27 GB of RSS (jdtls 970 MB, Spring Boot ~240 MB,
-- editor ~65 MB) even though the JVM only retained ~180 MB of live objects.
--
-- The flags below bring the same setup to roughly 640 MB peak, and the Spring
-- Boot server is not started at all. Everything else (lombok agent, jdtls
-- plugin bundles, workspace) is left at the upstream defaults.

local M = {}

-- 128m is enough for small and medium workspaces; raise the ceiling if a very
-- large multi-module project ever runs into OutOfMemoryError.
--
-- G1 keeps the peak heap committed after a workspace import, so the free-ratio
-- bounds plus the periodic idle collection hand that memory back to the OS.
local JVM_FLAGS = {
    "-Xms128m",
    "-Xmx1g",
    "-XX:MinHeapFreeRatio=10",
    "-XX:MaxHeapFreeRatio=40",
    "-XX:G1PeriodicGCInterval=180000",
    -- C1 only: a language server is short-lived work, so the C2 compiler and
    -- its code cache buy little and cost ~150 MB of RSS here. Remove this line
    -- if a very large workspace ever feels sluggish.
    "-XX:TieredStopAtLevel=1",
}

--- Replaces the hardcoded heap floor in nvim-java's jdtls command builder.
--- The builder resolves `cmd.get_jvm_args` through its module table on every
--- launch, so overriding the field here is enough.
local function patch_jvm_args()
    local ok, cmd = pcall(require, "java-core.ls.servers.jdtls.cmd")
    if not ok or cmd._heap_patched then
        return
    end
    cmd._heap_patched = true

    local get_jvm_args = cmd.get_jvm_args
    cmd.get_jvm_args = function(config)
        local args = get_jvm_args(config)
        local replaced = false

        for i, arg in ipairs(args) do
            if arg == "-Xms1G" then
                table.remove(args, i)
                for offset, flag in ipairs(JVM_FLAGS) do
                    table.insert(args, i + offset - 1, flag)
                end
                replaced = true
                break
            end
        end

        if not replaced then
            for _, flag in ipairs(JVM_FLAGS) do
                args:push(flag)
            end
        end

        return args
    end
end

function M.setup()
    require("java").setup({
        -- Extra ~240 MB JVM that only matters inside Spring applications.
        spring_boot_tools = { enable = false },
    })

    patch_jvm_args()

    vim.lsp.enable("jdtls")
end

return M
