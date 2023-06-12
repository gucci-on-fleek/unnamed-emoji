<!-- unnamed-emoji
     https://github.com/gucci-on-fleek/unnamed-emoji
     SPDX-License-Identifier: MPL-2.0+ OR CC-BY-SA-4.0+
     SPDX-FileCopyrightText: 2023 Max Chernoff
-->

# `unnamed-emoji`

An experimental emoji package for (La)TeX. Name to be chosen later. Not
very polished yet, but mostly functional.

## Features

- Directly supports pdfLaTeX, LuaLaTeX, Plain pdfTeX, and Plain LuaTeX.

- Supports XeLaTeX, Plain XeTeX, and `dvipdfmx` with a [patched version of
  `dvipdfmx`](dvipdfmx.patch).

- Only needs a single PDF file (2.9 MB) to supply all characters. And
  all the required metadata is in the PDF file itself, so no additional
  files are needed.

- Only includes a single copy of each character in your document no
  matter how many times you use it, so your documents are kept small.

- Subsets the font when you include it, which also keeps your documents
  small.

- Doesn't need shell escape or any external tools.

- Adds fairly little overhead, so compile times are kept fast.

- Easily extensible to include more fonts.

- All characters are properly Unicode-encoded, so you can copy-and-paste
  them from your compiled documents, even with pdfTeX.

## Examples

### LaTeX
```latex
\documentclass{article}

\usepackage{unnamed-emoji}

\begin{document}
    Duck \emoji{duck} another \emoji{1f986} again \emoji{129414}.

    Manually select a font: \emoji[noto-emoji.pdf]{duck}.

    % LuaTeX-only
    Duck \emoji{🦆}.
\end{document}
```

### Plain TeX
```tex
\input unnamed-emoji

Duck \emoji{duck} another \emoji{1f986} again \emoji{129414}.

Manually select a font: {\def\emojifont{noto-emoji.pdf}\emoji{duck}}.

% LuaTeX-only
Duck \emoji{🦆}.

\bye
```

## Missing features

- Ligated/composed emoji are not currently supported, but this should be
  fairly simple to fix.

- No support for direct Unicode input with pdfTeX. This should also be
  fixable.

## Generating the PDF-fonts

Make sure that `qpdf` and ConTeXt LMTX are installed. Next, uncomment
the definition of `lpdf.registerfontmethod` in the ConTeXt base file
`lpdf-emb.lmt`.

Then, run the following command:

```sh
./svg-to-pdf.cld --in=/path/to/svg/files/ --result=output-name
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

The file `noto-emoji.pdf` is probably licensed under the [_Apache
License_, version
2.0](https://github.com/googlefonts/noto-emoji/blob/934a570/LICENSE),
but it might be licenced under the [_SIL Open Font License_, version
1.1](https://github.com/googlefonts/noto-emoji/blob/934a570/fonts/LICENSE).
The situation is a little ambiguous, but either licence should be
permissive enough for most situations.
