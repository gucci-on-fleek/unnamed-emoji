<!-- unnamed-emoji
     https://github.com/gucci-on-fleek/unnamed-emoji
     SPDX-License-Identifier: MPL-2.0+ OR CC-BY-SA-4.0+
     SPDX-FileCopyrightText: 2023 Max Chernoff
-->

# `unnamed-emoji`

An experimental emoji package for (La)TeX. Name to be chosen later. Not
very polished yet, but mostly functional.

See
[the manual](https://github.com/gucci-on-fleek/unnamed-emoji/releases/latest/download/unnamed-emoji.pdf)
for complete usage details or the
[font specimens](https://github.com/gucci-on-fleek/unnamed-emoji/releases/latest/download/unnamed-emoji-specimens.pdf)
for a full listing of fonts and characters.

## Features

- Directly supports pdfLaTeX, LuaLaTeX, Plain pdfTeX, and Plain LuaTeX.

- Supports XeLaTeX, Plain XeTeX, and any TeX engine with `dvipdfmx`,
  provided that you use a [patched version of
  `dvipdfmx`](dvipdfmx.patch).

- Only needs a single PDF file per font to supply all characters. And
  all the required metadata is in the PDF file itself, so no additional
  files are needed.

- Only includes a single copy of each character in your document no
  matter how many times you use it, so your documents are kept small.

- Subsets the font when you include it, which also keeps your documents
  small.

- Doesn't need shell escape or any external tools.

- Adds fairly little overhead, so compile times are kept fast.

- All characters are properly Unicode-encoded, so you can copy-and-paste
  them from your compiled documents, even with pdfTeX.

- Supports ligated/composed emoji.

- Currently includes Noto Emoji (3458 characters), Twemoji (3689
  characters), FxEmoji (979 characters), OpenMoji (4094 characters), and
  EmojiOne (1832 characters), for a total of 14 052 characters. And more
  fonts can be easily added.

## Examples

### LaTeX
```latex
\documentclass{article}

\usepackage{unnamed-emoji}

\begin{document}
    Duck \emoji{duck} another \emoji{1f986} again \emoji{129414}.

    Manually select a font: \emoji[twemoji]{duck}.

    % LuaTeX-only
    Duck \emoji{🦆}.
\end{document}
```

### Plain TeX
```tex
\input unnamed-emoji

Duck \emoji{duck} another \emoji{1f986} again \emoji{129414}.

Manually select a font: {\def\emojifont{twemoji}\emoji{duck}}.

% LuaTeX-only
Duck \emoji{🦆}.

\bye
```

## Missing features

- No support for direct Unicode input with pdfTeX. This should also be
  fixable.

- Size changing doesn't work quite yet.

## Generating the PDF-fonts

_(Advanced users only)_

Make sure that `qpdf` and ConTeXt LMTX are installed. Next, uncomment
the definition of `lpdf.registerfontmethod` in the ConTeXt base file
`lpdf-emb.lmt`.

Then, run the following command:

```sh
./svg-to-pdf.cld --in=/path/to/svg/files/ --font=font --result=output-name
```

## Patching `dvipdfmx`

```sh
git clone --depth 1 https://github.com/TeX-Live/texlive-source.git
cd texlive-source
git apply /path/to/unnamed-emoji/dvipdfmx.patch
mkdir Work && cd Work
../configure --disable-all-pkgs --enable-dvipdfm-x
sudo cp -f texk/dvipdfm-x/xdvipdfmx "$(kpsewhich --var-value=SELFAUTOLOC)/xdvipdfmx"
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
