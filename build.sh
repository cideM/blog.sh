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

POSTS_SORTED=$(\
for f in posts/*/date
do
    printf '%s|%s\n' "$f" $(cat $f)
done | sort -t '|' -r -k 2 | cut -d '|' -f 1 | xargs dirname)

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

    post_date=$(cat "$f"/date)
    post_title=$(cat "$f"/title)
    file_out="$(basename "$f")".html

    TOC="$TOC
    <li>"
    TOC="$TOC
        <a class=\"toc_link\" href=\"$file_out\">$post_title</a>"
    TOC="$TOC
        <p class=\"toc_date\">$post_date</p>"
    TOC="$TOC
    </li>"

    post=$(pandoc --from markdown --to html "$f"/content)

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
$POSTS_SORTED
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
