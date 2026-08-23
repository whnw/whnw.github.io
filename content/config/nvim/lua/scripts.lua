local function split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

local function extract_diff_lines(diff_output)
    local line_changes = {}

    for line in diff_output:gmatch("[^\r\n]+") do
        if line:find("@@") then
            local parts = split(line, " ")

            if #parts >= 3 then
                local new_info = split(parts[3], ",")

                local new_start = tonumber(new_info[1]:sub(2)) -- 去掉加号
                local new_count = tonumber(new_info[2]) or 1 -- 默认数量为1

                -- 存储每个新代码块的起始行和行数
                print(string.format("Extracted change: start=%d, count=%d", new_start, new_count))
                table.insert(line_changes, {start = new_start, count = new_count})
            end
        end
    end

    return line_changes
end

function format_git_diff()
    local filepath = vim.fn.expand("%:p")
    local handle = io.popen("git diff --unified=0 " .. filepath)
    local result = handle:read("*a")
    handle:close()

    local line_changes = extract_diff_lines(result)

    if #line_changes == 0 then
        print("No changes found in the current file.")
        return
    end

    for i = #line_changes, 1, -1 do
        local change = line_changes[i]
        local start_line = change.start
        local end_line = start_line + change.count - 1

        -- 输出调试信息
        print(string.format("Formatting lines from %d to %d", start_line, end_line))

        -- 选中并格式化每个代码块
        vim.cmd(string.format("normal! %dG", start_line))
        vim.cmd(string.format("normal! V%dG", end_line))
        vim.cmd("normal! gq")
    end
end

vim.api.nvim_set_keymap("n", "<leader>fa", ":lua format_git_diff()<CR>", {noremap = true, silent = false})

