local M = {}

-- OpenAI API configuration
local openai_config = {
  api_key = nil,
  model = "gpt-3.5-turbo",
  max_tokens = 150,
  temperature = 0.3,
}

-- Function to make HTTP request to OpenAI API
local function make_openai_request(prompt)
  if not openai_config.api_key then
    return nil, "OpenAI API key not configured"
  end
  
  local curl = vim.fn.system({
    "curl", "-s", "-X", "POST",
    "https://api.openai.com/v1/chat/completions",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. openai_config.api_key,
    "-d", vim.json.encode({
      model = openai_config.model,
      messages = {
        {
          role = "system",
          content = "You are a helpful assistant that suggests relevant tags for markdown notes. You should suggest 3-5 tags that are specific, relevant, and follow common tagging conventions. Return ONLY the tags as a JSON array of strings, with no additional formatting, code blocks, or explanation. Example: [\"tag1\", \"tag2\", \"tag3\"]"
        },
        {
          role = "user",
          content = prompt
        }
      },
      max_tokens = openai_config.max_tokens,
      temperature = openai_config.temperature,
    })
  })
  
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to make API request: " .. curl
  end
  
  local success, response = pcall(vim.json.decode, curl)
  if not success then
    return nil, "Failed to parse API response: " .. curl
  end
  
  if response.error then
    return nil, "OpenAI API error: " .. response.error.message
  end
  
  if not response.choices or not response.choices[1] or not response.choices[1].message then
    return nil, "Unexpected API response format"
  end
  
  local content = response.choices[1].message.content
  local success2, tags = pcall(vim.json.decode, content)
  if not success2 then
    -- Try to extract JSON from code blocks or clean up the response
    local cleaned_content = content
    -- Remove markdown code blocks
    cleaned_content = cleaned_content:gsub("```json%s*", ""):gsub("```%s*", "")
    -- Remove any leading/trailing whitespace
    cleaned_content = cleaned_content:gsub("^%s+", ""):gsub("%s+$", "")
    
    success2, tags = pcall(vim.json.decode, cleaned_content)
    if not success2 then
      return nil, "Failed to parse tags from response: " .. content
    end
  end
  
  if type(tags) ~= "table" then
    return nil, "Expected array of tags, got: " .. type(tags)
  end
  
  return tags
end

-- Function to extract note content for AI analysis
local function extract_note_content_for_ai(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
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
  
  return table.concat(content_lines, "\n")
end

-- Function to get existing tags from directory for context
local function get_existing_tags_context(dir_path)
  local files = {}
  local handle = io.popen(string.format('find "%s" -maxdepth 1 -name "*.md" -type f', dir_path))
  if handle then
    for file in handle:lines() do
      table.insert(files, file)
    end
    handle:close()
  end
  
  local all_tags = {}
  for _, file_path in ipairs(files) do
    local file = io.open(file_path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      -- Extract YAML frontmatter
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
      
      local yaml_content = table.concat(yaml_lines, "\n")
      
      -- Extract tags
      local in_tags_section = false
      for _, line in ipairs(yaml_lines) do
        if line:match("^tags:") then
          in_tags_section = true
        elseif in_tags_section and line:match("^%s*-%s+(.+)") then
          local tag = line:match("^%s*-%s+(.+)")
          if tag then
            table.insert(all_tags, tag)
          end
        elseif in_tags_section and not line:match("^%s*-") and line:match("^%s*%w") then
          in_tags_section = false
        end
      end
    end
  end
  
  -- Count tag frequencies
  local tag_counts = {}
  for _, tag in ipairs(all_tags) do
    tag_counts[tag] = (tag_counts[tag] or 0) + 1
  end
  
  return tag_counts
end

-- Function to generate AI-powered tag suggestions
function M.generate_ai_suggestions(file_path)
  local note_content = extract_note_content_for_ai(file_path)
  if not note_content or #note_content:gsub("%s+", "") == 0 then
    return nil, "No content found in note"
  end
  
  local dir_path = vim.fn.fnamemodify(file_path, ":h")
  local existing_tags = get_existing_tags_context(dir_path)
  
  -- Build context about existing tags
  local existing_tags_text = ""
  if next(existing_tags) then
    local tag_list = {}
    for tag, count in pairs(existing_tags) do
      table.insert(tag_list, string.format("%s (%d times)", tag, count))
    end
    existing_tags_text = "Existing tags in this directory: " .. table.concat(tag_list, ", ") .. "\n\n"
  end
  
  -- Create the prompt for OpenAI
  local prompt = string.format([[
%sNote content:
%s

Please suggest 3-5 relevant tags for this note. Consider the existing tags in the directory and suggest tags that would be useful for organizing and finding this note. The tags should be specific, relevant, and follow common tagging conventions.
]], existing_tags_text, note_content)
  
  local tags, error = make_openai_request(prompt)
  if error then
    return nil, error
  end
  
  return tags
end

-- Function to set OpenAI API key
function M.set_api_key(api_key)
  openai_config.api_key = api_key
end

-- Function to configure OpenAI settings
function M.configure_openai(opts)
  openai_config = vim.tbl_deep_extend("force", openai_config, opts or {})
end

return M