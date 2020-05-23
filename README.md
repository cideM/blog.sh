# Fish, AWK, Pandoc

## Requirements

- Fish shell
- Pandoc

## How

The `build.fish` script finds and sorts all `.md` files. It then transforms each post into HTML with Pandoc. Additionally, the front matter is used to add entries to the landing page. `deploy.fish` uses the Netlify Rest API to deploy a `.zip` file containing the static assets from `public/`

Inspired by [kisslinux/website](https://github.com/kisslinux/website)
