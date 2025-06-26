local M = {}

-- Load AI module
local ai = require("nvim-tag-suggestions.ai")

-- Default configuration
local default_config = {
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
}

local config = vim.tbl_deep_extend("force", default_config, {})

-- Utility functions
local function get_current_file_path()
  return vim.fn.expand("%:p")
end

local function get_directory_path(file_path)
  return vim.fn.fnamemodify(file_path, ":h")
end

-- Function to format tag as full word with capital letter
local function format_tag_display(tag)
  -- Common acronyms that should stay all caps
  local acronyms = {
    "API", "URL", "HTTP", "HTTPS", "JSON", "XML", "HTML", "CSS", "JS", "SQL", "REST", "SOAP",
    "CRUD", "OAuth", "JWT", "SSL", "TLS", "SSH", "FTP", "SMTP", "POP3", "IMAP", "DNS", "IP",
    "TCP", "UDP", "VPN", "GUI", "CLI", "IDE", "SDK", "API", "SDK", "ORM", "MVC", "MVP",
    "CI", "CD", "AWS", "GCP", "Azure", "SaaS", "PaaS", "IaaS", "BaaS", "FaaS", "DB", "DBMS",
    "E2E", "CICD", "CI/CD", "TDD", "BDD", "DDD", "SOLID", "DRY", "KISS", "YAGNI", "SOLID",
    "REST", "GraphQL", "gRPC", "OAuth2", "JWT", "JWT", "OIDC", "SAML", "LDAP", "SSO",
    "API", "SDK", "SDK", "CLI", "GUI", "TUI", "CLI", "IDE", "IDE", "VSCode", "Vim", "Emacs",
    "Git", "SVN", "Mercurial", "Docker", "Kubernetes", "K8s", "Helm", "Terraform", "Ansible",
    "Jenkins", "GitLab", "GitHub", "Bitbucket", "Azure DevOps", "TeamCity", "Bamboo",
    "Maven", "Gradle", "npm", "yarn", "pip", "conda", "composer", "cargo", "go mod",
    "React", "Vue", "Angular", "Svelte", "Next.js", "Nuxt.js", "Gatsby", "Vite", "Webpack",
    "Babel", "TypeScript", "JavaScript", "ES6", "ES2015", "ES2016", "ES2017", "ES2018",
    "ES2019", "ES2020", "ES2021", "ES2022", "ES2023", "ES2024", "ES2025", "ES2026", "ES2027",
    "Node.js", "Deno", "Bun", "Python", "Ruby", "PHP", "Java", "C#", "C++", "C", "Go",
    "Rust", "Swift", "Kotlin", "Scala", "Clojure", "Haskell", "Elixir", "Erlang", "F#",
    "TypeScript", "JavaScript", "CoffeeScript", "LiveScript", "Dart", "Elm", "PureScript",
    "Reason", "OCaml", "F#", "C#", "VB.NET", "ASP.NET", "Spring", "Django", "Flask",
    "Express", "FastAPI", "Laravel", "Symfony", "Rails", "Sinatra", "Phoenix", "Actix",
    "Rocket", "Axum", "Gin", "Echo", "Fiber", "Chi", "Gorilla", "Mux", "Fasthttp",
    "PostgreSQL", "MySQL", "SQLite", "MongoDB", "Redis", "Cassandra", "DynamoDB",
    "Elasticsearch", "Solr", "Neo4j", "ArangoDB", "InfluxDB", "TimescaleDB", "CockroachDB",
    "Vitess", "TiDB", "YugabyteDB", "ScyllaDB", "RethinkDB", "CouchDB", "Couchbase",
    "RavenDB", "DocumentDB", "CosmosDB", "Firestore", "BigQuery", "Snowflake", "Redshift",
    "Databricks", "Delta Lake", "Iceberg", "Hudi", "Presto", "Trino", "Spark", "Flink",
    "Kafka", "RabbitMQ", "ActiveMQ", "ZeroMQ", "NATS", "gRPC", "Thrift", "Protocol Buffers",
    "Avro", "JSON", "XML", "YAML", "TOML", "INI", "HCL", "JSON5", "JSONC", "JSONL",
    "CSV", "TSV", "Parquet", "ORC", "Arrow", "Feather", "HDF5", "NetCDF", "Zarr",
    "Dask", "Vaex", "Polars", "Pandas", "NumPy", "SciPy", "Matplotlib", "Seaborn",
    "Plotly", "Bokeh", "Altair", "Vega", "D3.js", "Chart.js", "Highcharts", "ApexCharts",
    "Recharts", "Victory", "Visx", "Nivo", "Frappe Charts", "Apache ECharts", "G2",
    "AntV", "Observable", "Observable Plot", "Observable D3", "Observable Vega",
    "Observable Vega-Lite", "Observable Vega-Lite", "Observable Vega-Lite", "Observable Vega-Lite"
  }
  
  -- Check if the entire tag is a known acronym
  for _, acronym in ipairs(acronyms) do
    if tag:upper() == acronym then
      return acronym
    end
  end
  
  -- Handle space-separated words (e.g., "Cloud function" → "Cloud Function")
  if tag:find(" ") then
    local words = {}
    for word in tag:gmatch("[^%s]+") do
      -- Check if word is a known acronym (case-insensitive)
      local is_acronym = false
      for _, acronym in ipairs(acronyms) do
        if word:upper() == acronym then
          table.insert(words, acronym)
          is_acronym = true
          break
        end
      end
      
      -- Also check for common patterns like "E2e" → "E2E", "Cicd" → "CICD"
      if not is_acronym then
        local upper_word = word:upper()
        -- Only convert to all caps if it matches specific acronym patterns
        if upper_word:match("^[A-Z]%d+[A-Z]$") or -- E2E, C3P0, etc.
           upper_word:match("^[A-Z]+$") and #upper_word <= 4 then -- Short all-caps words like API, CLI, etc.
          table.insert(words, upper_word)
          is_acronym = true
        end
      end
      
      if not is_acronym then
        -- Capitalize first letter of each word
        table.insert(words, word:sub(1, 1):upper() .. word:sub(2):lower())
      end
    end
    return table.concat(words, " ")
  end
  
  -- Handle different tag formats
  if tag:match("^[A-Z][a-z]+$") then
    -- Already properly formatted (e.g., "ServiceCore")
    return tag
  elseif tag:match("^[a-z]+$") then
    -- All lowercase (e.g., "servicecore")
    return tag:sub(1, 1):upper() .. tag:sub(2)
  elseif tag:match("^[A-Z_]+$") then
    -- All caps with underscores (e.g., "SERVICE_CORE")
    local words = {}
    for word in tag:gmatch("[^_]+") do
      -- Check if word is an acronym
      local is_acronym = false
      for _, acronym in ipairs(acronyms) do
        if word:upper() == acronym then
          table.insert(words, acronym)
          is_acronym = true
          break
        end
      end
      if not is_acronym then
        table.insert(words, word:sub(1, 1) .. word:sub(2):lower())
      end
    end
    return table.concat(words, " ")
  elseif tag:match("^[A-Z][a-z]*[A-Z]") then
    -- CamelCase (e.g., "ServiceCore")
    return tag
  elseif tag:match("^[a-z]+[A-Z]") then
    -- camelCase (e.g., "serviceCore")
    return tag:sub(1, 1):upper() .. tag:sub(2)
  else
    -- Handle mixed case with potential acronyms
    local result = ""
    local i = 1
    while i <= #tag do
      local char = tag:sub(i, i)
      if char:match("[A-Z]") then
        -- Found uppercase letter, check if it's part of an acronym
        local acronym = char
        local j = i + 1
        while j <= #tag and tag:sub(j, j):match("[A-Z]") do
          acronym = acronym .. tag:sub(j, j)
          j = j + 1
        end
        
        -- Check if this is a known acronym
        local is_known_acronym = false
        for _, known_acronym in ipairs(acronyms) do
          if acronym:upper() == known_acronym then
            result = result .. known_acronym
            is_known_acronym = true
            break
          end
        end
        
        if not is_known_acronym then
          if j <= #tag and tag:sub(j, j):match("[a-z]") then
            -- Not an acronym, just capitalize first letter
            result = result .. char
          else
            -- It's an acronym-like pattern, keep it all caps
            result = result .. acronym
          end
        end
        i = j
      elseif char:match("[a-z]") then
        -- Lowercase letter, capitalize if it's the first character
        if i == 1 then
          result = result .. char:upper()
        else
          result = result .. char
        end
        i = i + 1
      else
        -- Non-letter character, keep as is
        result = result .. char
        i = i + 1
      end
    end
    return result
  end
end

local function extract_tags_from_yaml(yaml_content)
  local tags = {}
  local lines = vim.split(yaml_content, "\n")
  local in_tags_section = false
  
  for _, line in ipairs(lines) do
    if line:match("^tags:") then
      in_tags_section = true
    elseif in_tags_section and line:match("^%s*-%s+(.+)") then
      local tag = line:match("^%s*-%s+(.+)")
      if tag then
        table.insert(tags, tag)
      end
    elseif in_tags_section and not line:match("^%s*-") and line:match("^%s*%w") then
      -- Exit tags section if we hit another top-level key
      in_tags_section = false
    end
  end
  
  return tags
end

local function read_file_content(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

local function get_markdown_files_in_directory(dir_path)
  local files = {}
  
  -- Get files from current directory and subdirectories (recursive)
  local handle = io.popen(string.format('find "%s" -name "*.md" -type f', dir_path))
  if handle then
    for file in handle:lines() do
      table.insert(files, file)
    end
    handle:close()
  end
  
  -- Also get files from parent directories (up to 3 levels up)
  local current_dir = dir_path
  for i = 1, 3 do
    local parent_dir = vim.fn.fnamemodify(current_dir, ":h")
    if parent_dir ~= current_dir then
      local parent_handle = io.popen(string.format('find "%s" -maxdepth 1 -name "*.md" -type f', parent_dir))
      if parent_handle then
        for file in parent_handle:lines() do
          table.insert(files, file)
        end
        parent_handle:close()
      end
      current_dir = parent_dir
    else
      break
    end
  end
  
  return files
end

local function extract_yaml_frontmatter(content)
  if not content then return nil end
  
  local lines = vim.split(content, "\n")
  local yaml_lines = {}
  local in_frontmatter = false
  
  for _, line in ipairs(lines) do
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        break
      end
    elseif in_frontmatter then
      table.insert(yaml_lines, line)
    end
  end
  
  return table.concat(yaml_lines, "\n")
end

-- Function to extract keywords from content (simple approach)
local function extract_keywords(content)
  if not content then return {} end
  
  -- Remove YAML frontmatter
  local lines = vim.split(content, "\n")
  local content_lines = {}
  local in_frontmatter = false
  
  for _, line in ipairs(lines) do
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        in_frontmatter = false
      end
    elseif not in_frontmatter then
      table.insert(content_lines, line)
    end
  end
  
  local content_text = table.concat(content_lines, " ")
  
  -- Simple keyword extraction: find words that appear multiple times
  local words = {}
  for word in content_text:gmatch("%w+") do
    word = word:lower()
    if #word > config.min_word_length then  -- Use configurable minimum length
      words[word] = (words[word] or 0) + 1
    end
  end
  
  -- Filter out common words
  local common_words = {
    "this", "that", "with", "have", "will", "from", "they", "know", "want", "been",
    "good", "much", "some", "time", "very", "when", "come", "just", "into", "than",
    "more", "other", "about", "many", "then", "them", "these", "people", "only",
    "well", "also", "over", "still", "take", "every", "think", "back", "after",
    "work", "first", "should", "because", "through", "during", "before", "between",
    "never", "always", "often", "sometimes", "usually", "generally", "typically"
  }
  
  local keywords = {}
  for word, count in pairs(words) do
    if count >= config.min_keyword_frequency and not vim.tbl_contains(common_words, word) then
      table.insert(keywords, { word = word, count = count })
    end
  end
  
  table.sort(keywords, function(a, b)
    return a.count > b.count
  end)
  
  return keywords
end

-- Function to calculate content similarity
local function calculate_similarity(keywords1, keywords2)
  local score = 0
  local word_map = {}
  
  -- Create a map of words from keywords1
  for _, kw in ipairs(keywords1) do
    word_map[kw.word] = kw.count
  end
  
  -- Check for matches in keywords2
  for _, kw in ipairs(keywords2) do
    if word_map[kw.word] then
      score = score + math.min(word_map[kw.word], kw.count)
    end
  end
  
  return score
end

-- Enhanced function to collect tags with content analysis
local function collect_tags_with_analysis()
  local current_file = get_current_file_path()
  local dir_path = get_directory_path(current_file)
  local markdown_files = get_markdown_files_in_directory(dir_path)
  
  -- Get current file's content and keywords
  local current_content = read_file_content(current_file)
  local current_keywords = extract_keywords(current_content)
  
  local all_tags = {}
  local tag_scores = {}
  
  for _, file_path in ipairs(markdown_files) do
    -- Skip current file
    if file_path ~= current_file then
      local content = read_file_content(file_path)
      if content then
        local yaml_content = extract_yaml_frontmatter(content)
        if yaml_content then
          local tags = extract_tags_from_yaml(yaml_content)
          local keywords = extract_keywords(content)
          local similarity = calculate_similarity(current_keywords, keywords)
          
          for _, tag in ipairs(tags) do
            if not tag_scores[tag] then
              tag_scores[tag] = { count = 0, total_similarity = 0 }
            end
            tag_scores[tag].count = tag_scores[tag].count + 1
            tag_scores[tag].total_similarity = tag_scores[tag].total_similarity + similarity
          end
        end
      end
    end
  end
  
  -- Convert to sorted list with combined scoring
  for tag, data in pairs(tag_scores) do
    local score = data.count * config.frequency_weight + data.total_similarity  -- Use configurable weight
    table.insert(all_tags, { 
      tag = tag, 
      count = data.count,
      similarity = data.total_similarity,
      score = score
    })
  end
  
  table.sort(all_tags, function(a, b)
    return a.score > b.score
  end)
  
  return all_tags
end

-- Function to find the tags section in the current buffer
local function find_tags_section()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local in_frontmatter = false
  local tags_line = -1
  local insert_line = -1
  
  for i, line in ipairs(lines) do
    if line == "---" then
      if not in_frontmatter then
        in_frontmatter = true
      else
        break
      end
    elseif in_frontmatter then
      if line:match("^tags:") then
        tags_line = i - 1  -- Convert to 0-based index
        insert_line = i    -- Insert after the tags: line
      elseif tags_line > 0 and line:match("^%s*-%s+(.+)") then
        -- Found a tag, update insert position
        insert_line = i
      elseif tags_line > 0 and not line:match("^%s*-") and line:match("^%s*%w") then
        -- Hit another top-level key, stop looking
        break
      end
    end
  end
  
  return tags_line, insert_line
end

-- Function to insert a tag into the current file
local function insert_tag_into_file(tag)
  local tags_line, insert_line = find_tags_section()
  
  if tags_line == -1 then
    -- No tags section found, create one
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local frontmatter_end = -1
    
    for i, line in ipairs(lines) do
      if line == "---" and i > 1 then
        frontmatter_end = i - 1
        break
      end
    end
    
    if frontmatter_end > 0 then
      -- Insert tags section before the closing ---
      vim.api.nvim_buf_set_lines(0, frontmatter_end - 1, frontmatter_end - 1, false, {
        "tags:",
        "  - " .. tag,
      })
    else
      -- No frontmatter, create one at the beginning
      vim.api.nvim_buf_set_lines(0, 0, 0, false, {
        "---",
        "tags:",
        "  - " .. tag,
        "---",
        "",
      })
    end
  else
    -- Tags section exists, check if it's an empty array
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local tags_line_content = lines[tags_line + 1] -- Convert back to 1-based
    
    -- Check if it's an empty array like "tags: []"
    if tags_line_content and tags_line_content:match("^%s*tags:%s*%[%]%s*$") then
      -- Replace the empty array with proper format
      vim.api.nvim_buf_set_lines(0, tags_line, tags_line + 1, false, {
        "tags:",
        "  - " .. tag,
      })
    else
      -- Normal insertion
      if insert_line > 0 then
        vim.api.nvim_buf_set_lines(0, insert_line, insert_line, false, {
          "  - " .. tag,
        })
      else
        -- Insert after the tags: line
        vim.api.nvim_buf_set_lines(0, tags_line + 1, tags_line + 1, false, {
          "  - " .. tag,
        })
      end
    end
  end
  
  vim.notify("Added tag: " .. tag, vim.log.levels.INFO)
end

-- Function to combine AI and directory-based suggestions
local function combine_suggestions(directory_suggestions, ai_suggestions)
  local combined = {}
  local seen_tags = {}
  
  -- Add directory-based suggestions first
  for _, suggestion in ipairs(directory_suggestions) do
    table.insert(combined, {
      tag = suggestion.tag,
      count = suggestion.count,
      similarity = suggestion.similarity,
      score = suggestion.score,
      source = "directory"
    })
    seen_tags[suggestion.tag] = true
  end
  
  -- Add AI suggestions (with high score to prioritize them)
  if ai_suggestions then
    for _, tag in ipairs(ai_suggestions) do
      if not seen_tags[tag] then
        table.insert(combined, {
          tag = tag,
          count = 0,
          similarity = 0,
          score = 1000, -- High score for AI suggestions
          source = "ai"
        })
        seen_tags[tag] = true
      end
    end
  end
  
  -- Sort by score
  table.sort(combined, function(a, b)
    return a.score > b.score
  end)
  
  return combined
end

-- Function to show suggestions in a floating window
local function show_suggestions_floating(suggestions)
  local width = 50
  local height = math.min(#suggestions + 2, 10)
  
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "tag-suggestions")
  
  -- Add content
  local lines = { "Tag Suggestions:" }
  for i, suggestion in ipairs(suggestions) do
    if i <= config.max_suggestions then
      local source_indicator = suggestion.source == "ai" and "🤖" or "📁"
      if config.show_similarity_scores and suggestion.source == "directory" then
        table.insert(lines, string.format("  %s %s (freq: %d, sim: %.1f)", source_indicator, suggestion.tag, suggestion.count, suggestion.similarity))
      else
        table.insert(lines, string.format("  %s %s", source_indicator, suggestion.tag))
      end
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Add keymaps for accepting/rejecting
  local function close_window()
    vim.api.nvim_win_close(win, true)
  end
  
  local function accept_tag(tag)
    insert_tag_into_file(format_tag_display(tag))
    close_window()
  end
  
  -- Set up keymaps
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", close_window, opts)
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_win_get_cursor(win)[1]
    if line > 1 and line <= #suggestions + 1 then
      local suggestion_index = line - 1
      if suggestion_index <= #suggestions then
        local selection = suggestions[suggestion_index]
        accept_tag(selection.tag)
      end
    end
  end, opts)
  
  -- Auto-close when leaving the window
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = close_window,
    once = true,
  })
end

-- Function to show suggestions with telescope
local function show_suggestions_telescope(suggestions)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  local function accept_tag(selection)
    local tag = format_tag_display(selection.tag)
    insert_tag_into_file(tag)
  end
  
  -- Create a custom finder that allows custom input
  local function create_custom_finder()
    return finders.new_dynamic({
      fn = function(prompt)
        local results = {}
        
        -- Add custom input as first option if it's not empty
        if prompt and prompt:match("%S") then
          table.insert(results, {
            value = prompt,
            display = "✨ " .. format_tag_display(prompt) .. " (custom)",
            ordinal = prompt,
            tag = prompt,
            count = 0,
            similarity = 0,
            source = "custom",
          })
        end
        
        -- Add existing suggestions
        for _, entry in ipairs(suggestions) do
          local source_indicator = entry.source == "ai" and "🤖" or "📁"
          local display
          if config.show_similarity_scores and entry.source == "directory" then
            display = string.format("%s %s (freq: %d, sim: %.1f)", source_indicator, format_tag_display(entry.tag), entry.count, entry.similarity)
          else
            display = string.format("%s %s", source_indicator, format_tag_display(entry.tag))
          end
          table.insert(results, {
            value = entry.tag,
            display = display,
            ordinal = entry.tag,
            tag = entry.tag,
            count = entry.count,
            similarity = entry.similarity,
            source = entry.source,
          })
        end
        
        return results
      end,
      entry_maker = function(entry)
        return entry
      end,
    })
  end
  
  pickers.new({}, {
    prompt_title = "Tag Suggestions (type to add custom tag)",
    finder = create_custom_finder(),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          accept_tag(selection)
        end
      end)
      return true
    end,
  }):find()
end

-- Test function to verify plugin is working
function M.test()
  print("Tag suggestions plugin is loaded!")
  print("Current file: " .. vim.fn.expand("%:p"))
  print("Filetype: " .. vim.bo.filetype)
  print("Filename: " .. vim.fn.expand("%:t"))
  
  local suggestions = collect_tags_with_analysis()
  print("Found " .. #suggestions .. " suggestions")
  for i, suggestion in ipairs(suggestions) do
    print(string.format("  %d. %s (freq: %d, sim: %.1f)", i, format_tag_display(suggestion.tag), suggestion.count, suggestion.similarity))
  end
end

-- Test formatting function
function M.test_formatting()
  print("Testing tag formatting:")
  print("E2e Tests -> " .. format_tag_display("E2e Tests"))
  print("Cicd Pipeline -> " .. format_tag_display("Cicd Pipeline"))
  print("Api Documentation -> " .. format_tag_display("Api Documentation"))
  print("E2e -> " .. format_tag_display("E2e"))
  print("Cicd -> " .. format_tag_display("Cicd"))
  print("Api -> " .. format_tag_display("Api"))
  print("Cloud Function -> " .. format_tag_display("Cloud Function"))
  print("Service Core -> " .. format_tag_display("Service Core"))
end

-- Debug function to check plugin status
function M.debug()
  print("=== Tag Suggestions Plugin Debug ===")
  print("Plugin loaded: " .. tostring(M ~= nil))
  print("Current file: " .. vim.fn.expand("%:p"))
  print("Filetype: " .. vim.bo.filetype)
  print("Filename: " .. vim.fn.expand("%:t"))
  print("Is markdown: " .. tostring(vim.bo.filetype == "markdown" or vim.fn.expand("%:t"):match("%.md$")))
  print("Config loaded: " .. tostring(config ~= nil))
  if config then
    print("Trigger key: " .. config.trigger_key)
    print("AI enabled: " .. tostring(config.enable_ai))
    print("API key set: " .. tostring(config.openai_api_key ~= nil))
  end
  print("================================")
end

-- Enhanced main function to generate and show tag suggestions
function M.show_tag_suggestions()
  -- Check if current file is markdown
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand("%:t")
  
  if filetype ~= "markdown" and not filename:match("%.md$") then
    vim.notify("Tag suggestions only work with markdown files. Current filetype: " .. filetype, vim.log.levels.WARN)
    return
  end
  
  local directory_suggestions = collect_tags_with_analysis()
  local ai_suggestions = nil
  
  -- Get AI suggestions if enabled
  if config.enable_ai and config.openai_api_key then
    ai.set_api_key(config.openai_api_key)
    local current_file = get_current_file_path()
    ai_suggestions, error = ai.generate_ai_suggestions(current_file)
    if error then
      vim.notify("AI suggestions error: " .. error, vim.log.levels.WARN)
    end
  elseif config.enable_ai and not config.openai_api_key then
    vim.notify("AI suggestions enabled but OPENAI_API_KEY not set. Run './setup_openai.sh' for setup instructions.", vim.log.levels.WARN)
  end
  
  -- Combine suggestions
  local suggestions = combine_suggestions(directory_suggestions, ai_suggestions)
  
  if #suggestions == 0 then
    vim.notify("No tag suggestions found", vim.log.levels.INFO)
    return
  end
  
  if config.use_telescope then
    show_suggestions_telescope(suggestions)
  else
    show_suggestions_floating(suggestions)
  end
end

-- CLI Help function
local function show_cli_help()
  print([[
Tag Suggestions Plugin - CLI Help
================================

USAGE:
  nvim --headless -c "lua require('nvim-tag-suggestions').cli_help()" -c "quit"
  nvim --headless -c "lua require('nvim-tag-suggestions').cli_help()" --help -c "quit"

COMMANDS:
  --help, -h          Show this help message
  --test, -t          Test the plugin with current file
  --debug, -d         Show debug information
  --ai-test, -a       Test AI suggestions only
  --version, -v       Show plugin version

EXAMPLES:
  # Show help
  nvim --headless -c "lua require('nvim-tag-suggestions').cli_help()" -c "quit"

  # Test plugin with a specific file
  nvim --headless test_notes/test_note.md -c "lua require('nvim-tag-suggestions').test()" -c "quit"

  # Debug plugin status
  nvim --headless -c "lua require('nvim-tag-suggestions').debug()" -c "quit"

  # Test AI suggestions
  nvim --headless test_notes/test_note.md -c "lua require('nvim-tag-suggestions').test_ai()" -c "quit"

KEYBINDINGS (when in Neovim):
  <leader>ts          Show all tag suggestions (directory + AI)
  <leader>ta          Test AI suggestions only
  <leader>tt          Test tag suggestions (debug output)
  <leader>td          Debug plugin status

CONFIGURATION:
  The plugin can be configured in your Neovim config:
  
  require('nvim-tag-suggestions').setup({
    trigger_key = "<leader>ts",        -- Key to trigger suggestions
    auto_suggest = false,              -- Auto-suggest when entering tags section
    max_suggestions = 5,               -- Number of suggestions to show
    use_telescope = true,              -- Use telescope picker or floating window
    frequency_weight = 10,             -- Weight for frequency vs similarity
    min_word_length = 3,               -- Minimum word length for keywords
    min_keyword_frequency = 2,         -- Minimum keyword frequency
    show_similarity_scores = true,     -- Show similarity scores in UI
    enable_ai = false,                 -- Enable AI-powered suggestions
    openai_api_key = nil,             -- OpenAI API key
  })

FEATURES:
  • Directory-based tag suggestions from similar files
  • AI-powered tag suggestions using OpenAI
  • Content similarity analysis
  • Tag frequency analysis
  • Proper tag formatting (capitalization, acronyms)
  • Telescope integration for selection
  • Floating window fallback
  • Recursive directory search
  • Parent directory context

SETUP FOR AI:
  1. Run: ./setup_openai.sh
  2. Set your OpenAI API key
  3. Enable AI in config: enable_ai = true

TROUBLESHOOTING:
  • Use --debug to check plugin status
  • Ensure you're in a markdown file
  • Check that OpenAI API key is set for AI features
  • Verify telescope is installed for picker mode

VERSION: 1.0.0
]])
end

-- CLI test AI function
local function test_ai_cli()
  if not config.enable_ai then
    print("AI suggestions not enabled. Set enable_ai = true in config.")
    return
  end
  
  if not config.openai_api_key then
    print("OPENAI_API_KEY not set. Run './setup_openai.sh' for setup instructions.")
    return
  end
  
  local current_file = get_current_file_path()
  if current_file == "" then
    print("No file specified. Usage: nvim --headless <file.md> -c \"lua require('nvim-tag-suggestions').test_ai()\" -c \"quit\"")
    return
  end
  
  print("Testing AI suggestions for: " .. current_file)
  ai.set_api_key(config.openai_api_key)
  local suggestions, error = ai.generate_ai_suggestions(current_file)
  
  if error then
    print("AI test error: " .. error)
  else
    print("AI suggestions:")
    for i, tag in ipairs(suggestions) do
      print(string.format("  %d. %s", i, format_tag_display(tag)))
    end
  end
end

-- CLI version function
local function show_version()
  print("Tag Suggestions Plugin v1.0.0")
  print("A Neovim plugin for intelligent tag suggestions in markdown files")
  print("Supports directory-based and AI-powered suggestions")
end

-- CLI main function to handle arguments
local function handle_cli_args()
  local args = vim.fn.argv()
  
  for _, arg in ipairs(args) do
    if arg == "--help" or arg == "-h" then
      show_cli_help()
      return true
    elseif arg == "--version" or arg == "-v" then
      show_version()
      return true
    elseif arg == "--test" or arg == "-t" then
      M.test()
      return true
    elseif arg == "--debug" or arg == "-d" then
      M.debug()
      return true
    elseif arg == "--ai-test" or arg == "-a" then
      test_ai_cli()
      return true
    end
  end
  
  return false
end

-- Expose CLI functions
M.cli_help = show_cli_help
M.test_ai = test_ai_cli
M.version = show_version
M.handle_cli_args = handle_cli_args

-- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
  
  -- Configure AI if API key is provided
  if config.openai_api_key then
    ai.set_api_key(config.openai_api_key)
    config.enable_ai = true
  end
  
  -- Handle CLI arguments if in headless mode
  if vim.fn.has("nvim-0.8") == 1 and vim.fn.has("nvim-0.9") == 0 then
    -- For older Neovim versions, check if we're in headless mode differently
    if vim.fn.argc() > 0 then
      local handled = handle_cli_args()
      if handled then
        return -- Exit early if CLI command was handled
      end
    end
  else
    -- For newer Neovim versions, check if we're in headless mode
    if vim.fn.has("nvim-0.9") == 1 and vim.fn.argc() > 0 then
      local handled = handle_cli_args()
      if handled then
        return -- Exit early if CLI command was handled
      end
    end
  end
  
  -- Set up global keybindings (not buffer-local)
  vim.keymap.set("n", config.trigger_key, M.show_tag_suggestions, { 
    desc = "Show tag suggestions"
  })
  
  -- Test keybinding
  vim.keymap.set("n", "<leader>tt", M.test, { 
    desc = "Test tag suggestions"
  })
  
  -- Debug keybinding
  vim.keymap.set("n", "<leader>td", M.debug, { 
    desc = "Debug tag suggestions plugin"
  })
  
  -- AI test keybinding
  vim.keymap.set("n", "<leader>ta", function()
    if config.enable_ai then
      if config.openai_api_key then
        local current_file = get_current_file_path()
        local suggestions, error = ai.generate_ai_suggestions(current_file)
        if error then
          vim.notify("AI test error: " .. error, vim.log.levels.ERROR)
        else
          -- Show AI suggestions in Telescope modal
          local pickers = require("telescope.pickers")
          local finders = require("telescope.finders")
          local conf = require("telescope.config").values
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")
          
          local function accept_tag(selection)
            local tag = format_tag_display(selection.tag)
            insert_tag_into_file(tag)
          end
          
          pickers.new({}, {
            prompt_title = "AI Tag Suggestions",
            finder = finders.new_table({
              results = suggestions,
              entry_maker = function(entry)
                return {
                  value = entry,
                  display = "🤖 " .. format_tag_display(entry),
                  ordinal = entry,
                  tag = entry,
                }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                  accept_tag(selection)
                end
              end)
              return true
            end,
          }):find()
        end
      else
        vim.notify("OPENAI_API_KEY not set. Run './setup_openai.sh' for setup instructions.", vim.log.levels.WARN)
      end
    else
      vim.notify("AI suggestions not enabled. Set enable_ai = true in config.", vim.log.levels.WARN)
    end
  end, { 
    desc = "Test AI tag suggestions"
  })
  
  -- Auto-suggest when entering tags section (if enabled)
  if config.auto_suggest then
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "*.md",
      callback = function()
        -- TODO: Detect when cursor enters tags section and show suggestions
      end,
    })
  end
end

return M