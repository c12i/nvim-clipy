-- Kept out of init.lua so requiring "nvim-clipy" doesn't pull in telescope.

local M = {}

function M.pick(opts)
  opts = opts or {}

  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if not has_telescope then
    vim.notify("nvim-clipy: telescope.nvim is required for :ClipyPick", vim.log.levels.ERROR, { title = "nvim-clipy" })
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  require("nvim-clipy").fetch(opts, function(entries)
    pickers
      .new(opts, {
        prompt_title = "Clipboard History",
        finder = finders.new_table({
          results = entries,
          entry_maker = function(entry)
            local display = entry.content:gsub("%s+", " ")
            return {
              value = entry,
              display = display,
              ordinal = display,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
          title = "Clipboard Entry",
          define_preview = function(self, entry)
            local lines = vim.split(entry.value.content, "\n", { plain = true })
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          end,
        }),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if selection then
              require("nvim-clipy").copy(selection.value.id)
            end
          end)

          map({ "i", "n" }, "<C-d>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              actions.close(prompt_bufnr)
              require("nvim-clipy").delete(selection.value.id)
            end
          end)

          return true
        end,
      })
      :find()
  end)
end

return M
