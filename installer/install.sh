#!/usr/bin/env bash

# MailScanner tarball source installer
#
# Installs MailScanner with the option of installing 
# required perl modules via CPAN. Does not build any
# packages from source.
#
# Jerry Benton <mailscanner@mailborder.com>
# 24 FEB 2015

# Function used to Wait for n seconds
timewait () {
	DELAY=$1
	sleep $DELAY
}

#
# Locate a program given a list of directories to look in.
# Need to break out of loop as soon as we find it.
#
findprog () {
  _prog=$1
  shift
  for _path in $*
  do
    if [ -f ${_path}/${_prog} ]; then
      echo ${_path}/${_prog}
      break
    fi
    shift
  done
  echo
}

# Check for root user
if [ $(whoami) != "root" ]; then
	ROOTWARN='WARNING: root privileges not detected!';
else
	ROOTWARN=
fi

# user info screen before the install process starts
clear
echo;
echo "MailScanner Installation From Source"; echo; 
echo "This will install or upgrade the required software for MailScanner on *NIX systems";
echo "from source. A number of requirements are needed by MailScanner. If you have not";
echo "reviewed and installed these requirements, please do so before continuing with the"; 
echo "installation."; echo;
echo $ROOTWARN;
echo;
echo "Note that you should have the following programs installed before continuing:";
echo;
echo "		perl, tnef, make, bash";
echo "		gcc or cc";
echo "		GNU tar, or gtar, or gunzip";
echo;
echo "Press CTRL + C to exit or return to continue ... ";
read foobar


if [ x`uname -s` = "xSunOS" ]; then
  ARCHITECT=solaris
  # Need to add elements to path to find make as it is non-standard,
  # and SUN C compiler if installed.
  PATH=/usr/local/bin:/usr/ccs/bin:/opt/SUNWspro/bin:${PATH}
  export PATH
else
  ARCHITECT=unknown
fi

# check for standard perl location
if [ ! -x '/usr/bin/perl' ]; then
	# cannot find perl executable or link
	clear
	echo;
	echo "I cannot find the standard path to the perl executable at";
	echo "/usr/bin/perl on this system. If perl is in fact installed,";
	echo "create a soft link from /usr/bin/perl to the perl executable";
	echo "you will be using and run this installer again.";
	echo;
	exit 192
else
	PERL="usr/bin/perl";
fi

# find programs and location

# where i started
THISCURRPMDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# distribution type
DISTTYPE=tar

# tmp build dir
TMPBUILDDIR=/tmp
PERL_DIR="perl-tar"

# paths
TARPATH="/usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin";
CCPATH="/opt/SUNWspro/bin /usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin";
MAKEPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/ccs/bin /usr/bin /bin";
GUNZIPPATH="/usr/local/bin /usr/sfw/bin /usr/freeware/bin /usr/bin /bin";
TNEFPATH="/usr/local/bin /usr/local/sbin /usr/sfw/bin /usr/freeware/bin /usr/bin /usr/sbin /bin";
PERLPATH="/usr/bin /usr/local/bin";


# programs
TAR=`findprog tar $TARPATH`
GTAR=`findprog gtar $TARPATH`
MAKE=`findprog make $MAKEPATH`
GUNZIP=`findprog gunzip $GUNZIPPATH`
CC=`findprog cc $CCPATH`
GCC=`findprog gcc $TARPATH`
TNEF=`findprog tar $TNEFPATH`
PERLDOC=`findprog perldoc $PERLPATH`

# check for tnef
if [ "x$TNEF" = "x" ]; then
	# tnef missing
	TNEF_CHECK=0
	clear
	echo;
	echo "You are missing tnef"; echo;
	echo "I cannot find your tnef binary, which is used by MailScanner when handling";
	echo "Microsoft specific file attachments. I highly recommend that you press";
	echo "CTRL + C now and install this program. However, you can continue the install"; 
	echo "without this program present.";
	echo
	echo "Press CTRL + C to exit or return to continue ...";
	read foobar
else
	# tnef found
	TNEF_CHECK=1
fi

# Now we have tar, check it is GNU tar as we need the "z" option
TARCHECK=`$TAR --version 2>/dev/null | grep GNU`
if [ "x$TARCHECK"  = "x" ]; then
	# tar is not GNU
	TARISGNU=no
	
	if [ "x$GTAR" = "x" ]; then
		# Could not find gtar either
		if [ "x$GUNZIP" = "x" ]; then
			clear
			echo;
			echo "I could not find GNU tar, gtar or gunzip to decompress the installation";
			echo "files. Please install one or both of these programs and run the";
			echo "the installer again.";
			echo;
			exit 192
		fi
	else
		TAR=$GTAR
		TARISGNU=yes
		export TAR
		export TARISGNU
	fi
else
	# found GNU tar
	TARISGNU=yes
fi

# function used later for unpacking mailscanner
unpackarchive () {
  DIR=$1
  SOURCE=$2

  if [ "x$TARISGNU" = "xyes" ]; then
    ( cd $DIR && $TAR xzBpf - ) < $SOURCE
  else
    # Not GNU tar, so try to gunzip ourselves
    if [ "x$GUNZIP" = "x" ]; then
      SOURCE2=`echo $SOURCE | sed -e 's/\.gz$//'`
      if [ -f "$SOURCE2" ]; then
        ( cd $DIR && $TAR xBpf - ) < $SOURCE2
      else
        echo "Could not find $SOURCE2";
        echo "As I could not find GNU tar or gunzip, you need to";
        echo "uncompress each of the .gz files yourself.";
        echo;
        exit 1
      fi
    else
      $GUNZIP -c $SOURCE | ( cd $DIR && $TAR xBpf - )
    fi
  fi
}

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I can check and attempt to install missing Perl modules via CPAN, which will save";
echo "you time. This requires internet connectivity. Note that if you select this option";
echo "I will check for $HOME/.cpan/CPAN/MyConfig.pm and if missing will install a vanilla";
echo "configuration file for you. If you already have one in place, make sure that you";
echo "have specified that newly installed Perl modules are available system-wide.";
echo;
echo "Note: The 'perldoc' command must be installed (default) for this to work.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install missing Perl modules via CPAN? [n/Y] : " response

if [ "$response" = "yes" ]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
elif [ "$response" = "y" ]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
elif [ "x$response" = "x" ]; then    
	# user wants to use CPAN for missing modules
	CPANOPTION=1
else
    # user does not want to use CPAN
    CPANOPTION=0
fi

# ask if the user wants to install the Mail::ClamAV module
if [ "$CPANOPTION" = "1" ]; then
	# Mail::ClamAV
	clear
	echo;
	echo "Do you want to install Mail::ClamAV via CPAN?"; echo;
	echo "If you are using Clam AV I can install the perl module that supports command line";
	echo "scanning via Perl and Clam AV. This is only required if you are not going to use";
	echo "the Clam AV daemon. However, it does not hurt to have this module available.";
	echo;
	echo "Note: If using Clam AV it is recommended that you use the Clam AV daemon.";
	echo;
	echo "Recommended: N (no)"; echo;
	read -r -p "Install missing Mail::ClamAV module via CPAN? [y/N] : " response
	
	if [ "$response" = "yes" ]; then
		# user wants to use CPAN for clam av module
		CAV=1
	elif [ "$response" = "y" ]; then
		# user wants to use CPAN for clam av module
		CAV=1
	elif [ "x$response" = "x" ]; then     
		# user does not want to use CPAN for clam av module
		CAV=0
	else
		# user does not want to use CPAN for clam av module
		CAV=0
	fi
	
	# Mail::SpamAssassin
	clear
	echo;
	echo "Will you be using Spamassassin?"; echo;
	echo "If you are using spamassassin I can verify that the Mail::SpamAssassin perl module is ";
	echo "installed. Normally the spamassassin package will install the module by default, but I";
	echo "can verify this and install it via CPAN if missing. Enter 'n' or 'no' if you will not ";
	echo "be using spamassassin.";
	echo;
	echo "Recommended: Y (yes)"; echo;
	read -r -p "Install missing Mail::SpamAssassin module via CPAN? [n/Y] : " response
	
	if [ "$response" = "yes" ]; then
		# user wants to use CPAN for SpamAssassin module
		SA=1
	elif [ "$response" = "y" ]; then
		# user wants to use CPAN for SpamAssassin module
		SA=1
	elif [ "x$response" = "x" ]; then  
		# user does want to use CPAN for SpamAssassin module
		SA=1
	else
		# user does not want to use CPAN for SpamAssassin module
		SA=0
	fi
else
	# don't install if not using CPAN
	CAV=0
	SA=0
fi

# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

# the array of perl modules needed
ARMOD=();
ARMOD+=('Archive::Tar'); 		ARMOD+=('Archive::Zip');		ARMOD+=('bignum');				
ARMOD+=('Carp');				ARMOD+=('Compress::Zlib');		ARMOD+=('Compress::Raw::Zlib');	
ARMOD+=('Convert::BinHex'); 	ARMOD+=('Convert::TNEF');		ARMOD+=('Data::Dumper');		
ARMOD+=('Date::Parse');			ARMOD+=('DBD::SQLite');			ARMOD+=('DBI');					
ARMOD+=('Digest::HMAC');		ARMOD+=('Digest::MD5');			ARMOD+=('Digest::SHA1'); 		
ARMOD+=('DirHandle');			ARMOD+=('ExtUtils::MakeMaker');	ARMOD+=('Fcntl');				
ARMOD+=('File::Basename');		ARMOD+=('File::Copy');			ARMOD+=('File::Path');			
ARMOD+=('File::Spec');			ARMOD+=('File::Temp');			ARMOD+=('FileHandle');			
ARMOD+=('Filesys::Df');			ARMOD+=('Getopt::Long');		ARMOD+=('Inline::C');			
ARMOD+=('IO');					ARMOD+=('IO::File');			ARMOD+=('IO::Pipe');			
ARMOD+=('IO::Stringy');			ARMOD+=('HTML::Entities');		ARMOD+=('HTML::Parser');		
ARMOD+=('HTML::Tagset');		ARMOD+=('HTML::TokeParser');	ARMOD+=('Mail::Field');			
ARMOD+=('Mail::Header');		ARMOD+=('Mail::IMAPClient');	ARMOD+=('Mail::Internet');		
ARMOD+=('Math::BigInt');		ARMOD+=('Math::BigRat');		ARMOD+=('MIME::Base64');		
ARMOD+=('MIME::Decoder');		ARMOD+=('MIME::Decoder::UU');	ARMOD+=('MIME::Head');			
ARMOD+=('MIME::Parser');		ARMOD+=('MIME::QuotedPrint');	ARMOD+=('MIME::Tools');			
ARMOD+=('MIME::WordDecoder');	ARMOD+=('Net::CIDR');			ARMOD+=('Net::DNS');			
ARMOD+=('Net::IP');				ARMOD+=('OLE::Storage_Lite');	ARMOD+=('Pod::Escapes');		
ARMOD+=('Pod::Simple');			ARMOD+=('POSIX');				ARMOD+=('Scalar::Util');		
ARMOD+=('Socket'); 				ARMOD+=('Storable'); 	 	 	ARMOD+=('Test::Harness');		
ARMOD+=('Test::Pod');			ARMOD+=('Test::Simple');		ARMOD+=('Time::HiRes');			
ARMOD+=('Time::localtime'); 	ARMOD+=('Sys::Hostname::Long');	ARMOD+=('Sys::SigAction');		
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				ARMOD+=('File::ShareDir::Install');

# add to array if the user is wants spamassassin
if [ "$SA" = "1" ]; then
	ARMOD+=('Mail::SpamAssassin');
fi

# add to array if the user is wants clam av
if [ "$CAV" = "1" ]; then
	ARMOD+=('Mail::ClamAV');
fi

# used to give the user time to stop the script if a module is missing
STOPREAD=0

for i in "${ARMOD[@]}"
do
	$PERLDOC -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		if [ "$CPANOPTION" = "1" ]; then
			clear
			echo "$i is missing. Installing via CPAN ..."; echo;
			timewait 1
			$PERL -MCPAN -e "CPAN::Shell->force(qw(install $i ));"
		else
			echo "WARNING: $i is missing. You should fix this.";
			STOPREAD=1
		fi
	else
		echo "$i => OK";
	fi
done

# perl module(s) was found missing
if [ "$STOPREAD" = "1" ]; then
	echo;
	echo "You are missing some perl modules and have chosen not to remediate them";
	echo "automatically. You can press CTRL + C now to stop and remediate them on";
	echo "your own and start this installer again or you may continue.";
	echo;
	echo "Press CTRL + C to quit or return to continue ... ";
	read foobar
fi

# installing mailscanner

# Make a temp dir we use for a few things
#TMPINSTALL=${TMPBUILDDIR}/MStmpinstall.$$
#mkdir $TMPINSTALL
#chmod go-rwx $TMPINSTALL

echo "Installing MailScanner into /opt.";
echo "If you do not want it there, just move it to where you want it";
echo "and then edit MailScanner.conf and check_mailscanner";
echo "to set the correct locations.";

if [ \! -d /opt ]; then
	mkdir /opt
	chmod a+rx /opt
fi

unpackarchive /opt `ls ${PERL_DIR}/MailScanner*.tar.gz | tail -1`

VERNUM=`cd ${PERL_DIR}; ls MailScanner*.tar.gz | $PERL -pe 's/^MailScanner-([0-9.]+-\d+).*$/$1/' | tail -1`
echo "Installed version $VERNUM into /opt/MailScanner-$VERNUM";

# Create the symlink if not already present
if [ -d /opt/MailScanner ]; then
	echo "You will need to update the symlink /opt/MailScanner to point";
	echo "to the new version before starting it.";
else
	ln -sf MailScanner-${VERNUM} /opt/MailScanner
fi

# Create the spool directories if there aren't already signs of them
if [ \! -d /var/spool/MailScanner ]; then
	mkdir -p /var/spool/MailScanner/incoming
	mkdir -p /var/spool/MailScanner/incoming/Locks
	mkdir -p /var/spool/MailScanner/quarantine
	mkdir -p /var/spool/mqueue.in
	chown root /var/spool/mqueue.in
	chgrp bin  /var/spool/mqueue.in
	chmod u=rwx,g=rx,o-rwx /var/spool/mqueue.in
	chmod a+rx /var/spool/MailScanner/incoming
	chmod a+rx /var/spool/MailScanner/incoming/Locks
	echo "It looks like this is your first MailScanner installation so I have";
	echo "created the working directories and quarantine for you in /var/spool.";
fi

) 2>&1 | tee mailscanner-install.log