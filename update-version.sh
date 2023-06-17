#!/bin/sh

# unnamed-emoji
# https://github.com/gucci-on-fleek/unnamed-emoji
# SPDX-License-Identifier: MPL-2.0+
# SPDX-FileCopyrightText: 2023 Max Chernoff

git ls-files ':!:*.pdf' ':!:texmf' | xargs sed -i "/%%[v]ersion/ s/[[:digit:]]\.[[:digit:]]\.[[:digit:]]/$1/"

git ls-files ':!:*.pdf' ':!:texmf' | xargs sed -Ei "/%%[d]ashdate/ s/[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}/$(date -I)/"

git ls-files ':!:*.pdf' ':!:texmf' | xargs sed -Ei "/%%[s]lashdate/ s|[[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2}|$(date +%Y/%m/%d)|"
