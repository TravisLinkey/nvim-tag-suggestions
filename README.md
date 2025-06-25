# nvim-tag-suggestions

A Neovim plugin that provides intelligent tag suggestions for markdown notes, combining directory-based tag analysis with AI-powered suggestions using OpenAI.

## Features

- **Directory-based suggestions**: Scans existing markdown files in the current directory to suggest commonly used tags
- **AI-powered suggestions**: Uses OpenAI's API to generate contextually relevant tag suggestions
- **Multiple display modes**: Choose between Telescope picker or floating window for tag selection
- **Smart formatting**: Automatically formats tags with proper capitalization
- **Visual enhancements**: Emoji indicators (🏷️) for better visual identification
- **Easy integration**: Simple keybindings for quick access

## Installation

### Using Lazy.nvim

Add to your `init.lua` or plugin configuration:

```lua
{
  "TravisLinkey/nvim-tag-suggestions",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  event = "BufReadPre *.md",
  opts = {
    enable_ai = true,
    openai_api_key = os.getenv("OPENAI_API_KEY"),
    trigger_key = "<leader>ts",
    max_suggestions = 8,
    use_telescope = true,
  },
}
```

### Using Packer

```lua
use {
  "TravisLinkey/nvim-tag-suggestions",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("nvim-tag-suggestions").setup({
      enable_ai = true,
      openai_api_key = os.getenv("OPENAI_API_KEY"),
      trigger_key = "<leader>ts",
      max_suggestions = 8,
      use_telescope = true,
    })
  end
}
```

## Configuration

### Options

- `enable_ai` (boolean): Enable AI-powered suggestions (default: `true`)
- `openai_api_key` (string): OpenAI API key (default: `nil`, uses environment variable)
- `trigger_key` (string): Keybinding to trigger tag suggestions (default: `"<leader>ts"`)
- `max_suggestions` (number): Maximum number of suggestions to show (default: `8`)
- `use_telescope` (boolean): Use Telescope picker instead of floating window (default: `true`)

### OpenAI API Key Setup

Set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY="your-api-key-here"
```

Or add it to your shell configuration file (`.bashrc`, `.zshrc`, etc.).

## Usage

### Keybindings

- `<leader>ts` - Show tag suggestions (combines directory and AI suggestions)
- `<leader>ta` - Test AI tag suggestions only
- `<leader>td` - Test directory tag suggestions only
- `<leader>tc` - Custom tag input (manually enter a tag)

### Commands

You can also call the functions directly:

```lua
-- Show all suggestions
:lua require("nvim-tag-suggestions").show_suggestions()

-- Test AI suggestions
:lua require("nvim-tag-suggestions").test_ai_suggestions()

-- Test directory suggestions
:lua require("nvim-tag-suggestions").test_directory_suggestions()
```

## How It Works

### Directory-based Suggestions

The plugin scans all markdown files in the current directory and extracts existing tags. It then suggests the most frequently used tags, helping maintain consistency across your notes.

### AI-powered Suggestions

When enabled, the plugin sends the current note content and context to OpenAI's API to generate relevant tag suggestions. The AI considers:

- Current note content
- Existing tags in the directory
- Related notes in the same directory

### Custom Input

The plugin also supports manual tag input, allowing you to enter custom tags that aren't suggested by the AI or directory scanning. Custom tags are automatically formatted and inserted at the cursor position.

### Tag Formatting

Tags are automatically formatted to:
- Start with a capital letter
- Use proper spacing for multi-word tags
- Remove duplicates
- Maintain consistency
- Display with emoji indicators (🏷️) for better visual identification

### Display Modes

- **Telescope Picker**: Shows suggestions in a searchable Telescope modal with emoji indicators
- **Floating Window**: Shows suggestions in a centered floating window with numbered options

## Requirements

- Neovim 0.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for Telescope picker)
- OpenAI API key (optional, for AI suggestions)

## License

MIT License 