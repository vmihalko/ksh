########################################################################
#                                                                      #
#              This file is part of the ksh 93u+m package              #
#             Copyright (c) 2024 Contributors to ksh 93u+m             #
#                      and is licensed under the                       #
#                 Eclipse Public License, Version 2.0                  #
#                                                                      #
#                A copy of the License is available at                 #
#      https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.html      #
#         (with md5 checksum 84283fa8859daf213bdda5a9f8d1be1d)         #
#                                                                      #
#                  Martijn Dekker <martijn@inlv.org>                   #
#                                                                      #
########################################################################
#
# MAM dependency rules generator for $INSTALLROOT/include/ast headers
# By Martijn Dekker <martijn@inlv.org>, 2024-07-15
#
# Greps preinstalled AST header files for '#include <foo.h>' to generate header
# dependency rules for a library. The 'bind' command in mamake(1) Mamfiles will
# automatically include the generated dependencies in its current rule context.
#
# Usage: mkdeps -lLIBRARYNAME [ -lDEPENDNECYNAME ... ] [ HEADER.h ... ]
# The first -l option's argument is the short name of the library to be processed.
# The second and further -l options indicate its library header dependencies.
#
# This sh script is POSIX compliant and compatible with shell bugs.
#

# POSIX-ish standard mode where available.
case ${ZSH_VERSION+z} in
z)	emulate ksh ;;
*)	(command set -o posix) 2>/dev/null && set -o posix ;;
esac

# Safe-ish mode.
CCn='
'  # one linefeed
set -o noglob
IFS=$CCn

# === Function definitions ===

note()
{
	printf "$0: %s\\n" "$@" >&2
}

err_out()
{
	note "$@"
	exit 3
}

# Output NAME for each '#include <NAME.h>'
grep_includes()
{
	spc=' 	'  # space followed by tab
	sed -n "s|^[$spc]*#[$spc]*include[$spc]*<\([A-Za-z0-9_]*\)\.h>.*|\1|p" "$1"
}

print_indent()
{
	tabs=
	i=$indent
	while	test "$i" -gt 0
	do	tabs=$tabs'\t'
		i=$((i - 1))
	done
	printf "$tabs%s\n" "$1"
}

make_hdrdeps()
{
	test -f "$1.h" || return  # external header
	eval "state=\${state_$1}"
	case $state in
	making)
		print_indent "note * FIXME: circular dependency: $1.h"
		;;
	made)
		# output a 'prev' (not needed at top level; outdatedness propagates upwards)
		if	test "$indent" -gt 1
		then	print_indent "prev $prefix$1.h"
		fi
		;;
	*)
		# output a 'make' with possible recursive dependent rules
		eval "state_$1=making"
		print_indent "make $prefix$1.h implicit"
		indent=$((indent + 1))
		f=$(grep_includes "$1.h") || exit
		for f in $f
		do	make_hdrdeps "$f"
		done
		indent=$((indent - 1))
		print_indent "done $prefix$1.h"
		eval "state_$1=made"
		;;
	esac
}

# === Initialisation ===

# Parse options.
lib= libdeps=
while getopts 'l:' opt
do	case $opt in
	l)	case $lib in
		'')	lib=$OPTARG ;;
		*)	libdeps=$libdeps${libdeps:+$CCn}$OPTARG ;;
		esac ;;
	*)	exit 2 ;;
	esac
done
shift $((OPTIND - 1))

# Process library header dependencies.
for f in $libdeps
do	test -f "$INSTALLROOT/lib/mam/$f" || error_out "$f: header dependencies not found"
	# assign state_NAME=made for each dependency header, so only prev commands are generated
	f=$(sed -n 's|.*make \${INCLUDE_AST}/\([A-Za-z0-9_]*\)\.h.*|state_\1=made|p' "$INSTALLROOT/lib/mam/$f") || exit
	eval "$f"
done

# Init state.
ast=include/ast
root=${INSTALLROOT?AST environment not initialised}/$ast
prevar="INCLUDE_AST"
prefix="\${$prevar}/"
cd "$root" || error_out "cd '$root' failed"
indent=1

# Validate for 'eval' safety: header file names minus $root and .h must be valid variable name components.
for f
do	test -f "$f" || error_out "$f: not found"
	f=${f#"$root/"}
	case ${f%.h} in
	'' | *[!A-Za-z0-9_]*)
		error_out "$f: invalid header file name" ;;
	esac
done

# === Main ===

echo "note * Library header dependency rules for lib${lib:?option -l is required}."
echo "note * Generated by mkdeps(1). Included in Mamfile by 'bind -l$lib'."
echo "setv $prevar \${INSTALLROOT}/$ast"
# The 'bind' command in mamake(1) checks for the _hdrdeps_lib${lib}_ rule to avoid including dependencies more than once
# (it does a 'prev' instead); if the name of this internal rule is changed here, mamake.c must be changed to match!
wrapper_rule=_hdrdeps_lib${lib}_
echo "make $wrapper_rule virtual"
# Get mamake(1) to recursively include this library's header dependencies.
for f in $libdeps
do	print_indent "bind -l$f"
done
# Generate header dependencies for the headers given at the command line.
for f
do	f=${f#"$root/"}
	make_hdrdeps "${f%.h}"
done
echo "done $wrapper_rule"