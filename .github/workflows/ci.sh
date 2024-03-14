#!/bin/bash
set -eux
set -o pipefail

export TZ=UTC
ulimit -n 1024

COMPILER="${1:?}"
PHASE="${2:?}"

if [[ "$COMPILER" =~ ^CLANG_ ]]; then
    export CC=clang
    export CXX=clang++
fi

case "$PHASE" in
    BUILD|DEFAULT_TESTS|MULTIBYTE_LOCALES_TESTS)
        bin/package make
        case "$PHASE" in
            DEFAULT_TESTS)
            script -q -e -c "bin/package test"
            ;;
            MULTIBYTE_LOCALES_TESTS)
            LANG=nl_NL.UTF-8 script -q -e -c "bin/shtests --locale --nocompile"
            LANG=ja_JP.SJIS  script -q -e -c "bin/shtests --locale --nocompile"
            ;;
        esac
        ;;

    DISABLE_SHOPTS_TESTS)
        sed --regexp-extended --in-place=.orig \
          '/^SHOPT (AUDIT|BGX|BRACEPAT|DEVFD|DYNAMIC|EDPREDICT|ESH|FIXEDARRAY|HISTEXPAND|MULTIBYTE|NAMESPACE|OPTIMIZE|SPAWN|STATS|SUID_EXEC|VSH)=/ s/=1?/=0/' \
          src/cmd/ksh93/SHOPT.sh
       bin/package make
       : default regression tests with SHOPTs disabled
       script -q -e -c "bin/shtests"
       ;;

    SHOPT_SCRIPT_ONLY_TESTS)
        sed --regexp-extended --in-place=.orig \
          '/^SHOPT SCRIPTONLY=/ s/=0?/=1/' \
          src/cmd/ksh93/SHOPT.sh
        bin/package make
        : default regression tests with SHOPT_SCRIPTONLY enabled
        script -q -e -c "bin/shtests"
        ;;
    *)
        echo >&2 "Unknown phase '$PHASE'"
        exit 1
esac
