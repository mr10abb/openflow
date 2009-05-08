# -*- autoconf -*-

# Copyright (c) 2008, 2009 The Board of Trustees of The Leland Stanford
# Junior University
#
# We are making the OpenFlow specification and associated documentation
# (Software) available for public use and benefit with the expectation
# that others will use, modify and enhance the Software and contribute
# those enhancements back to the community. However, since we would
# like to make the Software available for broadest use, with as few
# restrictions as possible permission is hereby granted, free of
# charge, to any person obtaining a copy of this Software to deal in
# the Software under the copyrights without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# The name and trademarks of copyright holder(s) may NOT be used in
# advertising or publicity pertaining to the Software or any
# derivatives without specific, written prior permission.

dnl OFP_CHECK_LINUX(OPTION, VERSION, VARIABLE, CONDITIONAL)
dnl
dnl Configure linux kernel source tree 
AC_DEFUN([OFP_CHECK_LINUX], [
  AC_ARG_WITH([$1],
              [AC_HELP_STRING([--with-$1=/path/to/linux-$2],
                              [Specify the linux $2 kernel sources])],
              [path="$withval"], [path=])dnl
  if test -n "$path"; then
    path=`eval echo "$path"`

    AC_MSG_CHECKING([for $path directory])
    if test -d "$path"; then
	AC_MSG_RESULT([yes])
	$3=$path
	AC_SUBST($3)
    else
	AC_MSG_RESULT([no])
	AC_ERROR([source dir $path doesn't exist])
    fi

    AC_MSG_CHECKING([for $path kernel version])
    patchlevel=`sed -n 's/^PATCHLEVEL = //p' "$path/Makefile"`
    sublevel=`sed -n 's/^SUBLEVEL = //p' "$path/Makefile"`
    AC_MSG_RESULT([2.$patchlevel.$sublevel])
    if test "2.$patchlevel" != '$2'; then
       AC_ERROR([Linux kernel source in $path is not version $2])
    fi
    if ! test -e "$path"/include/linux/version.h || \
       ! test -e "$path"/include/linux/autoconf.h; then
	AC_MSG_ERROR([Linux kernel source in $path is not configured])
    fi
    m4_if($2, [2.6], [OFP_CHECK_LINUX26_COMPAT])
  fi
  AM_CONDITIONAL($4, test -n "$path")
])

dnl OFP_GREP_IFELSE(FILE, REGEX, IF-MATCH, IF-NO-MATCH)
dnl
dnl Greps FILE for REGEX.  If it matches, runs IF-MATCH, otherwise IF-NO-MATCH.
AC_DEFUN([OFP_GREP_IFELSE], [
  AC_MSG_CHECKING([whether $2 matches in $1])
  grep '$2' $1 >/dev/null 2>&1
  status=$?
  case $status in
    0) 
      AC_MSG_RESULT([yes])
      $3
      ;;
    1) 
      AC_MSG_RESULT([no])
      $4
      ;;
    *) 
      AC_MSG_ERROR([grep exited with status $status]) 
      ;;
  esac
])

dnl OFP_DEFINE(NAME)
dnl
dnl Defines NAME to 1 in kcompat.h.
AC_DEFUN([OFP_DEFINE], [
  echo '#define $1 1' >> datapath/linux-2.6/kcompat.h.new
])

AC_DEFUN([OFP_CHECK_VETH], [
  AC_MSG_CHECKING([whether to build veth module])
  if test "$sublevel" = 18; then
    AC_MSG_RESULT([yes])
    AC_SUBST([BUILD_VETH], 1)
  else
    AC_MSG_RESULT([no])
  fi
])

dnl OFP_CHECK_LINUX26_COMPAT
dnl
dnl Runs various Autoconf checks on the Linux 2.6 kernel source in
dnl the directory in $KSRC26.
AC_DEFUN([OFP_CHECK_LINUX26_COMPAT], [
  rm -f datapath/linux-2.6/kcompat.h.new
  mkdir -p datapath/linux-2.6
  : > datapath/linux-2.6/kcompat.h.new
  OFP_GREP_IFELSE([$KSRC26/include/linux/skbuff.h], [skb_transport_header],
                  [OFP_DEFINE([HAVE_SKBUFF_HEADER_HELPERS])])
  OFP_GREP_IFELSE([$KSRC26/include/linux/skbuff.h], [raw],
                  [OFP_DEFINE([HAVE_MAC_RAW])])
  OFP_GREP_IFELSE([$KSRC26/include/linux/skbuff.h], 
                  [skb_copy_from_linear_data_offset],
                  [OFP_DEFINE([HAVE_SKB_COPY_FROM_LINEAR_DATA_OFFSET])])
  OFP_GREP_IFELSE([$KSRC26/include/net/netlink.h], [NLA_NUL_STRING],
                  [OFP_DEFINE([HAVE_NLA_NUL_STRING])])
  OFP_CHECK_VETH
  if cmp -s datapath/linux-2.6/kcompat.h.new \
            datapath/linux-2.6/kcompat.h >/dev/null 2>&1; then
    rm datapath/linux-2.6/kcompat.h.new
  else
    mv datapath/linux-2.6/kcompat.h.new datapath/linux-2.6/kcompat.h
  fi
])

dnl Checks for --enable-hw-tables and substitutes HW_TABLES to any
dnl requested hardware table modules.
AC_DEFUN([OFP_CHECK_HWTABLES],
  [AC_ARG_ENABLE(
     [hw-tables],
     [AC_HELP_STRING([--enable-hw-tables=MODULE...],
                     [Configure and build the specified externally supplied 
                      hardware table support modules])])
   case "${enable_hw_tables}" in # (
     yes) 
       AC_MSG_ERROR([--enable-hw-tables has a required argument])
       ;; # (
     ''|no) 
       hw_tables=
       ;; # (
     *) 
       hw_tables=`echo "$enable_hw_tables" | sed 's/,/ /g'`
       ;;
   esac
   for d in $hw_tables; do
       mk=datapath/hwtable_$d/Modules.mk
       if test ! -e $srcdir/$mk; then
          AC_MSG_ERROR([--enable-hw-tables=$d specified but $mk is missing])
       fi
       HW_TABLES="$HW_TABLES \$(top_srcdir)/$mk"
   done
   AC_SUBST(HW_TABLES)])

dnl Checks for net/if_packet.h.
AC_DEFUN([OFP_CHECK_IF_PACKET],
  [AC_CHECK_HEADER([net/if_packet.h],
                   [HAVE_IF_PACKET=yes],
                   [HAVE_IF_PACKET=no])
   AM_CONDITIONAL([HAVE_IF_PACKET], [test "$HAVE_IF_PACKET" = yes])
   if test "$HAVE_IF_PACKET" = yes; then
      AC_DEFINE([HAVE_IF_PACKET], [1],
                [Define to 1 if net/if_packet.h is available.])
   fi])

dnl Enable OpenFlow extension submodule.
AC_DEFUN([OFP_ENABLE_EXT],
  [AC_ARG_ENABLE([ext],
     AS_HELP_STRING([--enable-ext], 
                    [use OpenFlow extensions
                     (default is yes if "ext" dir exists)]))
   case "${enable_ext}" in
     (yes)
       HAVE_EXT=yes
       ;;
     (no)
       HAVE_EXT=no
       ;;
     (*)
       if test -e "$srcdir/ext/automake.mk"; then
         HAVE_EXT=yes
       else
         HAVE_EXT=no
       fi
       ;;
   esac
   if test $HAVE_EXT = yes; then
     if test -e "$srcdir/ext/automake.mk"; then
       :
     else
       AC_MSG_ERROR([cannot configure extensions without "ext" directory])
     fi
     AC_DEFINE([HAVE_EXT], [1], 
               [Whether the OpenFlow extensions submodule is available])
   fi
   AM_CONDITIONAL([HAVE_EXT], [test $HAVE_EXT = yes])])

dnl Checks for dpkg-buildpackage.  If this is available then we check
dnl that the Debian packaging is functional at "make distcheck" time.
AC_DEFUN([OFP_CHECK_DPKG_BUILDPACKAGE],
  [AC_CHECK_PROG([HAVE_DPKG_BUILDPACKAGE], [dpkg-buildpackage], [yes], [no])
   AM_CONDITIONAL([HAVE_DPKG_BUILDPACKAGE], 
                  [test $HAVE_DPKG_BUILDPACKAGE = yes])])

dnl ----------------------------------------------------------------------
dnl These macros are from GNU PSPP, with the following original license:
dnl Copyright (C) 2005, 2006, 2007 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl OFP_CHECK_CC_OPTION([OPTION], [ACTION-IF-ACCEPTED], [ACTION-IF-REJECTED])
dnl Check whether the given C compiler OPTION is accepted.
dnl If so, execute ACTION-IF-ACCEPTED, otherwise ACTION-IF-REJECTED.
AC_DEFUN([OFP_CHECK_CC_OPTION],
[
  m4_define([ofp_cv_name], [ofp_cv_[]m4_translit([$1], [-], [_])])dnl
  AC_CACHE_CHECK([whether $CC accepts $1], [ofp_cv_name], 
    [ofp_save_CFLAGS="$CFLAGS"
     CFLAGS="$CFLAGS $1"
     AC_COMPILE_IFELSE([AC_LANG_PROGRAM(,)], [ofp_cv_name[]=yes], [ofp_cv_name[]=no])
     CFLAGS="$ofp_save_CFLAGS"])
  if test $ofp_cv_name = yes; then
    m4_if([$2], [], [;], [$2])
  else
    m4_if([$3], [], [:], [$3])
  fi
])

dnl OFP_ENABLE_OPTION([OPTION])
dnl Check whether the given C compiler OPTION is accepted.
dnl If so, add it to CFLAGS.
dnl Example: OFP_ENABLE_OPTION([-Wdeclaration-after-statement])
AC_DEFUN([OFP_ENABLE_OPTION], 
  [OFP_CHECK_CC_OPTION([$1], [CFLAGS="$CFLAGS $1"])])
dnl ----------------------------------------------------------------------
