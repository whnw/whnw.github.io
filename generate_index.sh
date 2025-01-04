#!/bin/bash

# Create or overwrite the index.html file
echo "<!DOCTYPE html>" > index.html
echo "<html lang=\"en\">" >> index.html
echo "<head>" >> index.html
echo "    <meta charset=\"UTF-8\">" >> index.html
echo "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">" >> index.html
echo "    <title>Index of Markdown and Text Files</title>" >> index.html
echo "</head>" >> index.html
echo "<body>" >> index.html
echo "    <h1>Index of Markdown and Text Files</h1>" >> index.html
echo "    <ul>" >> index.html

# Find all .md and .txt files and add them to the index.html file
find . -type f \( -name "*.md" -o -name "*.txt" \) | while read -r file; do
    filename=$(basename "$file")
    echo "        <li><a href=\"$file\">$filename</a></li>" >> index.html
done

echo "    </ul>" >> index.html
echo "</body>" >> index.html
echo "</html>" >> index.html

echo "index.html has been generated successfully."
