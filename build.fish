#!/usr/bin/env fish

read --null --local main_tpl < ./index.html

set --local table_of_contents

set -a table_of_contents "
<header>
    <a class=\"github_link\" href=\"https://github.com/cideM/\">florian beeres</a>
</header>
"

set -a table_of_contents "<ul class=\"toc\">"

# Sort posts by file names, in descending order, using the name of the .md file, which is a date
for f in (find . -name "*.md" | sort -t "/" -k 4 -r)
    # Parse front matter
    set --local front_matter (awk -f ./front_matter.awk $f)

    if test ! (string trim "$front_matter[3]") = "true"
        # Post is set to don't publish, skip
        continue
    end

    set -l date (string trim (string replace -a -r "['\"]" "" $front_matter[2]))
    set -l title (string trim "$front_matter[1]")
    set -l path (string escape --style=url (string lower (string join "_" (string split " " "$title"))))

    set -a table_of_contents "<li>"
    set -a table_of_contents "<a class=\"toc_link\" href=\"/$path.html\">$title</a>"
    set -a table_of_contents "<p class=\"toc_date\">$date</p>"
    set -a table_of_contents "</li>"

    set -l html (pandoc --from markdown --to html $f | string collect)

    # add title and date to post
    # could also do this in the actual posts
    set -p html "<p class=\"post_date\">$date</p>"
    set -p html "<h1 class=\"post_title\">$title</h1>"
    
    set -l tmp (string replace "%%TITLE%%" "$title" "$main_tpl" | string collect)
    string replace "%%CONTENT%%" "$html" "$tmp" > "./public/$path.html"
end

set -a table_of_contents "</ul>"

string replace\
    "%%CONTENT%%"\
    (string join \n $table_of_contents | string collect)\
    $main_tpl > "./public/index.html"

sed -i 's/%%TITLE%%/fbrs/' ./public/index.html

cp ./styles.css public
