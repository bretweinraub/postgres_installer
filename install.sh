#! /bin/bash
#
# M80 ---- see the License file for restrictions
#



PROGNAME=${0##*/}
TMPFILE=/tmp/${PROGNAME}.$$

if [ -n "${DEBUG}" ]; then	
	set -x
fi

PSCMD="ps axc"  








#
# $Header: /cvsroot/m80/m80/lib/shell/printmsg.sh,v 1.1.1.1 2003/11/26 22:24:33 bretweinraub Exp $
#
# Function:	printmsg
#
# Description:	generic error reporting routine.
#               BEWARE, white space is stripped and replaced with single spaces
#
# Call Signature:
#
# Side Effects:
#
# Assumptions:
#

printmsg () {
    if [ -z "${QUIET}" ]; then 
	if [ $# -ge 1 ]; then
	    /bin/echo -n ${M80_OVERRIDE_DOLLAR0:-$PROGNAME}:\($$\) >&2
		while [ $# -gt 0 ]; do /bin/echo -n " "$1 >&2 ; shift ; done
		if [ -z "${M80_SUPRESS_PERIOD}" ]; then
		    echo . >&2
		else
		    echo >&2
		fi
	fi
    fi
}


#
# Function:	cleanup
#
# Description:	generic KSH funtion for the end of a script
#
# History:	02.22.2000	bdw	passed error code through to localclean
#
# $Id: cleanup.sh,v 1.2 2004/04/06 22:42:02 bretweinraub Exp $
#

cleanup () {
    export EXITCODE=$1
    shift
    if [ $# -gt 0 ]; then
	printmsg $*
    fi
    if [ -n "${DQITMPFILE}" ]; then
	rm -f ${DQITMPFILE}
    fi
    if [ -n "${LOCALCLEAN}" ]; then
	localclean ${EXITCODE} # this function must be set
    fi
    if [ ${EXITCODE} -ne 0 ]; then
	# this is an error condition
	printmsg exiting with error code ${EXITCODE}
    else
	printmsg done
    fi
    exit ${EXITCODE}
}

trap "cleanup 1 caught signal" INT QUIT TERM HUP 2>&1 > /dev/null


require () {
    while [ $# -gt 0 ]; do
	#printmsg validating \$${1}
	derived=$(eval "echo \$"$1)
	if [ -z "$derived" ];then
	    printmsg \$${1} not defined
	    usage
	fi
	shift
    done
}



# 
# filesize () : returns the number of bytes for a file; more reliable than ls.
#

filesize () {
    if [ $# -ne 1 ]; then
	cleanup 1 illegal arguments to shell function filesize
    fi
    echo $1 | perl -nle '@stat = stat($_); print $stat[7]'
}


#
# Function:	docmd
#
# Description:	a generic wrapper for ksh functions
#
# $Id: docmd.sh,v 1.1.1.1 2003/11/26 22:24:33 bretweinraub Exp $

docmd () {
    if [ $# -lt 1 ]; then
	return
    fi
    #print ; eval "echo \* $*" ; print
    eval "echo '$*'"
    eval $*
    RETURNCODE=$?
    if [ $RETURNCODE -ne 0 ]; then
	cleanup $RETURNCODE command \"$*\" returned with error code $RETURNCODE
    fi
    return 0
}


#
# Function:	docmdi
#
# Description:	execute a command, but ignore the error code
#
# $Id: docmdi.sh,v 1.1.1.1 2003/11/26 22:24:33 bretweinraub Exp $

docmdi () {
    if [ $# -lt 1 ]; then
	return
    fi
#    print ; eval "echo \* $*" ; print
    eval "echo '$*'"
    eval $*
    export RETURNCODE=$?
    if [ $RETURNCODE -ne 0 ]; then
	printmsg command \"$*\" returned with error code $RETURNCODE, ignored
    fi
    return $RETURNCODE
}


#
# Function:	checkfile
#
# Description:	This function is used to check whether some file ($2) or
#               directory meets some condition ($1).  If not print out an error
#               message ($3+).
#
# $Id: checkfile.sh,v 1.1.1.1 2003/11/26 22:24:33 bretweinraub Exp $

checkfile () {
    if [ $# -lt 2 ]; then
	cleanup 1 illegal arguments to the checkfile \(\) function
    fi
    FILE=$2
    if [ ! $1 $FILE ]; then
	shift; shift
	cleanup 1 file $FILE $*
    fi
}

checkNotFile () {
    if [ $# -lt 2 ]; then
	cleanup 1 illegal arguments to the checkNotfile \(\) function
    fi
    FILE=$2
    if [ $1 $FILE ]; then
	shift; shift
	cleanup 1 file $FILE $*
    fi
}



SSHCOMMAND="ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey"


#
# shellfunc : show
#
# usage : show var1 var2 var3

show () {
    while [ $# -gt 0 ]; do
	this=$1
	that=$(eval "echo \$"$this)
	printmsg using $this as $that
	shift
    done
}




unset QUIET


usage () {
  printmsg  I am unhappy ...... a usage message follows for your benefit
  printmsg  Usage is -v {version} -p {port} -s {skipconfigure=TRUE} -i {installdir} -n {nomake=TRUE} 

printmsg  Required variables: port 


  cleanup 1
} 

OPTIND=0
while getopts :v:p:si:n c 
    do case $c in        
	v) export version=$OPTARG;;
	p) export port=$OPTARG;;
	s) export skipconfigure=TRUE;;
	i) export installdir=$OPTARG;;
	n) export nomake=TRUE;;
	:) printmsg $OPTARG requires a value
	   usage;;
	\?) printmsg unknown option $OPTARG
	   usage;;
    esac
done














test -z "${port}" && {
	printmsg missing value for port
	usage
}








version=${version:-9.0.1}
installdir=${installdir:-/usr/local/postgres-${version}}

if [ ! -f postgresql-${version}.tar ] ; then
    if [ ! -f postgresql-${version}.tar.bz2 ]; then
	docmd wget http://wwwmaster.postgresql.org/redir/170/h/source/v${version}/postgresql-${version}.tar.bz2
    fi
    docmd bunzip2 postgresql-${version}.tar.bz2
fi

if [ ! -d postgresql-${version} ]; then
    tar xvf postgresql-${version}.tar
fi

docmd cd postgresql-${version}

if [ -z "${skipconfigure}" ]; then
    exit 0
    docmd ./configure --with-pgport=$port --prefix=${installdir}
else
    printmsg skipping configure in virtue of -s flag
fi

if [ -z "${nomake}" ]; then
    docmd make -f GNUmakefile -j2
    docmd make check
    docmd sudo make install
else
    printmsg skipping make and install in virtue of -n flag
fi

sudo su - postgres -c 'bash' <<EOF

export PATH=${installdir}/bin:$PATH
export MANPATH=${installdir}/man:$MANPATH
export LD_LIBRARY_PATH=${installdir}/lib:$LD_LIBRARY_PATH


if [ ! -d \$HOME/${version}/data ]; then
mkdir -p \$HOME/${version}/data
initdb -D  \$HOME/${version}/data
else
echo "skipping initdb since \$HOME/${version}/data exists.  Remove this to override this check."
fi

cat > ${version}.sh <<EOF901
#!/bin/bash
export PATH=/usr/local/postgres-${version}/bin:\\\$PATH
export MANPATH=/usr/local/postgres-${version}/man:\\\$MANPATH
export LD_LIBRARY_PATH=/usr/local/postgres-${version}/lib:\\\$LD_LIBRARY_PATH

exec \\\$*

EOF901
chmod +x ${version}.sh

EOF

if [ $? -ne 0 ]; then
    cleanup 1 something went wrong
else
    cat <<EOF
################################################################################

SUCCESS!!!!!

You've installed postgres version ${version} to ${installdir}.

The server is configured to listen by default on port ${port} and is started as shown above

You'll want to set this in your environment to interact with this database:

export PATH=${installdir}/bin:\$PATH
export MANPATH=${installdir}/man:\$MANPATH
export LD_LIBRARY_PATH=${installdir}/lib:\$LD_LIBRARY_PATH

In case initdb didn't run, it wants to tell you (as postgres, and with the env vars shown above):

Success. You can now start the database server using:

    postgres -D \$HOME/${version}/data
or
    pg_ctl -D \$HOME/${version}/data -l logfile start


Also as a help, a wrapper script was left in ~postgres/${version}.sh

You can run like this:

~postgres/${version}.sh pg_ctl -D \$HOME/${version}/data -l logfile start

and it'll run whatever commands you pass it for that version of postgres.

One last thing .... I didn't modify your file:

~postgres/${version}/data/pg_hba.conf

You'll probably want your setting from 

/etc/postgresql/8.4/pg_hba.conf 

moved over, like this:

sudo su - postgres -c bash -c 'cp /etc/postgresql/8.4/main/pg_hba.conf ~postgres/${version}/data/pg_hba.conf'

Following the same theme, you can't start your server like this:

sudo su - postgres -c bash -c '~postgres/${version}.sh pg_ctl -D $HOME/${version}/data -l logfile start'

Hopefully this worked for you....

EOF
fi

cleanup 0
    
