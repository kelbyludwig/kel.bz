![](https://raw.githubusercontent.com/cntrump/hugo-notepadium/master/images/screenshot.png)

# hugo-notepadium ![](https://img.shields.io/badge/license-MIT-blue.svg) [![Netlify Status](https://api.netlify.com/api/v1/badges/2f389751-e070-437b-9dbd-3773bd57322e/deploy-status)](https://lvv.me)

Request Hugo Version: [0.60.0+](https://github.com/gohugoio/hugo/releases/)

a fast [gohugo](https://gohugo.io) theme, **100% JavaScript-free**.

Features

- Logo and slogan
- Navigation items
- Syntanx highlighting
- Math by MathJax
- Comments by Disqus
- CC License
- Builtin `Source Code Pro` font for code

Preview the exampleSite:

```shell
git clone https://github.com/cntrump/hugo-notepadium.git hugo-notepadium
cd hugo-notepadium/exampleSite
hugo server --themesDir ../..
```

## Quick Start

```shell
git submodule add https://github.com/cntrump/hugo-notepadium.git themes/hugo-notepadium
```

Example `config.toml`:

```toml
baseURL = "https://example.com"
title = "Notepadium"
theme = "hugo-notepadium"
copyright = "©2019 Notepadium."

languageCode = "zh-cn"
hasCJKLanguage = true

enableRobotsTXT = true

# Enable Disqus
# disqusShortname = "XXX"

[markup.highlight]
codeFences = true
noClasses = false

[markup.goldmark.renderer]
unsafe = true  # enable raw HTML in Markdown

[params]
logo = ""  # if you have a logo png
slogan = "100% JavaScript-free"
license = ""  # CC License

[params.MathJax]
url = ""  # builtin: "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.6/MathJax.js?config=TeX-AMS-MML_HTMLorMML"

[params.syntax]
use = "none"  # builtin: "prismjs", "hljs". "none" means Chroma
theme = "dracula"
webFonts = true  # builtin: 'Source Code Pro'

[params.nav]
showCategories = true       # /categories/
showTags = true             # /tags/

# custom navigation items

[[params.nav.custom]]
title = "About"
url = "/about"

[[params.nav.custom]]
title = "Hugo"
url = "https://gohugo.io/"
```

### Logo and Slogan

```toml
[params]
logo = "/img/logo.png"
slogan = "code my life ~"
```

### Navigation items

```toml
[params.nav]
showCategories = true       # /categories/
showTags = true             # /tags/

# custom items

[[params.nav.custom]]
title = "iOS"
url = "/tags/ios"

[[params.nav.custom]]
title = "Hugo"
url = "https://gohugo.io/"

```

### Syntax highlighting:

```toml
# enable JS highlight
[params.syntax]
use = "hljs"  # 1. prismjs 2. hljs 3. none
theme = "dracula"
webFonts = true  # use builtin font: Source Code Pro
```

### Math by MathJax

```toml
[params.MathJax]
enable = true  # true means globally, or on a per page set "math = true"
url = ""  # builtin CDN: "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.6/MathJax.js?config=TeX-AMS-MML_HTMLorMML"
```

Usage

```
When $a \ne 0$, there are two solutions to \(ax^2 + bx + c = 0\) and they are
$$x = {-b \pm \sqrt{b^2-4ac} \over 2a}.$$
```

### Comments by Disqus

Setup Disqus [shortname](https://help.disqus.com/en/articles/1717111-what-s-a-shortname) in config.toml:

```toml
# disqus
disqusShortname = "XXX"  # your short name
```

By default, comments is disabled for all posts.

You can enable comments like below:

```md
+++
title = "..."
date = 2019-12-08
...
comments = true
+++

...
```

## Thanks

- [**Hugo**](https://gohugo.io/)
- [**HighlightJS**](https://highlightjs.org/)
- [**PrismJS**](https://prismjs.com/)
- [**MathJax**](https://www.mathjax.org/)
- [**Disqus**](https://disqus.com/)
- [**Source Code Pro**](https://fonts.adobe.com/fonts/source-code-pro)
