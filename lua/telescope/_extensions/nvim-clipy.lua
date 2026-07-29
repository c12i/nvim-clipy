return require("telescope").register_extension({
  exports = {
    ["nvim-clipy"] = require("nvim-clipy.telescope").pick,
  },
})
