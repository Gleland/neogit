local a = require("plenary.async")
local cli = require("neogit.lib.git.cli")
local config_lib = require("neogit.lib.git.config")
local input = require("neogit.lib.input")
local config = require("neogit.config")
local M = {}

local function parse_branches(branches, include_current)
  local other_branches = {}

  local remotes = "^remotes/(.*)"
  local head = "^(.*)/HEAD"
  local ref = " %-> "
  local pattern = include_current and "^[* ] (.+)" or "^  (.+)"

  for _, b in ipairs(branches) do
    local branch_name = b:match(pattern)
    if branch_name then
      local name = branch_name:match(remotes) or branch_name
      if name and not name:match(ref) and not name:match(head) then
        table.insert(other_branches, name)
      end
    end
  end

  return other_branches
end

function M.get_local_branches(include_current)
  local branches = cli.branch.list(config.values.sort_branches).call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.get_remote_branches(include_current)
  local branches = cli.branch.remotes.list(config.values.sort_branches).call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.get_all_branches(include_current)
  local branches = cli.branch.list(config.values.sort_branches).all.call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.get_upstream()
  local full_name = cli["rev-parse"].abbrev_ref().show_popup(false).args("@{upstream}").call():trim().stdout
  local current = cli.branch.current.show_popup(false).call():trim().stdout

  if #full_name > 0 and #current > 0 then
    local remote = config_lib.get("branch." .. current[1] .. ".remote").value

    if remote then
      return {
        remote = remote,
        branch = full_name[1]:sub(#remote + 2, -1),
      }
    end
  end
end

function M.create()
  a.util.scheduler()
  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end

  cli.branch.name(name:gsub("%s", "-")).call_interactive()

  return name
end

function M.current()
  local head = require("neogit.lib.git").repo.head.branch
  if head then
    return head
  else
    local branch_name = cli.branch.current.call_sync():trim().stdout
    if #branch_name > 0 then
      return branch_name[1]
    end
    return nil
  end
end

function M.pushRemote(branch)
  branch = branch or require("neogit.lib.git").repo.head.branch

  if branch then
    return config_lib.get("branch." .. branch .. ".pushRemote").value
  end
end

function M.pushRemote_ref(branch)
  branch = branch or require("neogit.lib.git").repo.head.branch
  local pushRemote = M.pushRemote()

  if branch and pushRemote then
    return pushRemote .. "/" .. branch
  end
end

function M.pushRemote_label()
  return M.pushRemote_ref() or "pushRemote, setting that"
end

function M.upstream_label()
  return require("neogit.lib.git").repo.upstream.ref or "@{upstream}, creating it"
end

return M
