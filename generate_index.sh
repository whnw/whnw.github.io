#!/bin/bash

# Function to recursively scan directories and generate index
generate_index() {
    local current_dir="$1"
    local indent="$2"

    echo "${indent}<ul>" >> index.html

    # First, process directories
    for entry in "$current_dir"/.* "$current_dir"/*; do
        if [ -d "$entry" ] && [ "$entry" != "$current_dir/." ] && [ "$entry" != "$current_dir/.." ] && [ "$(basename "$entry")" != ".git" ]; then
            # If entry is a directory and not . or .. or .git, add it as a list level menu with folding functionality
            echo "${indent}  <li>" >> index.html
            echo "${indent}    <span class='folder' onclick='toggleFolder(this)'>📁 $(basename "$entry")</span>" >> index.html
            echo "${indent}    <div class='nested'>" >> index.html
            generate_index "$entry" "    $indent"
            echo "${indent}    </div>" >> index.html
            echo "${indent}  </li>" >> index.html
        fi
    done

    # Then, process files
    for entry in "$current_dir"/.* "$current_dir"/*; do
        if [ -f "$entry" ]; then
            # If entry is a file and does not end with .md, add it to the list
            case "$entry" in
                *.md)
                    # Skip markdown files
                    ;;
                *)
                    echo "${indent}  <li><a href=\"$entry\">📄 $(basename "$entry")</a></li>" >> index.html
                    ;;
            esac
        fi
    done

    echo "${indent}</ul>" >> index.html
}

# Starting point of the script
root_dir="."  # You can change this to any directory you want to start from

# Output the HTML header with styles and script for folding and unfolding
cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Index</title>
    <style>
        ul { list-style-type: none; }
        .folder { cursor: pointer; }
        .nested { display: none; }
        .active { display: block; }
        a { text-decoration: none; color: black; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
<h1>Directory Index</h1>
<script>
    function toggleFolder(element) {
        element.parentElement.querySelector(".nested").classList.toggle("active");
    }
</script>
EOF

# 使用 find 命令递归查找所有 .md 文件
find "$root_dir" -type f -name "*.md" | while read -r file; do
    # 获取文件所在目录
    dir=$(dirname "$file")
    
    # 获取文件名（不含扩展名）
    filename=$(basename "$file" .md)
    
    # 使用 pandoc 将 .md 文件转换为 .html 文件，保存在同一目录下
    pandoc "$file" -o "$dir/$filename.html"
    
    # 输出转换结果
    echo "Converted $file to $dir/$filename.html"
done


# Generate the index
generate_index "$root_dir" ""

# Output the HTML footer
cat <<EOF >> index.html
</body>
</html>
EOF
