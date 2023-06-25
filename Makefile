# unnamed-emoji
# https://github.com/gucci-on-fleek/unnamed-emoji
# SPDX-License-Identifier: MPL-2.0+
# SPDX-FileCopyrightText: 2023 Max Chernoff

# Configuration
.ONESHELL:
.SHELLFLAGS = -euc
export TEXMFHOME = ${CURDIR}/texmf


# Default target
.DEFAULT_GOAL := default
.PHONY: default
default:
	${error Please specify a target.}


# Build the font files
define build_font =
temp="$$(mktemp -d)"
cd "$$temp"

${CURDIR}/source/svg-to-pdf.cld \
	--path=${CURDIR}/source/ \
	--in=${abspath $<} \
	--font=${basename ${notdir $@}} \
	--cldr=${CURDIR}/third-party/cldr-json/
mv ./svg-to-pdf.pdf ${abspath $@}

rm -r "$$temp"
endef

fonts/noto-emoji.pdf: third-party/noto-emoji/svg source/svg-to-pdf.cld
	${build_font}

fonts/twemoji.pdf: third-party/twemoji/assets/svg source/svg-to-pdf.cld
	${build_font}

fonts/fxemoji.pdf: third-party/fxemoji/svgs/FirefoxEmoji
	${build_font}

fonts/openmoji.pdf: third-party/openmoji/color/svg source/svg-to-pdf.cld
	${build_font}

fonts/emojione.pdf: third-party/emojione/assets/svg source/svg-to-pdf.cld
	${build_font}

fonts/fluent-flat.pdf: third-party/fluentui-emoji/assets source/svg-to-pdf.cld
	${build_font}

fonts/noto-blob.pdf: third-party/noto-blob/svg source/svg-to-pdf.cld
	${build_font}

.PHONY: fonts
fonts: fonts/noto-emoji.pdf fonts/twemoji.pdf fonts/fxemoji.pdf fonts/openmoji.pdf fonts/emojione.pdf fonts/fluent-flat.pdf fonts/noto-blob.pdf ;


# Build the manual
documentation/unemoji-manual.pdf: documentation/unemoji-manual.tex
	cd ${dir $<}
	context ${notdir $<}

.PHONY: manual
manual: documentation/unemoji-manual.pdf ;


# Build the specimens
documentation/unemoji-specimens.pdf: documentation/unemoji-specimens.cld
	cd ${dir $<}
	./${notdir $<}

.PHONY: specimens
specimens: documentation/unemoji-specimens.pdf ;


# Bundle the files
.PHONY: bundle
bundle:
	rm -r ${CURDIR}/build/ctan ${CURDIR}/build/*.zip || true
	cd "${CURDIR}/texmf"
	zip -r "${CURDIR}/build/unnamed-emoji.tds.zip" ./*
	mkdir -p "${CURDIR}/build/ctan" && cd "${CURDIR}/build/ctan"
	mkdir -p unnamed-emoji
	find -L "${CURDIR}/texmf" -type f -exec cp '{}' unnamed-emoji \;
	cp "${CURDIR}/build/unnamed-emoji.tds.zip" .
	zip -r "${CURDIR}/build/unnamed-emoji.ctan.zip" ./*


# Update the file versions
version_run := git ls-files ':!:*.pdf' ':!:texmf' ':!:third-party' | xargs sed -Ei

.PHONY: update-version
update-version:
	${version_run} "/%%[v]ersion/ s/[[:digit:]]\.[[:digit:]]\.[[:digit:]]/${VERSION}/"
	${version_run} "/%%[d]ashdate/ s/[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}/$$(date -I)/"
	${version_run} "/%%[s]lashdate/ s|[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}|$$(date +%Y/%m/%d)|"


# Initialize the repository
.PHONY: init
init: .gitmodules_sparse
	git -c include.path=${abspath $^} submodule update --filter=blob:none --depth=1 --init
	sed -i '/registerfontmethod/,+4!b;{s/--/  /}' "$$(kpsewhich lpdf-emb.lmt)"
	context --make
