local M = {}

local function plugin_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h")
end

local HELPER = plugin_dir() .. "/docx_helper.py"

local dep_checked = false
local dep_ok = false

local function check_deps()
  if dep_checked then
    return dep_ok
  end
  dep_checked = true
  if vim.fn.executable("python3") ~= 1 then
    vim.notify(
      "docx-edit: python3 not found on PATH. Install Python 3 to edit .docx files.",
      vim.log.levels.ERROR
    )
    return false
  end
  local out = vim.fn.system({ "python3", "-c", "import docx" })
  if vim.v.shell_error ~= 0 then
    vim.notify(
      "docx-edit: python-docx not installed. Run:\n  python3 -m pip install --user python-docx",
      vim.log.levels.ERROR
    )
    return false
  end
  dep_ok = true
  return true
end

local function shell(args)
  local result = vim.fn.system(args)
  return result, vim.v.shell_error
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function buf_load_extract(buf, src, tmpdir)
  local stdout, code = shell({ "python3", HELPER, "extract", src, tmpdir })
  if code ~= 0 then
    vim.notify("docx-edit: extract failed:\n" .. stdout, vim.log.levels.ERROR)
    return false
  end

  local lines = vim.split(stdout, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "docx-edit")
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(buf, "modified", false)

  vim.api.nvim_buf_set_var(buf, "docx_src", src)
  vim.api.nvim_buf_set_var(buf, "docx_tmp", tmpdir)

  vim.api.nvim_buf_call(buf, function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = ""
    vim.cmd([[
      syntax clear
      syntax match docxMarker /⟦\d\+\(:field\|:obj\)\?⟧/ conceal
      syntax match docxTab /⟦→⟧/ conceal cchar=→
      syntax match docxBreak /⟦↵⟧/ conceal cchar=↵
      highlight default link docxMarker Comment
    ]])
  end)

  local meta_raw = read_file(tmpdir .. "/meta.json")
  if meta_raw then
    local ok, meta = pcall(vim.json.decode, meta_raw)
    if ok and meta then
      local msgs = {}
      table.insert(msgs, ("docx-edit: opened %s"):format(vim.fn.fnamemodify(src, ":t")))
      table.insert(msgs, ("backup: %s/original.docx (:DocxRevert)"):format(tmpdir))
      if meta.has_header_footer then
        table.insert(msgs, "warning: headers/footers exist and won't be edited")
      end
      if (meta.field_count or 0) > 0 or (meta.obj_count or 0) > 0 then
        table.insert(
          msgs,
          ("read-only: %d field, %d obj markers"):format(meta.field_count or 0, meta.obj_count or 0)
        )
      end
      vim.notify(table.concat(msgs, "\n"), vim.log.levels.INFO)
    end
  end

  return true
end

local function on_read(args)
  if not check_deps() then
    return
  end
  local src = vim.fn.fnamemodify(args.file, ":p")
  local buf = args.buf

  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")

  buf_load_extract(buf, src, tmpdir)
end

local function on_write(args)
  local buf = args.buf
  local ok_src, src = pcall(vim.api.nvim_buf_get_var, buf, "docx_src")
  local ok_tmp, tmpdir = pcall(vim.api.nvim_buf_get_var, buf, "docx_tmp")
  if not (ok_src and ok_tmp) then
    vim.notify("docx-edit: buffer is missing docx state; cannot save", vim.log.levels.ERROR)
    return
  end

  local target = vim.fn.fnamemodify(args.file, ":p")
  if target ~= src then
    vim.notify(
      "docx-edit: :saveas to a different .docx is not supported. Use :w to save in place.",
      vim.log.levels.ERROR
    )
    return
  end

  local edited = tmpdir .. "/edited.txt"
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local fh, err = io.open(edited, "wb")
  if not fh then
    vim.notify("docx-edit: cannot write temp file: " .. (err or "?"), vim.log.levels.ERROR)
    return
  end
  fh:write(table.concat(lines, "\n"))
  fh:close()

  local stdout, code = shell({ "python3", HELPER, "repack", src, tmpdir, edited })
  if code ~= 0 then
    vim.notify("docx-edit: repack failed:\n" .. stdout, vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_option(buf, "modified", false)
  vim.notify(("docx-edit: repacked %s"):format(vim.fn.fnamemodify(src, ":t")), vim.log.levels.INFO)
end

local function on_unload(args)
  local ok, tmpdir = pcall(vim.api.nvim_buf_get_var, args.buf, "docx_tmp")
  if ok and tmpdir and tmpdir ~= "" then
    pcall(vim.fn.delete, tmpdir, "rf")
  end
end

function M.revert()
  local buf = vim.api.nvim_get_current_buf()
  local ok_src, src = pcall(vim.api.nvim_buf_get_var, buf, "docx_src")
  local ok_tmp, tmpdir = pcall(vim.api.nvim_buf_get_var, buf, "docx_tmp")
  if not (ok_src and ok_tmp) then
    vim.notify("docx-edit: not a docx buffer", vim.log.levels.ERROR)
    return
  end
  local backup = tmpdir .. "/original.docx"
  if vim.fn.filereadable(backup) ~= 1 then
    vim.notify("docx-edit: backup missing at " .. backup, vim.log.levels.ERROR)
    return
  end
  local answer = vim.fn.confirm(
    ("Revert %s to original?"):format(vim.fn.fnamemodify(src, ":t")),
    "&Yes\n&No",
    2
  )
  if answer ~= 1 then
    return
  end
  local out = vim.fn.system({ "cp", backup, src })
  if vim.v.shell_error ~= 0 then
    vim.notify("docx-edit: revert copy failed:\n" .. out, vim.log.levels.ERROR)
    return
  end
  buf_load_extract(buf, src, tmpdir)
end

function M.reload()
  local buf = vim.api.nvim_get_current_buf()
  local ok_src, src = pcall(vim.api.nvim_buf_get_var, buf, "docx_src")
  local ok_tmp, tmpdir = pcall(vim.api.nvim_buf_get_var, buf, "docx_tmp")
  if not (ok_src and ok_tmp) then
    vim.notify("docx-edit: not a docx buffer", vim.log.levels.ERROR)
    return
  end
  buf_load_extract(buf, src, tmpdir)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("DocxEdit", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = { "*.docx" },
    callback = on_read,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = { "*.docx" },
    callback = on_write,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    pattern = { "*.docx" },
    callback = on_unload,
  })

  vim.api.nvim_create_user_command("DocxRevert", M.revert, {})
  vim.api.nvim_create_user_command("DocxReload", M.reload, {})
end

return M
