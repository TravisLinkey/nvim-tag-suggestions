# nvim-tag-suggestions

A Neovim plugin for intelligent tag suggestions in markdown files, combining directory-based analysis with AI-powered recommendations using OpenAI.

## Features

- **Directory-based suggestions**: Analyzes similar files in the same directory and parent directories
- **AI-powered suggestions**: Uses OpenAI GPT models to generate contextual tag recommendations
- **Smart formatting**: Automatically formats tags with proper capitalization and acronym handling
- **Telescope integration**: Beautiful picker interface with custom input support
- **Floating window fallback**: Alternative UI for environments without Telescope
- **Empty array handling**: Automatically converts `tags: []` to proper YAML format
- **Content similarity analysis**: Suggests tags based on content similarity between files
- **Frequency analysis**: Prioritizes commonly used tags in similar contexts

## Installation

### Using Lazy.nvim

Add this to your Neovim configuration:

```lua
{
  "your-username/nvim-tag-suggestions",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  event = "BufReadPre *.md",
  config = function()
    require("tag-suggestions").setup({
      -- Enable AI-powered suggestions (requires OPENAI_API_KEY environment variable)
      enable_ai = true,
      -- OpenAI API key from environment variable
      openai_api_key = os.getenv("OPENAI_API_KEY"),
      -- Other configuration options
      trigger_key = "<leader>ts",
      max_suggestions = 8,
      use_telescope = true,
    })
  end,
}
```

### Using Packer

```lua
use {
  "your-username/nvim-tag-suggestions",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("tag-suggestions").setup()
  end,
}
```

## Configuration

```lua
require("tag-suggestions").setup({
  -- Keybinding to trigger tag suggestions
  trigger_key = "<leader>ts",
  
  -- Whether to show suggestions automatically when entering tags section
  auto_suggest = false,
  
  -- Number of suggestions to show
  max_suggestions = 5,
  
  -- Whether to use telescope picker or floating window
  use_telescope = true,
  
  -- Weight for frequency vs similarity in scoring (higher = more weight on frequency)
  frequency_weight = 10,
  
  -- Minimum word length to consider as keyword
  min_word_length = 3,
  
  -- Minimum keyword frequency to consider
  min_keyword_frequency = 2,
  
  -- Whether to show similarity scores in the UI
  show_similarity_scores = true,
  
  -- Whether to enable AI-powered suggestions
  enable_ai = false,
  
  -- OpenAI API key (set this to enable AI suggestions)
  openai_api_key = nil,
})
```

## Setup for AI Features

1. **Get an OpenAI API key** from [OpenAI Platform](https://platform.openai.com/api-keys)

2. **Set the environment variable**:
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

3. **Add to your shell profile** (`.zshrc`, `.bashrc`, etc.):
   ```bash
   echo 'export OPENAI_API_KEY="your-api-key-here"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. **Enable AI in your config**:
   ```lua
   require("tag-suggestions").setup({
     enable_ai = true,
     openai_api_key = os.getenv("OPENAI_API_KEY"),
   })
   ```

## Usage

### Keybindings

- `<leader>ts` - Show all tag suggestions (directory + AI)
- `<leader>ta` - Test AI suggestions only
- `<leader>tt` - Test tag suggestions (debug output)
- `<leader>td` - Debug plugin status

### Commands

- `:TagSuggestions` - Show tag suggestions
- `:TagSuggestionsAI` - Test AI suggestions
- `:TagSuggestionsDebug` - Debug plugin status

### Telescope Interface

When using the Telescope picker:
1. **Browse suggestions**: Navigate through directory-based and AI suggestions
2. **Custom input**: Type to add your own custom tag
3. **Select**: Press Enter to add the selected tag to your file
4. **Format**: Tags are automatically formatted with proper capitalization

### Example Workflow

1. Open a markdown file with YAML frontmatter
2. Press `<leader>ts` to see tag suggestions
3. Select a suggestion or type a custom tag
4. The tag is automatically added to your frontmatter

## File Structure Support

The plugin searches for similar files in:
- Current directory (recursive)
- Parent directories (up to 3 levels up)
- Analyzes YAML frontmatter tags from all found markdown files

## Tag Formatting

The plugin automatically formats tags with:
- **Proper capitalization**: "cloud function" → "Cloud Function"
- **Acronym handling**: "E2e tests" → "E2E Tests", "Cicd pipeline" → "CICD Pipeline"
- **Empty array conversion**: `tags: []` → proper YAML format

## Troubleshooting

### AI suggestions not working
- Ensure `OPENAI_API_KEY` environment variable is set
- Check that `enable_ai = true` in your config
- Verify your API key is valid and has credits

### No suggestions found
- Ensure you're in a markdown file
- Check that there are other markdown files in the directory
- Verify the files have YAML frontmatter with tags

### Telescope not working
- Ensure Telescope is installed and configured
- Set `use_telescope = false` to use floating window instead

## Development

### Testing

```bash
# Test the plugin
nvim --headless test_notes/test_note.md -c "lua require('tag-suggestions').test()" -c "quit"

# Debug plugin status
nvim --headless -c "lua require('tag-suggestions').debug()" -c "quit"

# Test AI suggestions
nvim --headless test_notes/test_note.md -c "lua require('tag-suggestions').test_ai()" -c "quit"
```

### CLI Usage

```bash
# Show help
nvim --headless -c "lua require('tag-suggestions').cli_help()" -c "quit"

# Test with specific file
nvim --headless test_notes/test_note.md -c "lua require('tag-suggestions').test()" -c "quit"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built for Neovim with Lua
- Uses OpenAI API for AI-powered suggestions
- Integrates with Telescope for beautiful UI
- Inspired by the need for better tag management in markdown notes 