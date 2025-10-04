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

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function (args)
    local bufnm = vim.fn.bufname(args.buf)
    local tag = M.state.bufnm_totag[bufnm]
    if tag then
      -- Decrement global ref count for tag
      for tagk, refc in pairs(M.state.tag_torefc) do
        if tagk == tag then
          M.state.tag_torefc[tagk] = refc - 1
          assert(M.state.tag_torefc[tagk] >= 0)
        end
      end
      -- Decrement local ref counts for buffers using the same tag
      for obuf, tagk in pairs(M.state.bufnm_totag) do
        if tagk == tag then
          M.state.bufnm_toref[obuf] = math.max(0, M.state.bufnm_toref[obuf] - 1)
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

  local ns = vim.api.nvim_create_namespace("bufs")

  local wbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[wbuf].bufhidden = 'wipe'

  local width = 0
  local entries = {}

  local function close()
    H.close_windows_with(wbuf)
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
    end, { nowait = true, buffer = wbuf })
    local entry = { km, ln }

    table.insert(entries, entry)
    width = math.max(width, #entry[1] + #entry[2] + 1)
  end

  local lines = {}
  for _, entry in ipairs(entries) do
    local km = entry[1]
    local data = entry[2]
    table.insert(lines, data .. (" "):rep(width - #data - 1) .. km)
  end

  local win_height = H.window_get_height()
  local height = math.min(#entries, win_height)

  vim.api.nvim_buf_set_lines(wbuf, 0, height, false, lines)
  vim.bo[wbuf].modifiable = false

  local wid = vim.api.nvim_open_win(wbuf, true, {
    anchor = "SW",
    width = width + 1,
    height = height,
    row = win_height,
    col = 0,
    border = "single",
    style = "minimal",
    relative = "editor",
    focusable = false,
  })
  vim.api.nvim_set_current_win(wid)

  for i = 1, #lines do
    local km = entries[i][1]
    local data = entries[i][2]
    local offset = #data + (width - #data - 1)
    local len = #km
    local startpos = { i - 1, offset }
    local endpos = { i - 1, offset + len }
    vim.hl.range(wbuf, ns, "Number", startpos, endpos)
    -- vim.api.nvim_buf_set_extmark(wbuf, ns, i - 1, offset, {
    --   end_line = i - 1,
    --   end_col = offset + len,
    --   hl_group = "Number",
    -- })
  end
end

H.window_get_height = function()
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local has_statusline = vim.o.laststatus > 0
  return vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0)
end

H.close_windows_with = function(bufnr)
  -- Close all windows looking at the buffer list buffer
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
