#!/bin/sh

# Use HTML_SKELETON_PRE and HTML_SKELETON_POST to generate an HTML page, where
# the content goes between both templates. I couldn't get this to work by
# specifying a variable %%CONTENT%% and then replacing it with awk or sed,
# since the replacement contains lots of scary HTML with weird, unescaped
# characters. Doing it like that feels like cheating but it gets the job done
# and doesn't require me to dive into the specifics of quoting and escaping in
# various shell programs.
HTML_SKELETON_PRE='
<!doctype html>

<html lang="en">
<head>
  <meta charset="utf-8">

  <title>%%TITLE%%</title>
  <meta name="description" content="fbrs.io">
  <meta name="author" content="Florian Beeres">
  <meta http-equiv="x-ua-compatible" content="ie=edge" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />

  <link rel="stylesheet" href="styles.css">

</head>

<body>'

# Start of table of contents
TOC='
<header>
    <a class="github_link" href="https://github.com/cideM/">florian beeres</a>
</header>
<ul class="toc">'

HTML_SKELETON_POST='
</body>
</html>'

# Sort posts by date from frontmatter, in descending order. Print the filename
# as well, so I can sort filenames through the dates I got from the
# frontmatter. It's important that filename and frontmatter are on the same
# line for this. The echo '|' is used so I can easily split each line into its
# individual parts.
# Here's what the multiline pipeline does:
# 1. Read lines between --- and --- (frontmatter)
# 2. Remove first and last line, so remove the fences "---"
# 3. Split each line on : and print the 2nd part
# 4. Remove the preceding whitespace
# 5. Read the consecutive lines and add | in front of every line
# 6. Replace newlines with space, turning the multilines into foo|bar|bax
SORTED_WITH_FRONT_MATTER=$(\
for f in posts/*.md
do
    front_matter=$(\
    sed -n -e '/^---$/,/^---$/p' "$f"\
        | sed '1d;$d'\
        | awk -F':' '{print $2}'\
        | sed 's/^ *//'\
        | while read -r n; do printf '|%s' "$n"; done\
        | tr '\n' ' '\
    )
    printf '%s%s\n' "$f" "$front_matter"
done | sort -t '|' -r -k 3)

# Here's the standard POSIX way of looping over a multiline string in a
# variable:
# echo "$variable" | while IFS= read -r line ; do echo $line; done
# Use this to loop over the file
while IFS= read -r f ; do
    publish=$(echo "$f" | awk -F'|' '{ print $4 }')

    if [ "$publish" = "false" ]
    then
        continue
    fi

    post_date=$(echo "$f" | awk -F'|' '{ print $3 }')
    post_title=$(echo "$f" | awk -F'|' '{ print $2 }')
    file_in=$(echo "$f" | awk -F'|' '{ print $1 }')
    file_out="$(echo "$file_in" | sed 's/posts//' | sed 's/.md//')".html

    TOC="$TOC
    <li>"
    TOC="$TOC
        <a class=\"toc_link\" href=\"$file_out\">$post_title</a>"
    TOC="$TOC
        <p class=\"toc_date\">$post_date</p>"
    TOC="$TOC
    </li>"

    post=$(pandoc --from markdown --to html "$file_in")

    post="<p class=\"post_date\">$post_date</p>$post"
    post="<h1 class=\"post_title\">$post_title</h1>$post"
    post="<a href="index.html">back</a>$post"
    pre_with_title=$(echo "$HTML_SKELETON_PRE" | sed "s/%%TITLE%%/$post_title/")

    # Couldn't easily do this with sed since the replacement string needs to be
    # escaped
    printf "%s" "$pre_with_title" > ./public/"$file_out" 
    printf "%s" "$post" >> ./public/"$file_out"
    echo "$HTML_SKELETON_POST" >> ./public/"$file_out"

done <<EOF
$SORTED_WITH_FRONT_MATTER
EOF
# ^ Use HERE document instead of piping echo so it's not executed in subshell,
# since then the variable assignments are local to the loop

# Finish table of contents
TOC="$TOC
</ul>"

echo "$HTML_SKELETON_PRE" | sed "s/%%TITLE%%/fbrs/" > ./public/index.html
printf "%s" "$TOC" >> ./public/index.html
echo "$HTML_SKELETON_POST" >>  ./public/index.html

cp ./styles.css public
