AC_DEFUN([FW_CHECK_ORACLE],
[
if ( test -z "$ORACLEATRUNTIME" )
then
if ( test "$ENABLE_ORACLE" = "yes" )
then

	ORACLEVERSION=""
	ORACLEINCLUDES=""
	ORACLELIBS=""
	ORACLELIBSPATH=""
	ORACLESTATIC=""
	STATICFLAG=""
	LINKFAIL=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling
		echo "cross compiling"

	else

		AC_MSG_CHECKING(for oracle includes and libraries)

		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi

		if ( test -n "$ORACLE_HOME" )
		then

			dnl use sysliblist if it's there
			SYSLIBLIST="`cat $ORACLE_HOME/lib/sysliblist 2> /dev/null`"
			if ( test ! -n "$SYSLIBLIST" )
			then
				SYSLIBLIST="-lm $AIOLIB"
			fi

			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore4.a],[ORACLEVERSION=\"8.0\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclient -lncr -lcommon -lgeneric -lclntsh -lepcpt -lcore4 -lnlsrtl3 $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore8.a],[ORACLEVERSION=\"8i\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore9.a],[ORACLEVERSION=\"9i\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore10.a],[ORACLEVERSION=\"10g\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore11.a],[ORACLEVERSION=\"11g\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore12.a],[ORACLEVERSION=\"12c\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore18.a],[ORACLEVERSION=\"18c\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libcore19.a],[ORACLEVERSION=\"19c\"; ORACLELIBSPATH=\"$ORACLE_HOME/lib\"; ORACLELIBS=\"-L$ORACLE_HOME/lib -lclntsh $SYSLIBLIST\"])
			FW_CHECK_LIB([$ORACLE_HOME/lib/libclntsh.a],[ORACLESTATIC=\"$STATICFLAG\"])
		fi

		dnl if we didn't find anything yet,
		dnl look for non-RPM-based instantclient
		if ( test -z "$ORACLELIBS" )
		then

			dnl if a prefix wasn't passed in,
			dnl look in some common places
			if ( test -z "$ORACLE_INSTANTCLIENT_PREFIX" )
			then
				for i in \
					"/usr" \
					"/usr/lib" \
					"/usr/local" \
					"/opt"
				do
					INSTCLNT=`ls -d $i/instantclient* 2> /dev/null | tail -1`
					if ( test -n "$INSTCLNT" )
					then
						ORACLE_INSTANTCLIENT_PREFIX=$INSTCLNT
						break
					fi
				done
			fi

			dnl check for 19c/21c-style instantclient
			if ( test -z "$ORACLE_INSTANTCLIENT_PREFIX" )
			then
				for i in `ls -d /u*/app/*/product/*/client* 2> /dev/null`
				do
					if ( test -n "$i/instantclient" )
					then
						ORACLE_INSTANTCLIENT_PREFIX=$i
						break
					fi
				done
			fi

			dnl For some reason libclntsh.so isn't always included
			dnl in the non-RPM versions, so we have to look for and
			dnl use the file with a version number tacked on to the
			dnl end.
			if ( test -n "$ORACLE_INSTANTCLIENT_PREFIX" -a -r "`ls $ORACLE_INSTANTCLIENT_PREFIX/libclntsh.$SOSUFFIX.* 2> /dev/null | tail -1`" -a -r "$ORACLE_INSTANTCLIENT_PREFIX/sdk/include/oci.h" )
			then
				ORACLEVERSION="10g"
				if ( test -n "`basename $ORACLE_INSTANTCLIENT_PREFIX | grep 11`" )
				then
					ORACLEVERSION="11g"
				fi
				if ( test -n "`basename $ORACLE_INSTANTCLIENT_PREFIX | grep 12`" )
				then
					ORACLEVERSION="12c"
				fi
				if ( test -n "`basename $ORACLE_INSTANTCLIENT_PREFIX | grep 18`" )
				then
					ORACLEVERSION="18c"
				fi
				if ( test -n "`echo $ORACLE_INSTANTCLIENT_PREFIX | grep 19`" )
				then
					ORACLEVERSION="19c"
				fi
				if ( test -n "`echo $ORACLE_INSTANTCLIENT_PREFIX | grep 21`" )
				then
					ORACLEVERSION="21c"
				fi
				ORACLELIBSPATH="$ORACLE_INSTANTCLIENT_PREFIX"
				CLNTSH="`ls $ORACLE_INSTANTCLIENT_PREFIX/libclntsh.$SOSUFFIX.* 2> /dev/null | tail -1`"
				NNZ=`basename $ORACLELIBSPATH/libnnz*.$SOSUFFIX | sed -e "s|lib||" -e "s|.$SOSUFFIX||"`
				ORACLELIBS="-Wl,$CLNTSH -L$ORACLE_INSTANTCLIENT_PREFIX -l$NNZ"
				if ( test "$ORACLEVERSION" = "12c" )
				then
					ORACLELIBS="$ORACLELIBS -lons -lclntshcore"
				elif ( test "$ORACLEVERSION" = "18c" )
				then
					CLNTSHCORE="`ls $ORACLE_INSTANTCLIENT_PREFIX/libclntshcore.$SOSUFFIX.* 2> /dev/null | tail -1`"
					ORACLELIBS="$ORACLELIBS -lons -Wl,$CLNTSHCORE -lmql1 -lipc1"
				elif ( test "$ORACLEVERSION" = "19c" -o "$ORACLEVERSION" = "21c" )
				then
					CLNTSHCORE="`ls $ORACLE_INSTANTCLIENT_PREFIX/libclntshcore.$SOSUFFIX.* 2> /dev/null | tail -1`"
					ORACLELIBS="$ORACLELIBS -Wl,$CLNTSHCORE -lmql1 -lipc1"
				fi
				ORACLEINCLUDES="-I$ORACLE_INSTANTCLIENT_PREFIX/sdk/include"
			fi
		fi

		dnl if we didn't find anything yet, look for RPM-based
		dnl instantclient, which, oddly enough, does contain
		dnl libclntsh.so
		if ( test -z "$ORACLELIBS" -a -d "/usr/lib/oracle" )
		then
			cd /usr/lib/oracle
			for version in `ls -d * 2> /dev/null`
			do
				ORACLEVERSION="10g"
				if ( test -n "`echo $version | grep 11`" )
				then
					ORACLEVERSION="11g"
				fi
				if ( test -n "`echo $version | grep 12`" )
				then
					ORACLEVERSION="12c"
				fi
				if ( test -n "`echo $version | grep 18`" )
				then
					ORACLEVERSION="18c"
				fi

				dnl x86_64 uses client64 rather than client
				OCLIENT=""
				if ( test -r "/usr/lib/oracle/$version/client" )
				then
					OCLIENT="client"
				elif ( test -r "/usr/lib/oracle/$version/client64" )
				then
					OCLIENT="client64"
				fi
				if ( test -r "/usr/lib/oracle/$version/$OCLIENT/lib/libclntsh.$SOSUFFIX" -a -r "/usr/include/oracle/$version/$OCLIENT/oci.h" )
				then
					ORACLELIBSPATH="/usr/lib/oracle/$version/$OCLIENT/lib"
					NNZ=`basename $ORACLELIBSPATH/libnnz*.$SOSUFFIX | sed -e "s|lib||" -e "s|.$SOSUFFIX||"`
					ORACLELIBS="-L/usr/lib/oracle/$version/$OCLIENT/lib -lclntsh -l$NNZ"
					if ( test "$ORACLEVERSION" = "12c" )
					then
						ORACLELIBS="$ORACLELIBS -lons -lclntshcore"
					elif ( test "$ORACLEVERSION" = "18c" )
					then
						CLNTSHCORE="`ls /usr/lib/oracle/$version/$OCLIENT/lib/libclntshcore.$SOSUFFIX.* 2> /dev/null | tail -1`"
						ORACLELIBS="$ORACLELIBS -lons -Wl,$CLNTSHCORE -lmql1 -lipc1"
					fi
					ORACLEINCLUDES="-I/usr/include/oracle/$version/$OCLIENT"
				fi
			done
			cd -
		fi
		
		if ( test -n "$ORACLEVERSION" )
		then
			if ( test -z "$ORACLEINCLUDES" )
			then
				ORACLEINCLUDES="-I$ORACLE_HOME/rdbms/demo -I$ORACLE_HOME/rdbms/public -I$ORACLE_HOME/network/public -I$ORACLE_HOME/plsql/public"
			fi
		fi

		if ( test -n "$ORACLELIBS" -a -n "$ORACLEINCLUDES" )
		then
			AC_MSG_RESULT(yes)
		else
			AC_MSG_RESULT(no)
		fi
		
		
		OCI_H=""
		if ( test -n "$ORACLELIBS" )
		then
			AC_MSG_CHECKING(if Oracle has oci.h)
			if ( test -n "$RPATHFLAG" -a -n "$ORACLELIBSPATH" )
			then
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[exit(0)],[$ORACLESTATIC $ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); OCI_H=\"yes\"],[AC_MSG_RESULT(no)])
			else
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[exit(0)],[$ORACLESTATIC $ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); OCI_H=\"yes\"],[AC_MSG_RESULT(no)])
			fi
		fi
		
		
		LINKFAIL=""
		if ( test -n "$ORACLESTATIC" -a -n "$ORACLELIBS" )
		then
			AC_MSG_CHECKING(if Oracle can be statically linked without $DLLIB)
			if ( test -n "$OCI_H" )
			then
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,"",-1,"",-1,"",-1,OCI_LM_DEF);],[$ORACLESTATIC $ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			else
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#include <ociapr.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,"",-1,"",-1,"",-1,OCI_LM_DEF);],[$ORACLESTATIC $ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			fi
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Oracle can be statically linked with $DLLIB)
				if ( test -n "$OCI_H" )
				then
					FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,"",-1,"",-1,"",-1,OCI_LM_DEF);],[$ORACLESTATIC $ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); ORACLELIBS="$ORACLELIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no); ORACLESTATIC=""; LINKFAIL="yes"])
				else
					FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#include <ociapr.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,"",-1,"",-1,"",-1,OCI_LM_DEF);],[$ORACLESTATIC $ORACLEINCLUDES,$ORACLELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); ORACLELIBS="$ORACLELIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no); ORACLESTATIC=""; LINKFAIL="yes"])
				fi
			fi
		fi
		
		if ( test -z "$ORACLESTATIC" -a -n "$ORACLELIBS" )
		then
			AC_MSG_CHECKING(if Oracle can be dynamically linked without $DLLIB)
			if ( test -n "$OCI_H" )
			then
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,NULL,-1,NULL,-1,NULL,-1,OCI_LM_DEF);],[$ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			else
				FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#include <ociapr.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,NULL,-1,NULL,-1,NULL,-1,OCI_LM_DEF);],[$ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			fi
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Oracle can be dynamically linked with $DLLIB)
				if ( test -n "$OCI_H" )
				then
					FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#define OCIVER_ORACLE 1
#include <oci.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,NULL,-1,NULL,-1,NULL,-1,OCI_LM_DEF);],[$ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); ORACLELIBS="$ORACLELIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no); LINKFAIL="yes"])
				else
					FW_TRY_LINK([#ifdef __CYGWIN__
	#define _int64 long long
#endif
#include <ociapr.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[olog(NULL,NULL,NULL,-1,NULL,-1,NULL,-1,OCI_LM_DEF);],[$ORACLEINCLUDES],[$ORACLELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); ORACLELIBS="$ORACLELIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no); LINKFAIL="yes"])
				fi
			fi
		fi
		
		if ( test -n "$LINKFAIL" )
		then
			AC_MSG_WARN(No Oracle link configuration could be found.)
			ORACLEVERSION=""
			ORACLEINCLUDES=""
			ORACLELIBS=""
			ORACLESTATIC=""
		fi
		
		if ( test -n "$OCI_H" )
		then
			AC_DEFINE(HAVE_OCI_H,1,oci.h)
		fi
	fi
		
	if ( test "$ORACLEVERSION" != "8.0" )
	then
		AC_DEFINE(HAVE_ORACLE_8i,1,Oracle 8i or greater)
	fi

	if ( test -n $"ORACLEVERSION" )
	then
		FW_VERSION(oracle,[$ORACLEVERSION])
		FW_INCLUDES(oracle,[$ORACLEINCLUDES])
		FW_LIBS(oracle,[$ORACLELIBS])
	fi

	if ( test -z "$ORACLELIBS" -o -n "$LINKFAIL" )
	then
		AC_MSG_WARN(Oracle support will not be built.)
		ENABLE_ORACLE=""
	fi

	AC_SUBST(ORACLEVERSION)
	AC_SUBST(ORACLEINCLUDES)
	AC_SUBST(ORACLELIBS)
	AC_SUBST(ORACLELIBSPATH)
	AC_SUBST(ORACLESTATIC)
fi
fi
if ( test "$ORACLEATRUNTIME" = "yes" )
then
	AC_MSG_NOTICE(Oracle libraries will be loaded at runtime.)
	AC_DEFINE(ORACLE_AT_RUNTIME,1,Load Oracle libraries at runtime.)
fi
AC_SUBST(ENABLE_ORACLE)
])



AC_DEFUN([FW_CHECK_MYSQL],
[
if ( test "$ENABLE_MYSQL" = "yes" )
then

	MYSQLINCLUDES=""
	MYSQLLIBS=""
	MYSQLLIBSPATH=""
	MYSQLSTATIC=""
	STATICFLAG=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$MYSQLPATH" )
		then
			MYSQLINCLUDES="-I$MYSQLPATH/include/mysql"
			MYSQLLIBS="-L$MYSQLPATH/lib/mysql -lmysqlclient"
			MYSQLLIBSPATH="$MYSQLPATH/lib/mysql"
		fi

	else

		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi

		MYSQLPATHBIN=""
		if ( test -n "$MYSQLPATH" )
		then
			MYSQLPATHBIN="$MYSQLPATH/bin"
		fi

		dnl try mysql_config first...
		if ( test -z "$MYSQLLIBS" )
		then
			for dir in \
				"$MYSQLPATHBIN" \
				"" \
				"/usr/bin" \
				"/usr/local/bin" \
				"/usr/pkg/bin" \
				"/usr/local/mysql/bin" \
				"/opt/sfw/bin" \
				"/opt/sfw/mysql/bin" \
				"/usr/sfw/bin" \
				"/usr/sfw/mysql/bin" \
				"/opt/csw/bin" \
				"/sw/bin" \
				"/usr/freeware/bin" \
				"/boot/common/bin" \
				"/resources/index/bin" \
				`ls -d /usr/mysql/*/bin 2> /dev/null | sort -r` \
				"/usr/local/mariadb/bin" \
				"/opt/sfw/mariadb/bin" \
				"/usr/sfw/mariadb/bin" \
				`ls -d /usr/mariadb/*/bin 2> /dev/null | sort -r`
			do

				dnl try mysql_config, and if that fails,
				dnl try mariadb_config
				if ( test -n "$dir" )
				then
					MYSQLCONFIG="$dir/mysql_config"
				else
					MYSQLCONFIG="mysql_config"
				fi
				$MYSQLCONFIG --cflags > /dev/null 2> /dev/null
				if ( test "$?" -ne "0" )
				then
					if ( test -n "$dir" )
					then
						MYSQLCONFIG="$dir/mariadb_config"
					else
						MYSQLCONFIG="mariadb_config"
					fi
				fi

				MYSQLINCLUDES=`$MYSQLCONFIG --cflags 2> /dev/null | sed -e "s|'||g"`

				dnl try --libs and --libs_r flags and go with
				dnl --libs_r if it's valid
				MYSQLLIBS=`$MYSQLCONFIG --libs 2> /dev/null | sed -e "s|'||g"`
				MYSQLLIBSR=`$MYSQLCONFIG --libs_r 2> /dev/null | sed -e "s|'||g"`
				if ( test -n "$MYSQLLIBSR" -a -z "`echo $MYSQLLIBSR | grep Usage:`" )
				then

					dnl extract the libs path and libname
					dnl and verify that a file actually
					dnl exists at that path
					LIBPATH=""
					LIBNAME=""
					for part in `echo "$MYSQLLIBSR"`
					do
						if ( test "`echo $part | cut -c1-2`" = "-L" )
						then
							LIBPATH="`echo $part | cut -c3-1000`"
							break
						fi
					done
					for part in `echo "$MYSQLLIBSR"`
					do
						if ( test "`echo $part | cut -c1-2`" = "-l" )
						then
							LIBNAME="`echo $part | cut -c3-1000`"
							break
						fi
					done
					if ( test -n "`ls $LIBPATH/lib$LIBNAME.*$SOSUFFIX 2> /dev/null`" )
					then
						MYSQLLIBS=$MYSQLLIBSR
					fi
				fi

				dnl extract the libs path
				if ( test -n "$MYSQLLIBS" )
				then
					for part in `echo "$MYSQLLIBS"`
					do
						if ( test "`echo $part | cut -c1-2`" = "-L" )
						then
							MYSQLLIBSPATH="`echo $part | cut -c3-1000`"
							break
						fi
					done
					break
				fi
			done
		fi

		dnl if mysql_config/mariadb_config didn't work then fall back
		dnl to just looking directly for headers and libs
		if ( test -z "$MYSQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$MYSQLPATH],[mysql],[mysql.h],[mysqlclient],[$STATICFLAG],[$RPATHFLAG],[MYSQLINCLUDES],[MYSQLLIBS],[MYSQLLIBSPATH],[MYSQLSTATIC],[dummy],[no])
		fi
		if ( test -z "$MYSQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$MYSQLPATH],[mysql],[mysql.h],[mysqlclient],[$STATICFLAG],[$RPATHFLAG],[MYSQLINCLUDES],[MYSQLLIBS],[MYSQLLIBSPATH],[MYSQLSTATIC],[dummy],[yes])
		fi
		if ( test -z "$MYSQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$MYSQLPATH],[mariadb],[mysql.h],[mariadb],[$STATICFLAG],[$RPATHFLAG],[MYSQLINCLUDES],[MYSQLLIBS],[MYSQLLIBSPATH],[MYSQLSTATIC],[dummy],[yes])
		fi
		if ( test -z "$MYSQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$MYSQLPATH],[mariadb],[mysql.h],[mariadb],[$STATICFLAG],[$RPATHFLAG],[MYSQLINCLUDES],[MYSQLLIBS],[MYSQLLIBSPATH],[MYSQLSTATIC],[dummy],[no])
		fi

		dnl on some platforms, mysql_config returns options
		dnl that the native compiler likes but g++ does not
		if ( test -n "`echo $CXX | grep g++`" )
		then
			MYSQLINCLUDES=`echo $MYSQLINCLUDES | sed -e "s|-x.* ||g" -e "s|-x.*$||g" -e "s|-nofstore ||g" -e "s|-nofstore$||g" -e "s|-f.* ||g" -e "s|-f.*$||g" -e "s|-mt ||g" -e "s|-mt$||g"`
		fi
		
		if ( test "$MYSQLINCLUDES" = "-I/usr/include" )
		then
			MYSQLINCLUDES=""
		fi

		dnl sanity check
		if ( test -n "$MYSQLLIBS" )
		then
			AC_MSG_CHECKING(for valid mysql_config output)
			MYSQLCONFIGSUCCESS="no"
			FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_close(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); MYSQLCONFIGSUCCESS="yes"],[AC_MSG_RESULT(no)])

			dnl On freebsd 11.1, mysql_config doesn't include
			dnl -L/usr/local/lib, but it should because libiconv
			dnl is located there.  We'll try again, adding that,
			dnl if mysql_config fails the first time.
			if ( test "$MYSQLCONFIGSUCCESS" = "no" )
			then
				AC_MSG_CHECKING(again with -L/usr/local/lib)
				MYSQLLIBS="-L/usr/local/lib $MYSQLLIBS"
				FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_close(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); MYSQLINCLUDES=""; MYSQLLIBS=""])
			fi
		fi

		dnl do we need -lz?
		if ( test -n "$MYSQLLIBS" -a -z "$MICROSOFT" )
		then
		
			AC_MSG_CHECKING(if MySQL requires -lz)
			FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_real_connect(NULL,NULL,NULL,NULL,NULL,0,NULL,0); mysql_real_query(NULL,NULL,0); mysql_store_result(NULL); mysql_num_fields(NULL); mysql_fetch_row(NULL); mysql_free_result(NULL); mysql_close(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(no)],[AC_MSG_RESULT(yes); MYSQLLIBS="$MYSQLLIBS -lz"])
		
			NEEDSLIBZ=`echo "$MYSQLLIBS" | grep "\-lz"`
			if ( test -n "$NEEDSLIBZ" )
			then
				AC_CHECK_LIB(z,gzopen,,MYSQLINCLUDES=""; MYSQLLIBS=""; AC_MSG_WARN(MySQL requires libz but libz was not found.))
			fi
		fi
	fi

	if ( test -z "$MYSQLLIBS" )
	then
		AC_MSG_WARN(MySQL support will not be built.)
	else
		FW_CHECK_MYSQL_FUNCTIONS()
	fi

	FW_INCLUDES(mysql,[$MYSQLINCLUDES])
	FW_LIBS(mysql,[$MYSQLLIBS])
		
	AC_SUBST(MYSQLINCLUDES)
	AC_SUBST(MYSQLLIBS)
	AC_SUBST(MYSQLLIBSPATH)
	AC_SUBST(MYSQLSTATIC)
fi
])

AC_DEFUN([FW_CHECK_MYSQL_FUNCTIONS],
[
	AC_MSG_CHECKING(for mysql_real_connect)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_real_connect(NULL,NULL,NULL,NULL,NULL,0,NULL,0);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_REAL_CONNECT_FOR_SURE,1,MySQL supports mysql_real_connect)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_select_db)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_select_db(NULL,NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SELECT_DB,1,MySQL supports mysql_select_db)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_ping)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_ping(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_PING,1,MySQL supports mysql_ping)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_change_user)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_change_user(NULL,NULL,NULL,NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_CHANGE_USER,1,MySQL supports mysql_change_user)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_commit)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_commit(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_COMMIT,1,MySQL supports mysql_commit)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_rollback)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_rollback(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_ROLLBACK,1,MySQL supports mysql_rollback)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_autocommit)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_autocommit(NULL,0);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_AUTOCOMMIT,1,MySQL supports mysql_autocommit)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_prepare)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_stmt_prepare(NULL,NULL,0);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_STMT_PREPARE,1,MySQL supports mysql_stmt_prepare)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_next_result)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_next_result(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_NEXT_RESULT,1,MySQL supports mysql_next_result)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_set_character_set)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_set_character_set(NULL,"");],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SET_CHARACTER_SET,1,MySQL supports mysql_set_character_set)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for mysql_ssl_set)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_ssl_set(NULL,"","","","","");],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_SET,1,MySQL supports mysql_ssl_set)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for CR_SERVER_GONE_ERROR)
	FW_TRY_LINK([#include <mysql.h>
#include <errmsg.h>
#include <stdlib.h>],[int err=CR_SERVER_GONE_ERROR;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_CR_SERVER_GONE_ERROR,1,MySQL supports CR_SERVER_GONE_ERROR)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for CR_SERVER_LOST)
	FW_TRY_LINK([#include <mysql.h>
#include <errmsg.h>
#include <stdlib.h>],[int err=CR_SERVER_LOST;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_CR_SERVER_LOST,1,MySQL supports CR_SERVER_LOST)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for FIELD_TYPE_YEAR)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD field; field.type=FIELD_TYPE_YEAR;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_TYPE_YEAR,1,MySQL supports FIELD_TYPE_YEAR)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for FIELD_TYPE_NEWDATE)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD field; field.type=FIELD_TYPE_NEWDATE;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_TYPE_NEWDATE,1,MySQL supports FIELD_TYPE_NEWDATE)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for FIELD_TYPE_ENUM)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD field; field.type=FIELD_TYPE_ENUM;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_TYPE_ENUM,1,MySQL supports FIELD_TYPE_ENUM)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for FIELD_TYPE_SET)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD field; field.type=FIELD_TYPE_SET;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_TYPE_SET,1,MySQL supports FIELD_TYPE_SET)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for FIELD_TYPE_NEWDECIMAL)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD field; field.type=FIELD_TYPE_NEWDECIMAL;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_TYPE_NEWDECIMAL,1,MySQL supports FIELD_TYPE_NEWDECIMAL)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_RECONNECT)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_RECONNECT;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_RECONNECT,1,MySQL supports MYSQL_OPT_RECONNECT)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_SSL_CRL)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_SSL_CRL;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_SSL_CRL,1,MySQL supports MYSQL_OPT_SSL_CRL)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_SSL_CRLPATH)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_SSL_CRLPATH;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_SSL_CRLPATH,1,MySQL supports MYSQL_OPT_SSL_CRLPATH)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_SSL_MODE)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_SSL_MODE;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_SSL_MODE,1,MySQL supports MYSQL_OPT_SSL_MODE)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for SSL_MODE_DISABLED)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[unsigned int sslmode=SSL_MODE_DISABLED;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_MODE_DISABLED,1,MySQL supports SSL_MODE_DISABLED)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for SSL_MODE_PREFERRED)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[unsigned int sslmode=SSL_MODE_PREFERRED;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_MODE_PREFERRED,1,MySQL supports SSL_MODE_PREFERRED)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for SSL_MODE_REQUIRED)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[unsigned int sslmode=SSL_MODE_REQUIRED;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_MODE_REQUIRED,1,MySQL supports SSL_MODE_REQUIRED)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for SSL_MODE_VERIFY_CA)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[unsigned int sslmode=SSL_MODE_VERIFY_CA;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_MODE_VERIFY_CA,1,MySQL supports SSL_MODE_VERIFY_CA)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for SSL_MODE_VERIFY_IDENTITY)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[unsigned int sslmode=SSL_MODE_VERIFY_IDENTITY;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_SSL_MODE_VERIFY_IDENTITY,1,MySQL supports SSL_MODE_VERIFY_IDENTITY)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_SSL_ENFORCE)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_SSL_ENFORCE;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_SSL_ENFORCE,1,MySQL supports MYSQL_OPT_SSL_ENFORCE)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_SSL_VERIFY_SERVER_CERT)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_SSL_VERIFY_SERVER_CERT;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_SSL_VERIFY_SERVER_CERT,1,MySQL supports MYSQL_OPT_SSL_VERIFY_SERVER_CERT)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_OPT_TLS_VERSION)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_OPT_TLS_VERSION;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_OPT_TLS_VERSION,1,MySQL supports MYSQL_OPT_TLS_VERSION)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_REPORT_DATA_TRUNCATION)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_option a; a=MYSQL_REPORT_DATA_TRUNCATION;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_REPORT_DATA_TRUNCATION,1,MySQL supports MYSQL_REPORT_DATA_TRUNCATION)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_GET_SERVER_VERSION)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[mysql_get_server_version(NULL);],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_GET_SERVER_VERSION,1,MySQL supports MYSQL_GET_SERVER_VERSION)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_FIELD.name_length)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD f; unsigned int a=f.name_length;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_NAME_LENGTH,1,MySQL supports MYSQL_FIELD.name_length)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_FIELD.org_table)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD f; const char *a=f.org_table;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_ORG_TABLE,1,MySQL supports MYSQL_FIELD.org_table)],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(for MYSQL_FIELD.org_table_length)
	FW_TRY_LINK([#include <mysql.h>
#include <stdlib.h>],[MYSQL_FIELD f; unsigned int a=f.org_table_length;],[$MYSQLSTATIC $MYSQLINCLUDES],[$MYSQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_MYSQL_FIELD_ORG_TABLE_LENGTH,1,MySQL supports MYSQL_FIELD.org_table_length)],[AC_MSG_RESULT(no)])
])


AC_DEFUN([FW_CHECK_POSTGRESQL],
[
if ( test "$ENABLE_POSTGRESQL" = "yes" )
then

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$POSTGRESQLPATH" )
		then
			POSTGRESQLINCLUDES="-I$POSTGRESQLPATH/include"
			POSTGRESQLLIBS="-L$POSTGRESQLPATH/lib -lpq"
			POSTGRESQLLIBSPATH="$POSTGRESQLPATH/lib"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi

		FW_CHECK_HEADERS_AND_LIBS([$POSTGRESQLPATH],[pgsql],[libpq-fe.h],[pq],[$STATICFLAG],[$RPATHFLAG],[POSTGRESQLINCLUDES],[POSTGRESQLLIBS],[POSTGRESQLLIBSPATH],[POSTGRESQLSTATIC])

		if ( test -z "$POSTGRESQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$POSTGRESQLPATH],[postgresql],[libpq-fe.h],[pq],[$STATICFLAG],[$RPATHFLAG],[POSTGRESQLINCLUDES],[POSTGRESQLLIBS],[POSTGRESQLLIBSPATH],[POSTGRESQLSTATIC])
		fi

		if ( test -z "$POSTGRESQLLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$POSTGRESQLPATH],[postgres],[libpq-fe.h],[pq],[$STATICFLAG],[$RPATHFLAG],[POSTGRESQLINCLUDES],[POSTGRESQLLIBS],[POSTGRESQLLIBSPATH],[POSTGRESQLSTATIC])
		fi

		if ( test -z "$POSTGRESQLLIBS" )
		then
			for dir in `ls /Library/PostgreSQL 2> /dev/null`
			do
				FW_CHECK_HEADERS_AND_LIBS([$POSTGRESQLPATH],[PostgreSQL/$dir],[libpq-fe.h],[pq],[$STATICFLAG],[$RPATHFLAG],[POSTGRESQLINCLUDES],[POSTGRESQLLIBS],[POSTGRESQLLIBSPATH],[POSTGRESQLSTATIC])
			done
		fi
		
		LINKFAIL=""
		if ( test -n "$POSTGRESQLSTATIC" -a -n "$POSTGRESQLLIBS" )
		then
			AC_MSG_CHECKING(if PostgreSQL can be statically linked without -lcrypt)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetdbLogin(NULL,NULL,NULL,NULL,NULL,NULL,NULL);],[$POSTGRESQLSTATIC $POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" )
			then
				AC_MSG_CHECKING(if PostgreSQL can be statically linked with -lcrypt)
				FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetdbLogin(NULL,NULL,NULL,NULL,NULL,NULL,NULL);],[$POSTGRESQLSTATIC $POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS -lcrypt],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); POSTGRESQLLIBS="$POSTGRESQLLIBS -lcrypt"; LINKFAIL=""],[AC_MSG_RESULT(no); POSTGRESQLSTATIC=""; LINKFAIL="yes"])
			fi
		fi
		
		if ( test -z "$POSTGRESQLSTATIC" -a -n "$POSTGRESQLLIBS" )
		then
			AC_MSG_CHECKING(if PostgreSQL can be dynamically linked without -lcrypt)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetdbLogin(NULL,NULL,NULL,NULL,NULL,NULL,NULL);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" )
			then
				AC_MSG_CHECKING(if PostgreSQL can be dynamically linked with -lcrypt)
				FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetdbLogin(NULL,NULL,NULL,NULL,NULL,NULL,NULL);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS -lcrypt],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); POSTGRESQLLIBS="$POSTGRESQLLIBS -lcrypt"; LINKFAIL=""],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			fi
		fi
		
		if ( test -n "$LINKFAIL" )
		then
			AC_MSG_WARN(No PostgreSQL link configuration could be found.)
			POSTGRESQLINCLUDES=""
			POSTGRESQLLIBS=""
			POSTGRESQLSTATIC=""
		fi
		
		if ( test "$POSTGRESQLINCLUDES" = "-I/usr/include" )
		then
			POSTGRESQLINCLUDES=""
		fi

		if ( test -z "$POSTGRESQLLIBS" )
		then
			AC_MSG_WARN(PostgreSQL support will not be built.)
		fi
	fi

	if ( test -n "$POSTGRESQLLIBS" )
	then
		AC_MSG_CHECKING(if PostgreSQL has PQconnectdb)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQconnectdb(0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQCONNECTDB,1,Some versions of postgresql have PQconnectdb)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQfmod)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQfmod(0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQFMOD,1,Some versions of postgresql have PQfmod)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQsetNoticeProcessor)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetNoticeProcessor(0,0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQSETNOTICEPROCESSOR,1,Some versions of postgresql have PQsetNoticeProcessor)],[AC_MSG_RESULT(no)])
		if ( test -n "$ENABLE_POSTGRESQL8API" )
		then
			AC_MSG_CHECKING(if PostgreSQL has PQprepare)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQprepare(0,0,0,0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQPREPARE,1,Some versions of postgresql have PQprepare)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(if PostgreSQL has PQexecPrepared)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQexecPrepared(0,0,0,0,0,0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQEXECPREPARED,1,Some versions of postgresql have PQexecPrepared)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(if PostgreSQL has PQsendQueryPrepared)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsendQueryPrepared(0,0,0,0,0,0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQSENDQUERYPREPARED,1,Some versions of postgresql have PQsendQueryPrepared)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(if PostgreSQL has PQsetSingleRowMode)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetSingleRowMode(0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQSETSINGLEROWMODE,1,Some versions of postgresql have PQsetSingleRowMode)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(if PostgreSQL has PQdescribePrepared)
			FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQdescribePrepared(0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQDESCRIBEPREPARED,1,Some versions of postgresql have PQdescribePrepared)],[AC_MSG_RESULT(no)])
		fi
		AC_MSG_CHECKING(if PostgreSQL has PQserverVersion)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQserverVersion(0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQSERVERVERSION,1,Some versions of postgresql have PQserverVersion)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQparameterStatus)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQparameterStatus(0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQPARAMETERSTATUS,1,Some versions of postgresql have PQparameterStatus)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQsetClientEncoding)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQsetClientEncoding(0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQSETCLIENTENCODING,1,Some versions of postgresql have PQsetClientEncoding)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQoidValue)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQoidValue(0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQOIDVALUE,1,Some versions of postgresql have PQoidValue)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQbinaryTuples)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQbinaryTuples(0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQBINARYTUPLES,1,Some versions of postgresql have PQbinaryTuples)],[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(if PostgreSQL has PQftable)
		FW_TRY_LINK([#include <libpq-fe.h>
#include <stdlib.h>],[PQftable(0,0);],[$POSTGRESQLINCLUDES],[$POSTGRESQLLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$POSTGRESQLLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_POSTGRESQL_PQFTABLE,1,Some versions of postgresql have PQftable)],[AC_MSG_RESULT(no)])
	fi

	FW_INCLUDES(postgresql,[$POSTGRESQLINCLUDES])
	FW_LIBS(postgresql,[$POSTGRESQLLIBS])
		
	AC_SUBST(POSTGRESQLINCLUDES)
	AC_SUBST(POSTGRESQLLIBS)
	AC_SUBST(POSTGRESQLLIBSPATH)
	AC_SUBST(POSTGRESQLSTATIC)
fi
])


AC_DEFUN([FW_CHECK_GDBM],
[

if ( test "$cross_compiling" = "yes" )
then
	dnl cross compiling ...
	echo "cross compiling"
	if ( test -n "$GDBMPATH" )
	then
		GDBMINCLUDES="-I$GDBMPATH/include"
		GDBMLIBS="-L$GDBMPATH/lib -lgdbm"
		GDBMLIBSPATH="$GDBMPATH/lib"
	fi
else
	FW_CHECK_HEADERS_AND_LIBS([$LIBGDBMPATH],[gdbm],[gdbm.h],[gdbm],[$STATICFLAG],[$RPATHFLAG],[GDBMINCLUDES],[GDBMLIBS],[GDBMLIBSPATH],[GDBMSTATIC])
fi

FW_LIBS(gdbm,[$GDBMLIBS])

AC_SUBST(GDBMLIBS)
])


AC_DEFUN([FW_CHECK_SQLITE],
[
if ( test "$ENABLE_SQLITE" = "yes" )
then

	FW_CHECK_GDBM
		
	SQLITEINCLUDES=""
	SQLITELIBS=""
	SQLITELIBSPATH=""
	SQLITESTATIC=""
	SQLITEVERSION=""

	if ( test "$cross_compiling" = "yes" )
	then
		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$SQLITEPATH" )
		then
			SQLITEINCLUDES="-I$SQLITEPATH/include"
			SQLITELIBS="-L$SQLITEPATH/lib -lsqlite3"
			SQLITELIBSPATH="$SQLITEPATH/lib"
			SQLITEVERSION="3"
		fi
	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi
		
		if ( test -n "$HAVE_PTHREAD" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$SQLITEPATH],[sqlite],[sqlite.h],[sqlite],[$STATICFLAG],[$RPATHFLAG],[SQLITEINCLUDES],[SQLITELIBS],[SQLITELIBSPATH],[SQLITESTATIC])
			if ( test -z "$SQLITELIBS" )
			then
				FW_CHECK_HEADERS_AND_LIBS([$SQLITEPATH],[sqlite],[sqlite3.h],[sqlite3],[$STATICFLAG],[$RPATHFLAG],[SQLITEINCLUDES],[SQLITELIBS],[SQLITELIBSPATH],[SQLITESTATIC])
				if ( test -n "$SQLITELIBS" )
				then
					SQLITEVERSION="3"
				fi
			fi
		else
			AC_MSG_WARN(pthreads was not found.)
		fi
			
		if ( test -z "$SQLITELIBS" )
		then
			AC_MSG_WARN(SQLite support will not be built.)
		else
			if ( test -z "$SQLITEVERSION" )
			then
				AC_MSG_CHECKING(if SQLite needs gdbm)
				SQLITENEEDGDBM=""
				FW_TRY_LINK([#include <sqlite.h>],[sqlite *sqliteptr; char *errmesg; sqliteptr=sqlite_open("/tmp/testfile",666,&errmesg); sqlite_close(sqliteptr);],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $SOCKETLIBS $PTHREADLIB],[$LD_LIBRARY_PATH:$SQLITELIBSPATH],[AC_MSG_RESULT(no)],[AC_MSG_RESULT(yes); SQLITENEEDGDBM="yes"])
			
				if ( test -n "$SQLITENEEDGDBM" )
				then
					if ( test -z "$GDBMLIBS" )
					then
						AC_MSG_WARN(SQLite needs GDBM but GDBM was not found. SQLite support will not be built.)
						SQLITELIBS=""
						SQLITELIBSPATH=""
						SQLITEINCLUDES=""
						SQLITESTATIC=""
					else 
						SQLITELIBS="$SQLITELIBS $GDBMLIBS"
					fi
				else
					AC_DEFINE_UNQUOTED(SQLITE_TRANSACTIONAL,1,Some versions of sqlite are transactional)
				fi
			fi
		fi
	fi

	if ( test -n "$SQLITELIBS" )
	then

		if ( test "$SQLITEVERSION" = "3" )
		then
			SQLITEINCLUDES="-DSQLITE3 $SQLITEINCLUDES"
			AC_DEFINE_UNQUOTED(SQLITE_TRANSACTIONAL,1,Some versions of sqlite are transactional)
		fi

		AC_MSG_CHECKING(for sqlite3_stmt)
		FW_TRY_LINK([#include <sqlite3.h>
#include <stdlib.h>],[sqlite3_stmt *a=0;],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLITE3_STMT,1,SQLite supports sqlite3_stmt)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for sqlite3_prepare_v2)
		FW_TRY_LINK([#include <sqlite3.h>
#include <stdlib.h>],[sqlite3_prepare_v2(0,0,0,0,0);],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLITE3_PREPARE_V2,1,SQLite supports sqlite3_prepare_v2)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for sqlite3_malloc)
		FW_TRY_LINK([#include <sqlite3.h>
#include <stdlib.h>],[sqlite3_malloc(0);],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLITE3_MALLOC,1,SQLite supports sqlite3_malloc)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for sqlite3_free with char * argument)
		FW_TRY_LINK([#include <sqlite3.h>
#include <stdlib.h>],[char *a=0; sqlite3_free(a);],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLITE3_FREE_WITH_CHAR,1,SQLite supports sqlite3_malloc)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for sqlite3_column_table_name)
		FW_TRY_LINK([#include <sqlite3.h>
#include <stdlib.h>],[sqlite3_column_table_name(0,0);],[$SQLITESTATIC $SQLITEINCLUDES $PTHREADINCLUDES],[$SQLITELIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLITE3_COLUMN_TABLE_NAME,1,SQLite supports sqlite3_column_table_name)],[AC_MSG_RESULT(no)])

	fi

	FW_INCLUDES(sqlite,[$SQLITEINCLUDES])
	FW_LIBS(sqlite,[$SQLITELIBS])
		
	AC_SUBST(SQLITEINCLUDES)
	AC_SUBST(SQLITELIBS)
	AC_SUBST(SQLITELIBSPATH)
	AC_SUBST(SQLITESTATIC)
fi
])

AC_DEFUN([FW_CHECK_ICONV],
[
	FW_CHECK_HEADERS_AND_LIBS([/usr],[iconv],[iconv.h],[iconv],[$STATICFLAG],[$RPATHFLAG],[ICONVINCLUDES],[ICONVLIBS],[ICONVLIBPATH],[ICONVSTATIC])

	HAVE_ICONV=""
	AC_MSG_CHECKING(for iconv)
	FW_TRY_LINK([#include <iconv.h>
#include <stdlib.h>],[iconv(0,NULL,NULL,NULL,NULL);],[$ICONVINCLUDES],[$ICONVLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); HAVE_ICONV="yes"],[AC_MSG_RESULT(no)])

	AC_MSG_CHECKING(if iconv takes const char ** argument)
	FW_TRY_LINK([#include <iconv.h>
#include <stdlib.h>],[const char *t; iconv(0,&t,NULL,NULL,NULL);],[$ICONVINCLUDES],[$ICONVLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(ICONV_CONST_CHAR,1,Some iconv implementations use a const char ** parameter)],[AC_MSG_RESULT(no)])

	AC_SUBST(HAVE_ICONV)
	AC_SUBST(ICONVINCLUDES)
	AC_SUBST(ICONVLIBS)
])

AC_DEFUN([FW_CHECK_FREETDS],
[
if ( test "$ENABLE_FREETDS" = "yes" )
then

	FREETDSINCLUDES=""
	FREETDSLIBS=""
	FREETDSLIBSPATH=""
	FREETDSSTATIC=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$FREETDSPATH" )
		then
			FREETDSINCLUDES="-I$FREETDSPATH/include"
			FREETDSLIBS="-L$FREETDSPATH/lib -lct"
			FREETDSLIBSPATH="$FREETDSPATH/lib"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi

		FW_CHECK_HEADERS_AND_LIBS([$FREETDSPATH],[freetds],[ctpublic.h],[ct],[$STATICFLAG],[$RPATHFLAG],[FREETDSINCLUDES],[FREETDSLIBS],[FREETDSLIBPATH],[FREETDSSTATIC])
		
		if ( test -n "$FREETDSLIBS" )
		then

			dnl some versions of freetds need libiconv, see if
			dnl a simple test will link
			LINKFAILED=""
			FW_TRY_LINK([],[],[$FREETDSINCLUDES $PTHREADINCLUDES],[$FREETDSLIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[],[LINKFAILED="yes"])

			dnl if not, search for iconv
			if ( test -n "$LINKFAILED" )
			then

				dnl if iconv was found, try the test again,
				dnl using it
				dnl if it was not found, then freetds just
				dnl doesn't work
				if ( test -n "$ICONVLIBS" )
				then
					AC_MSG_CHECKING(whether freetds requires libiconv)

					FW_TRY_LINK([],[],[$FREETDSINCLUDES $ICONVINCLUDES $PTHREADINCLUDES],[$FREETDSLIBS $ICONVLIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[FREETDSINCLUDES="$FREETDSINCLUDES $ICONVINCLUDES"; FREETDSLIBS="$FREETDSLIBS $ICONVLIBS"; AC_MSG_RESULT(yes)],[FREETDSLIBS=""; FREETDSINCLUDES=""; AC_MSG_RESULT(no)])
				else
					FREETDSLIBS=""
					FREETDSINCLUDES=""
				fi
			fi

			dnl if we've figured out how to link a simple freetds
			dnl program, then try using c++ to see if we need
			dnl function definitions or not
			if ( test -n "$FREETDSLIBS" )
			then
				AC_MSG_CHECKING(whether ctpublic.h contains function definitions)
				FW_TRY_LINK([#include <ctpublic.h>
#include <stdlib.h>],[CS_CONTEXT *context; cs_ctx_alloc(CS_VERSION_100,&context);],[$FREETDSINCLUDES $PTHREADINCLUDES],[$FREETDSLIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_FREETDS_FUNCTION_DEFINITIONS,1,Some versions of FreeTDS have function definitions)],[AC_MSG_RESULT(no)])
			fi
		fi

		dnl if FREETDSLIBS is defined, check for tdsver.h
		if ( test -n "$FREETDSLIBS" )
		then
			AC_MSG_CHECKING(whether tdsver.h exists)
			FW_TRY_LINK([#include <tdsver.h>],[],[$FREETDSINCLUDES $PTHREADINCLUDES],[$FREETDSLIBS $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_FREETDS_H,1,Some versions of FreeTDS have tdsver.h)],[AC_MSG_RESULT(no)])
		fi

		dnl if FREETDSLIBS isn't defined at this point, then freetds
		dnl isn't installed or doesn't work
		if ( test -z "$FREETDSLIBS" )
		then
			AC_MSG_WARN(FreeTDS support will not be built.)
		fi
	fi

	FW_INCLUDES(freetds,[$FREETDSINCLUDES])
	FW_LIBS(freetds,[$FREETDSLIBS])
		
	AC_SUBST(FREETDSINCLUDES)
	AC_SUBST(FREETDSLIBS)
	AC_SUBST(FREETDSLIBSPATH)
	AC_SUBST(FREETDSSTATIC)
fi
])



AC_DEFUN([FW_CHECK_SYBASE],
[
if ( test -z "$SYBASEATRUNTIME" )
then
if ( test "$ENABLE_SYBASE" = "yes" )
then

	SYBASEINCLUDES=""
	SYBASELIBS=""
	SYBASESTATIC=""
	SYBASELIBSPATH=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$SYBASEPATH" )
		then
			SYBASEINCLUDES="-I$SYBASEPATH/include"
			SYBASELIBS="-L$SYBASEPATH/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck"
			SYBASELIBSPATH="$SYBASEPATH/lib"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi
		
		if ( test -n "$SYBASEPATH" )
		then
			FW_CHECK_HEADER_LIB([$SYBASEPATH/include/ctpublic.h],[SYBASEINCLUDES=\"-I$SYBASEPATH/include\"],[$SYBASEPATH/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"$SYBASEPATH/lib\"; SYBASELIBS=\"-L$SYBASEPATH/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"],[$SYBASEPATH/lib/libct.a],[SYBASELIBS=\"-L$SYBASEPATH/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"; SYBASESTATIC=\"$STATICFLAG\"])

			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([$SYBASEPATH/include/ctpublic.h],[SYBASEINCLUDES=\"-DSYB_LP64 -I$SYBASEPATH/include\"],[$SYBASEPATH/lib/libsybct64.$SOSUFFIX],[SYBASELIBSPATH=\"$SYBASEPATH/lib\"; SYBASELIBS=\"-L$SYBASEPATH/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybdb64 -lsybintl64\"],[$SYBASEPATH/lib/libsybct64.a],[SYBASELIBS=\"-L$SYBASEPATH/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybdb64 -lsybintl64\"; SYBASESTATIC=\"$STATICFLAG\"])
			fi
		else
		
			FW_CHECK_HEADER_LIB([/usr/local/sybase/include/ctpublic.h],[SYBASEINCLUDES=\"-I/usr/local/sybase/include\"],[/usr/local/sybase/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"/usr/local/sybase/lib\"; SYBASELIBS=\"-L/usr/local/sybase/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"],[/usr/local/sybase/lib/libct.a],[SYBASELIBS=\"-L/usr/local/sybase/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"; SYBASESTATIC=\"$STATICFLAG\"])
		
			FW_CHECK_HEADER_LIB([/opt/sybase/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sybase/include\"],[/opt/sybase/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase/lib\"; SYBASELIBS=\"-L/opt/sybase/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"],[/opt/sybase/lib/libct.a],[SYBASELIBS=\"-L/opt/sybase/lib -lblk -lcs -lct -lcomn -lsybtcl -lsybdb -lintl -linsck\"; SYBASESTATIC=\"$STATICFLAG\"])

			FW_CHECK_HEADER_LIB([/opt/sybase-12.5/OCS-12_5/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sybase-12.5/OCS-12_5/include\"],[/opt/sybase-12.5/OCS-12_5/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase-12.5/OCS-12_5/lib\"; SYBASELIBS=\"-L/opt/sybase-12.5/OCS-12_5/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl\"],[/opt/sybase-12.5/OCS-12_5/lib/libct.a],[SYBASELIBS=\"-L/opt/sybase-12.5/OCS-12_5/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl\"; SYBASESTATIC=\"$STATICFLAG\"])

			FW_CHECK_HEADER_LIB([/opt/sybase/OCS-12_5/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sybase/OCS-12_5/include\"],[/opt/sybase/OCS-12_5/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase/OCS-12_5/lib\"; SYBASELIBS=\"-L/opt/sybase/OCS-12_5/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl\"],[/opt/sybase/OCS-12_5/lib/libct.a],[SYBASELIBS=\"-L/opt/sybase/OCS-12_5/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl\"; SYBASESTATIC=\"$STATICFLAG\"])

			FW_CHECK_HEADER_LIB([/opt/sybase/OCS-15_0/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sybase/OCS-15_0/include\"],[/opt/sybase/OCS-15_0/lib/libsybct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase/OCS-15_0/lib\"; SYBASELIBS=\"-L/opt/sybase/OCS-15_0/lib -lsybblk -lsybct -lsybcs -lsybcomn -lsybtcl -lsybintl\"],[/opt/sybase/OCS-15_0/lib/libsybct.a],[SYBASELIBS=\"-L/opt/sybase/OCS-15_0/lib -lsybblk -lsybct -lsybcs -lsybcomn -lsybtcl -lsybintl\"; SYBASESTATIC=\"$STATICFLAG\"])

			FW_CHECK_HEADER_LIB([/opt/sap/OCS-16_0/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sap/OCS-16_0/include\"],[/opt/sap/OCS-16_0/lib/libsybct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sap/OCS-16_0/lib\"; SYBASELIBS=\"-L/opt/sap/OCS-16_0/lib -lsybblk -lsybct -lsybcs -lsybcomn -lsybtcl -lsybintl\"],[/opt/sap/OCS-16_0/lib/libsybct.a],[SYBASELIBS=\"-L/opt/sap/OCS-16_0/lib -lsybblk -lsybct -lsybcs -lsybcomn -lsybtcl -lsybintl\"; SYBASESTATIC=\"$STATICFLAG\"])

			dnl Link in libsybunic if it's present
			if ( test -n "$SYBASELIBS" )
			then
				FW_CHECK_LIB([/opt/sybase/OCS-15_0/lib/libsybunic.so],[SYBASELIBS=\"$SYBASELIBS -lsybunic\"])
				FW_CHECK_LIB([/opt/sap/OCS-16_0/lib/libsybunic.so],[SYBASELIBS=\"$SYBASELIBS -lsybunic\"])
			fi

			if ( test "$X64" = "x64" )
			then

				FW_CHECK_HEADER_LIB([/opt/sybase/OCS-15_0/include/ctpublic.h],[SYBASEINCLUDES=\"-DSYB_LP64 -I/opt/sybase/OCS-15_0/include\"],[/opt/sybase/OCS-15_0/lib/libsybct64.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase/OCS-15_0/lib\"; SYBASELIBS=\"-L/opt/sybase/OCS-15_0/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybintl64\"],[/opt/sybase/OCS-15_0/lib/libsybct64.a],[SYBASELIBS=\"-L/opt/sybase/OCS-15_0/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybintl64\"; SYBASESTATIC=\"$STATICFLAG\"])

				FW_CHECK_HEADER_LIB([/opt/sap/OCS-16_0/include/ctpublic.h],[SYBASEINCLUDES=\"-DSYB_LP64 -I/opt/sap/OCS-16_0/include\"],[/opt/sap/OCS-16_0/lib/libsybct64.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sap/OCS-16_0/lib\"; SYBASELIBS=\"-L/opt/sap/OCS-16_0/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybintl64\"],[/opt/sap/OCS-16_0/lib/libsybct64.a],[SYBASELIBS=\"-L/opt/sap/OCS-16_0/lib -lsybblk64 -lsybct64 -lsybcs64 -lsybcomn64 -lsybtcl64 -lsybintl64\"; SYBASESTATIC=\"$STATICFLAG\"])

				dnl Link in libsybunic if it's present
				if ( test -n "$SYBASELIBS" )
				then
					FW_CHECK_LIB([/opt/sybase/OCS-15_0/lib/libsybunic64.so],[SYBASELIBS=\"$SYBASELIBS -lsybunic64\"])
					FW_CHECK_LIB([/opt/sap/OCS-16_0/lib/libsybunic64.so],[SYBASELIBS=\"$SYBASELIBS -lsybunic64\"])
				fi
			fi
		
			if ( test -z "$SYBASELIBS" )
			then
				for i in "11.9.2" "11.0.3.3"
				do
					FW_CHECK_HEADER_LIB([/opt/sybase-$i/include/ctpublic.h],[SYBASEINCLUDES=\"-I/opt/sybase-$i/include\"],[/opt/sybase-$i/lib/libct.$SOSUFFIX],[SYBASELIBSPATH=\"/opt/sybase-$i/lib\"; SYBASELIBS=\"-L/opt/sybase-$i/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl -linsck\"],[/opt/sybase-$i/lib/libct.a],[SYBASELIBS=\"-L/opt/sybase-$i/lib -lblk -lct -lcs -lcomn -lsybtcl -lsybdb -lintl -linsck\"; SYBASESTATIC=\"$STATICFLAG\"])
					if ( test -n "$SYBASELIBS" )
					then
						break
					fi
				done
			fi
		fi
		
		LINKFAIL=""
		if ( test -n "$DLLIB" -a -n "$SYBASESTATIC" -a -n "$SYBASELIBS" )
		then
			AC_MSG_CHECKING(if Sybase can be statically linked without $DLLIB)
			FW_TRY_LINK([#include <ctpublic.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[CS_CONTEXT *context; cs_ctx_alloc(CS_VERSION_100,&context);],[$SYBASESTATIC $SYBASEINCLUDES],[$SYBASELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Sybase can be statically linked with $DLLIB)
				FW_TRY_LINK([#include <ctpublic.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[CS_CONTEXT *context; cs_ctx_alloc(CS_VERSION_100,&context);],[$SYBASESTATIC $SYBASEINCLUDES],[$SYBASELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); SYBASELIBS="$SYBASELIBS $DLLIB"; LINKFAIL="";],[AC_MSG_RESULT(no); SYBASESTATIC=""])
			fi
		fi
		
		if ( test -n "$DLLIB" -a -z "$SYBASESTATIC" -a -n "$SYBASELIBS" )
		then
			AC_MSG_CHECKING(if Sybase can be dynamically linked without $DLLIB)
			FW_TRY_LINK([#include <ctpublic.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[CS_CONTEXT *context; cs_ctx_alloc(CS_VERSION_100,&context);],[$SYBASEINCLUDES],[$SYBASELIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$SYBASELIBSPATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Sybase can be dynamically linked with $DLLIB)
				FW_TRY_LINK([#include <ctpublic.h>
#include <stdlib.h>
$GLIBC23HACKINCLUDE
$GLIBC23HACKCODE],[CS_CONTEXT *context; cs_ctx_alloc(CS_VERSION_100,&context);],[$SYBASEINCLUDES],[$SYBASELIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH:$SYBASELIBSPATH],[AC_MSG_RESULT(yes); SYBASELIBS="$SYBASELIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no)])
			fi
		fi

		if ( test -n "$LINKFAIL" )
		then
			AC_MSG_WARN(No Sybase link configuration could be found.)
			SYBASEINCLUDES=""
			SYBASELIBS=""
			SYBASELIBSPATH=""
			SYBASESTATIC=""
		fi
	fi

	if ( test -z "$SYBASELIBS" )
	then
		AC_MSG_WARN(SAP/Sybase support will not be built.)
		ENABLE_SYBASE=""
	fi

	FW_INCLUDES(sybase,[$SYBASEINCLUDES])
	FW_LIBS(sybase,[$SYBASELIBS])
		
	AC_SUBST(SYBASEINCLUDES)
	AC_SUBST(SYBASELIBS)
	AC_SUBST(SYBASELIBSPATH)
	AC_SUBST(SYBASESTATIC)
fi
fi
if ( test "$SYBASEATRUNTIME" = "yes" )
then
	AC_MSG_NOTICE(SAP/Sybase libraries will be loaded at runtime.)
	AC_DEFINE(SYBASE_AT_RUNTIME,1,Load SAP/Sybase libraries at runtime.)
fi
AC_SUBST(ENABLE_SYBASE)
])



AC_DEFUN([FW_CHECK_ODBC],
[
if ( test "$ENABLE_ODBC" = "yes" -o "$ENABLE_ODBC_DRIVER" = "yes" )
then

	ODBCINCLUDES=""
	ODBCLIBS=""
	ODBCLIBSPATH=""
	ODBCSTATIC=""
	ODBCUNICODE=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$ODBCPATH" )
		then
			ODBCINCLUDES="-I$ODBCPATH/include"
			ODBCLIBS="-L$ODBCPATH/lib -lodbc -lodbcinst"
			ODBCLIBSPATH="$ODBCPATH/lib"
			ODBCUNICODE="yes"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi
		HAVE_IODBC=""
		HAVE_UNIXODBC=""

		UNIXODBCLIBS=""
		UNIXODBCLIBSPATH=""
		UNIXODBCSTATIC=""
		UNIXODBCINCLUDES=""

		IODBCLIBS=""
		IODBCLIBSPATH=""
		IODBCSTATIC=""
		IODBCINCLUDES=""

		IODBCINSTLIBS=""
		IODBCINSTLIBSPATH=""
		IODBCINSTSTATIC=""
		IODBCINSTINCLUDES=""


		dnl unixodbc...
		FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[odbc],[sql.h],[odbc],[$STATICFLAG],[$RPATHFLAG],[UNIXODBCINCLUDES],[UNIXODBCLIBS],[UNIXODBCLIBSPATH],[UNIXODBCSTATIC])
		if ( test -n "$UNIXODBCLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[odbc],[sql.h],[odbcinst],[$STATICFLAG],[$RPATHFLAG],[UNIXODBCINSTINCLUDES],[UNIXODBCINSTLIBS],[UNIXODBCINSTLIBSPATH],[UNIXODBCINSTSTATIC])
			HAVE_UNIXODBC="yes"
		fi

		if ( test -z "$UNIXODBCLIBS" )
		then
			dnl unixodbc (again, in a more common place)...
			FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[unixodbc],[sql.h],[odbc],[$STATICFLAG],[$RPATHFLAG],[UNIXODBCINCLUDES],[UNIXODBCLIBS],[UNIXODBCLIBSPATH],[UNIXODBCSTATIC])
			if ( test -n "$UNIXODBCLIBS" )
			then
				FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[odbcinst],[sql.h],[odbcinst],[$STATICFLAG],[$RPATHFLAG],[UNIXODBCINSTINCLUDES],[UNIXODBCINSTLIBS],[UNIXODBCINSTLIBSPATH],[UNIXODBCINSTSTATIC])
				HAVE_UNIXODBC="yes"
			fi
		fi

		dnl iodbc...
		FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[iodbc],[sql.h],[iodbc],[$STATICFLAG],[$RPATHFLAG],[IODBCINCLUDES],[IODBCLIBS],[IODBCLIBSPATH],[IODBCSTATIC])
		if ( test -n "$IODBCLIBS" )
		then
			FW_CHECK_HEADERS_AND_LIBS([$ODBCPATH],[iodbcinst],[sql.h],[iodbcinst],[$STATICFLAG],[$RPATHFLAG],[IODBCINSTINCLUDES],[IODBCINSTLIBS],[IODBCINSTLIBSPATH],[IODBCINSTSTATIC])
			HAVE_IODBC="yes"
		fi

		if ( test -n "$MICROSOFT" -a -z "$ODBCLIBS" )
		then
			ODBC32LIBS=""
			ODBC32LIBSPATH=""
			ODBCCP32LIBS=""
			ODBCCP32LIBSPATH=""
			FW_CHECK_HEADER_LIB([/usr/include/w32api/sql.h],[],[/usr/lib/w32api/libodbc32.$SOSUFFIX],[ODBC32LIBSPATH=\"/usr/lib/w32api\"; ODBC32LIBS=\"-L/usr/lib/w32api -lodbc32\"],[/usr/lib/w32api/libodbc32.a],[ODBC32LIBSPATH=\"/usr/lib/w32api\"; ODBC32LIBS=\"-L/usr/lib/w32api -lodbc32\"; STATIC=\"$STATICFLAG\"])
			FW_CHECK_HEADER_LIB([/usr/include/w32api/sql.h],[],[/usr/lib/w32api/libodbccp32.$SOSUFFIX],[ODBCCP32LIBSPATH=\"/usr/lib/w32api\"; ODBCCP32LIBS=\"-L/usr/lib/w32api -lodbccp32\"],[/usr/lib/w32api/libodbccp32.a],[ODBCCP32LIBSPATH=\"/usr/lib/w32api\"; ODBCCP32LIBS=\"-L/usr/lib/w32api -lodbccp32\"; STATIC=\"$STATICFLAG\"])
			ODBCLIBS="$ODBC32LIBS $ODBCCP32LIBS"
			ODBCLIBSPATH="$ODBC32LIBSPATH $ODBCCP32LIBSPATH"
		fi

		if ( test -n "$HAVE_IODBC" )
		then
			ODBCLIBS="$IODBCLIBS $IODBCINSTLIBS"
			ODBCINCLUDES="$IODBCINCLUDES $IODBCINSTINCLUDES"
			ODBCLIBSPATH="$IODBCLIBSPATH"
			ODBCSTATIC="$IODBCSTATIC"
		elif ( test -n "$HAVE_UNIXODBC" )
		then
			ODBCLIBS="$UNIXODBCLIBS $UNIXODBCINSTLIBS"
			ODBCINCLUDES="$UNIXODBCINCLUDES $UNIXODBCINSTINCLUDES"
			ODBCLIBSPATH="$UNIXODBCLIBSPATH"
			ODBCSTATIC="$UNIXODBCSTATIC"
		fi
		
		if ( test -n "$HAVE_UNIXODBC" )
		then
			AC_DEFINE(HAVE_UNIXODBC,1,UnixODBC)
			AC_MSG_CHECKING(if UnixODBC needs threads)
			FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>],[SQLHENV env; SQLHDBC dbc; SQLAllocHandle(SQL_HANDLE_ENV,SQL_NULL_HANDLE,&env); SQLAllocHandle(SQL_HANDLE_DBC,env,&dbc); SQLFreeHandle(SQL_HANDLE_DBC,dbc); SQLFreeHandle(SQL_HANDLE_ENV,env);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(no)],[AC_MSG_RESULT(yes); ODBCINCLUDES="$ODBCINCLUDES $PTHREADINCLUDES"; ODBCLIBS="$ODBCLIBS $PTHREADLIB"])
		fi

		if ( test -n "$HAVE_IODBC" )
		then
			AC_DEFINE(HAVE_IODBC,1,iODBC)
			AC_MSG_CHECKING(if iODBC needs threads)
			FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>],[SQLHENV env; SQLHDBC dbc; SQLAllocEnv(&env); SQLAllocConnect(env,&dbc); SQLFreeConnect(&dbc); SQLFreeEnv(&env);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(no)],[AC_MSG_RESULT(yes); ODBCINCLUDES="$ODBCINCLUDES $PTHREADINCLUDES"; ODBCLIBS="$ODBCLIBS $PTHREADLIB"])
		fi
	fi
		
	dnl disable odbc if it doesn't support SQLULEN
	if ( test -n "$ODBCLIBS" )
	then
		AC_MSG_CHECKING(for SQLULEN)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>],[SQLULEN a;],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); ODBCLIBS=""])
	fi

	if ( test -n "$ODBCLIBS" )
	then
		AC_MSG_CHECKING(if SQLBindParameter takes SQLLEN * argument)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>],[SQLBindParameter(0,0,0,0,0,0,0,0,0,(SQLLEN *)1);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(SQLBINDPARAMETER_SQLLEN,1,Some systems use SQLLEN * in SQLBINDPARAMETER)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(if SQLColAttribute takes SQLLEN * argument)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>

extern "C" SQLRETURN SQL_API SQLColAttribute(SQLHSTMT statementhandle,
					SQLUSMALLINT columnnumber,
					SQLUSMALLINT fieldidentifier,
					SQLPOINTER characterattribute,
					SQLSMALLINT bufferlength,
					SQLSMALLINT *stringlength,
					SQLLEN *numericattribute) {
	return 1;
}],[],[$ODBCSTATIC $ODBCINCLUDES],[],[],[AC_MSG_RESULT(yes); AC_DEFINE(SQLCOLATTRIBUTE_SQLLEN,1,Some systems use SQLLEN * in SQLColAttribute)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(if SQLRowCount takes SQLLEN * argument)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>

extern "C" SQLRETURN SQL_API SQLRowCount(SQLHSTMT statementhandle,
					SQLLEN *rowcount) {
	return 1;
}],[],[$ODBCSTATIC $ODBCINCLUDES],[],[],[AC_MSG_RESULT(yes); AC_DEFINE(SQLROWCOUNT_SQLLEN,1,Some systems use SQLLEN * in SQLRowCount)],[AC_MSG_RESULT(no)])
		
		AC_MSG_CHECKING(if SQLBindCol takes SQLLEN * argument)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>
#include <stdlib.h>],[SQLBindCol(0,0,0,0,0,(SQLLEN *)0);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(SQLBINDCOL_SQLLEN,1,Some systems use SQLLEN * in SQLBindCol)],[AC_MSG_RESULT(no)])
		
		AC_MSG_CHECKING(for SQLConnectW)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#include <sqlucode.h>
#include <sqltypes.h>
#include <stdlib.h>],[SQLConnectW(0,NULL,0,NULL,0,NULL,0);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLCONNECTW,1,Some systems have SQLConnectW) ODBCUNICODE="yes"],[AC_MSG_RESULT(no)])
		
		AC_MSG_CHECKING(for SQLROWSETSIZE)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>],[SQLROWSETSIZE a;],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLROWSETSIZE,1,Some systems have SQLROWSETSIZE)],[AC_MSG_RESULT(no)])
		
		AC_MSG_CHECKING(parameters for SQLExtendedFetch)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
extern "C" SQLRETURN SQL_API SQLExtendedFetch(SQLHSTMT statementhandle, SQLUSMALLINT fetchorientation, SQLLEN fetchoffset, SQLULEN *pcrow, SQLUSMALLINT *rgfrowstatus) { return 0; }],[],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(SQLLEN/SQLULEN); AC_DEFINE(HAVE_SQLEXTENDEDFETCH_LEN,1,Some systems have SQLLEN/SQLULEN parameters for SQLExtendedFetch)],[AC_MSG_RESULT(SQLROWOFFSET/SQLROWSETSIZE)])
		
		AC_MSG_CHECKING(parameters for SQLParamOptions)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
extern "C" SQLRETURN SQL_API SQLParamOptions(SQLHSTMT statementhandle, SQLULEN crow, SQLULEN *pirow) { return 0; }],[],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(SQLULEN); AC_DEFINE(HAVE_SQLPARAMOPTIONS_ULEN,1,Some systems have SQLULEN parameters for SQLParamOptions)],[AC_MSG_RESULT(SQLUINTEGER)])

		AC_MSG_CHECKING(for odbcinst.h)
		AC_TRY_COMPILE([#include <odbcinst.h>],[],AC_DEFINE(HAVE_ODBCINST_H, 1, Some systems have odbcinst.h) AC_MSG_RESULT(yes),AC_MSG_RESULT(no))
		
		AC_MSG_CHECKING(for SQLGetPrivateProfileString)
		FW_TRY_LINK([#include <sql.h>
#include <sqlext.h>
#ifdef HAVE_ODBCINST_H
	#include <odbcinst.h>
#endif],[SQLGetPrivateProfileString(0,0,0,0,0,0);],[$ODBCSTATIC $ODBCINCLUDES],[$ODBCLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH:$ODBCLIBSPATH],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_SQLGETPRIVATEPROFILESTRING,1,Some systems have SQLGetPrivateProfileString)],[AC_MSG_RESULT(no)])
	fi

	if ( test -z "$ODBCLIBS" )
	then
		AC_MSG_WARN(ODBC connection support will not be built.)
	fi

	if ( test -z "$ODBCUNICODE" )
	then
		AC_MSG_WARN(unicode support missing... ODBC connection support will not be built.)
	fi

	if ( test -n "$ODBCLIBS" -a -n "$OBCUNICODE" -a -z "$HAVE_ICONV" )
	then
		AC_MSG_WARN(iconv support missing... ODBC connection support will not be built.)
		ODBCLIBS=""
	fi

	if ( test -z "$ODBCLIBS" )
	then
		AC_MSG_WARN(ODBC driver will not be built.)
	fi

	if ( test -n "$ODBCLIBS" )
	then
		FW_INCLUDES(odbc,[$ODBCINCLUDES])
	fi
	if ( test -n "$ODBCLIBS" )
	then
		FW_LIBS(odbc,[$ODBCLIBS])
	fi
		
	AC_SUBST(ODBCINCLUDES)
	AC_SUBST(ODBCLIBS)
	AC_SUBST(ODBCLIBSPATH)
	AC_SUBST(ODBCSTATIC)
	AC_SUBST(ODBCUNICODE)
fi
])



AC_DEFUN([FW_CHECK_DB2],
[
if ( test -z "$DB2ATRUNTIME" )
then
if ( test "$ENABLE_DB2" = "yes" )
then

	DB2INCLUDES=""
	DB2LIBS=""
	DB2LIBSPATH=""
	DB2LIBS32=""
	DB2LIBSPATH32=""
	DB2LIBS64=""
	DB2LIBSPATH64=""
	DB2STATIC=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$DB2PATH" )
		then
			DB2INCLUDES="-I$DB2PATH/include"
			DB2LIBS="-L$DB2PATH/lib -ldb2"
			DB2LIBSPATH="$DB2PATH/lib"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi
		
		if ( test -n "$DB2PATH" )
		then
			FW_CHECK_HEADER_LIB([$DB2PATH/include/sql.h],[DB2INCLUDES=\"-I$DB2PATH/include\"],[$DB2PATH/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"$DB2PATH/lib\"; DB2LIBS=\"-L$DB2PATH/lib -ldb2\"],[$DB2PATH/lib/libdb2.a],[DB2LIBS=\"-L$DB2PATH/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"])
		
		else

			dnl check /opt for 7.1
			FW_CHECK_HEADER_LIB([/opt/IBMdb2/V7.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBMdb2/V7.1/include\"; DB2VERSION=\"7\"],[/opt/IBMdb2/V7.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBMdb2/V7.1/lib\"; DB2LIBS=\"-L/opt/IBMdb2/V7.1/lib -ldb2\"; DB2VERSION=\"7\"],[/opt/IBMdb2/V7.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBMdb2/V7.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"7\"])
		
			dnl check /usr for 7.2
			FW_CHECK_HEADER_LIB([/usr/IBMdb2/V7.1/include/sql.h],[DB2INCLUDES=\"-I/usr/IBMdb2/V7.1/include\"; DB2VERSION=\"7\"],[/usr/IBMdb2/V7.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/usr/IBMdb2/V7.1/lib\"; DB2LIBS=\"-L/usr/IBMdb2/V7.1/lib -ldb2\"; DB2VERSION=\"7\"],[/usr/IBMdb2/V7.1/lib/libdb2.a],[DB2LIBS=\"-L/usr/IBMdb2/V7.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"7\"])
	
			dnl check /opt for 8.1
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V8.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V8.1/include\"; DB2VERSION=\"8\"],[/opt/IBM/db2/V8.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V8.1/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V8.1/lib -ldb2\"; DB2VERSION=\"8\"],[/opt/IBM/db2/V8.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V8.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"8\"])
	
			dnl check /opt for 9.1
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.1/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V9.1/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V9.1/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V9.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.1/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V9.1/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V9.1/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V9.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.1/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.1/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V9.1/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V9.1/lib32 -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.1/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V9.1/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.1/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.1/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V9.1/lib64\"; DB2LIBS=\"-L/opt/IBM/db2/V9.1/lib64 -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.1/lib64/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V9.1/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			fi
	
			dnl check /opt for 9.5
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V9.5/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V9.5/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V9.5/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])

			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V9.5/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V9.5/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V9.5/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V9.5/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V9.5/lib32 -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V9.5/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/IBM/db2/V9.5/lib32\"; DB2LIBS32=\"-L/opt/IBM/db2/V9.5/lib32 -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/IBM/db2/V9.5/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/ibm/db2/V9.5/lib64\"; DB2LIBS64=\"-L/opt/ibm/db2/V9.5/lib64 -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.5/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/ibm/db2/V9.5/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.5/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/IBM/db2/V9.5/lib64\"; DB2LIBS64=\"-L/opt/IBM/db2/V9.5/lib64 -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.5/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/IBM/db2/V9.5/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			fi
	
			dnl check /opt for 9.7
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V9.7/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V9.7/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V9.7/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V9.7/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V9.7/lib -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V9.7/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V9.7/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V9.7/lib32 -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V9.7/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/IBM/db2/V9.7/lib32\"; DB2LIBS32=\"-L/opt/IBM/db2/V9.7/lib32 -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/IBM/db2/V9.7/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/ibm/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/ibm/db2/V9.7/lib64\"; DB2LIBS64=\"-L/opt/ibm/db2/V9.7/lib64 -ldb2\"; DB2VERSION=\"9\"],[/opt/ibm/db2/V9.7/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/ibm/db2/V9.7/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V9.7/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V9.7/include\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/IBM/db2/V9.7/lib64\"; DB2LIBS64=\"-L/opt/IBM/db2/V9.7/lib64 -ldb2\"; DB2VERSION=\"9\"],[/opt/IBM/db2/V9.7/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/IBM/db2/V9.7/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"9\"])
			fi
	
			dnl check /opt for 10.1
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V10.1/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V10.1/lib -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V10.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V10.1/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V10.1/lib -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V10.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V10.1/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V10.1/lib32 -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V10.1/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/IBM/db2/V10.1/lib32\"; DB2LIBS32=\"-L/opt/IBM/db2/V10.1/lib32 -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/IBM/db2/V10.1/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/ibm/db2/V10.1/lib64\"; DB2LIBS64=\"-L/opt/ibm/db2/V10.1/lib64 -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.1/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/ibm/db2/V10.1/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.1/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/IBM/db2/V10.1/lib64\"; DB2LIBS64=\"-L/opt/IBM/db2/V10.1/lib64 -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.1/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/IBM/db2/V10.1/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			fi
	
			dnl check /opt for 10.5
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V10.5/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V10.5/lib -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V10.5/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V10.5/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V10.5/lib -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V10.5/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V10.5/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V10.5/lib32 -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V10.5/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/IBM/db2/V10.5/lib32\"; DB2LIBS32=\"-L/opt/IBM/db2/V10.5/lib32 -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/IBM/db2/V10.5/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/ibm/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/ibm/db2/V10.5/lib64\"; DB2LIBS64=\"-L/opt/ibm/db2/V10.5/lib64 -ldb2\"; DB2VERSION=\"10\"],[/opt/ibm/db2/V10.5/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/ibm/db2/V10.5/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V10.5/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V10.5/include\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/IBM/db2/V10.5/lib64\"; DB2LIBS64=\"-L/opt/IBM/db2/V10.5/lib64 -ldb2\"; DB2VERSION=\"10\"],[/opt/IBM/db2/V10.5/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/IBM/db2/V10.5/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"10\"])
			fi
	
			dnl check /opt for 11.1
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/ibm/db2/V11.1/lib\"; DB2LIBS=\"-L/opt/ibm/db2/V11.1/lib -ldb2\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/ibm/db2/V11.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib/libdb2.$SOSUFFIX],[DB2LIBSPATH=\"/opt/IBM/db2/V11.1/lib\"; DB2LIBS=\"-L/opt/IBM/db2/V11.1/lib -ldb2\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib/libdb2.a],[DB2LIBS=\"-L/opt/IBM/db2/V11.1/lib -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
			FW_CHECK_HEADER_LIB([/opt/ibm/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/ibm/db2/V11.1/lib32\"; DB2LIBS32=\"-L/opt/ibm/db2/V11.1/lib32 -ldb2\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/ibm/db2/V11.1/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
			FW_CHECK_HEADER_LIB([/opt/IBM/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib32/libdb2.$SOSUFFIX],[DB2LIBSPATH32=\"/opt/IBM/db2/V11.1/lib32\"; DB2LIBS32=\"-L/opt/IBM/db2/V11.1/lib32 -ldb2\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib32/libdb2.a],[DB2LIBS32=\"-L/opt/IBM/db2/V11.1/lib32 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
			if ( test "$X64" = "x64" )
			then
				FW_CHECK_HEADER_LIB([/opt/ibm/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/ibm/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/ibm/db2/V11.1/lib64\"; DB2LIBS64=\"-L/opt/ibm/db2/V11.1/lib64 -ldb2\"; DB2VERSION=\"11\"],[/opt/ibm/db2/V11.1/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/ibm/db2/V11.1/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
				FW_CHECK_HEADER_LIB([/opt/IBM/db2/V11.1/include/sql.h],[DB2INCLUDES=\"-I/opt/IBM/db2/V11.1/include\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib64/libdb2.$SOSUFFIX],[DB2LIBSPATH64=\"/opt/IBM/db2/V11.1/lib64\"; DB2LIBS64=\"-L/opt/IBM/db2/V11.1/lib64 -ldb2\"; DB2VERSION=\"11\"],[/opt/IBM/db2/V11.1/lib64/libdb2.a],[DB2LIBS64=\"-L/opt/IBM/db2/V11.1/lib64 -ldb2\"; DB2STATIC=\"$STATICFLAG\"; DB2VERSION=\"11\"])
			fi
		fi

		dnl determine if we need to use the 64 or 32 bit libs
		if ( test -n "$DB2LIBS64" )
		then
			AC_MSG_CHECKING(for 64-bit build)
			FW_TRY_LINK([#include <sqlcli1.h>],[SQLAllocHandle(SQL_HANDLE_ENV,SQL_NULL_HANDLE,NULL);],[$DB2INCLUDES],[$DB2LIBS64],[$DB2LIBSPATH64],[AC_MSG_RESULT(yes); DB2LIBS="$DB2LIBS64"; DB2LIBSPATH="$DB2LIBSPATH64"],[AC_MSG_RESULT(no)])
		fi
		if ( test -n "$DB2LIBS32" )
		then
			AC_MSG_CHECKING(for 32-bit build)
			FW_TRY_LINK([#include <sqlcli1.h>],[SQLAllocHandle(SQL_HANDLE_ENV,SQL_NULL_HANDLE,NULL);],[$DB2INCLUDES],[$DB2LIBS32],[$DB2LIBSPATH32],[AC_MSG_RESULT(yes); DB2LIBS="$DB2LIBS32"; DB2LIBSPATH="$DB2LIBSPATH32"],[AC_MSG_RESULT(no)])
		fi
		if ( test -n "$DB2LIBS" )
		then
			AC_MSG_CHECKING(for build with $DB2LIBS)
			FW_TRY_LINK([#include <sqlcli1.h>],[SQLAllocHandle(SQL_HANDLE_ENV,SQL_NULL_HANDLE,NULL);],[$DB2INCLUDES],[$DB2LIBS],[$DB2LIBSPATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); DB2INCLUDES=""; DB2LIBS=""; DB2LIBSPATH=""])
		fi
	fi

	if ( test -z "$DB2LIBS" )
	then
		AC_MSG_WARN(DB2 support will not be built.)
		ENABLE_DB2=""
	fi

	if ( test -n "$DB2LIBS" )
	then
		FW_VERSION(db2,[$DB2VERSION])
	fi

	FW_INCLUDES(db2,[$DB2INCLUDES])
	FW_LIBS(db2,[$DB2LIBS])
		
	AC_SUBST(DB2INCLUDES)
	AC_SUBST(DB2LIBS)
	AC_SUBST(DB2LIBSPATH)
	AC_SUBST(DB2STATIC)
	AC_DEFINE_UNQUOTED(DB2VERSION,$DB2VERSION,Version of DB2)
fi
fi
if ( test "$DB2ATRUNTIME" = "yes" )
then
	AC_MSG_NOTICE(DB2 libraries will be loaded at runtime.)
	AC_DEFINE(DB2_AT_RUNTIME,1,Load DB2 libraries at runtime.)
fi
AC_SUBST(ENABLE_DB2)
])



AC_DEFUN([FW_CHECK_INFORMIX],
[
if ( test -z "$INFORMIXATRUNTIME" )
then
if ( test "$ENABLE_INFORMIX" = "yes" )
then
	INFORMIXINCLUDES=""
	INFORMIXLIBS=""
	INFORMIXCLILIBSPATH=""
	INFORMIXESQLLIBSPATH=""
	INFORMIXSTATIC=""

	for dir in \
		"$INFORMIXPATH" \
		"$INFORMIXDIR" \
		"/opt/informix" \
		"/opt/IBM/informix" \
		"/home/informix" \
		"/usr/local/informix"
	do
		if ( test -z "$dir" )
		then
			continue
		fi

		if ( test -d "$dir" )
		then
			FW_CHECK_HEADER_LIB([$dir/incl/cli/infxsql.h],[INFORMIXINCLUDES=\"-I$dir/incl/cli\"],[$dir/lib/cli/libifcli.$SOSUFFIX],[INFORMIXLIBS=\"-L$dir/lib/cli -lifcli\"],[$dir/lib/cli/libifcli.a],[INFORMIXLIBS=\"$dir/lib/cli/libifcli.a\"; INFORMIXSTATIC=\"yes\"])

			if ( test -n "$INFORMIXLIBS" )
			then
				if ( test -d "$dir/lib/cli" )
				then
					INFORMIXCLILIBSPATH="$dir/lib/cli"
				fi
				if ( test -d "$dir/lib/esql" )
				then
					INFORMIXESQLLIBSPATH="$dir/lib/esql"
				fi
				break
			fi
		fi
	done

	dnl On some platforms (opensuse), rpaths get excluded if libraries in
	dnl that path aren't linked in, so if we're using rpath and we have an
	dnl esql path, then add the esql path and add the libs that will get
	dnl linked in from it.
	dnl FIXME: Arguably we should test for those libs too.
	if ( test "$INFORMIXUSERPATH" = "yes" -a -n "$INFORMIXESQLLIBSPATH" )
	then
		INFORMIXLIBS="$INFORMIXLIBS -L$INFORMIXESQLLIBSPATH -lifgls -lifglx"
	fi

	if ( test -z "$INFORMIXLIBS" )
	then
		AC_MSG_WARN(Informix support will not be built.)
		ENABLE_INFORMIX=""
	fi

	FW_INCLUDES(informix,[$INFORMIXINCLUDES])
	FW_LIBS(informix,[$INFORMIXLIBS])

	AC_SUBST(INFORMIXINCLUDES)
	AC_SUBST(INFORMIXLIBS)
	AC_SUBST(INFORMIXCLILIBSPATH)
	AC_SUBST(INFORMIXESQLLIBSPATH)
	AC_SUBST(INFORMIXUSERPATH)
fi
fi
if ( test "$INFORMIXATRUNTIME" = "yes" )
then
	AC_MSG_NOTICE(Informix libraries will be loaded at runtime.)
	AC_DEFINE(INFORMIX_AT_RUNTIME,1,Load Informix libraries at runtime.)
fi
AC_SUBST(ENABLE_INFORMIX)
])



AC_DEFUN([FW_CHECK_FIREBIRD],
[
if ( test "$ENABLE_FIREBIRD" = "yes" )
then

	FIREBIRDINCLUDES=""
	FIREBIRDLIBS=""
	FIREBIRDLIBSPATH=""
	FIREBIRDSTATIC=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling"
		if ( test -n "$FIREBIRDPATH" )
		then
			FIREBIRDINCLUDES="-I$FIREBIRDPATH/include"
			FIREBIRDLIBS="-L$FIREBIRDPATH/lib -lgds"
			FIREBIRDLIBSPATH="$FIREBIRDPATH/lib"
		fi

	else

		STATICFLAG=""
		if ( test -n "$STATICLINK" )
		then
			STATICFLAG="-static"
		fi
		
		FW_CHECK_HEADERS_AND_LIBS([$FIREBIRDPATH],[interbase],[ibase.h],[gds],[$STATICFLAG],[$RPATHFLAG],[FIREBIRDINCLUDES],[FIREBIRDLIBS],[FIREBIRDLIBSPATH],[FIREBIRDSQLSTATIC])
		FW_CHECK_HEADERS_AND_LIBS([$FIREBIRDPATH],[firebird],[ibase.h],[gds],[$STATICFLAG],[$RPATHFLAG],[FIREBIRDINCLUDES],[FIREBIRDLIBS],[FIREBIRDLIBSPATH],[FIREBIRDSQLSTATIC])
		FW_CHECK_HEADERS_AND_LIBS([$FIREBIRDPATH],[firebird],[ibase.h],[fbclient],[$STATICFLAG],[$RPATHFLAG],[FIREBIRDINCLUDES],[FIREBIRDLIBS],[FIREBIRDLIBSPATH],[FIREBIRDSQLSTATIC])
		if ( test -n "$FIREBIRDLIBS" )
		then
			FIREBIRDLIBS="$FIREBIRDLIBS -lcrypt"
		fi

		if ( test -z "$FIREBIRDLIBS" )
		then
			FW_CHECK_HEADER_LIB([/Library/Frameworks/Firebird.framework/Versions/Current/Headers/ibase.h],[FIREBIRDINCLUDES=\"-I/Library/Frameworks/Firebird.framework/Versions/Current/Headers\"],[/Library/Frameworks/Firebird.framework/Versions/Current/Firebird],[FIREBIRDLIBS=\"-framework Firebird\"],[],[])
		fi
		
		LINKFAIL=""
		if ( test -n "$DLLIB" -a -n "$FIREBIRDSTATIC" -a -n "$FIREBIRDLIBS" )
		then
			AC_MSG_CHECKING(if Firebird can be statically linked without $DLLIB)
			FW_TRY_LINK([#include <ibase.h>
	#include <stdlib.h>],[isc_db_handle db=0; isc_attach_database(NULL,0,"",&db,0,NULL);],[$FIREBIRDSTATIC $FIREBIRDINCLUDES],[$FIREBIRDLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Firebird can be statically linked with $DLLIB)
				FW_TRY_LINK([#include <ibase.h>
#include <stdlib.h>],[isc_db_handle db=0; isc_attach_database(NULL,0,"",&db,0,NULL);],[$FIREBIRDSTATIC $FIREBIRDINCLUDES],[$FIREBIRDLIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); FIREBIRDLIBS="$FIREBIRDLIBS $DLLIB"; LINKFAIL="";],[AC_MSG_RESULT(no); FIREBIRDSTATIC=""])
			fi
		fi
		
		if ( test -n "$DLLIB" -a -z "$FIREBIRDSTATIC" -a -n "$FIREBIRDLIBS" )
		then
			AC_MSG_CHECKING(if Firebird can be dynamically linked without $DLLIB)
			FW_TRY_LINK([#include <ibase.h>
#include <stdlib.h>],[isc_db_handle db=0; isc_attach_database(NULL,0,"",&db,0,NULL);],[$FIREBIRDINCLUDES],[$FIREBIRDLIBS $SOCKETLIBS],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); LINKFAIL="yes"])
			if ( test -n "$LINKFAIL" -a -n "$DLLIB" )
			then
				AC_MSG_CHECKING(if Firebird can be dynamically linked with $DLLIB)
				FW_TRY_LINK([#include <ibase.h>
#include <stdlib.h>],[isc_db_handle db=0; isc_attach_database(NULL,0,"",&db,0,NULL);],[$FIREBIRDINCLUDES],[$FIREBIRDLIBS $SOCKETLIBS $DLLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes); FIREBIRDLIBS="$FIREBIRDLIBS $DLLIB"; LINKFAIL=""],[AC_MSG_RESULT(no)])
			fi
		fi
		
		if ( test -n "$LINKFAIL" )
		then
			AC_MSG_WARN(No Firebird link configuration could be found.)
			FIREBIRDINCLUDES=""
			FIREBIRDLIBS=""
			FIREBIRDSTATIC=""
		fi
		
		if ( test -z "$FIREBIRDLIBS" )
		then
			AC_MSG_WARN(Firebird support will not be built.)
		fi
	fi

	dnl freebsd + firebird 2.0.3 segfaults on isc_attach_database,
	dnl when linked with -lfbclient, but works with -lgds
	if ( test -n "$FIREBIRDLIBS" -a -n "`uname -a 2> /dev/null | grep FreeBSD`" -a -n "`pkg_info 2> /dev/null | grep firebird-client | grep 2\.0\.3`" )
	then
		FIREBIRDLIBS=`echo "$FIREBIRDLIBS" | sed -e "s|fbclient|gds|g"`
		AC_MSG_WARN(replacng -lfbclient with -lgds on FreeBSD/Firebird-2.0.3)
	fi

	FW_INCLUDES(firebird,[$FIREBIRDINCLUDES])
	FW_LIBS(firebird,[$FIREBIRDLIBS])

	AC_SUBST(FIREBIRDINCLUDES)
	AC_SUBST(FIREBIRDLIBS)
	AC_SUBST(FIREBIRDLIBSPATH)
	AC_SUBST(FIREBIRDSTATIC)
fi
])



AC_DEFUN([FW_CHECK_PERL],
[
if ( test "$ENABLE_PERL" = "yes" )
then

	HAVE_PERL=""
	PERL=""
	PERLLIB=""
	PERLLIBS=""
	PERLPREFIX=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		if ( test -n "$PERLPATH" )
		then
			FW_CHECK_FILE("$PERLPATH/bin/perl",[PERL=\"$PERLPATH/bin/perl\"; HAVE_PERL=\"yes\"])
		else
			AC_CHECK_PROG(PERL,perl,"perl")
			if ( test -z "$PERL" )
			then
				for i in \
					"/usr/bin" \
					"/usr/local/bin" \
					"/usr/pkg/bin" \
					"/usr/local/perl/bin" \
					"/opt/sfw/bin" \
					"/usr/sfw/bin" \
					"/opt/csw/bin" \
					"/sw/bin" \
					"/usr/freeware/bin" \
					"/boot/common/bin" \
					"/resources/index/bin"
				do
					if ( test -d "$i" )
					then
						PERL=""
						FW_CHECK_FILE("$i/perl5",[PERL=\"$i/perl5\"])
						FW_CHECK_FILE("$i/perl",[PERL=\"$i/perl\"])
						if ( test -n "$PERL" )
						then
							break
						fi
					fi
				done
			fi
		fi

		dnl for cygwin and early mac os x add -lperl
		if ( test -n "$PERL" )
		then
			if ( test -n "$CYGWIN" )
			then
				DIRS=`$PERL -e 'foreach (@INC) { print("$_\n"); }'`
				for dir in $DIRS
				do
					FW_CHECK_FILE("$dir/CORE/libperl.$SOSUFFIX",[PERLLIBS=\"-L$dir/CORE -lperl\"])
				done
			elif ( test -n "$DARWIN" )
			then
				if ( test -z "$BUNDLE_LOADER" -a -z "$UNDEFINED_DYNAMIC_LOOKUP" )
				then
					DIRS=`perl -e 'foreach (@INC) { print("$_\n"); }'`
					for dir in $DIRS
					do
						FW_CHECK_FILE("$dir/CORE/libperl.$SOSUFFIX",[PERLLIBS=\"-L$dir/CORE -lperl\"])
					done
				elif ( test -n "$BUNDLE_LOADER" )
				then
					if ( test ! -r "$PERL" )
					then
						PERL="`which $PERL`"
					fi
					PERLLIBS="-Wl,$BUNDLE_LOADER -Wl,$PERL"
				else
					DIRS=`$PERL -e 'foreach (@INC) { print("$_\n"); }'`
					for dir in $DIRS
					do
						FW_CHECK_FILE("$dir/CORE/libperl.$SOSUFFIX",[PERLLIBS=\"-L$dir/CORE -lperl\"])
					done
				fi
			fi
		fi

		AC_MSG_CHECKING(for xsubpp)
		XSUBPP=""
		if ( test -n "$PERL" )
		then
			if ( test -z "`$PERL -V 2>&1 | grep Unrecognized`" )
			then
				PERLPREFIXCMD=`$PERL -V:prefix`
				PERLLIBCMD=`$PERL -V:privlibexp`
				PERLCCFLAGSCMD=`$PERL -V:ccflags`
				PERLOPTIMIZECMD=`$PERL -V:optimize`
				PERLSITEARCHCMD=`$PERL -V:sitearch`
				PERLSITELIBCMD=`$PERL -V:sitelib`
				PERLARCHLIBEXPCMD=`$PERL -V:archlibexp`
				PERLINSTALLMAN3DIRCMD=`$PERL -V:installman3dir`
				PERLMAN3EXTCMD=`$PERL -V:man3ext`

				PERLPREFIX=`eval "$PERLPREFIXCMD"; echo $prefix`
				PERLLIB=`eval "$PERLLIBCMD"; echo $privlibexp`
				PERLCCFLAGS=`eval "$PERLCCFLAGSCMD"; echo $ccflags`
				PERLOPTIMIZE=`eval "$PERLOPTIMIZECMD"; echo $optimize`
				PERLSITEARCH=`eval "$PERLSITEARCHCMD"; echo $sitearch`
				PERLSITELIB=`eval "$PERLSITELIBCMD"; echo $sitelib`
				PERLARCHLIBEXP=`eval "$PERLARCHLIBEXPCMD"; echo $archlibexp`
				PERLINC="-I$PERLARCHLIBEXP/CORE"
				PERLINSTALLMAN3DIR=`eval "$PERLINSTALLMAN3DIRCMD"; echo $installman3dir`
				PERLMAN3EXT=`eval "$PERLMAN3EXTCMD"; echo $man3ext`
			else
				PERLFPN=`which $PERL 2> /dev/null`
				PERLPREFIX=`dirname $PERLFPN | sed -e "s|/bin||g"`
				PERLLIB=$PERLPREFIX/lib/perl5
				PERLCCFLAGS=""
				PERLOPTIMIZE=""
				PERLSITEARCH=`ls -d $PERLLIB/*-* 2> /dev/null | head -1`
				PERLSITELIB=$PERLLIB
				PERLARCHLIBEXP=$PERLSITEARCH
				PERLINC="-I$PERLARCHLIBEXP/CORE"
				PERLINSTALLMAN3DIR=$PERLPREFIX/man/man3
				PERLMAN3EXT=3
				PERLREALLYOLD="-DPERLREALLYOLD"
			fi
			XSUBPP=$PERLLIB/ExtUtils/xsubpp
			if ( test ! -r "$XSUBPP" )
			then
				XSUBPP="$PERLPREFIX/bin/xsubpp"
			fi
			if ( test -n "`pod2man --help 2>&1 | grep Usage`" )
			then
				POD2MAN="pod2man"
			fi
			if ( test -n "`$PERL -v | grep version | grep 5\.00`" )
			then
				PERL500="-DPERL500"
			fi
		fi

		if ( test -r "$XSUBPP" )
		then
			AC_MSG_RESULT($XSUBPP)
			HAVE_PERL="yes"
		else
			AC_MSG_RESULT(not found)
			AC_MSG_WARN(xsubpp not found)
			AC_MSG_WARN(The Perl API will not be built.)
		fi
	fi

	dnl on mac os x with -undefined dynamic_loader, add that to PERLLIBS
	if ( test -n "$UNDEFINED_DYNAMIC_LOOKUP" )
	then
		PERLLIBS="$UNDEFINED_DYNAMIC_LOOKUP"
	fi

	if ( test -z "$HAVE_PERL" )
	then
		AC_MSG_CHECKING(for sys/vnode.h)
		AC_TRY_COMPILE([#include <sys/vnode.h>],[],AC_DEFINE(SQLRELAY_HAVE_SYS_VNODE_H, 1, Some systems have sys/vnode.h) AC_MSG_RESULT(yes),AC_MSG_RESULT(no))
	fi

	AC_SUBST(HAVE_PERL)
	AC_SUBST(PERL)
	AC_SUBST(PERLLIB)
	AC_SUBST(PERLLIBS)
	AC_SUBST(PERLCCFLAGS)
	AC_SUBST(PERLOPTIMIZE)
	AC_SUBST(PERLSITEARCH)
	AC_SUBST(PERLSITELIB)
	AC_SUBST(PERLARCHLIBEXP)
	AC_SUBST(PERLINC)
	AC_SUBST(PERLINSTALLMAN3DIR)
	AC_SUBST(PERLMAN3EXT)
	AC_SUBST(PERLPREFIX)
	AC_SUBST(XSUBPP)
	AC_SUBST(POD2MAN)
	AC_SUBST(PERL500)
	AC_SUBST(PERLREALLYOLD)
fi
])



AC_DEFUN([FW_CHECK_PYTHON],
[
if ( test "$ENABLE_PYTHON" = "yes" )
then

	OVERRIDEPYTHONDIR="$PYTHONDIR"

	HAVE_PYTHON=""
	PYTHONINCLUDES=""
	PYTHONDIR=""
	PYTHONSITEDIR=""
	PYTHONLIB=""
	PYTHONVERSION=""
	PYTHON=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		pyext=""

		for pyversion in \
				"3.20" \
				"3.19" \
				"3.18" \
				"3.17" \
				"3.16" \
				"3.15" \
				"3.14" \
				"3.13" \
				"3.12" \
				"3.11" \
				"3.10" \
				"3.9" \
				"3.8" \
				"3.7" \
				"3.6" \
				"3.5" \
				"3.4" \
				"3.3" \
				"3.2" \
				"3.1" \
				"3.0" \
				"2.9" \
				"2.8" \
				"2.7" \
				"2.6" \
				"2.5" \
				"2.4" \
				"2.3" \
				"2.2" \
				"2.1"
		do

			for pyprefix in \
				"$PYTHONPATH" \
				"/usr" \
				"/usr/local" \
				"/usr/pkg" \
				"/usr/local/python$pyversion" \
				"/opt/sfw" \
				"/usr/sfw" \
				"/opt/csw" \
				"/sw" \
				"/usr/freeware" \
				"/System/Library/Frameworks/Python.framework/Versions/Current" \
				"/boot/common"
			do

				if ( test -n "$pyprefix" )
				then

					for pyexe in \
						"python$pyversion$pyext" \
						"python$PYTHONVERSION$pyext" \
						"python$pyversion" \
						"python$PYTHONVERSION" "python"
					do
						if ( test -x "$pyprefix/bin/$pyexe" )
						then
							PYTHON="$pyprefix/bin/$pyexe"

							dnl on mac os x with -bundle_loader, set PYTHONLIB
							if ( test -n "$BUNDLE_LOADER" )
							then
								PYTHONLIB="-Wl,$BUNDLE_LOADER -Wl,$PYTHON"
							fi

							break
						fi
					done

					PYTHONINCLUDES=""
					for ext in "mu" "m" "u" ""
					do
						if ( test -d "$pyprefix/include/python$pyversion$ext" )
						then
							PYTHONINCLUDES="-I$pyprefix/include/python$pyversion$ext"
							PYTHONVERSION=`echo $pyversion | sed -e "s|\.||"`
							PYTHONMAJOR=`echo $pyversion | cut -d'.' -f1`
							PYTHONMINOR=`echo $pyversion | cut -d'.' -f2`
							pyext="$ext"
							break;
						fi
					done

					for pylibdir in \
						"$pyprefix/lib64/python$pyversion" \
						"$pyprefix/lib/python$pyversion"
					do

						PYTHONDIR=""
						for k in \
							"config" \
							"config-$MULTIARCHDIR" \
							"config-$pyversion-$MULTIARCHDIR" \
							"config-$pyversion" \
							"config-${pyversion}mu-$MULTIARCHDIR" \
							"config-${pyversion}mu" \
							"config-${pyversion}m-$MULTIARCHDIR" \
							"config-${pyversion}m" \
							"config-${pyversion}u-$MULTIARCHDIR" \
							"config-${pyversion}u"
						do

							if ( test -d "$pylibdir/$k" )
							then
								PYTHONDIR="$pylibdir"

								dnl for cygwin and early mac os x, add -lpython or similar
								if ( test -n "$CYGWIN" -a -r "$pylibdir/$k/libpython$pyversion.dll.a" )
								then
									PYTHONLIB="-L$PYTHONDIR/$k -lpython$pyversion"
								elif ( test -n "$DARWIN" -a -z "$BUNDLE_LOADER" -a -z "$UNDEFINED_DYNAMIC_LOOKUP" )
								then
									PYTHONLIB="-L$PYTHONDIR/$k -lpython$pyversion"
								fi
								if ( test -n "$PYTHONDIR" )
								then
									break
								fi
							fi
						done
						if ( test -n "$PYTHONDIR" )
						then
							break
						fi
					done

					if ( test -n "$PYTHONINCLUDES" -a -n "$PYTHONDIR" )
					then
						dnl override PYTHONDIR on osx in some cases
						if ( test -d "/Library/Python/$pyversion/site-packages" )
						then
							PYTHONDIR="/Library/Python/$pyversion"
						fi
						break
					fi
				fi

			done

			if ( test -n "$PYTHONINCLUDES" -a -n "$PYTHONDIR" )
			then
				break
			fi

		done

		if ( test -n "$PYTHONINCLUDES" -a -n "$PYTHONDIR" )
		then
			AC_MSG_CHECKING(for Python.h)
			FW_TRY_COMPILE([#include <Python.h>],[PyArg_ParseTuple(NULL,NULL,NULL,NULL,NULL);],[$PYTHONINCLUDES],[AC_MSG_RESULT(yes)],[AC_MSG_RESULT(no); PYTHONINCLUDES=""; PYTHONDIR=""])
		fi
		
		if ( test -n "$PYTHONINCLUDES" -a -n "$PYTHONDIR" )
		then
			HAVE_PYTHON="yes"

			dnl dist-packages or site-packages?  Ubuntu/Debian
			dnl use dist-packages.  Others use site-packages.
			if ( test -d "$PYTHONDIR/dist-packages" )
			then
				PYTHONSITEDIR="dist-packages"
			elif ( test -d "$PYTHONDIR/site-packages" )
			then
				PYTHONSITEDIR="site-packages"
			fi
			if ( test -z "$PYTHONSITEDIR" )
			then
				if ( test -r "/etc/debian_version" )
				then
					PYTHONSITEDIR="dist-packages"
				else
					PYTHONSITEDIR="site-packages"
				fi
			fi
		fi
	fi

	dnl on mac os x, add -framework Python to the includes
	if (test -n "$DARWIN" )
	then
		PYTHONINCLUDES="-framework Python $PYTHONINCLUDES"
	fi

	dnl on mac os x with -undefined dynamic_loader, add that to PYTHONLIB
	if ( test -n "$UNDEFINED_DYNAMIC_LOOKUP" )
	then
		PYTHONLIB="$PYTHONLIB $UNDEFINED_DYNAMIC_LOOKUP"
	fi

	dnl Python 3.10+ requires PY_SSIZE_T_CLEAN to be defined before
	dnl including Python.h, so we'll set a flag 
	if ( test "$PYTHONMAJOR" -ge "3" )
	then
		if ( test "$PYTHONMAJOR" -gt "3" -o "$PYTHONMINOR" -ge "10" )
		then
			AC_DEFINE(SQLRELAY_NEED_PY_SSIZE_T_CLEAN, 1, Some systems have Python 3.10+)
		fi
        fi

	FW_INCLUDES(python,[$PYTHONINCLUDES])
	FW_LIBS(python,[$PYTHONLIB])

	if ( test -n "$OVERRIDEPYTHONDIR" )
	then
		PYTHONDIR="$OVERRIDEPYTHONDIR"
	fi

	AC_SUBST(HAVE_PYTHON)
	AC_SUBST(PYTHONINCLUDES)
	AC_SUBST(PYTHONDIR)
	AC_SUBST(PYTHONSITEDIR)
	AC_SUBST(PYTHONLIB)
	AC_SUBST(PYTHON)
	AC_SUBST(PYTHONFRAMEWORK)


	dnl some flags for the python tests
	IMPORTEXCEPTIONS=""
	EXCEPTIONSSTANDARDERROR="Exception"
	if ( test "$PYTHONMAJOR" = "2" )
	then
		IMPORTEXCEPTIONS="import exceptions"
		EXCEPTIONSSTANDARDERROR="exceptions.StandardError"
	fi
	AC_SUBST(IMPORTEXCEPTIONS)
	AC_SUBST(EXCEPTIONSSTANDARDERROR)


	if ( test "$HAVE_PYTHON" = "" )
	then
		AC_MSG_WARN(The Python API will not be built.)
	fi
fi
])



AC_DEFUN([FW_CHECK_RUBY],
[
if ( test "$ENABLE_RUBY" = "yes" )
then

	HAVE_RUBY=""
	RUBY=""
	RUBYLIB=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		found="no"

		for major in "" "1" "2" "3"
		do

			for minor in \
				"" \
				"9" \
				"8" \
				"7" \
				"6" \
				"5" \
				"4" \
				"3" \
				"2" \
				"1" \
				"0"
			do

				for patchlevel in \
						"" \
						"0" \
						"1" \
						"2" \
						"3" \
						"4" \
						"5" \
						"6" \
						"7" \
						"8" \
						"9"
				do

					for separator in "" "."
					do

						ruby="ruby$major$separator$minor"
						if ( test -n "$patchlevel" )
						then
							ruby="ruby$major$separator$minor$separator$patchlevel"
						fi

						HAVE_RUBY=""
						RUBY=""
						RUBYLIB=""

						if ( test -n "$RUBYPATH" )
						then
							FW_CHECK_FILE("$RUBYPATH/bin/$ruby",[RUBY=\"$RUBYPATH/bin/$ruby\"])
						else
							AC_CHECK_PROG(RUBY,"$ruby","$ruby")
							if ( test -z "$RUBY" )
							then
								for i in "/usr/local/ruby/bin" "/usr/bin" "/usr/local/bin" "/usr/pkg/bin" "/opt/sfw/bin" "/usr/sfw/bin" "/opt/csw/bin" "/sw/bin" "/usr/freeware/bin" "/boot/common/bin" "/resources/index/bin"
								do
									FW_CHECK_FILE("$i/$ruby",[RUBY=\"$i/$ruby\"])
									if ( test -n "$RUBY" )
									then
										found="yes"
										break
									fi
								done
							fi
						fi

						if ( test -n "$RUBY" )
						then
							HAVE_RUBY="yes"

							dnl for cygwin and early mac os x, add -lruby
							if ( test -n "$CYGWIN" )
							then
								dnl FIXME: we really should include a -L option
								RUBYLIB="-lruby"
							elif ( test -n "$DARWIN" )
							then
								if ( test -n "$UNDEFINED_DYNAMIC_LOOKUP" )
								then
									RUBYLIB="$UNDEFINED_DYNAMIC_LOOKUP"
								elif ( test -n "$BUNDLE_LOADER" )
								then
									RUBYLIB="-Wl,$BUNDLE_LOADER -Wl,$RUBY"
								else
									dnl FIXME: we really should include a -L option
									RUBYLIB="-lruby"
								fi
							fi

							found="yes"
							break
						fi

						if ( test -z "$major" -o -z "$minor" -o -z "$patchlevel" )
						then
							break
						fi

					done
					if ( test "$found" = "yes" )
					then
						break
					fi
					if ( test -z "$minor" )
					then
						break
					fi
				done
				if ( test "$found" = "yes" )
				then
						break
				fi
				if ( test -z "$major" )
				then
					break
				fi
			done
			if ( test "$found" = "yes" )
			then
				break
			fi
		done

		if ( test -n "$HAVE_RUBY" )
		then
			rm -f conftest.rb
			cat > conftest.rb << END
require "mkmf"
drive = File::PATH_SEPARATOR == ";" ? /\A\w:/ : /\A/
print "\n"
print "arch = "
print CONFIG@<:@"arch"@:>@
print "\n"
print "ruby_version = "
begin
print Config::CONFIG@<:@"ruby_version"@:>@
rescue
print CONFIG@<:@"ruby_version"@:>@
end
print "\n"
print "prefix = "
print CONFIG@<:@"prefix"@:>@.sub(drive, "")
print "\n"
print "exec_prefix = "
print CONFIG@<:@"exec_prefix"@:>@.sub(drive, "")
print "\n"
print "libdir = "
print \$libdir.sub(drive, "")
print "\n"
print "rubylibdir = "
print \$rubylibdir.sub(drive, "")
print "\n"
print "topdir = "
print \$topdir
print "\n"
print "hdrdir = "
print \$hdrdir
print "\n\n"
print "all:\n"
print "	echo \$(hdrdir)\n"
END

			AC_MSG_CHECKING(for ruby.h)
			HAVE_RUBY_H=""
			for dir in `eval $RUBY conftest.rb 2>/dev/null | sed -e "s|-x.* | |g" -e "s|-belf||g" -e "s|-mtune=.* | |g" | $MAKE -s -f - 2> /dev/null | grep -v Entering | grep -v Leaving`
			do
				if ( test -r "$dir/ruby.h" )
				then
					HAVE_RUBY_H="yes"
				fi
			done
			if ( test -z "$HAVE_RUBY_H" )
			then
				AC_MSG_RESULT(no)
				dnl if we didn't have ruby.h
				dnl then we don't have ruby
				HAVE_RUBY=""
			else
				AC_MSG_RESULT(yes)
			fi

			AC_MSG_CHECKING(for ruby/thread.h)
			HAVE_RUBY_THREAD_H=""
			for dir in `eval $RUBY conftest.rb 2>/dev/null | sed -e "s|-x.* | |g" -e "s|-belf||g" -e "s|-mtune=.* | |g" | $MAKE -s -f - 2> /dev/null | grep -v Entering | grep -v Leaving`
			do
				if ( test -r "$dir/ruby/thread.h" )
				then
					HAVE_RUBY_THREAD_H="yes"
				fi
			done
			if ( test -z "$HAVE_RUBY_THREAD_H" )
			then
				AC_MSG_RESULT(no)
			else
				AC_MSG_RESULT(yes)
			fi

			rm -f conftest.rb
		fi
	fi

	if ( test -z "$HAVE_RUBY" )
	then
		AC_MSG_WARN(The Ruby API will not be built.)
	fi

	if ( test -n "$HAVE_RUBY_THREAD_H" )
	then
		AC_DEFINE(HAVE_RUBY_THREAD_H,1,Some versions of Ruby have ruby/thread.h)
	fi

	AC_SUBST(HAVE_RUBY)
	AC_SUBST(RUBY)
	AC_SUBST(RUBYLIB)
fi
])



AC_DEFUN([FW_CHECK_JAVA],
[
if ( test "$ENABLE_JAVA" = "yes" )
then

	HAVE_JAVA=""
	JAVAC=""
	JAVAINCLUDES=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else
		
		if ( test -z "$JAVAPATH" )
		then
			for i in \
`ls -d /etc/alternatives/java_sdk /usr/java/jdk* /usr/java/j2sdk* /usr/local/jdk* 2> /dev/null` \
/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK \
/System/Library/Frameworks/JavaVM.framework/Versions/Current \
/usr/java \
/usr/local/java \
`ls -d /usr/local/openjdk* /usr/pkg/java/openjdk* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.14* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.13* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.12* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.11* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.10* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.9* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.8* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.7* 2> /dev/null` \
`ls -d /usr/lib64/jvm/java-1.6* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-7-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-8-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-9-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-10-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-11-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-12-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-13-* 2> /dev/null` \
`ls -d /usr/lib64/jvm/jdk-14-* 2> /dev/null` \
`ls -d /usr/lib/jvm/java 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.14* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.13* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.12* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.11* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.10* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.9* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.8* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.7* 2> /dev/null` \
`ls -d /usr/lib/jvm/java-1.6* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-7-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-8-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-9-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-10-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-11-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-12-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-13-* 2> /dev/null` \
`ls -d /usr/lib/jvm/jdk-14-* 2> /dev/null` \
/usr \
/usr/local
			do
				FW_CHECK_FILE("$i/bin/javac$EXE",[JAVAPATH=\"$i\"])
				if ( test -z "$JAVAPATH" )
				then
					FW_CHECK_FILE("$i/Commands/javac$EXE",[JAVAPATH=\"$i\"])
				fi
				if ( test -n "$JAVAPATH" )
				then
					break
				fi
			done
		fi
		
		if ( test -n "$JAVAPATH" )
		then
			FW_CHECK_FILE("$JAVAPATH/bin/javac$EXE",[JAVAC=\"$JAVAPATH/bin/javac$EXE\"])
			FW_CHECK_FILE("$JAVAPATH/Commands/javac$EXE",[JAVAC=\"$JAVAPATH/Commands/javac$EXE\"])
			if ( test "`basename $CXX`" = "g++3" )
			then
				FW_CHECK_FILE("$JAVAPATH/bin/gcj3$EXE",[JAVAC=\"$JAVAPATH/bin/gcj3$EXE -C\"])
			else
				FW_CHECK_FILE("$JAVAPATH/bin/gcj$EXE",[JAVAC=\"$JAVAPATH/bin/gcj$EXE -C\"])
			fi
			FW_CHECK_FILE("$JAVAPATH/bin/jar$EXE",[JAR=\"$JAVAPATH/bin/jar$EXE\"])
			FW_CHECK_FILE("$JAVAPATH/Commands/jar$EXE",[JAR=\"$JAVAPATH/Commands/jar$EXE\"])
			if ( test "$JAVAPATH" != "/usr" )
			then
				FW_CHECK_FILE("$JAVAPATH/include/jni.h",[JAVAINCLUDES=\"-I$JAVAPATH/include\"])
			fi
			FW_CHECK_FILE("$JAVAPATH/Headers/jni.h",[JAVAINCLUDES=\"-I$JAVAPATH/Headers\"])
			if ( test -n "$JAVAINCLUDES" -a "$JAVAPATH" != "/usr" )
			then
				for i in `ls -d $JAVAPATH/include/* $JAVAPATH/Headers/* 2> /dev/null`
				do
					if ( test -d "$i" )
					then
						JAVAINCLUDES="$JAVAINCLUDES -I$i"
					fi
				done
			fi
		fi

		if ( test -n "$JAVAC" -a -n "$JAR" )
		then
			HAVE_JAVA="yes"
		fi
	fi

	dnl if java is really kaffe then don't use it
	if ( test -n "`grep kaffe $JAVAC | grep exec | grep Main`" )
	then
		AC_MSG_WARN(javac appears to use kaffe, which is not supported)
		HAVE_JAVA=""
	fi

	dnl if java is really gcj 2.x then don't use it
	if ( test "`basename $JAVAC 2> /dev/null`" = "gcj" -a "`$JAVAC --version 2>/dev/null | cut -d'.' -f1`" = "2" )
	then
		AC_MSG_WARN(javac appears to be gcj 2.xx, which is not supported)
		HAVE_JAVA=""
	fi

	if ( test -n "$HAVE_JAVA" )
	then
		AC_MSG_CHECKING(whether $JAVAC works)
		cat << EOF > conftest.java
public class conftest {
	public static void main(String[] args) {
		System.out.println("hello world");
	}
}
EOF
		$JAVAC conftest.java 2> /dev/null
		if ( test -r "conftest.class" )
		then
			AC_MSG_RESULT(yes)
			rm -f conftest.class
		else
			AC_MSG_RESULT(no)
			HAVE_JAVA=""
		fi
		rm -f conftest.java
	fi

	if ( test -n "$HAVE_JAVA" )
	then
		FW_TRY_COMPILE([#ifdef __CYGWIN__
#include <windows.h>
#endif
#include <jni.h>],[JNIEnv *env; jobjectArray a=(jobjectArray)env->NewObjectArray(0,NULL,NULL);],[$JAVAINCLUDES],[AC_DEFINE(CAST_NEW_OBJECT_ARRAY,1,On some platforms NewObjectArray requires a cast)],[])
	else
		AC_MSG_WARN(The Java API will not be built.)
	fi

	FW_INCLUDES(java,[$JAVAINCLUDES])

	CURSORCLASSPATH=""
	if ( test "$HAVE_SCO_UW" = "" )
	then
		CURSORCLASSPATH="-classpath \$(top_builddir)/src/api/java"
	fi
		
	AC_SUBST(HAVE_JAVA)
	AC_SUBST(JAVAC)
	AC_SUBST(JAR)
	AC_SUBST(JAVAINCLUDES)
	AC_SUBST(CURSORCLASSPATH)
fi
])


AC_DEFUN([FW_CHECK_PHP],
[
if ( test "$ENABLE_PHP" = "yes" )
then

	OVERRIDEPHPEXTDIR="$PHPEXTDIR"

	HAVE_PHP=""
	PHPINCLUDES=""
	PHPEXTDIR=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		PHPCONFIG=""
		for file in "php-config" "php-config-5" "php-config-5.1" "php-config-5.2" "php-config-5.3" "php-config-5.3" "php-config-5.4" "php-config-5.5" "php-config-5.6" "php-config-5.7" "php-config-5.8" "php-config-7.0" "php-config-7.1" "php-config-7.2" "php-config-7.3" "php-config-7.4" "php-config-8.0" "php-config-8.1" "php-config-8.2" "php-config-8.3" "php-config-8.4"
		do
			if ( test -n "$PHPPATH" )
			then
				FW_CHECK_FILE("$PHPPATH/bin/$file",[PHPCONFIG=\"$PHPPATH/bin/$file\"])
			else
				for i in "/usr/local/php/bin" "/usr/bin" "/usr/local/bin" "/usr/pkg/bin" "/opt/sfw/bin" "/usr/sfw/bin" "/opt/csw/bin" "/opt/csw/php4/bin" "/opt/csw/php5/bin" "/sw/bin" "/usr/freeware/bin" "/boot/common/bin" "/resources/index/bin"
				do
					FW_CHECK_FILE("$i/$file",[PHPCONFIG=\"$i/$file\"])
					if ( test -n "$PHPCONFIG" )
					then
						break
					fi
				done
			fi
                done
		
		if ( test -n "$PHPCONFIG" )
		then
			HAVE_PHP="yes"
			PHPPREFIX=`$PHPCONFIG --prefix`
			dnl some php's fail to replace ${prefix} with
			dnl their prefix when you run php-config
			dnl --includes, but php-config --prefix usually
			dnl works so we fake it here
			PHPINCLUDES=`$PHPCONFIG --includes | sed -e "s|\\${prefix}|$PHPPREFIX|" | sed -e "s|\\${prefix}|$PHPPREFIX|" | sed -e "s|\\${prefix}|$PHPPREFIX|" | sed -e "s|\\${prefix}|$PHPPREFIX|"`
			PHPEXTDIR=`$PHPCONFIG --extension-dir`
			PHPVERSION=`$PHPCONFIG --version`
			PHPMAJORVERSION=`echo "$PHPVERSION" | cut -d'.' -f1`

			dnl for cygwin and early mac os x...
			if ( test -n "$CYGWIN" )
			then
				dnl FIXME: we really should include a -L option
				PHPLIB="-lphp"
			elif ( test -n "$DARWIN" )
			then
				if ( test -n "$UNDEFINED_DYNAMIC_LOOKUP" )
				then
					PHPLIB="$UNDEFINED_DYNAMIC_LOOKUP"
				elif ( test -n "$BUNDLE_LOADER" )
				then
					AC_MSG_CHECKING(for php executable)
					PHP="`$PHPCONFIG --php-binary 2>&1 | grep -v Usage`"
					if ( test -z "$PHP" )
					then
						if ( test ! -r "$PHPCONFIG" )
						then
							PHPCONFIG="`which $PHPCONFIG`"
						fi
						BINDIR=`dirname $PHPCONFIG`
						PHP=$BINDIR/php
					fi
					if ( test -r "$PHP" )
					then
						AC_MSG_RESULT($PHP)
						PHPLIB="-Wl,$BUNDLE_LOADER -Wl,$PHP"
					else
						AC_MSG_RESULT(no)
						HAVE_PHP=""
						AC_MSG_WARN(The PHP API will not be built.)
					fi
				else
					dnl FIXME: we really should include a -L option
					PHPLIB="-lphp"
				fi
			fi
		else
			HAVE_PHP=""
			AC_MSG_WARN(The PHP API will not be built.)
		fi
	fi

	if ( test -n "$HAVE_PHP" )
	then
		FW_INCLUDES(php,[$PHPINCLUDES])
	fi

	if ( test -n "$OVERRIDEPHPEXTDIR" )
	then
		PHPEXTDIR="$OVERRIDEPHPEXTDIR"
	fi

	dnl find the directory for secondary config files
	dnl (ignore PHPPREFIX, PHP reliably wants its ini files under /etc)
	AC_MSG_CHECKING(for PHP config directory)
	PHPCONFDIR="none"
	PHPCONFSTYLE="unknown"
	if ( test -d "/etc/php.d" )
	then
		PHPCONFDIR="/etc/php.d"
		PHPCONFSTYLE="fedora"
	fi
	if ( test -d "/etc/php5/conf.d" )
	then
		PHPCONFDIR="/etc/php5/conf.d"
		PHPCONFSTYLE="suse"
	fi
	if ( test -d "/etc/php7/conf.d" )
	then
		PHPCONFDIR="/etc/php7/conf.d"
		PHPCONFSTYLE="suse"
	fi
	if ( test -d "/etc/php5/mods-available" )
	then
		PHPCONFDIR="/etc/php5/mods-available"
		if ( test -d "/etc/php5/conf.d" )
		then
			PHPCONFSTYLE="debian"
		else
			PHPCONFSTYLE="ubuntu"
		fi
	fi
	if ( test -d "/etc/php7/mods-available" )
	then
		PHPCONFDIR="/etc/php7/mods-available"
		if ( test -d "/etc/php7/conf.d" )
		then
			PHPCONFSTYLE="debian"
		else
			PHPCONFSTYLE="ubuntu"
		fi
	fi
	if ( test -d "`ls -d /etc/php/*/mods-available 2> /dev/null | sort | head -1`" )
	then
		PHPCONFDIR="`ls -d /etc/php/*/mods-available 2> /dev/null | sort | head -1`"
		if ( test -d "`ls -d /etc/php/*/conf.d 2> /dev/null | sort | head -1`" )
		then
			PHPCONFSTYLE="debian"
		else
			PHPCONFSTYLE="ubuntu"
		fi
	fi
	if ( test "$PHPCONFSTYLE" = "unknown" )
	then
		for dir in `ls -d /etc/php/* 2> /dev/null`
		do
			if ( test -d "$dir/conf.d" )
			then
				PHPCONFDIR="$dir/conf.d"
				PHPCONFSTYLE="solaris"
			fi
		done
	fi
	if ( test "$PHPCONFSTYLE" = "unknown" )
	then
		if ( test -d "/usr/local/etc/php" )
		then
			PHPCONFDIR="/usr/local/etc/php"
			PHPCONFSTYLE="freebsd"
		fi
	fi
	if ( test "$PHPCONFSTYLE" = "unknown" )
	then
		if ( test -d "/usr/pkg/etc/php.d" )
		then
			PHPCONFDIR="/usr/pkg/etc/php.d"
			PHPCONFSTYLE="netbsd"
		fi
	fi
	AC_MSG_RESULT($PHPCONFDIR - $PHPCONFSTYLE style)

	dnl strip trailing / from PHPEXTDIR or libtool might complain
	PHPEXTDIR="`echo $PHPEXTDIR | sed -e 's|/$||'`"

	AC_SUBST(HAVE_PHP)
	AC_SUBST(PHPINCLUDES)
	AC_SUBST(PHPEXTDIR)
	AC_SUBST(PHPVERSION)
	AC_SUBST(PHPMAJORVERSION)
	AC_DEFINE_UNQUOTED(PHPMAJORVERSION,[$PHPMAJORVERSION],PHP major version)
	AC_SUBST(PHPLIB)
	AC_SUBST(PHPCONFDIR)
	AC_SUBST(PHPCONFSTYLE)
fi
])


AC_DEFUN([FW_CHECK_PHP_PDO],
[
if ( test "$ENABLE_PHP" = "yes" )
then

	AC_MSG_CHECKING(for PHP PDO)
	HAVE_PHP_PDO=""
	FW_TRY_COMPILE([
#define __STDC_LIMIT_MACROS 1
#include <php.h>
#include <pdo/php_pdo.h>
#include <pdo/php_pdo_driver.h>],[struct pdo_dbh_methods a;],[$PHPINCLUDES],[AC_MSG_RESULT(yes); HAVE_PHP_PDO="yes"],[AC_MSG_RESULT(no)])
	AC_SUBST(HAVE_PHP_PDO)

	if ( test "$HAVE_PHP_PDO" = "yes" )
	then
		AC_MSG_CHECKING(for PDO::ATTR_EMULATE_PREPARES)
		FW_TRY_COMPILE([
#define __STDC_LIMIT_MACROS 1
#include <php.h>
#include <pdo/php_pdo.h>
#include <pdo/php_pdo_driver.h>],[pdo_attribute_type a=PDO_ATTR_EMULATE_PREPARES;],[$PHPINCLUDES],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_PHP_PDO_ATTR_EMULATE_PREPARES,1,Some versions of PHP PDO have PDO::ATTR_EMULATE_PREPARES)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for const zend_function_entry)
		FW_TRY_COMPILE([
#define __STDC_LIMIT_MACROS 1
#include <php.h>
#include <pdo/php_pdo.h>
#include <pdo/php_pdo_driver.h>
static const zend_function_entry *test(pdo_dbh_t *dbh, int kind TSRMLS_DC) { return 0; }
static struct pdo_dbh_methods methods={ 0,0,0,0,0,0,0,0,0,0,0,0,test };
],[],[$PHPINCLUDES],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_PHP_PDO_CONST_ZEND_FUNCTION_ENTRY,1,Some versions of PHP PDO don't support const zend_function_entry)],[AC_MSG_RESULT(no)])

		AC_MSG_CHECKING(for PDO_PARAM_ZVAL)
		FW_TRY_COMPILE([
#define __STDC_LIMIT_MACROS 1
#include <php.h>
#include <pdo/php_pdo.h>
#include <pdo/php_pdo_driver.h>],[pdo_param_type a=PDO_PARAM_ZVAL;],[$PHPINCLUDES],[AC_MSG_RESULT(yes); AC_DEFINE(HAVE_PHP_PDO_PARAM_ZVAL,1,Some versions of PHP PDO have PDO_PARAM_ZVAL)],[AC_MSG_RESULT(no)])
	fi
fi
])


AC_DEFUN([FW_CHECK_ERLANG],
[
if ( test "$ENABLE_ERLANG" = "yes" )
then

	HAVE_ERLANG=""
	ERLANGINCLUDES=""
	ERLANGLIBS=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		AC_ERLANG_PATH_ERLC
		AC_ERLANG_PATH_ERL

		if ( test -z "$ERLC" -o -z "$ERL" )
		then
			AC_MSG_CHECKING(for alternative erlc/erl)
			for version in "" "20" "19" "18" "17" "16" "15"
			do
				for path in "/" "/usr" "/usr/local/erlang" "/opt/erlang" "/usr/erlang" "/usr/local" "/usr/pkg" "/usr/pkg/erlang" "/opt/sfw" "/opt/sfw/erlang" "/usr/sfw" "/usr/sfw/erlang" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/erlang"
				do
					if ( test -r "$path/bin/erl$version" -a -r "$path/bin/erlc$version" )
					then
						ERL="$path/bin/erl$version"
						ERLC="$path/bin/erlc$version"
						break
					fi
				done
				if ( test -r "$ERL" -a -r "$ERLC" )
				then
					break
				fi
			done

			if ( test -r "$ERL" -a -r "$ERLC" )
			then
				AC_MSG_RESULT($ERL $ERLC)
			else
				AC_MSG_RESULT(no)
			fi
		fi


		if ( test -n "$ERLC" -a -n "$ERL" )
		then

			dnl get ERLANG_ROOT_DIR
			if ( test -z "$ERLANG_ROOT_DIR" )
			then
				rm -f conftest.erl
				cat > conftest.erl << END
-module(conftest).
-export([[start/0]]).
start() ->
	RootDir = code:root_dir(),
	file:write_file("conftest.out", RootDir),
	ReturnValue = 0,
	halt(ReturnValue)
.
END
				cat > conftest << END
#!/bin/sh
ERLC_EMULATOR=$ERL $ERLC $ERLCFLAGS -b beam conftest.erl
$ERL -run conftest start -run init stop -noshell
END
				chmod 755 conftest
				./conftest
				ERLANG_ROOT_DIR=`cat conftest.out`
				rm -f conftest.out
				rm -f conftest.erl
				rm -f conftest.beam
			fi

			dnl get ERLANG_LIB_DIR
			if ( test -z "$ERLANG_LIB_DIR" )
			then
				rm -f conftest.erl
				cat > conftest.erl << END
-module(conftest).
-export([[start/0]]).
start() ->
	LibDir = code:lib_dir(),
	file:write_file("conftest.out", LibDir),
	ReturnValue = 0,
	halt(ReturnValue)
.
END
				cat > conftest << END
#!/bin/sh
ERLC_EMULATOR=$ERL $ERLC $ERLCFLAGS -b beam conftest.erl
$ERL -run conftest start -run init stop -noshell
END
				chmod 755 conftest
				./conftest
				ERLANG_LIB_DIR=`cat conftest.out`
				rm -f conftest.out
				rm -f conftest.erl
				rm -f conftest.beam
			fi

			if ( test -z "$ERLANG_INSTALL_LIB_DIR" )
			then
				ERLANG_INSTALL_LIB_DIR='%{libdir}/erlang/lib'
			fi
			


			ERLANG_INCLUDE_DIR=`ls -d $ERLANG_LIB_DIR/erl_interface*/include 2> /dev/null`
			ERLANG_LIB_DIR=`ls -d $ERLANG_LIB_DIR/erl_interface*/lib 2> /dev/null`


			if ( test -n "$ERLANG_INCLUDE_DIR" -a -n "$ERLANG_LIB_DIR" )
			then

				if ( test "$ERLANG_INCLUDE_DIR" != "/usr" )
				then
					ERLANGINCLUDES="-I$ERLANG_INCLUDE_DIR"
				fi

				if ( test "$ERLANG_LIB_DIR" != "/usr" )
				then
					ERLANGLIBS="-L$ERLANG_LIB_DIR"
				fi

				ERLINTERFACELIB=""
				if ( test -r "$ERLANG_LIB_DIR/liberl_interface.a" )
				then
					ERLINTERFACELIB="-lerl_interface"
				fi

				ERLANGLIBS="$ERLANGLIBS $ERLINTERFACELIB -lei"

				HAVE_ERLANG="yes"
			else
				AC_MSG_WARN(The Erlang API will not be built.)
			fi
		else
			AC_MSG_WARN(The Erlang API will not be built.)
		fi
	fi

	FW_INCLUDES(erlang,[$ERLANGINCLUDES])
	FW_LIBS(erlang,[$ERLANGLIBS])

	AC_SUBST(ERL)
	AC_SUBST(ERLC)
	AC_SUBST(HAVE_ERLANG)
	AC_SUBST(ERLANGINCLUDES)
	AC_SUBST(ERLANGLIBS)
	AC_SUBST(ERLANG_ROOT_DIR)
	AC_SUBST(ERLANG_LIB_DIR)
	AC_SUBST(ERLANG_INSTALL_LIB_DIR)
fi
])


AC_DEFUN([FW_CHECK_MONO],
[
if ( test "$ENABLE_MONO" = "yes" )
then

	HAVE_MONO=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		dnl look for the compiler
		AC_MSG_CHECKING(for compiler)
		CSC=""
		CSCFLAGS=""
		for compiler in "mcs" "gmcs" "dmcs" "smcs"
		do

			for path in "$MONOPATH" "/" "/usr" "/usr/local/mono" "/opt/mono" "/usr/mono" "/usr/local" "/usr/pkg" "/usr/pkg/mono" "/opt/sfw" "/opt/sfw/mono" "/usr/sfw" "/usr/sfw/mono" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/mono"
			do
				if ( test -r "$path/bin/$compiler" )
				then
					CSC="$path/bin/$compiler"
					MONOPATH="$path"
					break
				fi
			done

			if ( test -n "$CSC" )
			then
				break
			fi
		done

		if ( test -n "$CSC" )
		then
			AC_MSG_RESULT($CSC)
		else
			AC_MSG_RESULT(no)
		fi


		dnl look for the sn
		SN=""
		AC_MSG_CHECKING(for sn)

		for path in "$MONOPATH" "/" "/usr" "/usr/local/mono" "/opt/mono" "/usr/mono" "/usr/local" "/usr/pkg" "/usr/pkg/mono" "/opt/sfw" "/opt/sfw/mono" "/usr/sfw" "/usr/sfw/mono" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/mono"
		do
			if ( test -r "$path/bin/sn" )
			then
				SN="$path/bin/sn"
				break
			fi
		done

		if ( test -r "$SN" )
		then
			AC_MSG_RESULT($SN)
		else
			AC_MSG_RESULT(no)
		fi


		dnl look for the ildasm/monodis
		ILDASM=""
		AC_MSG_CHECKING(for monodis)

		for path in "$MONOPATH" "/" "/usr" "/usr/local/mono" "/opt/mono" "/usr/mono" "/usr/local" "/usr/pkg" "/usr/pkg/mono" "/opt/sfw" "/opt/sfw/mono" "/usr/sfw" "/usr/sfw/mono" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/mono"
		do
			if ( test -r "$path/bin/monodis" )
			then
				ILDASM="$path/bin/monodis"
				break
			fi
		done

		if ( test -r "$ILDASM" )
		then
			AC_MSG_RESULT($ILDASM)
		else
			AC_MSG_RESULT(no)
		fi


		dnl look for the ilasm
		ILASM=""
		AC_MSG_CHECKING(for ilasm)

		for path in "$MONOPATH" "/" "/usr" "/usr/local/mono" "/opt/mono" "/usr/mono" "/usr/local" "/usr/pkg" "/usr/pkg/mono" "/opt/sfw" "/opt/sfw/mono" "/usr/sfw" "/usr/sfw/mono" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/mono"
		do
			if ( test -r "$path/bin/ilasm" )
			then
				ILASM="$path/bin/ilasm"
				break
			fi
		done

		if ( test -r "$ILASM" )
		then
			AC_MSG_RESULT($ILASM)
		else
			AC_MSG_RESULT(no)
		fi


		dnl look for the gacutil
		GACUTIL=""
		AC_MSG_CHECKING(for gacutil)

		for path in "$MONOPATH" "/" "/usr" "/usr/local/mono" "/opt/mono" "/usr/mono" "/usr/local" "/usr/pkg" "/usr/pkg/mono" "/opt/sfw" "/opt/sfw/mono" "/usr/sfw" "/usr/sfw/mono" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/mono"
		do
			if ( test -r "$path/bin/gacutil" )
			then
				GACUTIL="$path/bin/gacutil"
				break
			fi
		done

		if ( test -r "$GACUTIL" )
		then
			AC_MSG_RESULT($GACUTIL)
		else
			AC_MSG_RESULT(no)
		fi
	fi

	dnl Don't worry about gacutil for now, we're not going to install
	dnl anything in the global assembly cache at this point.
	dnl Don't worry about sn, ildasm or ilasm either, we're not going
	dnl to sign anything at this point either.
	dnl if ( test -r "$CSC" -a -r "$SN" -a -r "$ILDASM" -a -r "$ILASM" -a -r "$GACUTIL" )
	if ( test -r "$CSC" )
	then
		CSCFLAGS=""
		HAVE_MONO="yes"
	fi

	if ( test -n "$HAVE_MONO" )
	then

		for flags in "-pkg:dotnet" "-pkg:dotnet -lib:$MONOPATH/lib/mono/4.6" "-pkg:dotnet -lib:$MONOPATH/lib/mono/4.5" "-pkg:dotnet -lib:$MONOPATH/lib/mono/4.0" "-pkg:dotnet -lib:$MONOPATH/lib/mono/3.5" "-pkg:dotnet -lib:$MONOPATH/lib/mono/2.0"
		do

			CSCFLAGS="$flags"
			AC_MSG_CHECKING(whether $CSC $CSCFLAGS works)

			cat << EOF > conftest.cs
using System;
namespace ConfTest
{
    public class ConfTestClass
    {
        public static void Main(String[[]] args)
        {
            Console.WriteLine("hello world");
        }
    }
}
EOF

			$CSC $CSCFLAGS /out:conftest.exe conftest.cs > /dev/null 2> /dev/null

			if ( test -r "conftest.exe" )
			then
				AC_MSG_RESULT(yes)
				break
			else
				AC_MSG_RESULT(no)
			fi
		done

		if ( test ! -r "conftest.exe" )
		then
			AC_MSG_WARN(The Mono API will not be built.)
			CSCFLAGS=""
			HAVE_MONO=""
		fi

		rm -f conftest.cs
		rm -f conftest.exe
	else
		AC_MSG_WARN(The Mono API will not be built.)
	fi

	dnl for now, mono 2.8 or higher is required
	if ( test -n "$HAVE_MONO" )
	then
		AC_MSG_CHECKING(for mono version)

		MONOMAJOR=`$CSC --version 2> /dev/null | cut -d' ' -f5 | cut -d'.' -f1`
		MONOMINOR=`$CSC --version 2> /dev/null | cut -d' ' -f5 | cut -d'.' -f2`

		AC_MSG_RESULT([$MONOMAJOR.$MONOMINOR (2.8 required)])

		if ( test -z "$MONOMAJOR" -o -z "$MONOMINOR" )
		then
			HAVE_MONO=""
		else
			if ( test "$MONOMAJOR" -lt "2" )
			then
				HAVE_MONO=""
			elif ( test "$MONOMAJOR" = "2" -a "$MONOMINOR" -lt "8" )
			then
				HAVE_MONO=""
			fi
		fi

		if ( test -z "$HAVE_MONO" )
		then
			AC_MSG_WARN(The Mono API will not be built.)
		fi
	fi

	AC_SUBST(HAVE_MONO)
	AC_SUBST(CSC)
	AC_SUBST(CSCFLAGS)
	AC_SUBST(SN)
	AC_SUBST(ILDASM)
	AC_SUBST(ILASM)
	AC_SUBST(GACUTIL)
fi
])


AC_DEFUN([FW_CHECK_NODEJS],
[
if ( test "$ENABLE_NODEJS" = "yes" )
then

	HAVE_NODEJS=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		NODE=""
		NODEGYP=""
		NODEDIR=""
		NODEMAJORVERSION=""
		NODEJSCXXFLAGS=""
		AC_MSG_CHECKING(for node)

		for path in "$NODEJSPATH" "/usr" "/" "/usr/local/node" "/opt/node" "/usr/node" "/usr/local" "/usr/pkg" "/usr/pkg/node" "/opt/sfw" "/opt/sfw/node" "/usr/sfw" "/usr/sfw/node" "/opt/csw" "/sw" "/usr/freeware" "/boot/common" "/resources/index" "/resources" "/resources/node"
		do
			if ( test -z "$path" )
			then
				continue
			fi

			if ( test -r "$path/bin/node" )
			then
				NODE="$path/bin/node"
			fi

			if ( test -r "$path/bin/nodejs" )
			then
				NODE="$path/bin/nodejs"
			fi

			if ( test -n "$NODE" )
			then
				NODEDIR="$path"
				break
			fi
		done

		if ( test -r "$NODE" )
		then
			AC_MSG_RESULT($NODE)
		else
			AC_MSG_RESULT(no)
		fi
	fi

	if ( test -r "$NODE" )
	then
		HAVE_NODEJS="yes"

		dnl node >= 6.x requires -std=c++11 and sometimes
		dnl node-gyp doesn't enable it automatically
		AC_MSG_CHECKING(for node major version)
		NODEMAJORVERSION=`$NODE --version 2> /dev/null | tr -d 'v' | cut -d'.' -f1`
		if ( test "$NODEMAJORVERSION" -ge "6" )
		then
			NODEJSCXXFLAGS="-std=c++11"
		fi
		AC_MSG_RESULT($NODEMAJORVERSION)
		

		AC_MSG_CHECKING(for node module directory)
		for file in "$NODEDIR/lib64/node_modules" "$NODEDIR/lib64/nodejs" "$NODEDIR/lib/node_modules" "$NODEDIR/lib/nodejs"
		do
			if ( test -d "$file" )
			then
				NODEMODULEDIR="$file"
				break
			fi
		done
		AC_MSG_RESULT($NODEMODULEDIR)

		AC_MSG_CHECKING(for node-gyp)
		if ( test -r "$NODEMODULEDIR" )
		then
			for file in "$NODEMODULEDIR/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm6/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm6/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm7/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm7/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm8/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm8/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm9/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm9/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm10/node_modules/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/npm10/nodejs/node-gyp/bin/node-gyp.js" "$NODEMODULEDIR/../../share/node-gyp/bin/node-gyp.js"
			do
				if ( test -r "$file" )
				then
					NODEGYP="$file"
					break
				fi
			done
		fi
		if ( test -n "$NODEGYP" )
		then
			AC_MSG_RESULT($NODEGYP)
		else
			AC_MSG_RESULT(no)
		fi
	fi

	if ( test -z "$NODE" -o -z "$NODEGYP" )
	then
		HAVE_NODEJS=""
		AC_MSG_WARN(The node.js API will not be built.)
	fi

	TOP_BUILDDIR_ABS=`pwd`

	AC_SUBST(HAVE_NODEJS)
	AC_SUBST(NODE)
	AC_SUBST(NODEGYP)
	AC_SUBST(NODEMODULEDIR)
	AC_SUBST(NODEJSCXXFLAGS)
	AC_SUBST(TOP_BUILDDIR_ABS)
fi
])


AC_DEFUN([FW_CHECK_TCL],
[
if ( test "$ENABLE_TCL" = "yes" )
then

	HAVE_TCL=""
	TCLINCLUDE=""
	TCLLIB=""
	HAVETCLGETSTRING=""

	if ( test "$cross_compiling" = "yes" )
	then

		dnl cross compiling ...
		echo "cross compiling..."

	else

		dnl Checks for TCL.
		for i in "/sw/include" "/usr/freeware/include" "/opt/csw/include" "/usr/sfw/include" "/opt/sfw/include" "/usr/pkg/include" "/usr/local/include" "$prefix/include" "/usr/include" "$TCLINCLUDEPATH"
		do
			for j in "" "/tcl8.0" "/tcl8.1" "/tcl8.2" "/tcl8.3" "/tcl8.4" "/tcl8.5" "/tcl8.6" "/tcl8.7" "/tcl8.8" "/tcl8.9"
			do
				FW_CHECK_FILE($i$j/tcl.h,[TCLINCLUDE=\"-I$i/$j\"])
			done
		done
		dnl first look for a dynamic libtcl
		if ( test -n "$TCLINCLUDE" )
		then
			for i in "/sw/lib" "/usr/freeware/$LIBARCHDIR" "/opt/csw/lib" "/usr/sfw/lib" "/opt/sfw/lib" "/usr/pkg/lib" "/usr/local/lib" "/usr/local/lib64" "$prefix/lib" "$prefix/lib64" "/usr/lib" "/usr/lib64" "/usr/lib/$MULTIARCHDIR" "/usr/lib64/$MULTIARCHDIR" "$TCLLIBSPATH"
			do
				for j in "" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5" "8.6" "8.7" "8.8" "8.9" "80" "81" "82" "83" "84" "85" "86" "87" "88" "89"
				do
					FW_CHECK_FILE($i/libtcl$j.$SOSUFFIX,[TCLLIB=\"$i/libtcl$j.$SOSUFFIX\"; TCLLIBSPATH=\"$i\"])
					if ( test -z "$TCLLIB" )
					then
						TESTLIB=`ls $i/libtcl$j.$SOSUFFIX.? 2>/dev/null`
						if ( test -n "$TESTLIB" )
						then
							TCLLIB="$TESTLIB"
							TCLLIBSPATH="$i"
						fi
					fi
					if ( test -z "$TCLLIB" )
					then
						TESTLIB=`ls $i/libtcl$j.$SOSUFFIX.?.? 2>/dev/null`
						if ( test -n "$TESTLIB" )
						then
							TCLLIB="$TESTLIB"
							TCLLIBSPATH="$i"
						fi
					fi
					if ( test -z "$TCLLIB" )
					then
						TESTLIB=`ls $i/libtcl$j.$SOSUFFIX.?.?.? 2>/dev/null`
						if ( test -n "$TESTLIB" )
						then
							TCLLIB="$TESTLIB"
							TCLLIBSPATH="$i"
						fi
					fi
				done
			done
		fi

		dnl if we didn't find it, look for a dynamic libtclstub
		if ( test -n "$TCLINCLUDE " -a -z "$TCLLIB" )
		then
			for i in "/sw/lib" "/usr/freeware/$LIBARCHDIR" "/opt/csw/lib" "/usr/sfw/lib" "/opt/sfw/lib" "/usr/pkg/lib" "/usr/local/lib" "/usr/local/lib64" "$prefix/lib" "$prefix/lib64" "/usr/lib" "/usr/lib64" "/usr/lib/$MULTIARCHDIR" "/usr/lib64/$MULTIARCHDIR" "$TCLLIBSPATH"
			do
				for j in "" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5" "8.6" "8.7" "8.8" "8.9" "80" "81" "82" "83" "84" "85" "86" "87" "88" "89"
				do
					FW_CHECK_FILE($i/libtclstub$j.$SOSUFFIX,[TCLLIB=\"$i/libtclstub$j.$SOSUFFIX\"; TCLLIBSPATH=\"$i\"; TCLINCLUDE=\"-DUSE_TCL_STUBS $TCLINCLUDE\"])
				done
			done
		fi

		dnl translate /path/libtcl.*.$SOSUFFIX to -Lpath -ltcl.*
		if ( test -n "$TCLLIB" )
		then
			LIBPATH=`dirname $TCLLIB`
			LIBITSELF=`basename $TCLLIB | sed -e "s/^lib//" -e "s/\.$SOSUFFIX.*//"`
			TCLLIB="-L$LIBPATH -l$LIBITSELF"
		fi

		if ( test -z "$TCLLIB" )
		then
			AC_MSG_WARN("The TCL API will not be installed.")
		else
			HAVE_TCL="yes"
			AC_MSG_CHECKING(for Tcl_GetString)
			FW_TRY_LINK([#include <tcl.h>],[Tcl_GetString(NULL);],[$TCLINCLUDE $PTHREADINCLUDES],[$TCLLIB $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes) AC_DEFINE_UNQUOTED(HAVE_TCL_GETSTRING,1,Some versions of TCL don't have Tcl_GetString)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(for Tcl_WideInt)
			FW_TRY_LINK([#include <tcl.h>],[Tcl_WideInt row;],[$TCLINCLUDE $PTHREADINCLUDES],[$TCLLIB $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes) AC_DEFINE_UNQUOTED(HAVE_TCL_WIDEINT,1,Some versions of TCL don't have Tcl_WideInt)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(for const char ** support)
			FW_TRY_LINK([#include <tcl.h>],[static const char *options[]={""}; Tcl_GetIndexFromObj(NULL,NULL,(const char **)options,NULL,0,NULL);],[$TCLINCLUDE $PTHREADINCLUDES],[$TCLLIB $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes) AC_DEFINE_UNQUOTED(HAVE_TCL_CONSTCHAR,1,Some versions of TCL don't use const char ** arguments)],[AC_MSG_RESULT(no)])
			AC_MSG_CHECKING(for Tcl_NewStringObj with const char *)
			FW_TRY_LINK([#include <tcl.h>],[const char *a=""; Tcl_NewStringObj(a,0);],[$TCLINCLUDE $PTHREADINCLUDES],[$TCLLIB $PTHREADLIB],[$LD_LIBRARY_PATH],[AC_MSG_RESULT(yes) AC_DEFINE_UNQUOTED(HAVE_TCL_NEWSTRINGOBJ_CONST_CHAR,1,Some versions of TCL don't use const char ** arguments)],[AC_MSG_RESULT(no)])
		fi
	fi

	FW_INCLUDES(tcl,[$TCLINCLUDE])
	FW_LIBS(tcl,[$TCLLIB])

	AC_SUBST(HAVE_TCL)
	AC_SUBST(TCLINCLUDE)
	AC_SUBST(TCLLIB)
	AC_SUBST(TCLLIBSPATH)
fi
])


AC_DEFUN([FW_CHECK_NEED_REDHAT_9_GLIBC_2_3_2_HACK],
[
	dnl if there's no features.h then we're not using glibc (hopefully)
	AC_CHECK_HEADER([features.h],[USING_GLIBC=yes],[USING_GLIBC=no])

	if ( test "$USING_GLIBC" = "yes" )
	then
		AC_MSG_CHECKING(for broken glibc-2.3)
		GLIBC23HACKCODE=""
		GLIBC23HACKINCLUDE=""
		AC_TRY_LINK([#include <ctype.h>
#include <features.h>],[#if __GLIBC__==2 && __GLIBC_MINOR__==3
	__ctype_toupper('a');
#endif],[AC_MSG_RESULT(no)],[AC_MSG_RESULT(yes) AC_DEFINE_UNQUOTED(NEED_REDHAT_9_GLIBC_2_3_2_HACK,1,Some versions of glibc-2.3 need a fixup) GLIBC23HACKINCLUDE="#include <ctype.h>"; GLIBC23HACKCODE=" const unsigned short int **__ctype_b() { return __ctype_b_loc(); } const __int32_t **__ctype_toupper() { return __ctype_toupper_loc(); } const __int32_t **__ctype_tolower() { return __ctype_tolower_loc(); }"])
	fi
])
