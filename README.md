<!-- unnamed-emoji
     https://github.com/gucci-on-fleek/unnamed-emoji
     SPDX-License-Identifier: MPL-2.0+ OR CC-BY-SA-4.0+
     SPDX-FileCopyrightText: 2023 Max Chernoff
-->

# `unnamed-emoji`

Unnamed-emoji is an emoji package for LaTeX, ConTeXt, Plain TeX, and OpTeX.
It natively supports pdfTeX and LuaTeX, and (with a patch) supports
XeTeX and any other TeX engine using `dvipdfmx`.

See
[the manual](https://github.com/gucci-on-fleek/unnamed-emoji/releases/latest/download/unnamed-emoji-manual.pdf)
for complete usage details or the
[font specimens](https://github.com/gucci-on-fleek/unnamed-emoji/releases/latest/download/unnamed-emoji-specimens.pdf)
for a full listing of fonts and characters.

[Download the latest release (TDS `.zip` archive)](https://github.com/gucci-on-fleek/unnamed-emoji/releases/latest/download/unnamed-emoji.tds.zip)

## Example

```latex
\documentclass{article}
\usepackage{unnamed-emoji}

\begin{document}
    \emoji{goose}          \emoji{🦢}
    \emoji[openmoji]{duck} \emoji{0x1f427}
\end{document}
```

## Licence

Most files should list their licence near the top. In general, the code
is licensed under the [_Mozilla Public License_, version
2.0](https://www.mozilla.org/en-US/MPL/2.0/) or greater. The
documentation is additionally licensed under [CC-BY-SA, version
4.0](https://creativecommons.org/licenses/by-sa/4.0/legalcode) or
greater.

### `noto-emoji.pdf`

`noto-emoji.pdf` (“Noto Emoji”) was created from the `svg/` folder of
[`googlefonts/noto-emoji@934a5706`](https://github.com/googlefonts/noto-emoji/tree/934a5706)
and is licensed under the [_Apache License_, version
2.0](https://github.com/googlefonts/noto-emoji/blob/934a5706/LICENSE).

The flags in `noto-emoji.pdf` were derived from the `svg/` folder of
[`fonttools/region-flags@0f2ae1a`](https://github.com/fonttools/region-flags/tree/0f2ae1a)
and are all
[exempt from copyright or in the public domain](https://github.com/fonttools/region-flags/blob/0f2ae1a/COPYING).

### `twemoji.pdf`

`twemoji.pdf` (“Twitter Emoji”) was created from the `assets/svg/`
folder of
[`twitter/twemoji@d94f4cf7`](https://github.com/twitter/twemoji/tree/d94f4cf7)
and is licensed under [CC-BY
4.0](https://github.com/twitter/twemoji/blob/d94f4cf7/LICENSE-GRAPHICS).

### `fxemoji.pdf`

`fxemoji.pdf` (“FxEmojis”) was created from the `svgs/FirefoxEmoji/`
folder of
[`mozilla/fxemoji@270af343`](https://github.com/mozilla/fxemoji/tree/270af343)
and is licensed under [CC-BY
4.0](https://github.com/mozilla/fxemoji/blob/270af343/LICENSE.md).

### `openmoji.pdf`

`openmoji.pdf` (“OpenMoji”) was created from the `color/svg/` folder of
[`hfg-gmuend/openmoji@d6d0daad`](https://github.com/hfg-gmuend/openmoji/tree/d6d0daad)
and is licensed under [CC-BY-SA
4.0](https://github.com/hfg-gmuend/openmoji/blob/d6d0daad/LICENSE.txt).

### `emojione.pdf`

`emojione.pdf` (“EmojiOne”) was created from the `assets/svg/` folder of
[`joypixels/emojione@v2.2.7`](https://github.com/joypixels/emojione/tree/v2.2.7)
and is licensed under [CC-BY
4.0](https://github.com/joypixels/emojione/blob/v2.2.7/LICENSE.md).

### `fluent-flat.pdf`

`fluent-flat.pdf` (“Fluent Emoji”) was created from the
`assets/**/Flat/` folder of
[`microsoft/fluentui-emoji@dfb5c3b7`](https://github.com/microsoft/fluentui-emoji/tree/dfb5c3b7)
and is licensed under the [_MIT License_](https://github.com/microsoft/fluentui-emoji/blob/dfb5c3b7/LICENSE).

### `noto-blob.pdf`

`noto-blob.pdf` (“Noto Emoji”) was created from the `svg/` folder of
[`googlefonts/noto-emoji@8f0a65b1`](https://github.com/googlefonts/noto-emoji/tree/8f0a65b1)
and is licensed under the [_Apache License_, version
2.0](https://github.com/googlefonts/noto-emoji/blob/8f0a65b1/LICENSE).

### Unicode Data

The names used for the emoji were taken from the
`cldr-json/cldr-annotations-*modern/` folder of
[`unicode-org/cldr-json@43.1.0`](https://github.com/unicode-org/cldr-json/tree/43.1.0)
and are licensed under the
[_Unicode Licence Agreement_](https://github.com/unicode-org/cldr-json/blob/43.1.0/LICENSE)
