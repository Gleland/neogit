local a = require("plenary.async")
local logger = require("neogit.logger")

local function empty_state()
  return {
    ---The cwd when this was updated.
    ---Used to generate absolute paths
    cwd = ".",
    head = {
      branch = nil,
      commit_message = "",
    },
    upstream = {
      remote = nil,
      branch = nil,
      commit_message = "",
    },
    untracked = {
      items = {},
    },
    unstaged = {
      items = {},
    },
    staged = {
      items = {},
    },
    stashes = {
      items = {},
    },
    unpulled = {
      items = {},
    },
    unmerged = {
      items = {},
    },
    recent = {
      items = {},
    },
    rebase = {
      items = {},
      head = nil,
    },
    cherry_pick = {
      items = {},
      head = nil,
    },
    merge = {
      items = {},
      head = nil,
      msg = nil,
    },
  }
end

local meta = {
  __index = function(self, method)
    return self.state[method]
  end,
}

local M = {}

M.state = empty_state()
M.lib = {}

function M.reset(self)
  self.state = empty_state()
end

function M.refresh(self, lib)
  local refreshes = {}

  if lib and type(lib) == "table" then
    if lib.status then
      self.lib.update_status(self.state)
      a.util.scheduler()
    end

    if lib.branch_information then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing branch information")
        self.lib.update_branch_information(self.state)
      end)
    end

    if lib.rebase then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing rebase information")
        self.lib.update_rebase_status(self.state)
      end)
    end

    if lib.cherry_pick then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing cherry-pick information")
        self.lib.update_cherry_pick_status(self.state)
      end)
    end

    if lib.merge then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing merge information")
        self.lib.update_merge_status(self.state)
      end)
    end

    if lib.stashes then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing stash")
        self.lib.update_stashes(self.state)
      end)
    end

    if lib.unpulled then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing unpulled commits")
        self.lib.update_unpulled(self.state)
      end)
    end

    if lib.unmerged then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing unpushed commits")
        self.lib.update_unmerged(self.state)
      end)
    end

    if lib.recent then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing recent commits")
        self.lib.update_recent(self.state)
      end)
    end

    if lib.diffs then
      local filter = (type(lib) == "table" and type(lib.diffs) == "table") and lib.diffs or nil

      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing diffs")
        self.lib.update_diffs(self.state, filter)
      end)
    end
  else
    logger.debug("[REPO]: Refreshing ALL")
    self.lib.update_status(self.state)
    a.util.scheduler()

    for name, fn in pairs(self.lib) do
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing " .. name)
        fn(self.state)
      end)
    end
  end

  logger.debug(string.format("[REPO]: Running %d refresh(es)", #refreshes))
  a.util.join(refreshes)
  a.util.scheduler()
  logger.debug("[REPO]: Refreshes completed")
end

if not M.initialized then
  logger.debug("[REPO]: Initializing Repository")
  M.initialized = true

  setmetatable(M, meta)

  local modules = {
    "status",
    "diff",
    "stash",
    "pull",
    "push",
    "log",
    "rebase",
    "cherry_pick",
    "merge",
  }

  for _, m in ipairs(modules) do
    require("neogit.lib.git." .. m).register(M.lib)
  end
end

return M
