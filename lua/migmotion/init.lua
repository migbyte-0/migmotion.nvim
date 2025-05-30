-- migmotion.lua — Tiny word-navigator, digits 0-9 (10 ⇒ 0)
-- Author: migbyte — MIT | Neovim ≥ 0.9

local M = {}

---------------------------------------------------------------- CONFIG
M.config = {
  max        = 0,  -- 0 → to end of line
  before     = true,
  after      = true,
  colours    = { Red = "DiagnosticError", Yellow = "WarningMsg" },
  size_modes = { "superscript", "normal" }, -- zoom levels
  hl_prefix  = "Migmotion",
}

---------------------------------------------------------------- STATE
M.ns         = vim.api.nvim_create_namespace("migmotion")
M.enabled    = false
M.col_key    = "Red"
M.size_idx   = 1   -- 1=sup, 2=normal
M._au        = nil

---------------------------------------------------------------- HIGHLIGHT
local function ensure_hl()
  for key, link in pairs(M.config.colours) do
    local g = M.config.hl_prefix .. key
    if vim.fn.hlID(g) == 0 then
      vim.api.nvim_set_hl(0, g, { link = link })
    end
  end
end

---------------------------------------------------------------- DIGIT MAPS
local sup = { ["0"]="⁰",["1"]="¹",["2"]="²",["3"]="³",["4"]="⁴",["5"]="⁵",
              ["6"]="⁶",["7"]="⁷",["8"]="⁸",["9"]="⁹" }
-- convert absolute distance → single glyph 0-9 (mod 10)
local function glyph(dist)
  local d = dist % 10  -- 0..9 (10→0, 11→1 …)
  if M.size_idx == 2 then
    return tostring(d)
  else
    return sup[tostring(d)]
  end
end

---------------------------------------------------------------- WORD PARSE
local function split_words(line)
  local t, i = {}, 1
  while true do
    local s, e = line:find("%S+", i)
    if not s then break end
    t[#t + 1] = { start = s - 1, len = e - s + 1 }
    i = e + 1
  end
  return t
end

---------------------------------------------------------------- MARK HELPER
local function mark(buf,row,col,char,hl)
  vim.api.nvim_buf_set_extmark(buf,M.ns,row,0,{virt_text={{char,hl}},virt_text_pos="overlay",virt_text_win_col=math.max(col,0),priority=200,hl_mode="combine"})
end

---------------------------------------------------------------- DRAW
function M.draw()
  if not M.enabled then return end
  ensure_hl()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win)); row=row-1

  vim.api.nvim_buf_clear_namespace(buf,M.ns,0,-1)
  local line = vim.api.nvim_buf_get_lines(buf,row,row+1,false)[1] or ""
  if line=="" then return end
  local words = split_words(line); if #words==0 then return end

  -- current word idx
  local cur=1; for i,w in ipairs(words) do if col>=w.start and col<w.start+w.len then cur=i break end end

  local before = M.config.before and (#words) or 0
  local after  = M.config.after  and (#words) or 0
  before = math.min(before, cur-1)
  after  = math.min(after,  #words-cur)

  local hl = M.config.hl_prefix .. M.col_key

  local function place(i)
    local w = words[i]
    local d = math.abs(i-cur)
    mark(buf,row,w.start-1,glyph(d),hl)
  end

  for i=cur-before,cur-1 do place(i) end
  for i=cur+1,cur+after  do place(i) end
end

---------------------------------------------------------------- STATE / AUTOCMD
local function attach()
  if M._au then return end
  M._au = vim.api.nvim_create_augroup("Migmotion", {})
  vim.api.nvim_create_autocmd({"CursorMoved","CursorMovedI"},{group=M._au,callback=M.draw})
end

function M.enable()  M.enabled=true; attach(); M.draw() end
function M.disable() M.enabled=false; if M._au then vim.api.nvim_del_augroup_by_id(M._au); M._au=nil end; vim.api.nvim_buf_clear_namespace(0,M.ns,0,-1) end
function M.toggle() (M.enabled and M.disable or M.enable)() end

function M.set_colour(k) if M.config.colours[k] then M.col_key=k; M.draw() end end
function M.increase_size() M.size_idx = math.min(#M.config.size_modes, M.size_idx+1); M.draw() end
function M.decrease_size() M.size_idx = math.max(1, M.size_idx-1); M.draw() end

---------------------------------------------------------------- KEYMAPS
local function maps()
  local map,o=vim.keymap.set,{noremap=true,silent=true}
  map("n","<leader>mn",M.toggle,o)
  map("n","<leader>mm",M.increase_size,o)
  map("n","<leader>ml",M.decrease_size,o)
  map("n","<leader>mcr",function() M.set_colour("Red") end,o)
  map("n","<leader>mcy",function() M.set_colour("Yellow") end,o)
  for n=1,9 do
    map("n","<leader>"..n,function() vim.cmd(n.."w") end,o)
    map("n","<leader><S-"..n..">",function() vim.cmd(n.."b") end,o)
  end
end

---------------------------------------------------------------- SETUP
function M.setup(opts)
  if M._setup then return end
  M._setup=true
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  maps(); M.enable()
end

return M
