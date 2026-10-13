# pkg - default bare `pkg` to `pkg all` (search Repos + AUR).
# The ~/.local/bin/pkg script opens a menu when called with no args;
# this wrapper makes the `all` installer the default instead.
# Args pass through untouched: `pkg install`, `pkg remove`, etc. unchanged.
function pkg --wraps pkg
    if test (count $argv) -eq 0
        command pkg all
    else
        command pkg $argv
    end
end
