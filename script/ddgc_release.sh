#!/bin/sh

CURRENT_DATE_FILENAME=$( date +%Y%m%d_%H%M%S )

if [ "$1" = "view" ];
then
	DDGC_RELEASE_HOSTNAME="view.dukgo.com"
else 	if [ "$1" = "prod" ];
	then
		DDGC_RELEASE_HOSTNAME="duck.co"
	fi
fi

if [ -z $DDGC_RELEASE_HOSTNAME ];
then
	printf "need a release target\n"
	exit 1
fi

if [[ $2 =~ DDGC-([0-9\.]*)\. ]] ; then
	DDGC_RELEASE_VERSION=${BASH_REMATCH[1]}
fi

if [[ -z $DDGC_RELEASE_VERSION ]] ; then
	printf "Cannot extract version from tarball name, bailing...\n"
	exit -1
fi

DDGC_RELEASE_DIRECTORY="$DDGC_RELEASE_VERSION-$CURRENT_DATE_FILENAME"

printf "\n*** Releasing DDGC $DDGC_RELEASE_VERSION to $DDGC_RELEASE_HOSTNAME...\n\n"

printf "***\n*** Creating deploy directory...\n***\n"
ssh -t ddgc@$DDGC_RELEASE_HOSTNAME "(
	if [ ! -d ~/deploy/$DDGC_RELEASE_DIRECTORY ] ; then
		mkdir -p ~/deploy/$DDGC_RELEASE_DIRECTORY
	fi
)" && \
printf "***\n*** Transfer release file $2...\n***\n" && \
scp $2 ddgc@$DDGC_RELEASE_HOSTNAME:~/deploy/$DDGC_RELEASE_DIRECTORY && \
printf "***\n*** Preparing release on remote site...\n***\n" && \
ssh -t ddgc@$DDGC_RELEASE_HOSTNAME "(
	. /home/ddgc/perl5/perlbrew/etc/bashrc &&
	. /home/ddgc/ddgc_config.sh &&
	cd ~/deploy/$DDGC_RELEASE_DIRECTORY &&
	tar xz --strip-components=1 -f $2 &&
	cpanm -n --installdeps . &&
	duckpan DDGC::Static &&
	touch ~/ddgc_web_maintenance &&
	printf Stopping current system... && 
	sudo /usr/local/sbin/stop_ddgc.sh && 
	printf Creating live installation... && 
	if [ ! -L ~/live ] ; then
		mv ~/live ~/backup/$CURRENT_DATE_FILENAME
	fi
	ln -sfn ~/deploy/$DDGC_RELEASE_DIRECTORY ~/live
	rm -rf ~/cache &&
	mkdir ~/cache &&
	cp -ar ~/live/share/docroot/* ~/docroot/ &&
	cp -ar ~/live/share/docroot_duckpan/* ~/ddgc/duckpan/ &&
	printf Starting new system... && 
	sudo /usr/local/sbin/start_ddgc.sh
)"
