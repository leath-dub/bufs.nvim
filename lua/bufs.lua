local M = {}

M.config = {
  letters = "sadflewcmpghio",
}

M.state = {
  bufnm_totag = {},
  bufnm_toref = {},
  tag_torefc = {},
  derived_from = nil,
}

local H = {}

H.cache = {
  guicursor = nil,
}

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function (args)
    local bufnm = vim.fn.bufname(args.buf)
    local tag = M.state.bufnm_totag[bufnm]
    if tag then
      for tagk, refc in pairs(M.state.tag_torefc) do
        if tagk == tag then
          M.state.tag_torefc[tagk] = refc - 1
          assert(M.state.tag_torefc[tagk] >= 0)
        end
      end
    end
    M.state.bufnm_totag[bufnm] = nil
    M.state.bufnm_toref[bufnm] = nil
  end,
})

function M.state_init()
  M.state.derived_from = M.config
  for i = 1, #M.config.letters do
    M.state.tag_torefc[M.config.letters:sub(i, i)] = 0
  end
end

function M.list_bufs()
  -- if the derived state is out of sync with the configuration
  -- just re-initialize the state
  if M.state.derived_from ~= M.config then
    M.state_init()
  end

  local wbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[wbuf].bufhidden = 'wipe'

  local width = 0
  local lines = {}

  local function close()
    H.close_windows_with(wbuf)
    -- cursor hide hack restoration
    if H.cache.guicursor == '' then vim.cmd('set guicursor=a: | redraw') end
    pcall(function() vim.o.guicursor = H.cache.guicursor end)
  end

  vim.keymap.set("n", "q", close, { buffer = wbuf })
  vim.keymap.set("n", "<esc>", close, { buffer = wbuf })

  local bufs_outp = vim.api.nvim_exec2("buffers", { output = true }).output;
  for ln in vim.gsplit(bufs_outp, "\n", { plain = true }) do
    local bufnm = ln:match([["(.*)"]])
    local bufnr = ln:match([[^ *([0-9]+)]])

    local tag = M.state.bufnm_totag[bufnm]
    if tag == nil then
      -- find minimum reference count tag to select
      local min = M.config.letters:sub(1, 1);
      for i = 1, #M.config.letters do
        local tagk = M.config.letters:sub(i, i)
        if M.state.tag_torefc[tagk] < M.state.tag_torefc[min] then
          min = tagk
        end
      end
      tag = min
      M.state.bufnm_totag[bufnm] = tag;
      M.state.bufnm_toref[bufnm] = M.state.tag_torefc[tag];
      M.state.tag_torefc[tag] = M.state.tag_torefc[tag] + 1;
    end

    local km = string.rep(".", M.state.bufnm_toref[bufnm]) .. tag
    vim.keymap.set("n", km, function()
      close()
      vim.schedule(function() vim.cmd.buffer(bufnr) end)
    end, { buffer = wbuf })
    local entry = km .. ln

    table.insert(lines, entry)
    width = math.max(width, #entry)
  end

  local win_height = H.window_get_height()
  local height = math.min(#lines, win_height)

  vim.api.nvim_buf_set_lines(wbuf, 0, height, false, lines)
  vim.bo[wbuf].modifiable = false

  -- cursor hide hack
  H.cache.guicursor = vim.o.guicursor
  vim.o.guicursor = 'a:BufsCursor'

  vim.api.nvim_set_hl(0, "BufsCursor", { blend = 100, nocombine = true })

  local wid = vim.api.nvim_open_win(wbuf, true, {
    anchor = "SW",
    width = width,
    height = height,
    row = win_height,
    col = 0,
    border = "single",
    style = "minimal",
    relative = "editor",
  })
end

H.window_get_height = function()
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local has_statusline = vim.o.laststatus > 0
  return vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0)
end

H.close_windows_with = function(bufnr)
  -- close all windows looking at the buffer list buffer
  -- this is better than storing win_id and hoping it stays in sync
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      if vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_win_close(win, true) -- true = force
      end
    end
  end
end

return M
