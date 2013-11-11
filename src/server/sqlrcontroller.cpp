// Copyright (c) 1999-2011  David Muse
// See the file COPYING for more information

#include <config.h>

#include <sqlrcontroller.h>
#include <rudiments/file.h>
#include <rudiments/rawbuffer.h>
#include <rudiments/passwdentry.h>
#include <rudiments/groupentry.h>
#include <rudiments/process.h>
#include <rudiments/permissions.h>
#include <rudiments/snooze.h>
#include <rudiments/error.h>
#include <rudiments/signalclasses.h>
#include <rudiments/datetime.h>
#include <rudiments/character.h>
#include <rudiments/charstring.h>
#include <rudiments/stdio.h>

// for gettimeofday()
// SCO OSR 5.0.0 needs the extern "C"
extern "C" {
	#include <sys/time.h>
}

#include <defines.h>
#include <datatypes.h>
#define NEED_CONVERT_DATE_TIME
#include <parsedatetime.h>

#ifndef SQLRELAY_ENABLE_SHARED
	extern "C" {
		#include "sqlrconnectiondeclarations.cpp"
	}
#endif

sqlrcontroller_svr::sqlrcontroller_svr() : listener() {

	conn=NULL;

	cmdl=NULL;
	cfgfl=NULL;
	semset=NULL;
	idmemory=NULL;
	connstats=NULL;

	updown=NULL;

	dbselected=false;
	originaldb=NULL;

	tmpdir=NULL;

	unixsocket=NULL;
	unixsocketptr=NULL;
	unixsocketptrlen=0;
	serversockun=NULL;
	serversockin=NULL;
	serversockincount=0;

	inetport=0;
	authc=NULL;
	lastuserbuffer[0]='\0';
	lastpasswordbuffer[0]='\0';
	lastauthsuccess=false;

	commitorrollback=false;

	autocommitforthissession=false;

	translatebegins=true;
	faketransactionblocks=false;
	faketransactionblocksautocommiton=false;
	intransactionblock=false;

	fakeinputbinds=false;
	translatebinds=false;

	isolationlevel=NULL;

	ignoreselectdb=false;

	maxquerysize=0;
	maxbindcount=0;
	maxbindnamelength=0;
	maxstringbindvaluelength=0;
	maxlobbindvaluelength=0;
	maxerrorlength=0;
	idleclienttimeout=-1;

	connected=false;
	inclientsession=false;
	loggedin=false;

	// maybe someday these parameters will be configurable
	bindpool=new memorypool(512,128,100);
	bindmappingspool=new memorypool(512,128,100);
	inbindmappings=new namevaluepairs;
	outbindmappings=new namevaluepairs;

	sqlp=NULL;
	sqlt=NULL;
	sqlw=NULL;
	sqltr=NULL;
	sqlrlg=NULL;
	sqlrq=NULL;
	sqlrpe=NULL;

	decrypteddbpassword=NULL;

	debugsqltranslation=false;
	debugtriggers=false;

	cur=NULL;

	pidfile=NULL;

	clientinfo=NULL;
	clientinfolen=0;

	decrementonclose=false;
	silent=false;

	loggedinsec=0;
	loggedinusec=0;

	dbhostname=NULL;
	dbipaddress=NULL;

	reformatdatetimes=false;

	proxymode=false;
	proxypid=0;
}

sqlrcontroller_svr::~sqlrcontroller_svr() {

	if (connstats) {
		rawbuffer::zero(connstats,sizeof(sqlrconnstatistics));
	}

	delete cmdl;
	delete cfgfl;

	delete[] updown;

	delete[] originaldb;

	delete tmpdir;

	delete authc;

	delete idmemory;

	delete semset;

	if (unixsocket) {
		file::remove(unixsocket);
		delete[] unixsocket;
	}

	delete bindpool;

	delete bindmappingspool;
	delete inbindmappings;
	delete outbindmappings;

	delete sqlp;
	delete sqlt;
	delete sqlw;
	delete sqltr;
	delete sqlrlg;
	delete sqlrq;
	delete sqlrpe;

	delete[] decrypteddbpassword;

	delete[] clientinfo;

	if (pidfile) {
		file::remove(pidfile);
		delete[] pidfile;
	}

	delete conn;
}

bool sqlrcontroller_svr::init(int argc, const char **argv) {

	// process command line
	cmdl=new cmdline(argc,argv);

	// set the tmpdir
	tmpdir=new tempdir(cmdl);

	// default id warning
	if (!charstring::compare(cmdl->getId(),DEFAULT_ID)) {
		stderror.printf("Warning: using default id.\n");
	}

	// get whether this connection was spawned by the scaler
	scalerspawned=cmdl->found("-scaler");

	// get the connection id from the command line
	connectionid=cmdl->getValue("-connectionid");
	if (!connectionid[0]) {
		connectionid=DEFAULT_CONNECTIONID;
		stderror.printf("Warning: using default connectionid.\n");
	}

	// get the time to live from the command line
	const char	*ttlstr=cmdl->getValue("-ttl");
	ttl=(ttlstr)?charstring::toInteger(cmdl->getValue("-ttl")):-1;

	silent=cmdl->found("-silent");

	// parse the config file
	cfgfl=new sqlrconfigfile();
	if (!cfgfl->parse(cmdl->getConfig(),cmdl->getId())) {
		return false;
	}

	// get password encryptions
	const char	*pwdencs=cfgfl->getPasswordEncryptions();
	if (charstring::length(pwdencs)) {
		sqlrpe=new sqlrpwdencs;
		sqlrpe->loadPasswordEncryptions(pwdencs);
	}	

	// load the authenticator
	authc=new sqlrauthenticator(cfgfl,sqlrpe);

	setUserAndGroup();

	// load database plugin
	conn=initConnection(cfgfl->getDbase());
	if (!conn) {
		return false;
	}

	// get loggers
	const char	*loggers=cfgfl->getLoggers();
	if (charstring::length(loggers)) {
		sqlrlg=new sqlrloggers;
		sqlrlg->loadLoggers(loggers);
		sqlrlg->initLoggers(NULL,conn);
	}

	// handle the unix socket directory
	if (cfgfl->getListenOnUnix()) {
		setUnixSocketDirectory();
	}

	// handle the pid file
	if (!handlePidFile()) {
		return false;
	}

	// handle the connect string
	constr=cfgfl->getConnectString(connectionid);
	if (!constr) {
		stderror.printf("Error: invalid connectionid \"%s\".\n",
							connectionid);
		return false;
	}
	conn->handleConnectString();

	initDatabaseAvailableFileName();

	if (cfgfl->getListenOnUnix() && !getUnixSocket()) {
		return false;
	}

	if (!createSharedMemoryAndSemaphores(cmdl->getId())) {
		return false;
	}

	// log in and detach
	bool	reloginatstart=cfgfl->getReLoginAtStart();
	if (!reloginatstart) {
		if (!attemptLogIn(!silent)) {
			return false;
		}
	}
	if (!cmdl->found("-nodetach")) {
		process::detach();
	}
	if (reloginatstart) {
		while (!attemptLogIn(false)) {
			snooze::macrosnooze(5);
		}
	}
	initConnStats();

	// Get the query translators.  Do it after logging in, as
	// getSqlTranslator might return a different class depending on what
	// version of the db it gets logged into
	const char	*translations=cfgfl->getTranslations();
	if (charstring::length(translations)) {
		sqlp=new sqlparser;
		sqlt=conn->getSqlTranslations();
		sqlt->loadTranslations(translations);
		sqlw=conn->getSqlWriter();
	}
	debugsqltranslation=cfgfl->getDebugTranslations();

	// get the triggers
	const char	*triggers=cfgfl->getTriggers();
	if (charstring::length(triggers)) {
		// for triggers, we'll need an sqlparser as well
		if (!sqlp) {
			sqlp=new sqlparser;
		}
		sqltr=new sqltriggers;
		sqltr->loadTriggers(triggers);
	}
	debugtriggers=cfgfl->getDebugTriggers();

	// update various configurable parameters
	maxclientinfolength=cfgfl->getMaxClientInfoLength();
	maxquerysize=cfgfl->getMaxQuerySize();
	maxbindcount=cfgfl->getMaxBindCount();
	maxbindnamelength=cfgfl->getMaxBindNameLength();
	maxstringbindvaluelength=cfgfl->getMaxStringBindValueLength();
	maxlobbindvaluelength=cfgfl->getMaxLobBindValueLength();
	maxerrorlength=cfgfl->getMaxErrorLength();
	idleclienttimeout=cfgfl->getIdleClientTimeout();
	reformatdatetimes=(cfgfl->getDateTimeFormat() ||
				cfgfl->getDateFormat() ||
				cfgfl->getTimeFormat());

	// set autocommit behavior
	setAutoCommit(conn->autocommit);

	// get fake input bind variable behavior
	// (this may have already been set true by the connect string)
	fakeinputbinds=(fakeinputbinds || cfgfl->getFakeInputBindVariables());

	// get translate bind variable behavior
	translatebinds=cfgfl->getTranslateBindVariables();

	// initialize cursors
	mincursorcount=cfgfl->getCursors();
	maxcursorcount=cfgfl->getMaxCursors();
	if (!initCursors(mincursorcount)) {
		closeCursors(false);
		logOut();
		return false;
	}

	// create connection pid file
	pid_t	pid=process::getProcessId();
	size_t	pidfilelen=tmpdir->getLength()+22+
				charstring::length(cmdl->getId())+1+
				charstring::integerLength((uint64_t)pid)+1;
	pidfile=new char[pidfilelen];
	charstring::printf(pidfile,pidfilelen,
				"%s/pids/sqlr-connection-%s.%ld",
				tmpdir->getString(),cmdl->getId(),(long)pid);
	process::createPidFile(pidfile,permissions::ownerReadWrite());

	// create clientinfo buffer
	clientinfo=new char[maxclientinfolength+1];

	// create error buffer
	// FIXME: this should definitely be done inside the connection class
	conn->error=new char[maxerrorlength+1];

	// increment connection counter
	if (cfgfl->getDynamicScaling()) {
		incrementConnectionCount();
	}

	// set the transaction isolation level
	isolationlevel=cfgfl->getIsolationLevel();
	conn->setIsolationLevel(isolationlevel);

	// ignore selectDatabase() calls?
	ignoreselectdb=cfgfl->getIgnoreSelectDatabase();

	// get the database/schema we're using so
	// we can switch back to it at end of session
	originaldb=conn->getCurrentDatabase();

	markDatabaseAvailable();

	// get the custom query handlers
	const char	*queries=cfgfl->getQueries();
	if (charstring::length(queries)) {
		sqlrq=new sqlrqueries;
		sqlrq->loadQueries(queries);
	}
	
	return true;
}

void sqlrcontroller_svr::setUserAndGroup() {

	// get the user that we're currently running as
	char	*currentuser=
		passwdentry::getName(process::getEffectiveUserId());

	// get the group that we're currently running as
	char	*currentgroup=
		groupentry::getName(process::getEffectiveGroupId());

	// switch groups, but only if we're not currently running as the
	// group that we should switch to
	if (charstring::compare(currentgroup,cfgfl->getRunAsGroup()) &&
				!process::setGroup(cfgfl->getRunAsGroup())) {
		stderror.printf("Warning: could not change group to %s\n",
						cfgfl->getRunAsGroup());
	}

	// switch users, but only if we're not currently running as the
	// user that we should switch to
	if (charstring::compare(currentuser,cfgfl->getRunAsUser()) &&
				!process::setUser(cfgfl->getRunAsUser())) {
		stderror.printf("Warning: could not change user to %s\n",
						cfgfl->getRunAsUser());
	}

	// clean up
	delete[] currentuser;
	delete[] currentgroup;
}

sqlrconnection_svr *sqlrcontroller_svr::initConnection(const char *dbase) {

#ifdef SQLRELAY_ENABLE_SHARED
	// load the connection module
	stringbuffer	modulename;
	modulename.append(LIBEXECDIR);
	modulename.append("/sqlrconnection_");
	modulename.append(dbase)->append(".")->append(SQLRELAY_MODULESUFFIX);
	if (!dl.open(modulename.getString(),true,true)) {
		stderror.printf("failed to load connection module: %s\n",
							modulename.getString());
		char	*error=dl.getError();
		stderror.printf("%s\n",error);
		delete[] error;
		return NULL;
	}

	// load the connection itself
	stringbuffer	functionname;
	functionname.append("new_")->append(dbase)->append("connection");
	sqlrconnection_svr	*(*newConn)(sqlrcontroller_svr *)=
				(sqlrconnection_svr *(*)(sqlrcontroller_svr *))
					dl.getSymbol(functionname.getString());
	if (!newConn) {
		stderror.printf("failed to load connection: %s\n",dbase);
		char	*error=dl.getError();
		stderror.printf("%s\n",error);
		delete[] error;
		return NULL;
	}

	sqlrconnection_svr	*conn=(*newConn)(this);

#else
	sqlrconnection_svr	*conn;
	stringbuffer		connectionname;
	connectionname.append(dbase)->append("connection");
	#include "sqlrconnectionassignments.cpp"
	{
		conn=NULL;
	}
#endif

	if (!conn) {
		stderror.printf("failed to create connection: %s\n",dbase);
#ifdef SQLRELAY_ENABLE_SHARED
		char	*error=dl.getError();
		stderror.printf("%s\n",error);
		delete[] error;
#endif
	}
	return conn;
}

void sqlrcontroller_svr::setUnixSocketDirectory() {
	size_t	unixsocketlen=tmpdir->getLength()+31;
	unixsocket=new char[unixsocketlen];
	charstring::printf(unixsocket,unixsocketlen,
				"%s/sockets/",tmpdir->getString());
	unixsocketptr=unixsocket+tmpdir->getLength()+8+1;
	unixsocketptrlen=unixsocketlen-(unixsocketptr-unixsocket);
}

bool sqlrcontroller_svr::handlePidFile() {

	// check for listener's pid file
	// (Look a few times.  It might not be there right away.  The listener
	// writes it out after forking and it's possible that the connection
	// might start up after the sqlr-listener has forked, but before it
	// writes out the pid file)
	size_t	listenerpidfilelen=tmpdir->getLength()+20+
				charstring::length(cmdl->getId())+1;
	char	*listenerpidfile=new char[listenerpidfilelen];
	charstring::printf(listenerpidfile,listenerpidfilelen,
				"%s/pids/sqlr-listener-%s",
				tmpdir->getString(),cmdl->getId());

	bool	retval=true;
	bool	found=false;
	for (uint8_t i=0; !found && i<10; i++) {
		if (i) {
			snooze::microsnooze(0,100000);
		}
		found=(process::checkForPidFile(listenerpidfile)!=-1);
	}
	if (!found) {
		stderror.printf("\nsqlr-connection error:\n");
		stderror.printf("	The pid file %s",listenerpidfile);
		stderror.printf(" was not found.\n");
		stderror.printf("	This usually means "
					"that the sqlr-listener \n");
		stderror.printf("is not running.\n");
		stderror.printf("	The sqlr-listener must be running ");
		stderror.printf("for the sqlr-connection to start.\n\n");
		retval=false;
	}

	delete[] listenerpidfile;

	return retval;
}

void sqlrcontroller_svr::initDatabaseAvailableFileName() {

	// initialize the database up/down filename
	size_t	updownlen=charstring::length(tmpdir->getString())+5+
					charstring::length(cmdl->getId())+1+
					charstring::length(connectionid)+1;
	updown=new char[updownlen];
	charstring::printf(updown,updownlen,"%s/ipc/%s-%s",
			tmpdir->getString(),cmdl->getId(),connectionid);
}

bool sqlrcontroller_svr::getUnixSocket() {

	logDebugMessage("getting unix socket...");

	file	sockseq;
	if (!openSequenceFile(&sockseq) || !lockSequenceFile(&sockseq)) {
		return false;
	}
	if (!getAndIncrementSequenceNumber(&sockseq)) {
		unLockSequenceFile(&sockseq);
		sockseq.close();
		return false;
	}
	if (!unLockSequenceFile(&sockseq)) {
		sockseq.close();
		return false;
	}
	if (!sockseq.close()) {
		return false;
	}

	logDebugMessage("done getting unix socket");

	return true;
}

bool sqlrcontroller_svr::openSequenceFile(file *sockseq) {

	// open the sequence file and get the current port number
	size_t	sockseqnamelen=tmpdir->getLength()+9;
	char	*sockseqname=new char[sockseqnamelen];
	charstring::printf(sockseqname,sockseqnamelen,
				"%s/sockseq",tmpdir->getString());

	size_t	stringlen=8+charstring::length(sockseqname)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,"opening %s",sockseqname);
	logDebugMessage(string);
	delete[] string;

	mode_t	oldumask=process::setFileCreationMask(011);
	bool	success=sockseq->open(sockseqname,O_RDWR|O_CREAT,
					permissions::everyoneReadWrite());
	process::setFileCreationMask(oldumask);

	// handle error
	if (!success) {

		stderror.printf("Could not open: %s\n",sockseqname);
		stderror.printf("Make sure that the file and directory are \n");
		stderror.printf("readable and writable.\n\n");
		unixsocketptr[0]='\0';

		debugstr.clear();
		debugstr.append("failed to open socket sequence file: ");
		debugstr.append(sockseqname);
		logInternalError(NULL,debugstr.getString());
		delete[] string;
	}

	delete[] sockseqname;

	return success;
}

bool sqlrcontroller_svr::lockSequenceFile(file *sockseq) {

	logDebugMessage("locking...");

	if (!sockseq->lockFile(F_WRLCK)) {
		logInternalError(NULL,"failed to lock socket sequence file");
		return false;
	}
	return true;
}

bool sqlrcontroller_svr::unLockSequenceFile(file *sockseq) {

	// unlock and close the file in a platform-independent manner
	logDebugMessage("unlocking...");

	if (!sockseq->unlockFile()) {
		logInternalError(NULL,"failed to unlock socket sequence file");
		return false;
	}
	return true;
}

bool sqlrcontroller_svr::getAndIncrementSequenceNumber(file *sockseq) {

	// get the sequence number from the file
	int32_t	buffer;
	if (sockseq->read(&buffer)!=sizeof(int32_t)) {
		buffer=0;
	}
	charstring::printf(unixsocketptr,unixsocketptrlen,"%d",buffer);

	size_t	stringlen=21+charstring::length(unixsocketptr)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,
			"got sequence number: %s",unixsocketptr);
	logDebugMessage(string);
	delete[] string;

	// increment the sequence number but don't let it roll over
	if (buffer==2147483647) {
		buffer=0;
	} else {
		buffer=buffer+1;
	}

	string=new char[50];
	charstring::printf(string,50,"writing new sequence number: %d",buffer);
	logDebugMessage(string);
	delete[] string;

	// write the sequence number back to the file
	if (sockseq->setPositionRelativeToBeginning(0)==-1 ||
			sockseq->write(buffer)!=sizeof(int32_t)) {
		logInternalError(NULL,"failed to update socket sequence file");
		return false;
	}
	return true;
}

bool sqlrcontroller_svr::attemptLogIn(bool printerrors) {

	logDebugMessage("logging in...");

	// log in
	if (!logIn(printerrors)) {
		return false;
	}

	// get stats
	struct timeval	tv;
	gettimeofday(&tv,NULL);
	loggedinsec=tv.tv_sec;
	loggedinusec=tv.tv_usec;

	logDebugMessage("done logging in");
	return true;
}

bool sqlrcontroller_svr::logIn(bool printerrors) {

	// don't do anything if we're already logged in
	if (loggedin) {
		return true;
	}

	// attempt to log in
	const char	*err=NULL;
	if (!conn->logIn(&err)) {
		if (printerrors) {
			stderror.printf("Couldn't log into database.\n");
			if (err) {
				stderror.printf("%s\n",err);
			}
		}
		if (sqlrlg) {
			debugstr.clear();
			debugstr.append("database login failed");
			if (err) {
				debugstr.append(": ")->append(err);
			}
			logInternalError(NULL,debugstr.getString());
		}
		return false;
	}

	// success... update stats
	incrementOpenDatabaseConnections();

	// update db host name and ip address
	dbhostname=conn->dbHostName();
	dbipaddress=conn->dbIpAddress();

	loggedin=true;

	logDbLogIn();

	return true;
}

void sqlrcontroller_svr::logOut() {

	// don't do anything if we're already logged out
	if (!loggedin) {
		return;
	}

	logDebugMessage("logging out...");

	// log out
	conn->logOut();

	// update stats
	decrementOpenDatabaseConnections();

	logDbLogOut();

	loggedin=false;

	logDebugMessage("done logging out");
}

void sqlrcontroller_svr::setAutoCommit(bool ac) {
	logDebugMessage("setting autocommit...");
	if (ac) {
		if (!autoCommitOn()) {
			logDebugMessage("setting autocommit on failed");
			stderror.printf("Couldn't set autocommit on.\n");
			return;
		}
	} else {
		if (!autoCommitOff()) {
			logDebugMessage("setting autocommit off failed");
			stderror.printf("Couldn't set autocommit off.\n");
			return;
		}
	}
	logDebugMessage("done setting autocommit");
}

bool sqlrcontroller_svr::initCursors(int32_t count) {

	logDebugMessage("initializing cursors...");

	cursorcount=count;
	if (!cur) {
		cur=new sqlrcursor_svr *[maxcursorcount];
		rawbuffer::zero(cur,maxcursorcount*sizeof(sqlrcursor_svr *));
	}

	for (int32_t i=0; i<cursorcount; i++) {

		if (!cur[i]) {
			cur[i]=initCursor();
		}
		if (!cur[i]->openInternal(i)) {
			debugstr.clear();
			debugstr.append("cursor init failed: ")->append(i);
			logInternalError(NULL,debugstr.getString());
			return false;
		}
	}

	logDebugMessage("done initializing cursors");

	return true;
}

sqlrcursor_svr *sqlrcontroller_svr::initCursor() {
	sqlrcursor_svr	*cursor=conn->initCursor();
	if (cursor) {
		incrementOpenDatabaseCursors();
	}
	return cursor;
}

void sqlrcontroller_svr::incrementConnectionCount() {

	logDebugMessage("incrementing connection count...");

	if (scalerspawned) {

		logDebugMessage("scaler will do the job");
		signalScalerToRead();

	} else {

		acquireConnectionCountMutex();

		// increment the counter
		shm->totalconnections++;
		decrementonclose=true;

		releaseConnectionCountMutex();
	}

	logDebugMessage("done incrementing connection count");
}

void sqlrcontroller_svr::decrementConnectionCount() {

	logDebugMessage("decrementing connection count...");

	if (scalerspawned) {

		logDebugMessage("scaler will do the job");

	} else {

		acquireConnectionCountMutex();

		if (shm->totalconnections) {
			shm->totalconnections--;
		}
		decrementonclose=false;

		releaseConnectionCountMutex();
	}

	logDebugMessage("done decrementing connection count");
}

void sqlrcontroller_svr::markDatabaseAvailable() {

	size_t	stringlen=9+charstring::length(updown)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,"creating %s",updown);
	logDebugMessage(string);
	delete[] string;

	// the database is up if the file is there, 
	// opening and closing it will create it
	file	fd;
	fd.create(updown,permissions::ownerReadWrite());
}

void sqlrcontroller_svr::markDatabaseUnavailable() {

	// if the database is behind a load balancer, don't mark it unavailable
	if (constr->getBehindLoadBalancer()) {
		return;
	}

	size_t	stringlen=10+charstring::length(updown)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,"unlinking %s",updown);
	logDebugMessage(string);
	delete[] string;

	// the database is down if the file isn't there
	file::remove(updown);
}

bool sqlrcontroller_svr::openSockets() {

	logDebugMessage("listening on sockets...");

	// get the next available unix socket and open it
	if (cfgfl->getListenOnUnix() && unixsocketptr && unixsocketptr[0]) {

		if (!serversockun) {
			serversockun=new unixsocketserver();
			if (serversockun->listen(unixsocket,0000,5)) {

				size_t	stringlen=26+
					charstring::length(unixsocket)+1;
				char	*string=new char[stringlen];
				charstring::printf(string,stringlen,
						"listening on unix socket: %s",
						unixsocket);
				logDebugMessage(string);
				delete[] string;

				addFileDescriptor(serversockun);

			} else {
				debugstr.clear();
				debugstr.append("failed to listen on socket: ");
				debugstr.append(unixsocket);
				logInternalError(NULL,debugstr.getString());

				stderror.printf("Could not listen on ");
				stderror.printf("unix socket: ");
				stderror.printf("%s\n",unixsocket);
				stderror.printf("Make sure that the file and ");
				stderror.printf("directory are readable ");
				stderror.printf("and writable.\n\n");
				delete serversockun;
				return false;
			}
		}
	}

	// open the next available inet socket
	if (cfgfl->getListenOnInet()) {

		if (!serversockin) {
			const char * const *addresses=cfgfl->getAddresses();
			serversockincount=cfgfl->getAddressCount();
			serversockin=new inetsocketserver *[serversockincount];
			bool	failed=false;
			for (uint64_t index=0;
					index<serversockincount;
					index++) {
				serversockin[index]=NULL;
				if (failed) {
					continue;
				}
				serversockin[index]=new inetsocketserver();
				if (serversockin[index]->
					listen(addresses[index],inetport,5)) {

					if (!inetport) {
						inetport=serversockin[index]->
								getPort();
					}

					char	string[33];
					charstring::printf(string,33,
						"listening on inet socket: %d",
						inetport);
					logDebugMessage(string);
	
					addFileDescriptor(serversockin[index]);

				} else {
					debugstr.clear();
					debugstr.append("failed to listen "
							"on port: ");
					debugstr.append(inetport);
					logInternalError(NULL,
							debugstr.getString());

					stderror.printf("Could not listen on ");
					stderror.printf("inet socket: ");
					stderror.printf("%d\n\n",inetport);
					failed=true;
				}
			}
			if (failed) {
				for (uint64_t index=0;
						index<serversockincount;
						index++) {
					delete serversockin[index];
				}
				delete[] serversockin;
				serversockincount=0;
				return false;
			}
		}
	}

	logDebugMessage("done listening on sockets");

	return true;
}

bool sqlrcontroller_svr::listen() {

	uint16_t	sessioncount=0;
	bool		clientconnectfailed=false;

	for (;;) {

		waitForAvailableDatabase();
		initSession();
		announceAvailability(unixsocket,inetport,connectionid);

		// loop to handle suspended sessions
		bool	loopback=false;
		for (;;) {

			int	success=waitForClient();

			if (success==1) {

				suspendedsession=false;

				// have a session with the client
				clientSession();

				// break out of the loop unless the client
				// suspended the session
				if (!suspendedsession) {
					break;
				}

			} else if (success==2) {

				// this is a special case, basically it means
				// that the listener wants the connection to
				// reconnect to the database, just loop back
				// so that can be handled naturally
				loopback=true;
				break;

			} else if (success==-1) {

				// if waitForClient() errors out, break out of
				// the suspendedsession loop and loop back
				// for another session and close connection if
				// it is possible otherwise wait for session,
				// but it seems that on hard load it's
				// impossible to change handoff socket for pid
				clientconnectfailed=true;
				break;

			} else {

				// if waitForClient() times out waiting for
				// someone to pick up the suspended
				// session, roll it back and kill it
				if (suspendedsession) {
					if (conn->isTransactional()) {
						rollback();
					}
					suspendedsession=false;
				}
			}
		}

		if (!loopback && cfgfl->getDynamicScaling()) {

			decrementConnectedClientCount();

			if (scalerspawned) {

				if (clientconnectfailed) {
					return false;
				}

				if (ttl==0) {
					return true;
				}

				if (ttl>0 && cfgfl->getMaxSessionCount()) {
					sessioncount++;
					if (sessioncount==
						cfgfl->getMaxSessionCount()) {
						return true;
					}
				}
			}
		}
	}
}

void sqlrcontroller_svr::waitForAvailableDatabase() {

	logDebugMessage("waiting for available database...");

	updateState(WAIT_FOR_AVAIL_DB);

	if (!file::exists(updown)) {
		logDebugMessage("database is not available");
		reLogIn();
		markDatabaseAvailable();
	}

	logDebugMessage("database is available");
}

void sqlrcontroller_svr::reLogIn() {

	markDatabaseUnavailable();

	// run the session end queries
	// FIXME: only run these if a dead connection prompted
	// a relogin, not if we couldn't login at startup
	sessionEndQueries();

	// get the current db so we can restore it
	char	*currentdb=conn->getCurrentDatabase();

	// FIXME: get the isolation level so we can restore it

	logDebugMessage("relogging in...");

	// attempt to log in over and over, once every 5 seconds
	int32_t	oldcursorcount=cursorcount;
	closeCursors(false);
	logOut();
	for (;;) {
			
		logDebugMessage("trying...");

		incrementReLogInCount();

		if (logIn(false)) {
			if (!initCursors(oldcursorcount)) {
				closeCursors(false);
				logOut();
			} else {
				break;
			}
		}
		snooze::macrosnooze(5);
	}

	logDebugMessage("done relogging in");

	// run the session-start queries
	// FIXME: only run these if a dead connection prompted
	// a relogin, not if we couldn't login at startup
	sessionStartQueries();

	// restore the db
	conn->selectDatabase(currentdb);
	delete[] currentdb;

	// restore autocommit
	if (conn->autocommit) {
		conn->autoCommitOn();
	} else {
		conn->autoCommitOff();
	}

	// FIXME: restore the isolation level

	markDatabaseAvailable();
}

void sqlrcontroller_svr::initSession() {

	logDebugMessage("initializing session...");

	commitorrollback=false;
	suspendedsession=false;
	for (int32_t i=0; i<cursorcount; i++) {
		cur[i]->state=SQLRCURSORSTATE_AVAILABLE;
	}
	accepttimeout=5;

	logDebugMessage("done initializing session...");
}

void sqlrcontroller_svr::announceAvailability(const char *unixsocket,
						unsigned short inetport,
						const char *connectionid) {

	logDebugMessage("announcing availability...");

	// connect to listener if we haven't already
	// and pass it this process's pid
	if (!connected) {
		registerForHandoff();
	}

	// handle time-to-live
	if (ttl>0) {
		signalmanager::alarm(ttl);
	}

	acquireAnnounceMutex();

	// cancel time-to-live alarm
	//
	// It's important to cancel the alarm here.
	//
	// Connections which successfully announce themselves to the listener
	// cannot then die off.
	//
	// If handoff=pass, the listener can handle it if a connection dies off,
	// but not if handoff=reconnect, there's no way for it to know the
	// connection is gone.
	//
	// But, if the connection signals the listener to read the registration
	// and dies off before it receives a return signal from the listener
	// indicating that the listener has read it, then it can cause
	// problems.  And we can't simply call waitWithUndo() and
	// signalWithUndo().  Not only could the undo counter could overflow,
	// but we really only want to undo the signal() if the connection shuts
	// down before doing the wait() and there's no way to optionally
	// undo a semaphore.
	//
	// What a mess.
	if (ttl>0) {
		signalmanager::alarm(0);
	}

	updateState(ANNOUNCE_AVAILABILITY);

	// get a pointer to the shared memory segment
	shmdata	*idmemoryptr=getAnnounceBuffer();

	// first, write the connectionid into the segment
	charstring::copy(idmemoryptr->connectionid,
				connectionid,MAXCONNECTIONIDLEN);

	// write the pid into the segment
	idmemoryptr->connectioninfo.connectionpid=process::getProcessId();

	signalListenerToRead();

	waitForListenerToFinishReading();

	releaseAnnounceMutex();

	logDebugMessage("done announcing availability...");
}

void sqlrcontroller_svr::registerForHandoff() {

	logDebugMessage("registering for handoff...");

	// construct the name of the socket to connect to
	size_t	handoffsocknamelen=tmpdir->getLength()+9+
				charstring::length(cmdl->getId())+8+1;
	char	*handoffsockname=new char[handoffsocknamelen];
	charstring::printf(handoffsockname,handoffsocknamelen,
					"%s/sockets/%s-handoff",
					tmpdir->getString(),cmdl->getId());

	size_t	stringlen=17+charstring::length(handoffsockname)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,
				"handoffsockname: %s",handoffsockname);
	logDebugMessage(string);
	delete[] string;

	// Try to connect over and over forever on 1 second intervals.
	// If the connect succeeds but the write fails, loop back and
	// try again.
	connected=false;
	for (;;) {

		logDebugMessage("trying...");

		if (handoffsockun.connect(handoffsockname,-1,-1,1,0)==
							RESULT_SUCCESS) {
			handoffsockun.dontUseNaglesAlgorithm();
			if (handoffsockun.write(
				(uint32_t)process::getProcessId())==
							sizeof(uint32_t)) {
				connected=true;
				break;
			}
			handoffsockun.flushWriteBuffer(-1,-1);
			deRegisterForHandoff();
		}
		snooze::macrosnooze(1);
	}

	logDebugMessage("done registering for handoff");

	delete[] handoffsockname;
}

void sqlrcontroller_svr::deRegisterForHandoff() {
	
	logDebugMessage("de-registering for handoff...");

	// construct the name of the socket to connect to
	size_t	removehandoffsocknamelen=tmpdir->getLength()+9+
					charstring::length(cmdl->getId())+14+1;
	char	*removehandoffsockname=new char[removehandoffsocknamelen];
	charstring::printf(removehandoffsockname,
				removehandoffsocknamelen,
				"%s/sockets/%s-removehandoff",
				tmpdir->getString(),cmdl->getId());

	size_t	stringlen=23+charstring::length(removehandoffsockname)+1;
	char	*string=new char[stringlen];
	charstring::printf(string,stringlen,
				"removehandoffsockname: %s",
				removehandoffsockname);
	logDebugMessage(string);
	delete[] string;

	// attach to the socket and write the process id
	unixsocketclient	removehandoffsockun;
	removehandoffsockun.connect(removehandoffsockname,-1,-1,0,1);
	removehandoffsockun.dontUseNaglesAlgorithm();
	removehandoffsockun.write((uint32_t)process::getProcessId());
	removehandoffsockun.flushWriteBuffer(-1,-1);

	logDebugMessage("done de-registering for handoff");

	delete[] removehandoffsockname;
}

int32_t sqlrcontroller_svr::waitForClient() {

	logDebugMessage("waiting for client...");

	updateState(WAIT_CLIENT);

	// reset proxy mode flag
	proxymode=false;

	// FIXME: listen() checks for 2,1,0 or -1 from this method, but this
	// method only returns 2, 1 or -1.  0 should indicate that a suspended
	// session timed out.

	if (!suspendedsession) {

		// If we're not in the middle of a suspended session,
		// talk to the listener...


		// the client file descriptor
		int32_t	descriptor;

		// What is this loop all aboout?
		// If the listener is proxying clients, it can't tell whether
		// the client succeeded in transmitting an END_SESSION or
		// whether it even tried, so it sends one when the client
		// disconnects no matter what.  If the client did send one then
		// we'll receive a second END_SESSION here.  Depending on the
		// byte order of the host, we'll receive either a 1536 or 6.
		// If we got an END_SESION then just loop back and read again,
		// the command will follow.
		uint16_t	command;
		do {
			// get the command
			if (handoffsockun.read(&command)!=sizeof(uint16_t)) {
				logInternalError(NULL,
					"read handoff command failed");
				logDebugMessage("done waiting for client");
				// If this fails, then the listener most likely
				// died because sqlr-stop was run.  Arguably
				// this condition should initiate a shut down
				// of this process as well, but for now we'll
				// just wait to be shut down manually.
				// Unfortunatley, that means looping over and
				// over, with that read failing every time.
				// We'll sleep so as not to slam the machine
				// while we loop.
				snooze::microsnooze(0,100000);
				return -1;
			}
		} while (command==1536 || command==6);

		if (command==HANDOFF_RECONNECT) {

			// if we're supposed to reconnect, then just do that...
			return 2;

		} else if (command==HANDOFF_PASS) {

			// Receive the client file descriptor and use it.
			if (!handoffsockun.receiveFileDescriptor(&descriptor)) {
				logInternalError(NULL,"failed to receive "
						"client file descriptor");
				logDebugMessage("done waiting for client");
				// If this fails, then the listener most likely
				// died because sqlr-stop was run.  Arguably
				// this condition should initiate a shut down
				// of this process as well, but for now we'll
				// just wait to be shut down manually.
				// Unfortunatley, that means looping over and
				// over, with that read above failing every
				// time, thus the  sleep so as not to slam the
				// machine while we loop.
				return -1;
			}

		} else if (command==HANDOFF_PROXY) {

			logDebugMessage("listener is proxying the client");

			// get the listener's pid
			if (handoffsockun.read(&proxypid)!=sizeof(uint32_t)) {
				logInternalError(NULL,
						"failed to read process "
						"id during proxy handoff");
				return -1;
			}

			debugstr.clear();
			debugstr.append("listener pid: ")->append(proxypid);
			logDebugMessage(debugstr.getString());

			// acknowledge
			#define ACK	6
			handoffsockun.write((unsigned char)ACK);
			handoffsockun.flushWriteBuffer(-1,-1);

			descriptor=handoffsockun.getFileDescriptor();

			proxymode=true;

		} else {

			logInternalError(NULL,"received invalid handoff mode");
			return -1;
		}

		// set up the client socket
		clientsock=new filedescriptor;
		clientsock->setFileDescriptor(descriptor);

		logDebugMessage("done waiting for client");

	} else {

		// If we're in the middle of a suspended session, wait for
		// a client to reconnect...


		if (waitForNonBlockingRead(accepttimeout,0)<1) {
			logInternalError(NULL,"wait for client connect failed");
			// FIXME: I think this should return 0
			return -1;
		}

		// get the first socket that had data available...
		filedescriptor	*fd=getReadyList()->getFirstNode()->getValue();

		inetsocketserver	*iss=NULL;
		for (uint64_t index=0; index<serversockincount; index++) {
			if (fd==serversockin[index]) {
				iss=serversockin[index];
			}
		}
		if (iss) {
			clientsock=iss->accept();
		} else if (fd==serversockun) {
			clientsock=serversockun->accept();
		}

		if (fd) {
			logDebugMessage("client reconnect succeeded");
		} else {
			logInternalError(NULL,"client reconnect failed");
		}
		logDebugMessage("done waiting for client");

		if (!fd) {
			// FIXME: I think this should return 0
			return -1;
		}
	}

	// set up the socket
	clientsock->translateByteOrder();
	clientsock->dontUseNaglesAlgorithm();
	clientsock->setReadBufferSize(8192);
	clientsock->setWriteBufferSize(8192);
	return 1;
}

void sqlrcontroller_svr::clientSession() {

	logDebugMessage("client session...");

	inclientsession=true;

	// update various stats
	updateState(SESSION_START);
	updateClientAddr();
	updateClientSessionStartTime();
	incrementOpenClientConnections();

	logClientConnected();

	// determine client protocol...
	switch (getClientProtocol()) {
		case SQLRPROTOCOL_SQLRCLIENT:
			sqlrClientSession();
			break;
		case SQLRPROTOCOL_HTTP:
		case SQLRPROTOCOL_MYSQL:
		case SQLRPROTOCOL_POSTGRESQL:
		case SQLRPROTOCOL_TDS:
		default:
			closeClientSocket();
			break;
	}
}

sqlrprotocol_t sqlrcontroller_svr::getClientProtocol() {

	uint16_t	value=0;
	ssize_t		result=0;

	// get the first 2 bytes
	result=clientsock->read(&value,idleclienttimeout,0);
	if (result!=sizeof(value)) {
		return SQLRPROTOCOL_UNKNOWN;
	}

	// check for sqlrclient protocol
	if (value!=SQLRCLIENT_PROTOCOL) {
		return SQLRPROTOCOL_UNKNOWN;
	}

	// get the next 2 bytes
	result=clientsock->read(&value,idleclienttimeout,0);
	if (result!=sizeof(value)) {
		return SQLRPROTOCOL_UNKNOWN;
	}

	// check for version 1
	if (value!=1) {
		return SQLRPROTOCOL_UNKNOWN;
	}

	return SQLRPROTOCOL_SQLRCLIENT;
}

void sqlrcontroller_svr::sqlrClientSession() {

	// During each session, the client will send a series of commands.
	// The session ends when the client ends it or when certain commands
	// fail.
	bool		loop=true;
	bool		endsession=true;
	uint16_t	command;
	do {

		// get a command from the client
		if (!getCommand(&command)) {
			break;
		}

		// get the command start time
		timeval		tv;
		gettimeofday(&tv,NULL);

		// these commands are all handled at the connection level
		if (command==AUTHENTICATE) {
			incrementAuthenticateCount();
			if (authenticateCommand()) {
				sessionStartQueries();
				continue;
			}
			endsession=false;
			break;
		} else if (command==SUSPEND_SESSION) {
			incrementSuspendSessionCount();
			suspendSessionCommand();
			endsession=false;
			break;
		} else if (command==END_SESSION) {
			incrementEndSessionCount();
			break;
		} else if (command==PING) {
			incrementPingCount();
			pingCommand();
			continue;
		} else if (command==IDENTIFY) {
			incrementIdentifyCount();
			identifyCommand();
			continue;
		} else if (command==AUTOCOMMIT) {
			incrementAutocommitCount();
			autoCommitCommand();
			continue;
		} else if (command==BEGIN) {
			incrementBeginCount();
			beginCommand();
			continue;
		} else if (command==COMMIT) {
			incrementCommitCount();
			commitCommand();
			continue;
		} else if (command==ROLLBACK) {
			incrementRollbackCount();
			rollbackCommand();
			continue;
		} else if (command==DBVERSION) {
			incrementDbVersionCount();
			dbVersionCommand();
			continue;
		} else if (command==BINDFORMAT) {
			incrementBindFormatCount();
			bindFormatCommand();
			continue;
		} else if (command==SERVERVERSION) {
			incrementServerVersionCount();
			serverVersionCommand();
			continue;
		} else if (command==SELECT_DATABASE) {
			incrementSelectDatabaseCount();
			selectDatabaseCommand();
			continue;
		} else if (command==GET_CURRENT_DATABASE) {
			incrementGetCurrentDatabaseCount();
			getCurrentDatabaseCommand();
			continue;
		} else if (command==GET_LAST_INSERT_ID) {
			incrementGetLastInsertIdCount();
			getLastInsertIdCommand();
			continue;
		} else if (command==DBHOSTNAME) {
			incrementDbHostNameCount();
			dbHostNameCommand();
			continue;
		} else if (command==DBIPADDRESS) {
			incrementDbIpAddressCount();
			dbIpAddressCommand();
			continue;
		}

		// For the rest of the commands,
		// the client will request a cursor
		sqlrcursor_svr	*cursor=getCursor(command);
		if (!cursor) {
			// Don't worry about reporting that a cursor wasn't
			// available for abort-result-set commands. Those
			// commands don't look for a response from the server
			// and it doesn't matter if a non-existent result set
			// was aborted.
			if (command!=ABORT_RESULT_SET) {
				noAvailableCursors(command);
			}
			continue;
		}

		// keep track of the command start time
		cursor->commandstartsec=tv.tv_sec;
		cursor->commandstartusec=tv.tv_usec;

		// these commands are all handled at the cursor level
		if (command==NEW_QUERY) {
			incrementNewQueryCount();
			loop=newQueryCommand(cursor);
		} else if (command==REEXECUTE_QUERY) {
			incrementReexecuteQueryCount();
			loop=reExecuteQueryCommand(cursor);
		} else if (command==FETCH_FROM_BIND_CURSOR) {
			incrementFetchFromBindCursorCount();
			loop=fetchFromBindCursorCommand(cursor);
		} else if (command==FETCH_RESULT_SET) {
			incrementFetchResultSetCount();
			loop=fetchResultSetCommand(cursor);
		} else if (command==ABORT_RESULT_SET) {
			incrementAbortResultSetCount();
			abortResultSetCommand(cursor);
		} else if (command==SUSPEND_RESULT_SET) {
			incrementSuspendResultSetCount();
			suspendResultSetCommand(cursor);
		} else if (command==RESUME_RESULT_SET) {
			incrementResumeResultSetCount();
			loop=resumeResultSetCommand(cursor);
		} else if (command==GETDBLIST) {
			incrementGetDbListCount();
			loop=getDatabaseListCommand(cursor);
		} else if (command==GETTABLELIST) {
			incrementGetTableListCount();
			loop=getTableListCommand(cursor);
		} else if (command==GETCOLUMNLIST) {
			incrementGetColumnListCount();
			loop=getColumnListCommand(cursor);
		} else if (command==GET_QUERY_TREE) {
			incrementGetQueryTreeCount();
			loop=getQueryTreeCommand(cursor);
		} else {
			loop=false;
		}

		// get the command end-time
		gettimeofday(&tv,NULL);
		cursor->commandendsec=tv.tv_sec;
		cursor->commandendusec=tv.tv_usec;

		// log query-related commands
		// FIXME: this won't log triggers
		if (command==NEW_QUERY ||
			command==REEXECUTE_QUERY ||
			command==FETCH_FROM_BIND_CURSOR) {
			logQuery(cursor);
		}

	} while (loop);

	if (endsession) {
		endSession();
	}

	closeClientSocket();
	closeSuspendedSessionSockets();

	const char	*info="an error occurred";
	if (command==NO_COMMAND) {
		info="client closed connection";
	} else if (command==END_SESSION) {
		info="client ended the session";
	} else if (command==SUSPEND_SESSION) {
		info="client suspended the session";
	}
	logClientDisconnected(info);

	decrementOpenClientConnections();
	inclientsession=false;

	logDebugMessage("done with client session");
}

bool sqlrcontroller_svr::getCommand(uint16_t *command) {

	logDebugMessage("getting command...");

	updateState(GET_COMMAND);

	// get the command
	ssize_t	result=clientsock->read(command,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {

		// Return false but don't consider it an error if we get a
		// timeout or a 0 (meaning that the client closed the socket)
		// as either would be natural to do here.
		if (result!=RESULT_TIMEOUT && result!=0) {
			logClientProtocolError(NULL,
				"get command failed",result);
		}

		*command=NO_COMMAND;
		return false;
	}

	debugstr.clear();
	debugstr.append("command: ")->append(*command);
	logDebugMessage(debugstr.getString());

	logDebugMessage("done getting command");
	return true;
}

sqlrcursor_svr *sqlrcontroller_svr::getCursor(uint16_t command) {

	logDebugMessage("getting a cursor...");

	// does the client need a cursor or does it already have one
	uint16_t	neednewcursor=DONT_NEED_NEW_CURSOR;
	if (command==NEW_QUERY ||
		command==GETDBLIST ||
		command==GETTABLELIST ||
		command==GETCOLUMNLIST ||
		command==ABORT_RESULT_SET ||
		command==GET_QUERY_TREE) {
		ssize_t	result=clientsock->read(&neednewcursor,
						idleclienttimeout,0);
		if (result!=sizeof(uint16_t)) {
			logClientProtocolError(NULL,
					"get cursor failed: "
					"failed to get whether client "
					"needs  new cursor or not",result);
			return NULL;
		}
	}

	sqlrcursor_svr	*cursor=NULL;

	if (neednewcursor==DONT_NEED_NEW_CURSOR) {

		// which cursor is the client requesting?
		uint16_t	id;
		ssize_t		result=clientsock->read(&id,
						idleclienttimeout,0);
		if (result!=sizeof(uint16_t)) {
			logClientProtocolError(NULL,
					"get cursor failed: "
					"failed to get cursor id",result);
			return NULL;
		}

		// get the current cursor that they requested.
		bool	found=false;
		for (uint16_t i=0; i<cursorcount; i++) {
			if (cur[i]->id==id) {
				cursor=cur[i];
				incrementTimesCursorReused();
				found=true;
				break;
			}
		}

		// don't allow the client to request a cursor 
		// beyond the end of the array.
		if (!found) {
			debugstr.clear();
			debugstr.append("get cursor failed: "
					"client requested an invalid cursor: ");
			debugstr.append(id);
			logClientProtocolError(NULL,debugstr.getString(),1);
			return NULL;
		}

	} else {

		// find an available cursor
		cursor=findAvailableCursor();

 		// mark this as a new cursor being used
		if (cursor) {
			incrementTimesNewCursorUsed();
		}
	}

	logDebugMessage("done getting a cursor");
	return cursor;
}

sqlrcursor_svr *sqlrcontroller_svr::findAvailableCursor() {

	// find an available cursor
	for (uint16_t i=0; i<cursorcount; i++) {
		if (cur[i]->state==SQLRCURSORSTATE_AVAILABLE) {
			debugstr.clear();
			debugstr.append("available cursor: ")->append(i);
			logDebugMessage(debugstr.getString());
			cur[i]->state=SQLRCURSORSTATE_BUSY;
			return cur[i];
		}
	}

	// apparently there weren't any available cursors...

	// if we can't create any new cursors then return an error
	if (cursorcount==maxcursorcount) {
		logDebugMessage("all cursors are busy");
		return NULL;
	}

	// create new cursors
	uint16_t	expandto=cursorcount+cfgfl->getCursorsGrowBy();
	if (expandto>=maxcursorcount) {
		expandto=maxcursorcount;
	}
	uint16_t	firstnewcursor=cursorcount;
	do {
		cur[cursorcount]=initCursor();
		cur[cursorcount]->state=SQLRCURSORSTATE_AVAILABLE;
		if (!cur[cursorcount]->openInternal(cursorcount)) {
			debugstr.clear();
			debugstr.append("cursor init failure: ");
			debugstr.append(cursorcount);
			logInternalError(NULL,debugstr.getString());
			return NULL;
		}
		cursorcount++;
	} while (cursorcount<expandto);
	
	// return the first new cursor that we created
	cur[firstnewcursor]->state=SQLRCURSORSTATE_BUSY;
	return cur[firstnewcursor];
}

void sqlrcontroller_svr::noAvailableCursors(uint16_t command) {

	// If no cursor was available, the client
	// cound send an entire query and bind vars
	// before it reads the error and closes the
	// socket.  We have to absorb all of that
	// data.  We shouldn't just loop forever
	// though, that would provide a point of entry
	// for a DOS attack.  We'll read the maximum
	// number of bytes that could be sent.
	uint32_t	size=(
				// query size and query
				sizeof(uint32_t)+maxquerysize+
				// input bind var count
				sizeof(uint16_t)+
				// input bind vars
				maxbindcount*(2*sizeof(uint16_t)+
						maxbindnamelength)+
				// output bind var count
				sizeof(uint16_t)+
				// output bind vars
				maxbindcount*(2*sizeof(uint16_t)+
						maxbindnamelength)+
				// get column info
				sizeof(uint16_t)+
				// skip/fetch
				2*sizeof(uint32_t));

	clientsock->useNonBlockingMode();
	unsigned char	*dummy=new unsigned char[size];
	clientsock->read(dummy,size,idleclienttimeout,0);
	clientsock->useBlockingMode();
	delete[] dummy;

	// indicate that an error has occurred
	clientsock->write((uint16_t)ERROR_OCCURRED);

	// send the error code
	clientsock->write((uint64_t)SQLR_ERROR_NOCURSORS);

	// send the error itself
	uint16_t	len=charstring::length(SQLR_ERROR_NOCURSORS_STRING);
	clientsock->write(len);
	clientsock->write(SQLR_ERROR_NOCURSORS_STRING,len);
	clientsock->flushWriteBuffer(-1,-1);
}

bool sqlrcontroller_svr::authenticateCommand() {

	logDebugMessage("authenticate");

	// get the user/password from the client and authenticate
	if (getUserFromClient() && getPasswordFromClient() && authenticate()) {
		return true;
	}

	// indicate that an error has occurred
	clientsock->write((uint16_t)ERROR_OCCURRED_DISCONNECT);
	clientsock->write((uint64_t)SQLR_ERROR_AUTHENTICATIONERROR);
	clientsock->write((uint16_t)charstring::length(
				SQLR_ERROR_AUTHENTICATIONERROR_STRING));
	clientsock->write(SQLR_ERROR_AUTHENTICATIONERROR_STRING);
	clientsock->flushWriteBuffer(-1,-1);
	conn->endSession();
	return false;
}

bool sqlrcontroller_svr::getUserFromClient() {
	uint32_t	size=0;
	ssize_t		result=clientsock->read(&size,idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(NULL,
			"authentication failed: "
			"failed to get user size",result);
		return false;
	}
	if (size>=sizeof(userbuffer)) {
		debugstr.clear();
		debugstr.append("authentication failed: user size too long: ");
		debugstr.append(size);
		logClientConnectionRefused(debugstr.getString());
		return false;
	}
	result=clientsock->read(userbuffer,size,idleclienttimeout,0);
	if ((uint32_t)result!=size) {
		logClientProtocolError(NULL,
			"authentication failed: "
			"failed to get user",result);
		return false;
	}
	userbuffer[size]='\0';
	return true;
}

bool sqlrcontroller_svr::getPasswordFromClient() {
	uint32_t	size=0;
	ssize_t		result=clientsock->read(&size,idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(NULL,
			"authentication failed: "
			"failed to get password size",result);
		return false;
	}
	if (size>=sizeof(passwordbuffer)) {
		debugstr.clear();
		debugstr.append("authentication failed: "
				"password size too long: ");
		debugstr.append(size);
		logClientConnectionRefused(debugstr.getString());
		return false;
	}
	result=clientsock->read(passwordbuffer,size,idleclienttimeout,0);
	if ((uint32_t)result!=size) {
		logClientProtocolError(NULL,
			"authentication failed: "
			"failed to get password",result);
		return false;
	}
	passwordbuffer[size]='\0';
	return true;
}

bool sqlrcontroller_svr::authenticate() {

	logDebugMessage("authenticate...");

	// authenticate on the approprite tier
	if (cfgfl->getAuthOnDatabase() && conn->supportsAuthOnDatabase()) {
		return databaseBasedAuth(userbuffer,passwordbuffer);
	}
	return connectionBasedAuth(userbuffer,passwordbuffer);
}

bool sqlrcontroller_svr::connectionBasedAuth(const char *userbuffer,
						const char *passwordbuffer) {

	// handle connection-based authentication
	bool	retval=authc->authenticate(userbuffer,passwordbuffer);
	if (retval) {
		logDebugMessage("auth succeeded on connection");
	} else {
		logClientConnectionRefused("auth failed on connection: "
						"invalid user/password");
	}
	return retval;
}

bool sqlrcontroller_svr::databaseBasedAuth(const char *userbuffer,
						const char *passwordbuffer) {

	// if the user we want to change to is different from the
	// user that's currently proxied, try to change to that user
	bool	authsuccess;
	if ((!lastuserbuffer[0] && !lastpasswordbuffer[0]) || 
		charstring::compare(lastuserbuffer,userbuffer) ||
		charstring::compare(lastpasswordbuffer,passwordbuffer)) {

		// change authentication 
		logDebugMessage("change user");
		authsuccess=conn->changeUser(userbuffer,passwordbuffer);

		// keep a record of which user we're changing to
		// and whether that user was successful in 
		// authenticating
		charstring::copy(lastuserbuffer,userbuffer);
		charstring::copy(lastpasswordbuffer,passwordbuffer);
		lastauthsuccess=authsuccess;
	}

	if (lastauthsuccess) {
		logDebugMessage("auth succeeded on database");
	} else {
		logClientConnectionRefused("auth failed on database: "
						"invalid user/password");
	}
	return lastauthsuccess;
}

void sqlrcontroller_svr::suspendSessionCommand() {

	logDebugMessage("suspending session...");

	// mark the session suspended
	suspendedsession=true;

	// we can't wait forever for the client to resume, set a timeout
	accepttimeout=cfgfl->getSessionTimeout();

	// abort all cursors that aren't suspended...
	logDebugMessage("aborting busy cursors...");
	for (int32_t i=0; i<cursorcount; i++) {
		if (cur[i]->state==SQLRCURSORSTATE_BUSY) {
			cur[i]->abort();
		}
	}
	logDebugMessage("done aborting busy cursors");

	// open sockets to resume on
	logDebugMessage("opening sockets to resume on...");
	uint16_t	unixsocketsize=0;
	uint16_t	inetportnumber=0;
	if (openSockets()) {
		if (serversockun) {
			unixsocketsize=charstring::length(unixsocket);
		}
		inetportnumber=inetport;
	}
	logDebugMessage("done opening sockets to resume on");

	// pass the socket info to the client
	logDebugMessage("passing socket info to client...");
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	clientsock->write(unixsocketsize);
	if (unixsocketsize) {
		clientsock->write(unixsocket,unixsocketsize);
	}
	clientsock->write(inetportnumber);
	clientsock->flushWriteBuffer(-1,-1);
	logDebugMessage("done passing socket info to client");

	logDebugMessage("done suspending session");
}

void sqlrcontroller_svr::pingCommand() {
	logDebugMessage("ping");
	bool	pingresult=conn->ping();
	if (pingresult) {
		logDebugMessage("ping succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("ping failed");
		returnError(!conn->liveconnection);
	}
	if (!pingresult) {
		reLogIn();
	}
}

void sqlrcontroller_svr::identifyCommand() {

	logDebugMessage("identify");

	// get the identification
	const char	*ident=conn->identify();

	// send it to the client
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	idlen=charstring::length(ident);
	clientsock->write(idlen);
	clientsock->write(ident,idlen);
	clientsock->flushWriteBuffer(-1,-1);
}

void sqlrcontroller_svr::autoCommitCommand() {
	logDebugMessage("autocommit...");
	bool	on;
	ssize_t	result=clientsock->read(&on,idleclienttimeout,0);
	if (result!=sizeof(bool)) {
		logClientProtocolError(NULL,
				"get autocommit failed: "
				"failed to get autocommit setting",result);
		return;
	}
	bool	success=false;
	if (on) {
		logDebugMessage("autocommit on");
		success=autoCommitOn();
	} else {
		logDebugMessage("autocommit off");
		success=autoCommitOff();
	}
	if (success) {
		logDebugMessage("succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("failed");
		returnError(!conn->liveconnection);
	}
}

bool sqlrcontroller_svr::autoCommitOn() {
	autocommitforthissession=true;
	return conn->autoCommitOn();
}

bool sqlrcontroller_svr::autoCommitOff() {
	autocommitforthissession=false;
	return conn->autoCommitOff();
}

void sqlrcontroller_svr::beginCommand() {
	logDebugMessage("begin...");
	if (begin()) {
		logDebugMessage("succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("failed");
		returnError(!conn->liveconnection);
	}
}

bool sqlrcontroller_svr::begin() {
	// if we're faking transaction blocks, do that,
	// otherwise run an actual begin query
	return (faketransactionblocks)?
			beginFakeTransactionBlock():conn->begin();
}

bool sqlrcontroller_svr::beginFakeTransactionBlock() {

	// save the current autocommit state
	faketransactionblocksautocommiton=autocommitforthissession;

	// if autocommit is on, turn it off
	if (autocommitforthissession) {
		if (!autoCommitOff()) {
			return false;
		}
	}
	intransactionblock=true;
	return true;
}

void sqlrcontroller_svr::commitCommand() {
	logDebugMessage("commit...");
	if (commit()) {
		logDebugMessage("succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("failed");
		returnError(!conn->liveconnection);
	}
}

bool sqlrcontroller_svr::commit() {
	if (conn->commit()) {
		endFakeTransactionBlock();
		return true;
	}
	return false;
}

bool sqlrcontroller_svr::endFakeTransactionBlock() {

	// if we're faking begins and autocommit is on,
	// reset autocommit behavior
	if (faketransactionblocks && faketransactionblocksautocommiton) {
		if (!autoCommitOn()) {
			return false;
		}
	}
	intransactionblock=false;
	return true;
}

void sqlrcontroller_svr::rollbackCommand() {
	logDebugMessage("rollback...");
	if (rollback()) {
		logDebugMessage("succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("failed");
		returnError(!conn->liveconnection);
	}
}

bool sqlrcontroller_svr::rollback() {
	if (conn->rollback()) {
		endFakeTransactionBlock();
		return true;
	}
	return false;
}

void sqlrcontroller_svr::dbVersionCommand() {

	logDebugMessage("db version");

	// get the db version
	const char	*dbversion=conn->dbVersion();

	// send it to the client
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	dbvlen=charstring::length(dbversion);
	clientsock->write(dbvlen);
	clientsock->write(dbversion,dbvlen);
	clientsock->flushWriteBuffer(-1,-1);
}

void sqlrcontroller_svr::bindFormatCommand() {

	logDebugMessage("bind format");

	// get the bind format
	const char	*bf=conn->bindFormat();

	// send it to the client
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	bflen=charstring::length(bf);
	clientsock->write(bflen);
	clientsock->write(bf,bflen);
	clientsock->flushWriteBuffer(-1,-1);
}

void sqlrcontroller_svr::serverVersionCommand() {

	logDebugMessage("server version");

	// get the server version
	const char	*svrversion=SQLR_VERSION;

	// send it to the client
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	svrvlen=charstring::length(svrversion);
	clientsock->write(svrvlen);
	clientsock->write(svrversion,svrvlen);
	clientsock->flushWriteBuffer(-1,-1);
}

void sqlrcontroller_svr::selectDatabaseCommand() {

	logDebugMessage("select database");

	// get length of db parameter
	uint32_t	dblen;
	ssize_t		result=clientsock->read(&dblen,idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		clientsock->write(false);
		logClientProtocolError(NULL,
				"select database failed: "
				"failed to get db length",result);
		return;
	}

	// bounds checking
	if (dblen>maxquerysize) {
		clientsock->write(false);
		debugstr.clear();
		debugstr.append("select database failed: "
				"client sent bad db length: ");
		debugstr.append(dblen);
		logClientProtocolError(NULL,debugstr.getString(),1);
		return;
	}

	// read the db parameter into the buffer
	char	*db=new char[dblen+1];
	if (dblen) {
		result=clientsock->read(db,dblen,idleclienttimeout,0);
		if ((uint32_t)result!=dblen) {
			clientsock->write(false);
			clientsock->flushWriteBuffer(-1,-1);
			delete[] db;
			logClientProtocolError(NULL,
				"select database failed: "
				"failed to get database name",result);
			return;
		}
	}
	db[dblen]='\0';
	
	// Select the db and send back the result.  If we've been told to
	// ignore these calls, skip the actual call but act like it succeeded.
	if ((ignoreselectdb)?true:conn->selectDatabase(db)) {
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		returnError(!conn->liveconnection);
	}

	delete[] db;

	return;
}

void sqlrcontroller_svr::getCurrentDatabaseCommand() {

	logDebugMessage("get current database");

	// get the current database
	char	*currentdb=conn->getCurrentDatabase();

	// send it to the client
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	currentdbsize=charstring::length(currentdb);
	clientsock->write(currentdbsize);
	clientsock->write(currentdb,currentdbsize);
	clientsock->flushWriteBuffer(-1,-1);

	// clean up
	delete[] currentdb;
}

void sqlrcontroller_svr::getLastInsertIdCommand() {
	logDebugMessage("getting last insert id...");
	uint64_t	id;
	if (conn->getLastInsertId(&id)) {
		logDebugMessage("get last insert id succeeded");
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);
		clientsock->write(id);
		clientsock->flushWriteBuffer(-1,-1);
	} else {
		logDebugMessage("get last insert id failed");
		returnError(!conn->liveconnection);
	}
}

void sqlrcontroller_svr::dbHostNameCommand() {

	logDebugMessage("getting db host name");

	const char	*hostname=conn->dbHostName();
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	hostnamelen=charstring::length(hostname);
	clientsock->write(hostnamelen);
	clientsock->write(hostname,hostnamelen);
	clientsock->flushWriteBuffer(-1,-1);
}

void sqlrcontroller_svr::dbIpAddressCommand() {

	logDebugMessage("getting db host name");

	const char	*ipaddress=conn->dbIpAddress();
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	uint16_t	ipaddresslen=charstring::length(ipaddress);
	clientsock->write(ipaddresslen);
	clientsock->write(ipaddress,ipaddresslen);
	clientsock->flushWriteBuffer(-1,-1);
}

bool sqlrcontroller_svr::newQueryCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("new query");
	return handleQueryOrBindCursor(cursor,false,false,true);
}

bool sqlrcontroller_svr::reExecuteQueryCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("rexecute query");
	return handleQueryOrBindCursor(cursor,true,false,true);
}

bool sqlrcontroller_svr::fetchFromBindCursorCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("fetch from bind cursor");
	return handleQueryOrBindCursor(cursor,false,true,true);
}

bool sqlrcontroller_svr::handleQueryOrBindCursor(sqlrcursor_svr *cursor,
							bool reexecute,
							bool bindcursor,
							bool getquery) {


	logDebugMessage("handling query...");

	// decide whether to use the cursor itself
	// or an attached custom query cursor
	if (cursor->customquerycursor) {
		if (reexecute) {
			cursor=cursor->customquerycursor;
		} else {
			cursor->customquerycursor->close();
			delete cursor->customquerycursor;
			cursor->customquerycursor=NULL;
		}
	}

	// re-init error data
	cursor->clearError();

	// clear bind mappings and reset the fake input binds flag
	// (do this here because getInput/OutputBinds uses the bindmappingspool)
	if (!bindcursor && !reexecute) {
		bindmappingspool->deallocate();
		inbindmappings->clear();
		outbindmappings->clear();
		cursor->fakeinputbindsforthisquery=fakeinputbinds;
	}

	// clean up whatever result set the cursor might have been busy with
	cursor->cleanUpData();

	// get the query and bind data from the client...
	bool	usingcustomquerycursor=false;
	if (getquery) {

		// re-init buffers
		if (!reexecute && !bindcursor) {
			clientinfo[0]='\0';
			clientinfolen=0;
		}
		if (!reexecute) {
			cursor->querybuffer[0]='\0';
			cursor->querylength=0;
		}
		cursor->inbindcount=0;
		cursor->outbindcount=0;
		for (uint16_t i=0; i<maxbindcount; i++) {
			rawbuffer::zero(&(cursor->inbindvars[i]),
						sizeof(bindvar_svr));
			rawbuffer::zero(&(cursor->outbindvars[i]),
						sizeof(bindvar_svr));
		}

		// get the data
		bool	success=true;
		if (!reexecute && !bindcursor) {
			success=(getClientInfo(cursor) &&
					getQuery(cursor));

			// do we need to use a custom query
			// handler for this query?
			if (success && sqlrq) {
				cursor->customquerycursor=
					sqlrq->match(conn,
						cursor->querybuffer,
						cursor->querylength);
				
			}

			if (cursor->customquerycursor) {

				// open the cursor
				cursor->customquerycursor->openInternal(
								cursor->id);

				// copy the query that we just got into the
				// custom query cursor
				charstring::copy(
					cursor->customquerycursor->querybuffer,
					cursor->querybuffer);
				cursor->customquerycursor->querylength=
							cursor->querylength;

				// set the cursor state
				cursor->customquerycursor->state=
						SQLRCURSORSTATE_BUSY;

				// reset the rest of this method to use
				// the custom query cursor
				cursor=cursor->customquerycursor;

				usingcustomquerycursor=true;
			}
		}
		if (success && !bindcursor) {
			success=(getInputBinds(cursor) &&
					getOutputBinds(cursor));
		}
		if (success) {
			success=getSendColumnInfo();
		}
		if (!success) {
			// The client is apparently sending us something we
			// can't handle.  Return an error if there was one,
			// instruct the client to disconnect and return false
			// to end the session on this side.
			if (cursor->errnum) {
				returnError(cursor,true);
			}
			logDebugMessage("failed to handle query");
			return false;
		}
	}

	updateState((usingcustomquerycursor)?PROCESS_CUSTOM:PROCESS_SQL);

	// loop here to handle down databases
	for (;;) {

		// process the query
		bool	success=false;
		bool	wasfaketransactionquery=false;
		if (!reexecute && !bindcursor && faketransactionblocks) {
			success=handleFakeTransactionQueries(cursor,
						&wasfaketransactionquery);
		}
		if (!wasfaketransactionquery) {
			success=processQuery(cursor,reexecute,bindcursor);
		}

		if (success) {
			// get skip and fetch parameters here so everything
			// can be done in one round trip without relying on
			// buffering
			success=getSkipAndFetch(cursor);
		}

		if (success) {

			// indicate that no error has occurred
			clientsock->write((uint16_t)NO_ERROR_OCCURRED);

			// send the client the id of the 
			// cursor that it's going to use
			clientsock->write(cursor->id);

			// tell the client that this is not a
			// suspended result set
			clientsock->write((uint16_t)NO_SUSPENDED_RESULT_SET);

			// if the query processed 
			// ok then send a result set
			// header and return...
			returnResultSetHeader(cursor);

			// free memory used by binds
			bindpool->deallocate();

			logDebugMessage("handle query succeeded");

			// reinit lastrow
			cursor->lastrowvalid=false;

			// return the result set
			return returnResultSetData(cursor,false);

		} else {

			// if the db is still up, or if we're not waiting
			// for them if they're down, then return the error
			if (cursor->liveconnection ||
				!cfgfl->getWaitForDownDatabase()) {

				// return the error
				returnError(cursor,!cursor->liveconnection);
			}

			// if the error was a dead connection
			// then re-establish the connection
			if (!cursor->liveconnection) {

				logDebugMessage("database is down...");

				logDbError(cursor,cursor->error);

				reLogIn();

				// if we're waiting for down databases then
				// loop back and try the query again
				if (cfgfl->getWaitForDownDatabase()) {
					continue;
				}
			}

			return true;
		}
	}
}

bool sqlrcontroller_svr::getClientInfo(sqlrcursor_svr *cursor) {

	logDebugMessage("getting client info...");

	// init
	clientinfolen=0;
	clientinfo[0]='\0';

	// get the length of the client info
	ssize_t	result=clientsock->read(&clientinfolen);
	if (result!=sizeof(uint64_t)) {
		clientinfolen=0;
		logClientProtocolError(cursor,
				"get client info failed: "
				"failed to get clientinfo length",result);
		return false;
	}

	// bounds checking
	if (clientinfolen>maxclientinfolength) {

		stringbuffer	err;
		err.append(SQLR_ERROR_MAXCLIENTINFOLENGTH_STRING);
		err.append(" (")->append(clientinfolen)->append('>');
		err.append(maxclientinfolength)->append(')');
		cursor->setError(err.getString(),
				SQLR_ERROR_MAXCLIENTINFOLENGTH,true);

		debugstr.clear();
		debugstr.append("get client info failed: "
				"client sent bad client info size: ");
		debugstr.append(clientinfolen);
		logClientProtocolError(cursor,debugstr.getString(),1);

		clientinfolen=0;
		return false;
	}

	// read the client info into the buffer
	result=clientsock->read(clientinfo,clientinfolen);
	if ((uint64_t)result!=clientinfolen) {
		clientinfolen=0;
		clientinfo[0]='\0';
		logClientProtocolError(cursor,
				"get client info failed: "
				"failed to get client info",result);
		return false;
	}
	clientinfo[clientinfolen]='\0';

	if (sqlrlg) {
		debugstr.clear();
		debugstr.append("clientinfolen: ")->append(clientinfolen);
		logDebugMessage(debugstr.getString());
		debugstr.clear();
		debugstr.append("clientinfo: ")->append(clientinfo);
		logDebugMessage(debugstr.getString());
		logDebugMessage("getting clientinfo succeeded");
	}

	// update the stats with the client info
	updateClientInfo(clientinfo,clientinfolen);

	return true;
}

bool sqlrcontroller_svr::getQuery(sqlrcursor_svr *cursor) {

	logDebugMessage("getting query...");

	// init
	cursor->querylength=0;
	cursor->querybuffer[0]='\0';

	// get the length of the query
	ssize_t	result=clientsock->read(&cursor->querylength,
						idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		cursor->querylength=0;
		logClientProtocolError(cursor,
				"get query failed: "
				"failed to get query length",result);
		return false;
	}

	// bounds checking
	if (cursor->querylength>maxquerysize) {

		stringbuffer	err;
		err.append(SQLR_ERROR_MAXQUERYLENGTH_STRING);
		err.append(" (")->append(cursor->querylength)->append('>');
		err.append(maxquerysize)->append(')');
		cursor->setError(err.getString(),
				SQLR_ERROR_MAXQUERYLENGTH,true);

		debugstr.clear();
		debugstr.append("get query failed: "
				"client sent bad query length: ");
		debugstr.append(cursor->querylength);
		logClientProtocolError(cursor,debugstr.getString(),1);

		cursor->querylength=0;
		return false;
	}

	// read the query into the buffer
	result=clientsock->read(cursor->querybuffer,
				cursor->querylength,
				idleclienttimeout,0);
	if ((uint32_t)result!=cursor->querylength) {

		cursor->querylength=0;
		cursor->querybuffer[0]='\0';

		logClientProtocolError(cursor,
				"get query failed: "
				"failed to get query",result);
		return false;
	}
	cursor->querybuffer[cursor->querylength]='\0';

	if (sqlrlg) {
		debugstr.clear();
		debugstr.append("querylength: ")->append(cursor->querylength);
		logDebugMessage(debugstr.getString());
		debugstr.clear();
		debugstr.append("query: ")->append(cursor->querybuffer);
		logDebugMessage(debugstr.getString());
		logDebugMessage("getting query succeeded");
	}

	// update the stats with the current query
	updateCurrentQuery(cursor->querybuffer,cursor->querylength);

	return true;
}

bool sqlrcontroller_svr::getInputBinds(sqlrcursor_svr *cursor) {

	logDebugMessage("getting input binds...");

	// get the number of input bind variable/values
	if (!getBindVarCount(cursor,&(cursor->inbindcount))) {
		return false;
	}
	
	// fill the buffers
	for (uint16_t i=0; i<cursor->inbindcount && i<maxbindcount; i++) {

		bindvar_svr	*bv=&(cursor->inbindvars[i]);

		// get the variable name and type
		if (!(getBindVarName(cursor,bv) && getBindVarType(bv))) {
			return false;
		}

		// get the value
		if (bv->type==NULL_BIND) {
			getNullBind(bv);
		} else if (bv->type==STRING_BIND) {
			if (!getStringBind(cursor,bv)) {
				return false;
			}
		} else if (bv->type==INTEGER_BIND) {
			if (!getIntegerBind(bv)) {
				return false;
			}
		} else if (bv->type==DOUBLE_BIND) {
			if (!getDoubleBind(bv)) {
				return false;
			}
		} else if (bv->type==DATE_BIND) {
			if (!getDateBind(bv)) {
				return false;
			}
		} else if (bv->type==BLOB_BIND) {
			// can't fake blob binds
			cursor->fakeinputbindsforthisquery=false;
			if (!getLobBind(cursor,bv)) {
				return false;
			}
		} else if (bv->type==CLOB_BIND) {
			if (!getLobBind(cursor,bv)) {
				return false;
			}
		}		  
	}

	logDebugMessage("done getting input binds");
	return true;
}

bool sqlrcontroller_svr::getOutputBinds(sqlrcursor_svr *cursor) {

	logDebugMessage("getting output binds...");

	// get the number of output bind variable/values
	if (!getBindVarCount(cursor,&(cursor->outbindcount))) {
		return false;
	}

	// fill the buffers
	for (uint16_t i=0; i<cursor->outbindcount && i<maxbindcount; i++) {

		bindvar_svr	*bv=&(cursor->outbindvars[i]);

		// get the variable name and type
		if (!(getBindVarName(cursor,bv) && getBindVarType(bv))) {
			return false;
		}

		// get the size of the value
		if (bv->type==STRING_BIND) {
			bv->value.stringval=NULL;
			if (!getBindSize(cursor,bv,&maxstringbindvaluelength)) {
				return false;
			}
			// This must be a allocated and cleared because oracle8
			// gets angry if these aren't initialized to NULL's.
			// It's possible that just the first character needs to
			// be NULL, but for now I'm just going to go ahead and
			// use allocateAndClear.
			bv->value.stringval=
				(char *)bindpool->allocateAndClear(
							bv->valuesize+1);
			logDebugMessage("STRING");
		} else if (bv->type==INTEGER_BIND) {
			logDebugMessage("INTEGER");
		} else if (bv->type==DOUBLE_BIND) {
			logDebugMessage("DOUBLE");
			// these don't typically get set, but they get used
			// when building debug strings, so we need to
			// initialize them
			bv->value.doubleval.precision=0;
			bv->value.doubleval.scale=0;
		} else if (bv->type==DATE_BIND) {
			logDebugMessage("DATE");
			bv->value.dateval.year=0;
			bv->value.dateval.month=0;
			bv->value.dateval.day=0;
			bv->value.dateval.hour=0;
			bv->value.dateval.minute=0;
			bv->value.dateval.second=0;
			bv->value.dateval.microsecond=0;
			bv->value.dateval.tz=NULL;
			// allocate enough space to store the date/time string
			// or whatever buffer a child might need to store a
			// date 512 bytes ought to be enough
			bv->value.dateval.buffersize=512;
			bv->value.dateval.buffer=(char *)bindpool->allocate(
						bv->value.dateval.buffersize);
		} else if (bv->type==BLOB_BIND || bv->type==CLOB_BIND) {
			if (!getBindSize(cursor,bv,&maxlobbindvaluelength)) {
				return false;
			}
			if (bv->type==BLOB_BIND) {
				logDebugMessage("BLOB");
			} else if (bv->type==CLOB_BIND) {
				logDebugMessage("CLOB");
			}
		} else if (bv->type==CURSOR_BIND) {
			logDebugMessage("CURSOR");
			sqlrcursor_svr	*curs=findAvailableCursor();
			if (!curs) {
				// FIXME: set error here
				return false;
			}
			curs->state=SQLRCURSORSTATE_BUSY;
			bv->value.cursorid=curs->id;
		}

		// init the null indicator
		bv->isnull=conn->nonNullBindValue();
	}

	logDebugMessage("done getting output binds");
	return true;
}

bool sqlrcontroller_svr::getBindVarCount(sqlrcursor_svr *cursor,
						uint16_t *count) {

	// init
	*count=0;

	// get the number of input bind variable/values
	ssize_t	result=clientsock->read(count,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(cursor,
				"get binds failed: "
				"failed to get bind count",result);
		*count=0;
		return false;
	}

	// bounds checking
	if (*count>maxbindcount) {

		stringbuffer	err;
		err.append(SQLR_ERROR_MAXBINDCOUNT_STRING);
		err.append(" (")->append(*count)->append('>');
		err.append(maxbindcount)->append(')');
		cursor->setError(err.getString(),SQLR_ERROR_MAXBINDCOUNT,true);

		debugstr.clear();
		debugstr.append("get binds failed: "
				"client tried to send too many binds: ");
		debugstr.append(*count);
		logClientProtocolError(cursor,debugstr.getString(),1);

		*count=0;
		return false;
	}

	return true;
}

bool sqlrcontroller_svr::getBindVarName(sqlrcursor_svr *cursor,
						bindvar_svr *bv) {

	// init
	bv->variablesize=0;
	bv->variable=NULL;

	// get the variable name size
	uint16_t	bindnamesize;
	ssize_t		result=clientsock->read(&bindnamesize,
						idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(cursor,
				"get binds failed: "
				"failed to get variable name length",result);
		return false;
	}

	// bounds checking
	if (bindnamesize>maxbindnamelength) {

		stringbuffer	err;
		err.append(SQLR_ERROR_MAXBINDNAMELENGTH_STRING);
		err.append(" (")->append(bindnamesize)->append('>');
		err.append(maxbindnamelength)->append(')');
		cursor->setError(err.getString(),
					SQLR_ERROR_MAXBINDNAMELENGTH,true);

		debugstr.clear();
		debugstr.append("get binds failed: bad variable name length: ");
		debugstr.append(bindnamesize);
		logClientProtocolError(cursor,debugstr.getString(),1);
		return false;
	}

	// get the variable name
	bv->variablesize=bindnamesize+1;
	bv->variable=(char *)bindmappingspool->allocate(bindnamesize+2);
	bv->variable[0]=conn->bindVariablePrefix();
	result=clientsock->read(bv->variable+1,bindnamesize,
					idleclienttimeout,0);
	if (result!=bindnamesize) {
		bv->variablesize=0;
		bv->variable[0]='\0';
		logClientProtocolError(cursor,
				"get binds failed: "
				"failed to get variable name",result);
		return false;
	}
	bv->variable[bindnamesize+1]='\0';

	logDebugMessage(bv->variable);

	return true;
}

bool sqlrcontroller_svr::getBindVarType(bindvar_svr *bv) {

	// get the type
	ssize_t	result=clientsock->read(&bv->type,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get type",result);
		return false;
	}
	return true;
}

bool sqlrcontroller_svr::getBindSize(sqlrcursor_svr *cursor,
					bindvar_svr *bv, uint32_t *maxsize) {

	// init
	bv->valuesize=0;

	// get the size of the value
	ssize_t	result=clientsock->read(&(bv->valuesize),idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		bv->valuesize=0;
		logClientProtocolError(cursor,
				"get binds failed: "
				"failed to get bind value length",result);
		return false;
	}

	// bounds checking
	if (bv->valuesize>*maxsize) {
		if (maxsize==&maxstringbindvaluelength) {
			stringbuffer	err;
			err.append(SQLR_ERROR_MAXSTRINGBINDVALUELENGTH_STRING);
			err.append(" (")->append(bv->valuesize)->append('>');
			err.append(*maxsize)->append(')');
			cursor->setError(err.getString(),
				SQLR_ERROR_MAXSTRINGBINDVALUELENGTH,true);
		} else {
			stringbuffer	err;
			err.append(SQLR_ERROR_MAXLOBBINDVALUELENGTH_STRING);
			err.append(" (")->append(bv->valuesize)->append('>');
			err.append(*maxsize)->append(')');
			cursor->setError(err.getString(),
				SQLR_ERROR_MAXLOBBINDVALUELENGTH,true);
		}
		debugstr.clear();
		debugstr.append("get binds failed: bad value length: ");
		debugstr.append(bv->valuesize);
		logClientProtocolError(cursor,debugstr.getString(),1);
		return false;
	}

	return true;
}

void sqlrcontroller_svr::getNullBind(bindvar_svr *bv) {

	logDebugMessage("NULL");

	bv->value.stringval=(char *)bindpool->allocate(1);
	bv->value.stringval[0]='\0';
	bv->valuesize=0;
	bv->isnull=conn->nullBindValue();
}

bool sqlrcontroller_svr::getStringBind(sqlrcursor_svr *cursor,
						bindvar_svr *bv) {

	logDebugMessage("STRING");

	// init
	bv->value.stringval=NULL;

	// get the size of the value
	if (!getBindSize(cursor,bv,&maxstringbindvaluelength)) {
		return false;
	}

	// allocate space to store the value
	bv->value.stringval=(char *)bindpool->allocate(bv->valuesize+1);

	// get the bind value
	ssize_t	result=clientsock->read(bv->value.stringval,
					bv->valuesize,
					idleclienttimeout,0);
	if ((uint32_t)result!=(uint32_t)(bv->valuesize)) {
		bv->value.stringval[0]='\0';
		const char	*info="get binds failed: "
					"failed to get bind value";
		logClientProtocolError(cursor,info,result);
		return false;
	}
	bv->value.stringval[bv->valuesize]='\0';
	bv->isnull=conn->nonNullBindValue();

	logDebugMessage(bv->value.stringval);

	return true;
}

bool sqlrcontroller_svr::getIntegerBind(bindvar_svr *bv) {

	logDebugMessage("INTEGER");

	// get the value itself
	uint64_t	value;
	ssize_t		result=clientsock->read(&value,idleclienttimeout,0);
	if (result!=sizeof(uint64_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get bind value",result);
		return false;
	}

	// set the value
	bv->value.integerval=(int64_t)value;

	char	*intval=charstring::parseNumber(bv->value.integerval);
	logDebugMessage(intval);
	delete[] intval;

	return true;
}

bool sqlrcontroller_svr::getDoubleBind(bindvar_svr *bv) {

	logDebugMessage("DOUBLE");

	// get the value
	ssize_t	result=clientsock->read(&(bv->value.doubleval.value),
						idleclienttimeout,0);
	if (result!=sizeof(double)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get bind value",result);
		return false;
	}

	// get the precision
	result=clientsock->read(&(bv->value.doubleval.precision),
						idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get precision",result);
		return false;
	}

	// get the scale
	result=clientsock->read(&(bv->value.doubleval.scale),
						idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get scale",result);
		return false;
	}

	char	*doubleval=charstring::parseNumber(bv->value.doubleval.value);
	logDebugMessage(doubleval);
	delete[] doubleval;

	return true;
}

bool sqlrcontroller_svr::getDateBind(bindvar_svr *bv) {

	logDebugMessage("DATE");

	// init
	bv->value.dateval.tz=NULL;

	uint16_t	temp;

	// get the year
	ssize_t	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get year",result);
		return false;
	}
	bv->value.dateval.year=(int16_t)temp;

	// get the month
	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get month",result);
		return false;
	}
	bv->value.dateval.month=(int16_t)temp;

	// get the day
	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get day",result);
		return false;
	}
	bv->value.dateval.day=(int16_t)temp;

	// get the hour
	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get hour",result);
		return false;
	}
	bv->value.dateval.hour=(int16_t)temp;

	// get the minute
	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get minute",result);
		return false;
	}
	bv->value.dateval.minute=(int16_t)temp;

	// get the second
	result=clientsock->read(&temp,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get second",result);
		return false;
	}
	bv->value.dateval.second=(int16_t)temp;

	// get the microsecond
	uint32_t	temp32;
	result=clientsock->read(&temp32,idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get microsecond",result);
		return false;
	}
	bv->value.dateval.microsecond=(int32_t)temp32;

	// get the size of the time zone
	uint16_t	length;
	result=clientsock->read(&length,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get timezone size",result);
		return false;
	}

	// FIXME: do bounds checking here

	// allocate space to store the time zone
	bv->value.dateval.tz=(char *)bindpool->allocate(length+1);

	// get the time zone
	result=clientsock->read(bv->value.dateval.tz,length,
					idleclienttimeout,0);
	if ((uint16_t)result!=length) {
		bv->value.dateval.tz[0]='\0';
		logClientProtocolError(NULL,
				"get binds failed: "
				"failed to get timezone",result);
		return false;
	}
	bv->value.dateval.tz[length]='\0';

	// allocate enough space to store the date/time string
	// 64 bytes ought to be enough
	bv->value.dateval.buffersize=64;
	bv->value.dateval.buffer=(char *)bindpool->allocate(
					bv->value.dateval.buffersize);

	stringbuffer	str;
	str.append(bv->value.dateval.year)->append("-");
	str.append(bv->value.dateval.month)->append("-");
	str.append(bv->value.dateval.day)->append(" ");
	str.append(bv->value.dateval.hour)->append(":");
	str.append(bv->value.dateval.minute)->append(":");
	str.append(bv->value.dateval.second)->append(":");
	str.append(bv->value.dateval.microsecond)->append(" ");
	str.append(bv->value.dateval.tz);
	logDebugMessage(str.getString());

	return true;
}

bool sqlrcontroller_svr::getLobBind(sqlrcursor_svr *cursor, bindvar_svr *bv) {

	// init
	bv->value.stringval=NULL;

	if (bv->type==BLOB_BIND) {
		logDebugMessage("BLOB");
	}
	if (bv->type==CLOB_BIND) {
		logDebugMessage("CLOB");
	}

	// get the size of the value
	if (!getBindSize(cursor,bv,&maxlobbindvaluelength)) {
		return false;
	}

	// allocate space to store the value
	// (the +1 is to store the NULL-terminator for CLOBS)
	bv->value.stringval=(char *)bindpool->allocate(bv->valuesize+1);

	// get the bind value
	ssize_t	result=clientsock->read(bv->value.stringval,
					bv->valuesize,
					idleclienttimeout,0);
	if ((uint32_t)result!=(uint32_t)(bv->valuesize)) {
		bv->value.stringval[0]='\0';
		logClientProtocolError(cursor,
				"get binds failed: bad value",result);
		return false;
	}

	// It shouldn't hurt to NULL-terminate the lob because the actual size
	// (which doesn't include the NULL terminator) should be used when
	// binding.
	bv->value.stringval[bv->valuesize]='\0';
	bv->isnull=conn->nonNullBindValue();

	return true;
}

bool sqlrcontroller_svr::getSendColumnInfo() {

	logDebugMessage("get send column info...");

	ssize_t	result=clientsock->read(&sendcolumninfo,idleclienttimeout,0);
	if (result!=sizeof(uint16_t)) {
		logClientProtocolError(NULL,
				"get send column info failed",result);
		return false;
	}

	if (sendcolumninfo==SEND_COLUMN_INFO) {
		logDebugMessage("send column info");
	} else {
		logDebugMessage("don't send column info");
	}
	logDebugMessage("done getting send column info...");

	return true;
}

bool sqlrcontroller_svr::handleFakeTransactionQueries(sqlrcursor_svr *cursor,
						bool *wasfaketransactionquery) {

	*wasfaketransactionquery=false;

	// Intercept begins and handle them.  If we're faking begins, commit
	// and rollback queries also need to be intercepted as well, otherwise
	// the query will be sent directly to the db and endFakeBeginTransaction
	// won't get called.
	if (isBeginTransactionQuery(cursor)) {
		*wasfaketransactionquery=true;
		cursor->inbindcount=0;
		cursor->outbindcount=0;
		sendcolumninfo=DONT_SEND_COLUMN_INFO;
		if (intransactionblock) {
			charstring::copy(cursor->error,
				"begin while in transaction block");
			cursor->errorlength=charstring::length(cursor->error);
			cursor->errnum=999999;
			return false;
		}
		return begin();
		// FIXME: if the begin fails and the db api doesn't support
		// a begin command then the connection-level error needs to
		// be copied to the cursor so handleQueryOrBindCursor can
		// report it
	} else if (isCommitQuery(cursor)) {
		*wasfaketransactionquery=true;
		cursor->inbindcount=0;
		cursor->outbindcount=0;
		sendcolumninfo=DONT_SEND_COLUMN_INFO;
		if (!intransactionblock) {
			charstring::copy(cursor->error,
				"commit while not in transaction block");
			cursor->errorlength=charstring::length(cursor->error);
			cursor->errnum=999998;
			return false;
		}
		return commit();
		// FIXME: if the commit fails and the db api doesn't support
		// a commit command then the connection-level error needs to
		// be copied to the cursor so handleQueryOrBindCursor can
		// report it
	} else if (isRollbackQuery(cursor)) {
		*wasfaketransactionquery=true;
		cursor->inbindcount=0;
		cursor->outbindcount=0;
		sendcolumninfo=DONT_SEND_COLUMN_INFO;
		if (!intransactionblock) {
			charstring::copy(cursor->error,
				"rollback while not in transaction block");
			cursor->errorlength=charstring::length(cursor->error);
			cursor->errnum=999997;
			return false;
		}
		return rollback();
		// FIXME: if the rollback fails and the db api doesn't support
		// a rollback command then the connection-level error needs to
		// be copied to the cursor so handleQueryOrBindCursor can
		// report it
	}
	return false;
}

bool sqlrcontroller_svr::isBeginTransactionQuery(sqlrcursor_svr *cursor) {

	// find the start of the actual query
	const char	*ptr=cursor->skipWhitespaceAndComments(
						cursor->querybuffer);

	// See if it was any of the different queries used to start a
	// transaction.  IMPORTANT: don't just look for the first 5 characters
	// to be "BEGIN", make sure it's the entire query.  Many db's use
	// "BEGIN" to start a stored procedure block, but in those cases,
	// something will follow it.
	if (!charstring::compareIgnoringCase(ptr,"BEGIN",5)) {

		// make sure there are only spaces, comments or the word "work"
		// after the begin
		const char	*spaceptr=
				cursor->skipWhitespaceAndComments(ptr+5);
		
		if (!charstring::compareIgnoringCase(spaceptr,"WORK",4) ||
			*spaceptr=='\0') {
			return true;
		}
		return false;

	} else if (!charstring::compareIgnoringCase(ptr,"START ",6)) {
		return true;
	}
	return false;
}

bool sqlrcontroller_svr::isCommitQuery(sqlrcursor_svr *cursor) {
	return !charstring::compareIgnoringCase(
			cursor->skipWhitespaceAndComments(
						cursor->querybuffer),
			"commit",6);
}

bool sqlrcontroller_svr::isRollbackQuery(sqlrcursor_svr *cursor) {
	return !charstring::compareIgnoringCase(
			cursor->skipWhitespaceAndComments(
						cursor->querybuffer),
			"rollback",8);
}

bool sqlrcontroller_svr::processQuery(sqlrcursor_svr *cursor,
					bool reexecute, bool bindcursor) {

	logDebugMessage("processing query...");

	// on reexecute, translate bind variables from mapping
	if (reexecute) {
		translateBindVariablesFromMappings(cursor);
	}

	bool	success=false;
	bool	supportsnativebinds=cursor->supportsNativeBinds();

	if (reexecute &&
		!cursor->fakeinputbindsforthisquery &&
		supportsnativebinds) {

		// if we're reexecuting and not faking binds then
		// the statement doesn't need to be prepared again,
		// just execute it...

		logDebugMessage("re-executing...");
		success=(handleBinds(cursor) && executeQuery(cursor,
							cursor->querybuffer,
							cursor->querylength));

	} else if (bindcursor) {

		// if we're handling a bind cursor...
		logDebugMessage("bind cursor...");
		success=cursor->fetchFromBindCursor();

	} else {

		// otherwise, prepare and execute the query...
		// generally this a first time query but it could also be
		// a reexecute if we're faking binds

		logDebugMessage("preparing/executing...");

		// rewrite the query, if necessary
		rewriteQuery(cursor);

		// buffers and pointers...
		stringbuffer	outputquery;
		const char	*query=cursor->querybuffer;
		uint32_t	querylen=cursor->querylength;

		// fake input binds if necessary
		// NOTE: we can't just overwrite the querybuffer when
		// faking binds or we'll lose the original query and
		// end up rerunning the modified query when reexecuting
		if (cursor->fakeinputbindsforthisquery ||
					!supportsnativebinds) {
			logDebugMessage("faking binds...");
			if (cursor->fakeInputBinds(&outputquery)) {
				query=outputquery.getString();
				querylen=outputquery.getStringLength();
			}
		}

		// prepare
		success=cursor->prepareQuery(query,querylen);

		// if we're not faking binds then
		// handle the binds for real
		if (success &&
			!cursor->fakeinputbindsforthisquery &&
			cursor->supportsNativeBinds()) {
			success=handleBinds(cursor);
		}

		// execute
		if (success) {
			success=executeQuery(cursor,query,querylen);
		}
	}

	// was the query a commit or rollback?
	commitOrRollback(cursor);

	// On success, autocommit if necessary.
	// Connection classes could override autoCommitOn() and autoCommitOff()
	// to do database API-specific things, but will not set 
	// fakeautocommit, so this code won't get called at all for those 
	// connections.
	// FIXME: when faking autocommit, a BEGIN on a db that supports them
	// could cause commit to be called immediately
	if (success && conn->isTransactional() && commitorrollback &&
				conn->fakeautocommit && conn->autocommit) {
		logDebugMessage("commit necessary...");
		success=commit();
	}
	
	// if the query failed, get the error (unless it's already been set)
	if (!success && !cursor->errnum) {
		// FIXME: errors for queries run by triggers won't be set here
		cursor->errorMessage(cursor->error,
					maxerrorlength,
					&(cursor->errorlength),
					&(cursor->errnum),
					&(cursor->liveconnection));
	}

	if (success) {
		logDebugMessage("processing query succeeded");
	} else {
		logDebugMessage("processing query failed");
	}
	logDebugMessage("done processing query");

	return success;
}

void sqlrcontroller_svr::translateBindVariablesFromMappings(
						sqlrcursor_svr *cursor) {
	// index variable
	uint16_t	i=0;

	// run two passes
	for (i=0; i<2; i++) {

		// first pass for input binds, second pass for output binds
		uint16_t	count=(!i)?cursor->inbindcount:
						cursor->outbindcount;
		bindvar_svr	*vars=(!i)?cursor->inbindvars:
						cursor->outbindvars;
		namevaluepairs	*mappings=(!i)?inbindmappings:outbindmappings;

		for (uint16_t j=0; j<count; j++) {

			// get the bind var
			bindvar_svr	*b=&(vars[j]);

			// remap it
			char	*newvariable;
			if (mappings->getValue(b->variable,&newvariable)) {
				b->variable=newvariable;
			}
		}
	}

	// debug
	logDebugMessage("remapped input binds:");
	for (i=0; i<cursor->inbindcount; i++) {
		logDebugMessage(cursor->inbindvars[i].variable);
	}
	logDebugMessage("remapped output binds:");
	for (i=0; i<cursor->outbindcount; i++) {
		logDebugMessage(cursor->outbindvars[i].variable);
	}
}

void sqlrcontroller_svr::rewriteQuery(sqlrcursor_svr *cursor) {

	if (sqlp && sqlt && sqlw) {
		if (!translateQuery(cursor)) {
			// FIXME: do something?
		}
	}

	if (translatebinds) {
		translateBindVariables(cursor);
	}

	if (conn->supportsTransactionBlocks()) {
		translateBeginTransaction(cursor);
	}
}

bool sqlrcontroller_svr::translateQuery(sqlrcursor_svr *cursor) {

	if (debugsqltranslation) {
		stdoutput.printf("original:\n\"%s\"\n\n",cursor->querybuffer);
	}

	// parse the query
	bool	parsed=sqlp->parse(cursor->querybuffer);

	// get the parsed tree
	delete cursor->querytree;
	cursor->querytree=sqlp->detachTree();
	if (!cursor->querytree) {
		return false;
	}

	if (debugsqltranslation) {
		stdoutput.printf("before translation:\n");
		cursor->querytree->getRootNode()->print(&stdoutput);
		stdoutput.printf("\n");
	}

	if (!parsed) {
		if (debugsqltranslation) {
			stdoutput.printf(
				"parse failed, using original:\n\"%s\"\n\n",
							cursor->querybuffer);
		}
		delete cursor->querytree;
		cursor->querytree=NULL;
		return false;
	}

	// apply translation rules
	if (!sqlt->runTranslations(conn,cursor,cursor->querytree)) {
		return false;
	}

	if (debugsqltranslation) {
		stdoutput.printf("after translation:\n");
		cursor->querytree->getRootNode()->print(&stdoutput);
		stdoutput.printf("\n");
	}

	// write the query back out
	stringbuffer	translatedquery;
	if (!sqlw->write(conn,cursor,cursor->querytree,&translatedquery)) {
		return false;
	}

	if (debugsqltranslation) {
		stdoutput.printf("translated:\n\"%s\"\n\n",
				translatedquery.getString());
	}

	// copy the translated query into query buffer
	if (translatedquery.getStringLength()>maxquerysize) {
		// the translated query was too large
		return false;
	}
	charstring::copy(cursor->querybuffer,
			translatedquery.getString(),
			translatedquery.getStringLength());
	cursor->querylength=translatedquery.getStringLength();
	cursor->querybuffer[cursor->querylength]='\0';
	return true;
}

enum queryparsestate_t {
	IN_QUERY=0,
	IN_QUOTES,
	BEFORE_BIND,
	IN_BIND
};

void sqlrcontroller_svr::translateBindVariables(sqlrcursor_svr *cursor) {

	// index variable
	uint16_t	i=0;

	// debug
	logDebugMessage("translating bind variables...");
	logDebugMessage("original:");
	logDebugMessage(cursor->querybuffer);
	logDebugMessage("input binds:");
	for (i=0; i<cursor->inbindcount; i++) {
		logDebugMessage(cursor->inbindvars[i].variable);
	}
	logDebugMessage("output binds:");
	for (i=0; i<cursor->outbindcount; i++) {
		logDebugMessage(cursor->outbindvars[i].variable);
	}

	// convert queries from whatever bind variable format they currently
	// use to the format required by the database...

	bool			convert=false;
	queryparsestate_t	parsestate=IN_QUERY;
	stringbuffer	newquery;
	stringbuffer	currentbind;
	const char	*endptr=cursor->querybuffer+cursor->querylength-1;

	// use 1-based index for bind variables
	uint16_t	bindindex=1;
	
	// run through the querybuffer...
	char *c=cursor->querybuffer;
	do {

		// if we're in the query...
		if (parsestate==IN_QUERY) {

			// if we find a quote, we're in quotes
			if (*c=='\'') {
				parsestate=IN_QUOTES;
			}

			// if we find whitespace or a couple of other things
			// then the next thing could be a bind variable
			if (character::isWhitespace(*c) ||
					*c==',' || *c=='(' || *c=='=') {
				parsestate=BEFORE_BIND;
			}

			// append the character
			newquery.append(*c);
			c++;
			continue;
		}

		// copy anything in quotes verbatim
		if (parsestate==IN_QUOTES) {
			if (*c=='\'') {
				parsestate=IN_QUERY;
			}
			newquery.append(*c);
			c++;
			continue;
		}

		if (parsestate==BEFORE_BIND) {

			// if we find a bind variable...
			// (make sure to catch @'s but not @@'s
			if (*c=='?' || *c==':' ||
				(*c=='@' && *(c+1)!='@') || *c=='$') {
				parsestate=IN_BIND;
				currentbind.clear();
				continue;
			}

			// if we didn't find a bind variable then we're just
			// back in the query
			parsestate=IN_QUERY;
			continue;
		}

		// if we're in a bind variable...
		if (parsestate==IN_BIND) {

			// If we find whitespace or a few other things
			// then we're done with the bind variable.  Process it.
			// Otherwise get the variable itself in another buffer.
			bool	endofbind=(character::isWhitespace(*c) ||
						*c==',' || *c==')' || *c==';' ||
						(*c==':' && *(c+1)=='='));
			if (endofbind || c==endptr) {

				// special case if we hit the end of the string
				// an it's not one of the special chars
				if (c==endptr && !endofbind) {
					currentbind.append(*c);
					c++;
				}

				// Bail if the current bind variable format
				// matches the db bind format.
				if (matchesNativeBindFormat(
						currentbind.getString())) {
					return;
				}

				// translate...
				convert=true;
				translateBindVariableInStringAndArray(cursor,
								&currentbind,
								bindindex,
								&newquery);
				bindindex++;

				parsestate=IN_QUERY;

			} else {
				currentbind.append(*c);
				c++;
			}
			continue;
		}

	} while (c<=endptr);

	if (!convert) {
		return;
	}


	// if we made it here then some conversion
	// was done - update the querybuffer...
	const char	*newq=newquery.getString();
	cursor->querylength=newquery.getStringLength();
	if (cursor->querylength>maxquerysize) {
		cursor->querylength=maxquerysize;
	}
	charstring::copy(cursor->querybuffer,newq,cursor->querylength);
	cursor->querybuffer[cursor->querylength]='\0';


	// debug
	if (debugsqltranslation) {
		stdoutput.printf("bind translation:\n\"%s\"\n",
						cursor->querybuffer);
		for (i=0; i<cursor->inbindcount; i++) {
			stdoutput.printf("  inbind: \"%s\"\n",
					cursor->inbindvars[i].variable);
		}
		for (i=0; i<cursor->outbindcount; i++) {
			stdoutput.printf("  outbind: \"%s\"\n",
					cursor->outbindvars[i].variable);
		}
		stdoutput.printf("\n");
	}
	logDebugMessage("converted:");
	logDebugMessage(cursor->querybuffer);
	logDebugMessage("input binds:");
	for (i=0; i<cursor->inbindcount; i++) {
		logDebugMessage(cursor->inbindvars[i].variable);
	}
	logDebugMessage("output binds:");
	for (i=0; i<cursor->outbindcount; i++) {
		logDebugMessage(cursor->outbindvars[i].variable);
	}
}

bool sqlrcontroller_svr::matchesNativeBindFormat(const char *bind) {

	const char	*bindformat=conn->bindFormat();
	size_t		bindformatlen=charstring::length(bindformat);

	// the bind variable name matches the format if...
	// * the first character of the bind variable name matches the 
	//   first character of the bind format
	//
	//	and...
	//
	// * the format is just a single character
	// 	or..
	// * the second character of the format is a 1 and the second character
	//   of the bind variable name is a digit
	// 	or..
	// * the second character of the format is a * and the second character
	//   of the bind varaible name is alphanumeric
	return (bind[0]==bindformat[0]  &&
		(bindformatlen==1 ||
		(bindformat[1]=='1' && character::isDigit(bind[1])) ||
		(bindformat[1]=='*' && !character::isAlphanumeric(bind[1]))));
}

void sqlrcontroller_svr::translateBindVariableInStringAndArray(
						sqlrcursor_svr *cursor,
						stringbuffer *currentbind,
						uint16_t bindindex,
						stringbuffer *newquery) {

	const char	*bindformat=conn->bindFormat();
	size_t		bindformatlen=charstring::length(bindformat);

	// append the first character of the bind format to the new query
	newquery->append(bindformat[0]);

	if (bindformatlen==1) {

		// replace bind variable itself with number
		translateBindVariableInArray(cursor,NULL,bindindex);

	} else if (bindformat[1]=='1' &&
			!charstring::isNumber(currentbind->getString()+1)) {

		// replace bind variable in string with number
		newquery->append(bindindex);

		// replace bind variable itself with number
		translateBindVariableInArray(cursor,
					currentbind->getString(),
					bindindex);

	} else {

		// if the bind variable contained a name or number then use
		// it, otherwise replace the bind variable in the string and
		// the bind variable itself with a number 
		if (currentbind->getStringLength()>1) {
			newquery->append(currentbind->getString()+1,
					currentbind->getStringLength()-1);
		} else {
			// replace bind variable in string with number
			newquery->append(bindindex);

			// replace bind variable itself with number
			translateBindVariableInArray(cursor,
						currentbind->getString(),
						bindindex);
		}
	}
}

void sqlrcontroller_svr::translateBindVariableInArray(sqlrcursor_svr *cursor,
						const char *currentbind,
						uint16_t bindindex) {

	// run two passes
	for (uint16_t i=0; i<2; i++) {

		// first pass for input binds, second pass for output binds
		uint16_t	count=(!i)?cursor->inbindcount:
						cursor->outbindcount;
		bindvar_svr	*vars=(!i)?cursor->inbindvars:
						cursor->outbindvars;
		namevaluepairs	*mappings=(!i)?inbindmappings:outbindmappings;

		for (uint16_t j=0; j<count; j++) {

			// get the bind var
			bindvar_svr	*b=&(vars[j]);

			// If a bind var name was passed in, look for a bind
			// variable with a matching name.
			// If no name was passed in then the bind vars are
			// numeric; get the variable who's numeric name matches
			// the index passed in.
			if ((currentbind &&
				!charstring::compare(currentbind,
							b->variable)) ||
				(charstring::toInteger((b->variable)+1)==
								bindindex)) {

				// create the new bind var
				// name and get its length
				char		*tempnumber=charstring::
							parseNumber(bindindex);
				uint16_t	tempnumberlen=charstring::
							length(tempnumber);

				// keep track of the old name
				char	*oldvariable=b->variable;

				// allocate memory for the new name
				b->variable=(char *)bindmappingspool->
						allocate(tempnumberlen+2);

				// replace the existing bind var name and size
				b->variable[0]=conn->bindVariablePrefix();
				charstring::copy(b->variable+1,tempnumber);
				b->variable[tempnumberlen+1]='\0';
				b->variablesize=tempnumberlen+1;

				// create bind variable mappings
				mappings->setValue(oldvariable,b->variable);
				
				// clean up
				delete[] tempnumber;
			}
		}
	}
}

void sqlrcontroller_svr::translateBeginTransaction(sqlrcursor_svr *cursor) {

	if (!isBeginTransactionQuery(cursor)) {
		return;
	}

	// debug
	logDebugMessage("translating begin tx query...");
	logDebugMessage("original:");
	logDebugMessage(cursor->querybuffer);

	// translate query
	const char	*beginquery=conn->beginTransactionQuery();
	cursor->querylength=charstring::length(beginquery);
	charstring::copy(cursor->querybuffer,beginquery,cursor->querylength);
	cursor->querybuffer[cursor->querylength]='\0';

	// debug
	logDebugMessage("converted:");
	logDebugMessage(cursor->querybuffer);
}

bool sqlrcontroller_svr::handleBinds(sqlrcursor_svr *cursor) {

	bindvar_svr	*bind=NULL;
	
	// iterate through the arrays, binding values to variables
	for (int16_t in=0; in<cursor->inbindcount; in++) {

		bind=&cursor->inbindvars[in];

		// bind the value to the variable
		if (bind->type==STRING_BIND || bind->type==NULL_BIND) {
			if (!cursor->inputBind(
					bind->variable,
					bind->variablesize,
					bind->value.stringval,
					bind->valuesize,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==INTEGER_BIND) {
			if (!cursor->inputBind(
					bind->variable,
					bind->variablesize,
					&bind->value.integerval)) {
				return false;
			}
		} else if (bind->type==DOUBLE_BIND) {
			if (!cursor->inputBind(
					bind->variable,
					bind->variablesize,
					&bind->value.doubleval.value,
					bind->value.doubleval.precision,
					bind->value.doubleval.scale)) {
				return false;
			}
		} else if (bind->type==DATE_BIND) {
			if (!cursor->inputBind(
					bind->variable,
					bind->variablesize,
					bind->value.dateval.year,
					bind->value.dateval.month,
					bind->value.dateval.day,
					bind->value.dateval.hour,
					bind->value.dateval.minute,
					bind->value.dateval.second,
					bind->value.dateval.microsecond,
					bind->value.dateval.tz,
					bind->value.dateval.buffer,
					bind->value.dateval.buffersize,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==BLOB_BIND) {
			if (!cursor->inputBindBlob(
					bind->variable,
					bind->variablesize,
					bind->value.stringval,
					bind->valuesize,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==CLOB_BIND) {
			if (!cursor->inputBindClob(
					bind->variable,
					bind->variablesize,
					bind->value.stringval,
					bind->valuesize,
					&bind->isnull)) {
				return false;
			}
		}
	}

	for (int16_t out=0; out<cursor->outbindcount; out++) {

		bind=&cursor->outbindvars[out];

		// bind the value to the variable
		if (bind->type==STRING_BIND) {
			if (!cursor->outputBind(
					bind->variable,
					bind->variablesize,
					bind->value.stringval,
					bind->valuesize+1,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==INTEGER_BIND) {
			if (!cursor->outputBind(
					bind->variable,
					bind->variablesize,
					&bind->value.integerval,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==DOUBLE_BIND) {
			if (!cursor->outputBind(
					bind->variable,
					bind->variablesize,
					&bind->value.doubleval.value,
					&bind->value.doubleval.precision,
					&bind->value.doubleval.scale,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==DATE_BIND) {
			if (!cursor->outputBind(
					bind->variable,
					bind->variablesize,
					&bind->value.dateval.year,
					&bind->value.dateval.month,
					&bind->value.dateval.day,
					&bind->value.dateval.hour,
					&bind->value.dateval.minute,
					&bind->value.dateval.second,
					&bind->value.dateval.microsecond,
					(const char **)&bind->value.dateval.tz,
					bind->value.dateval.buffer,
					bind->value.dateval.buffersize,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==BLOB_BIND) {
			if (!cursor->outputBindBlob(
					bind->variable,
					bind->variablesize,out,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==CLOB_BIND) {
			if (!cursor->outputBindClob(
					bind->variable,
					bind->variablesize,out,
					&bind->isnull)) {
				return false;
			}
		} else if (bind->type==CURSOR_BIND) {

			bool	found=false;

			// find the cursor that we acquird earlier...
			for (uint16_t j=0; j<cursorcount; j++) {

				if (cur[j]->id==bind->value.cursorid) {
					found=true;

					// bind the cursor
					if (!cursor->outputBindCursor(
							bind->variable,
							bind->variablesize,
							cur[j])) {
						return false;
					}
					break;
				}
			}

			// this shouldn't happen, but if it does, return false
			if (!found) {
				return false;
			}
		}
	}
	return true;
}

bool sqlrcontroller_svr::executeQuery(sqlrcursor_svr *curs,
						const char *query,
						uint32_t length) {

	// handle before-triggers
	if (sqltr) {
		sqltr->runBeforeTriggers(conn,curs,curs->querytree);
	}

	// variables for query timing
	timeval		tv;
	struct timezone	tz;

	// get the query start time
	gettimeofday(&tv,&tz);
	curs->querystartsec=tv.tv_sec;
	curs->querystartusec=tv.tv_usec;

	// execute the query
	curs->queryresult=curs->executeQuery(query,length);

	// get the query end time
	gettimeofday(&tv,&tz);
	curs->queryendsec=tv.tv_sec;
	curs->queryendusec=tv.tv_usec;

	// update query and error counts
	incrementQueryCounts(curs->queryType(query,length));
	if (!curs->queryresult) {
		incrementTotalErrors();
	}

	// handle after-triggers
	if (sqltr) {
		sqltr->runAfterTriggers(conn,curs,curs->querytree,true);
	}

	return curs->queryresult;
}

void sqlrcontroller_svr::commitOrRollback(sqlrcursor_svr *cursor) {

	logDebugMessage("commit or rollback check...");

	// if the query was a commit or rollback, set a flag indicating so
	if (conn->isTransactional()) {
		// FIXME: if db has been put in the repeatable-read isolation
		// level then commitorrollback=true needs to be set no
		// matter what the query was
		if (cursor->queryIsCommitOrRollback()) {
			logDebugMessage("commit or rollback not needed");
			commitorrollback=false;
		} else if (cursor->queryIsNotSelect()) {
			logDebugMessage("commit or rollback needed");
			commitorrollback=true;
		}
	}

	logDebugMessage("done with commit or rollback check");
}

void sqlrcontroller_svr::setFakeInputBinds(bool fake) {
	fakeinputbinds=fake;
}

bool sqlrcontroller_svr::getSkipAndFetch(sqlrcursor_svr *cursor) {

	// get the number of rows to skip
	ssize_t		result=clientsock->read(&skip,idleclienttimeout,0);
	if (result!=sizeof(uint64_t)) {
		logClientProtocolError(cursor,
				"return result set data failed: "
				"failed to get rows to skip",result);
		return false;
	}

	// get the number of rows to fetch
	result=clientsock->read(&fetch,idleclienttimeout,0);
	if (result!=sizeof(uint64_t)) {
		logClientProtocolError(cursor,
				"return result set data failed: "
				"failed to get rows to fetch",result);
		return false;
	}
	return true;
}

void sqlrcontroller_svr::returnResultSetHeader(sqlrcursor_svr *cursor) {

	logDebugMessage("returning result set header...");

	// return the row counts
	logDebugMessage("returning row counts...");
	sendRowCounts(cursor->knowsRowCount(),cursor->rowCount(),
			cursor->knowsAffectedRows(),cursor->affectedRows());
	logDebugMessage("done returning row counts");


	// write a flag to the client indicating whether 
	// or not the column information will be sent
	clientsock->write(sendcolumninfo);

	if (sendcolumninfo==SEND_COLUMN_INFO) {
		logDebugMessage("column info will be sent");
	} else {
		logDebugMessage("column info will not be sent");
	}


	// return the column count
	logDebugMessage("returning column counts...");
	clientsock->write(cursor->colCount());
	logDebugMessage("done returning column counts");


	if (sendcolumninfo==SEND_COLUMN_INFO) {

		// return the column type format
		logDebugMessage("sending column type format...");
		uint16_t	format=cursor->columnTypeFormat();
		if (format==COLUMN_TYPE_IDS) {
			logDebugMessage("id's");
		} else {
			logDebugMessage("names");
		}
		clientsock->write(format);
		logDebugMessage("done sending column type format");

		// return the column info
		logDebugMessage("returning column info...");
		returnColumnInfo(cursor,format);
		logDebugMessage("done returning column info");
	}


	// return the output bind vars
	returnOutputBindValues(cursor);


	// terminate the bind vars
	clientsock->write((uint16_t)END_BIND_VARS);

	logDebugMessage("done returning result set header");
}

void sqlrcontroller_svr::returnColumnInfo(sqlrcursor_svr *cursor,
							uint16_t format) {

	for (uint32_t i=0; i<cursor->colCount(); i++) {

		const char	*name=cursor->getColumnName(i);
		uint16_t	namelen=cursor->getColumnNameLength(i);
		uint32_t	length=cursor->getColumnLength(i);
		uint32_t	precision=cursor->getColumnPrecision(i);
		uint32_t	scale=cursor->getColumnScale(i);
		uint16_t	nullable=cursor->getColumnIsNullable(i);
		uint16_t	primarykey=cursor->getColumnIsPrimaryKey(i);
		uint16_t	unique=cursor->getColumnIsUnique(i);
		uint16_t	partofkey=cursor->getColumnIsPartOfKey(i);
		uint16_t	unsignednumber=cursor->getColumnIsUnsigned(i);
		uint16_t	zerofill=cursor->getColumnIsZeroFilled(i);
		uint16_t	binary=cursor->getColumnIsBinary(i);
		uint16_t	autoincrement=
					cursor->getColumnIsAutoIncrement(i);

		if (format==COLUMN_TYPE_IDS) {
			sendColumnDefinition(name,namelen,
					cursor->getColumnType(i),
					length,precision,scale,
					nullable,primarykey,unique,partofkey,
					unsignednumber,zerofill,binary,
					autoincrement);
		} else {
			sendColumnDefinitionString(name,namelen,
					cursor->getColumnTypeName(i),
					cursor->getColumnTypeNameLength(i),
					length,precision,scale,
					nullable,primarykey,unique,partofkey,
					unsignednumber,zerofill,binary,
					autoincrement);
		}
	}
}

void sqlrcontroller_svr::sendRowCounts(bool knowsactual, uint64_t actual,
					bool knowsaffected, uint64_t affected) {

	logDebugMessage("sending row counts...");

	// send actual rows, if that is known
	if (knowsactual) {

		char	string[30];
		charstring::printf(string,30,	
				"actual rows: %lld",	
				(long long)actual);
		logDebugMessage(string);

		clientsock->write((uint16_t)ACTUAL_ROWS);
		clientsock->write(actual);

	} else {

		logDebugMessage("actual rows unknown");

		clientsock->write((uint16_t)NO_ACTUAL_ROWS);
	}

	
	// send affected rows, if that is known
	if (knowsaffected) {

		char	string[46];
		charstring::printf(string,46,
				"affected rows: %lld",
				(long long)affected);
		logDebugMessage(string);

		clientsock->write((uint16_t)AFFECTED_ROWS);
		clientsock->write(affected);

	} else {

		logDebugMessage("affected rows unknown");

		clientsock->write((uint16_t)NO_AFFECTED_ROWS);
	}

	logDebugMessage("done sending row counts");
}

void sqlrcontroller_svr::returnOutputBindValues(sqlrcursor_svr *cursor) {

	if (sqlrlg) {
		debugstr.clear();
		debugstr.append("returning ");
		debugstr.append(cursor->outbindcount);
		debugstr.append(" output bind values: ");
		logDebugMessage(debugstr.getString());
	}

	// run through the output bind values, sending them back
	for (uint16_t i=0; i<cursor->outbindcount; i++) {

		bindvar_svr	*bv=&(cursor->outbindvars[i]);

		if (sqlrlg) {
			debugstr.clear();
			debugstr.append(i);
			debugstr.append(":");
		}

		if (conn->bindValueIsNull(bv->isnull)) {

			if (sqlrlg) {
				debugstr.append("NULL");
			}

			clientsock->write((uint16_t)NULL_DATA);

		} else if (bv->type==BLOB_BIND) {

			if (sqlrlg) {
				debugstr.append("BLOB:");
			}

			returnOutputBindBlob(cursor,i);

		} else if (bv->type==CLOB_BIND) {

			if (sqlrlg) {
				debugstr.append("CLOB:");
			}

			returnOutputBindClob(cursor,i);

		} else if (bv->type==STRING_BIND) {

			if (sqlrlg) {
				debugstr.append("STRING:");
				debugstr.append(bv->value.stringval);
			}

			clientsock->write((uint16_t)STRING_DATA);
			bv->valuesize=charstring::length(
						(char *)bv->value.stringval);
			clientsock->write(bv->valuesize);
			clientsock->write(bv->value.stringval,bv->valuesize);

		} else if (bv->type==INTEGER_BIND) {

			if (sqlrlg) {
				debugstr.append("INTEGER:");
				debugstr.append(bv->value.integerval);
			}

			clientsock->write((uint16_t)INTEGER_DATA);
			clientsock->write((uint64_t)bv->value.integerval);

		} else if (bv->type==DOUBLE_BIND) {

			if (sqlrlg) {
				debugstr.append("DOUBLE:");
				debugstr.append(bv->value.doubleval.value);
				debugstr.append("(");
				debugstr.append(bv->value.doubleval.precision);
				debugstr.append(",");
				debugstr.append(bv->value.doubleval.scale);
				debugstr.append(")");
			}

			clientsock->write((uint16_t)DOUBLE_DATA);
			clientsock->write(bv->value.doubleval.value);
			clientsock->write((uint32_t)bv->value.
						doubleval.precision);
			clientsock->write((uint32_t)bv->value.
						doubleval.scale);

		} else if (bv->type==DATE_BIND) {

			if (sqlrlg) {
				debugstr.append("DATE:");
				debugstr.append(bv->value.dateval.year);
				debugstr.append("-");
				debugstr.append(bv->value.dateval.month);
				debugstr.append("-");
				debugstr.append(bv->value.dateval.day);
				debugstr.append(" ");
				debugstr.append(bv->value.dateval.hour);
				debugstr.append(":");
				debugstr.append(bv->value.dateval.minute);
				debugstr.append(":");
				debugstr.append(bv->value.dateval.second);
				debugstr.append(":");
				debugstr.append(bv->value.dateval.microsecond);
				debugstr.append(" ");
				debugstr.append(bv->value.dateval.tz);
			}

			clientsock->write((uint16_t)DATE_DATA);
			clientsock->write((uint16_t)bv->value.dateval.year);
			clientsock->write((uint16_t)bv->value.dateval.month);
			clientsock->write((uint16_t)bv->value.dateval.day);
			clientsock->write((uint16_t)bv->value.dateval.hour);
			clientsock->write((uint16_t)bv->value.dateval.minute);
			clientsock->write((uint16_t)bv->value.dateval.second);
			clientsock->write((uint32_t)bv->value.
							dateval.microsecond);
			uint16_t	length=charstring::length(
							bv->value.dateval.tz);
			clientsock->write(length);
			clientsock->write(bv->value.dateval.tz,length);

		} else if (bv->type==CURSOR_BIND) {

			if (sqlrlg) {
				debugstr.append("CURSOR:");
				debugstr.append(bv->value.cursorid);
			}

			clientsock->write((uint16_t)CURSOR_DATA);
			clientsock->write(bv->value.cursorid);
		}

		if (sqlrlg) {
			logDebugMessage(debugstr.getString());
		}
	}

	logDebugMessage("done returning output bind values");
}

void sqlrcontroller_svr::returnOutputBindBlob(sqlrcursor_svr *cursor,
							uint16_t index) {
	sendLobOutputBind(cursor,index);
}

void sqlrcontroller_svr::returnOutputBindClob(sqlrcursor_svr *cursor,
							uint16_t index) {
	sendLobOutputBind(cursor,index);
}

#define MAX_BYTES_PER_CHAR	4

void sqlrcontroller_svr::sendLobOutputBind(sqlrcursor_svr *cursor,
							uint16_t index) {

	// Get lob length.  If this fails, send a NULL field.
	uint64_t	loblength;
	if (!cursor->getLobOutputBindLength(index,&loblength)) {
		sendNullField();
		return;
	}

	// for lobs of 0 length
	if (!loblength) {
		startSendingLong(0);
		sendLongSegment("",0);
		endSendingLong();
		return;
	}

	// initialize sizes and status
	uint64_t	charstoread=sizeof(cursor->lobbuffer)/
						MAX_BYTES_PER_CHAR;
	uint64_t	charsread=0;
	uint64_t	offset=0;
	bool		start=true;

	for (;;) {

		// read a segment from the lob
		if (!cursor->getLobOutputBindSegment(
					index,
					cursor->lobbuffer,
					sizeof(cursor->lobbuffer),
					offset,charstoread,&charsread) ||
					!charsread) {

			// if we fail to get a segment or got nothing...
			// if we haven't started sending yet, then send a NULL,
			// otherwise just end normally
			if (start) {
				sendNullField();
			} else {
				endSendingLong();
			}
			return;

		} else {

			// if we haven't started sending yet, then do that now
			if (start) {
				startSendingLong(loblength);
				start=false;
			}

			// send the segment we just got
			sendLongSegment(cursor->lobbuffer,charsread);

			// FIXME: or should this be charsread?
			offset=offset+charstoread;
		}
	}
}

bool sqlrcontroller_svr::sendColumnInfo() {
	if (sendcolumninfo==SEND_COLUMN_INFO) {
		return true;
	}
	return false;
}

void sqlrcontroller_svr::sendColumnDefinition(const char *name,
						uint16_t namelen,
						uint16_t type, 
						uint32_t size,
						uint32_t precision,
						uint32_t scale,
						uint16_t nullable,
						uint16_t primarykey,
						uint16_t unique,
						uint16_t partofkey,
						uint16_t unsignednumber,
						uint16_t zerofill,
						uint16_t binary,
						uint16_t autoincrement) {

	if (sqlrlg) {
		debugstr.clear();
		for (uint16_t i=0; i<namelen; i++) {
			debugstr.append(name[i]);
		}
		debugstr.append(":");
		debugstr.append(type);
		debugstr.append(":");
		debugstr.append(size);
		debugstr.append(" (");
		debugstr.append(precision);
		debugstr.append(",");
		debugstr.append(scale);
		debugstr.append(") ");
		if (!nullable) {
			debugstr.append("NOT NULL ");
		}
		if (primarykey) {
			debugstr.append("Primary key ");
		}
		if (unique) {
			debugstr.append("Unique");
		}
		logDebugMessage(debugstr.getString());
	}

	clientsock->write(namelen);
	clientsock->write(name,namelen);
	clientsock->write(type);
	clientsock->write(size);
	clientsock->write(precision);
	clientsock->write(scale);
	clientsock->write(nullable);
	clientsock->write(primarykey);
	clientsock->write(unique);
	clientsock->write(partofkey);
	clientsock->write(unsignednumber);
	clientsock->write(zerofill);
	clientsock->write(binary);
	clientsock->write(autoincrement);
}

void sqlrcontroller_svr::sendColumnDefinitionString(const char *name,
						uint16_t namelen,
						const char *type, 
						uint16_t typelen,
						uint32_t size,
						uint32_t precision,
						uint32_t scale,
						uint16_t nullable,
						uint16_t primarykey,
						uint16_t unique,
						uint16_t partofkey,
						uint16_t unsignednumber,
						uint16_t zerofill,
						uint16_t binary,
						uint16_t autoincrement) {

	if (sqlrlg) {
		debugstr.clear();
		for (uint16_t ni=0; ni<namelen; ni++) {
			debugstr.append(name[ni]);
		}
		debugstr.append(":");
		for (uint16_t ti=0; ti<typelen; ti++) {
			debugstr.append(type[ti]);
		}
		debugstr.append(":");
		debugstr.append(size);
		debugstr.append(" (");
		debugstr.append(precision);
		debugstr.append(",");
		debugstr.append(scale);
		debugstr.append(") ");
		if (!nullable) {
			debugstr.append("NOT NULL ");
		}
		if (primarykey) {
			debugstr.append("Primary key ");
		}
		if (unique) {
			debugstr.append("Unique");
		}
		logDebugMessage(debugstr.getString());
	}

	clientsock->write(namelen);
	clientsock->write(name,namelen);
	clientsock->write(typelen);
	clientsock->write(type,typelen);
	clientsock->write(size);
	clientsock->write(precision);
	clientsock->write(scale);
	clientsock->write(nullable);
	clientsock->write(primarykey);
	clientsock->write(unique);
	clientsock->write(partofkey);
	clientsock->write(unsignednumber);
	clientsock->write(zerofill);
	clientsock->write(binary);
	clientsock->write(autoincrement);
}

bool sqlrcontroller_svr::returnResultSetData(sqlrcursor_svr *cursor,
						bool getskipandfetch) {

	logDebugMessage("returning result set data...");

	updateState(RETURN_RESULT_SET);

	// decide whether to use the cursor itself
	// or an attached custom query cursor
	if (cursor->customquerycursor) {
		cursor=cursor->customquerycursor;
	}

	// get the number of rows to skip and fetch
	if (getskipandfetch) {
		if (!getSkipAndFetch(cursor)) {
			return false;
		}
	}

	// reinit cursor state (in case it was suspended)
	cursor->state=SQLRCURSORSTATE_BUSY;

	// for some queries, there are no rows to return, 
	if (cursor->noRowsToReturn()) {
		clientsock->write((uint16_t)END_RESULT_SET);
		clientsock->flushWriteBuffer(-1,-1);
		logDebugMessage("done returning result set data");
		return true;
	}

	// skip the specified number of rows
	if (!skipRows(cursor,skip)) {
		clientsock->write((uint16_t)END_RESULT_SET);
		clientsock->flushWriteBuffer(-1,-1);
		logDebugMessage("done returning result set data");
		return true;
	}


	if (sqlrlg) {
		debugstr.clear();
		debugstr.append("fetching ");
		debugstr.append(fetch);
		debugstr.append(" rows...");
		logDebugMessage(debugstr.getString());
	}

	// send the specified number of rows back
	for (uint64_t i=0; (!fetch || i<fetch); i++) {

		if (!cursor->fetchRow()) {
			clientsock->write((uint16_t)END_RESULT_SET);
			clientsock->flushWriteBuffer(-1,-1);
			logDebugMessage("done returning result set data");
			return true;
		}

		if (sqlrlg) {
			debugstr.clear();
		}

		returnRow(cursor);

		if (sqlrlg) {
			logDebugMessage(debugstr.getString());
		}

		if (cursor->lastrowvalid) {
			cursor->lastrow++;
		} else {
			cursor->lastrowvalid=true;
			cursor->lastrow=0;
		}
	}
	clientsock->flushWriteBuffer(-1,-1);

	logDebugMessage("done returning result set data");
	return true;
}

bool sqlrcontroller_svr::skipRows(sqlrcursor_svr *cursor, uint64_t rows) {

	if (sqlrlg) {
		debugstr.clear();
		debugstr.append("skipping ");
		debugstr.append(rows);
		debugstr.append(" rows...");
		logDebugMessage(debugstr.getString());
	}

	for (uint64_t i=0; i<rows; i++) {

		logDebugMessage("skip...");

		if (cursor->lastrowvalid) {
			cursor->lastrow++;
		} else {
			cursor->lastrowvalid=true;
			cursor->lastrow=0;
		}

		if (!cursor->skipRow()) {
			logDebugMessage("skipping rows hit the "
					"end of the result set");
			return false;
		}
	}

	logDebugMessage("done skipping rows");
	return true;
}

void sqlrcontroller_svr::returnRow(sqlrcursor_svr *cursor) {

	// run through the columns...
	for (uint32_t i=0; i<cursor->colCount(); i++) {

		// init variables
		const char	*field=NULL;
		uint64_t	fieldlength=0;
		bool		blob=false;
		bool		null=false;

		// get the field
		cursor->getField(i,&field,&fieldlength,&blob,&null);

		// send data to the client
		if (null) {
			sendNullField();
		} else if (blob) {
			sendLobField(cursor,i);
			cursor->cleanUpLobField(i);
		} else {
			sendField(cursor,i,field,fieldlength);
		}
	}

	// get the next row
	cursor->nextRow();
}

void sqlrcontroller_svr::sendField(sqlrcursor_svr *cursor,
					uint32_t index,
					const char *data,
					uint32_t size) {

	// convert date/time values, if configured to do so
	if (reformatdatetimes) {

		// are dates going to be in MM/DD or DD/MM format?
		bool	ddmm=cfgfl->getDateDdMm();
		bool	yyyyddmm=cfgfl->getDateYyyyDdMm();

		// This weirdness is mainly to address a FreeTDS/MSSQL
		// issue.  See the code for the method
		// freetdscursor::ignoreDateDdMmParameter() for more info.
		if (cursor->ignoreDateDdMmParameter(index,data,size)) {
			ddmm=false;
			yyyyddmm=false;
		}

		int16_t	year=-1;
		int16_t	month=-1;
		int16_t	day=-1;
		int16_t	hour=-1;
		int16_t	minute=-1;
		int16_t	second=-1;
		int16_t	fraction=-1;
		if (parseDateTime(data,ddmm,yyyyddmm,true,
					&year,&month,&day,
					&hour,&minute,&second,
					&fraction)) {

			// decide which format to use based on what parts
			// were detected in the date/time
			const char	*format=cfgfl->getDateTimeFormat();
			if (hour==-1) {
				format=cfgfl->getDateFormat();
			} else if (day==-1) {
				format=cfgfl->getTimeFormat();
			}

			// convert to the specified format
			char	*newdata=convertDateTime(format,
							year,month,day,
							hour,minute,second,
							fraction);

			// send the field
			sendField(newdata,charstring::length(newdata));

			if (debugsqltranslation) {
				stdoutput.printf("converted date: "
					"\"%s\" to \"%s\" using ddmm=%d\n",
					data,newdata,ddmm);
			}

			// clean up
			delete[] newdata;
			return;
		}
	}

	// send the field normally
	sendField(data,size);
}

void sqlrcontroller_svr::sendField(const char *data, uint32_t size) {

	if (sqlrlg) {
		debugstr.append("\"");
		debugstr.append(data,size);
		debugstr.append("\",");
	}

	clientsock->write((uint16_t)STRING_DATA);
	clientsock->write(size);
	clientsock->write(data,size);
}

void sqlrcontroller_svr::sendNullField() {

	if (sqlrlg) {
		debugstr.append("NULL");
	}

	clientsock->write((uint16_t)NULL_DATA);
}

#define MAX_BYTES_PER_CHAR	4

void sqlrcontroller_svr::sendLobField(sqlrcursor_svr *cursor, uint32_t col) {

	// Get lob length.  If this fails, send a NULL field.
	uint64_t	loblength;
	if (!cursor->getLobFieldLength(col,&loblength)) {
		sendNullField();
		return;
	}

	// for lobs of 0 length
	if (!loblength) {
		startSendingLong(0);
		sendLongSegment("",0);
		endSendingLong();
		return;
	}

	// initialize sizes and status
	uint64_t	charstoread=sizeof(cursor->lobbuffer)/
						MAX_BYTES_PER_CHAR;
	uint64_t	charsread=0;
	uint64_t	offset=0;
	bool		start=true;

	for (;;) {

		// read a segment from the lob
		if (!cursor->getLobFieldSegment(col,
					cursor->lobbuffer,
					sizeof(cursor->lobbuffer),
					offset,charstoread,&charsread) ||
					!charsread) {

			// if we fail to get a segment or got nothing...
			// if we haven't started sending yet, then send a NULL,
			// otherwise just end normally
			if (start) {
				sendNullField();
			} else {
				endSendingLong();
			}
			return;

		} else {

			// if we haven't started sending yet, then do that now
			if (start) {
				startSendingLong(loblength);
				start=false;
			}

			// send the segment we just got
			sendLongSegment(cursor->lobbuffer,charsread);

			// FIXME: or should this be charsread?
			offset=offset+charstoread;
		}
	}
}

void sqlrcontroller_svr::startSendingLong(uint64_t longlength) {
	clientsock->write((uint16_t)START_LONG_DATA);
	clientsock->write(longlength);
}

void sqlrcontroller_svr::sendLongSegment(const char *data, uint32_t size) {

	if (sqlrlg) {
		debugstr.append(data,size);
	}

	clientsock->write((uint16_t)STRING_DATA);
	clientsock->write(size);
	clientsock->write(data,size);
}

void sqlrcontroller_svr::endSendingLong() {

	if (sqlrlg) {
		debugstr.append(",");
	}

	clientsock->write((uint16_t)END_LONG_DATA);
}

void sqlrcontroller_svr::returnError(bool disconnect) {

	// Get the error data if none is set already
	if (!conn->error) {
		conn->errorMessage(conn->error,maxerrorlength,
				&conn->errorlength,&conn->errnum,
				&conn->liveconnection);
		if (!conn->liveconnection) {
			disconnect=true;
		}
	}

	// send the appropriate error status
	if (disconnect) {
		clientsock->write((uint16_t)ERROR_OCCURRED_DISCONNECT);
	} else {
		clientsock->write((uint16_t)ERROR_OCCURRED);
	}

	// send the error code and error string
	clientsock->write((uint64_t)conn->errnum);

	// send the error string
	clientsock->write((uint16_t)conn->errorlength);
	clientsock->write(conn->error,conn->errorlength);
	clientsock->flushWriteBuffer(-1,-1);

	logDbError(NULL,conn->error);
}

void sqlrcontroller_svr::returnError(sqlrcursor_svr *cursor, bool disconnect) {

	logDebugMessage("returning error...");

	// send the appropriate error status
	if (disconnect) {
		clientsock->write((uint16_t)ERROR_OCCURRED_DISCONNECT);
	} else {
		clientsock->write((uint16_t)ERROR_OCCURRED);
	}

	// send the error code
	clientsock->write((uint64_t)cursor->errnum);

	// send the error string
	clientsock->write((uint16_t)cursor->errorlength);
	clientsock->write(cursor->error,cursor->errorlength);

	// client will be sending skip/fetch, better get
	// it even though we're not going to use it
	uint64_t	skipfetch;
	clientsock->read(&skipfetch,idleclienttimeout,0);
	clientsock->read(&skipfetch,idleclienttimeout,0);

	// Even though there was an error, we still 
	// need to send the client the id of the 
	// cursor that it's going to use.
	clientsock->write(cursor->id);
	clientsock->flushWriteBuffer(-1,-1);

	logDebugMessage("done returning error");

	logDbError(cursor,cursor->error);
}

bool sqlrcontroller_svr::fetchResultSetCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("fetching result set...");
	bool	retval=returnResultSetData(cursor,true);
	logDebugMessage("done fetching result set");
	return retval;
}

void sqlrcontroller_svr::abortResultSetCommand(sqlrcursor_svr *cursor) {

	logDebugMessage("aborting result set...");

	// Very important...
	// Do not cleanUpData() here, otherwise result sets that were suspended
	// after the entire result set was fetched won't be able to return
	// column data when resumed.
	cursor->abort();

	logDebugMessage("done aborting result set");
}

void sqlrcontroller_svr::suspendResultSetCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("suspend result set...");
	cursor->state=SQLRCURSORSTATE_SUSPENDED;
	if (cursor->customquerycursor) {
		cursor->customquerycursor->state=SQLRCURSORSTATE_SUSPENDED;
	}
	logDebugMessage("done suspending result set");
}

bool sqlrcontroller_svr::resumeResultSetCommand(sqlrcursor_svr *cursor) {
	logDebugMessage("resume result set...");

	bool	retval=true;

	if (cursor->state==SQLRCURSORSTATE_SUSPENDED) {

		logDebugMessage("previous result set was suspended");

		// indicate that no error has occurred
		clientsock->write((uint16_t)NO_ERROR_OCCURRED);

		// send the client the id of the 
		// cursor that it's going to use
		clientsock->write(cursor->id);
		clientsock->write((uint16_t)SUSPENDED_RESULT_SET);

		// if the requested cursor really had a suspended
		// result set, send the lastrow of it to the client
		// then resume the result set
		clientsock->write(cursor->lastrow);

		returnResultSetHeader(cursor);
		retval=returnResultSetData(cursor,true);

	} else {

		logDebugMessage("previous result set was not suspended");

		// indicate that an error has occurred
		clientsock->write((uint16_t)ERROR_OCCURRED);

		// send the error code (zero for now)
		clientsock->write((uint64_t)SQLR_ERROR_RESULTSETNOTSUSPENDED);

		// send the error itself
		uint16_t	len=charstring::length(
				SQLR_ERROR_RESULTSETNOTSUSPENDED_STRING);
		clientsock->write(len);
		clientsock->write(SQLR_ERROR_RESULTSETNOTSUSPENDED_STRING,len);

		retval=false;
	}

	logDebugMessage("done resuming result set");
	return retval;
}
bool sqlrcontroller_svr::getDatabaseListCommand(sqlrcursor_svr *cursor) {
 	logDebugMessage("get db list...");
	bool	retval=getListCommand(cursor,0,false);
 	logDebugMessage("done getting db list");
	return retval;
}

bool sqlrcontroller_svr::getTableListCommand(sqlrcursor_svr *cursor) {
 	logDebugMessage("get table list...");
	bool	retval=getListCommand(cursor,1,false);
 	logDebugMessage("done getting table list");
	return retval;
}

bool sqlrcontroller_svr::getColumnListCommand(sqlrcursor_svr *cursor) {
 	logDebugMessage("get column list...");
	bool	retval=getListCommand(cursor,2,true);
 	logDebugMessage("done getting column list");
	return retval;
}

bool sqlrcontroller_svr::getListCommand(sqlrcursor_svr *cursor,
						int which, bool gettable) {

	// clean up any custom query cursors
	if (cursor->customquerycursor) {
		cursor->customquerycursor->close();
		delete cursor->customquerycursor;
		cursor->customquerycursor=NULL;
	}

	// clean up whatever result set the cursor might have been busy with
	cursor->cleanUpData();

	// get length of wild parameter
	uint32_t	wildlen;
	ssize_t		result=clientsock->read(&wildlen,idleclienttimeout,0);
	if (result!=sizeof(uint32_t)) {
		logClientProtocolError(cursor,
				"get list failed: "
				"failed to get wild length",result);
		return false;
	}

	// bounds checking
	if (wildlen>maxquerysize) {
		debugstr.clear();
		debugstr.append("get list failed: wild length too large: ");
		debugstr.append(wildlen);
		logClientProtocolError(cursor,debugstr.getString(),1);
		return false;
	}

	// read the wild parameter into the buffer
	char	*wild=new char[wildlen+1];
	if (wildlen) {
		result=clientsock->read(wild,wildlen,idleclienttimeout,0);
		if ((uint32_t)result!=wildlen) {
			logClientProtocolError(cursor,
					"get list failed: "
					"failed to get wild parameter",result);
			return false;
		}
	}
	wild[wildlen]='\0';

	// read the table parameter into the buffer
	char	*table=NULL;
	if (gettable) {

		// get length of table parameter
		uint32_t	tablelen;
		result=clientsock->read(&tablelen,idleclienttimeout,0);
		if (result!=sizeof(uint32_t)) {
			logClientProtocolError(cursor,
					"get list failed: "
					"failed to get table length",result);
			return false;
		}

		// bounds checking
		if (tablelen>maxquerysize) {
			debugstr.clear();
			debugstr.append("get list failed: "
					"table length too large: ");
			debugstr.append(tablelen);
			logClientProtocolError(cursor,debugstr.getString(),1);
			return false;
		}

		// read the table parameter into the buffer
		table=new char[tablelen+1];
		if (tablelen) {
			result=clientsock->read(table,tablelen,
						idleclienttimeout,0);
			if ((uint32_t)result!=tablelen) {
				logClientProtocolError(cursor,
					"get list failed: "
					"failed to get table parameter",result);
				return false;
			}
		}
		table[tablelen]='\0';

		// some apps aren't well behaved, trim spaces off of both sides
		charstring::bothTrim(table);

		// translate table name, if necessary
		if (sqlt) {
			const char	*newname=NULL;
			if (sqlt->getReplacementTableName(NULL,NULL,
							table,&newname)) {
				delete[] table;
				table=charstring::duplicate(newname);
			}
		}
	}

	// set the values that we won't get from the client
	cursor->inbindcount=0;
	cursor->outbindcount=0;
	sendcolumninfo=SEND_COLUMN_INFO;

	// get the list and return it
	bool	retval=true;
	if (conn->getListsByApiCalls()) {
		retval=getListByApiCall(cursor,which,table,wild);
	} else {
		retval=getListByQuery(cursor,which,table,wild);
	}

	// clean up
	delete[] wild;
	delete[] table;

	return retval;
}

bool sqlrcontroller_svr::getListByApiCall(sqlrcursor_svr *cursor,
						int which,
						const char *table,
						const char *wild) {

	// initialize flags andbuffers
	bool	success=false;

	// get the appropriate list
	switch (which) {
		case 0:
			success=conn->getDatabaseList(cursor,wild);
			break;
		case 1:
			success=conn->getTableList(cursor,wild);
			break;
		case 2:
			success=conn->getColumnList(cursor,table,wild);
			break;
	}

	if (success) {
		success=getSkipAndFetch(cursor);
	}

	// if an error occurred...
	if (!success) {
		cursor->errorMessage(cursor->error,
					maxerrorlength,
					&(cursor->errorlength),
					&(cursor->errnum),
					&(cursor->liveconnection));
		returnError(cursor,!cursor->liveconnection);

		// this is actually OK, only return false on a network error
		return true;
	}

	// indicate that no error has occurred
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);

	// send the client the id of the 
	// cursor that it's going to use
	clientsock->write(cursor->id);

	// tell the client that this is not a
	// suspended result set
	clientsock->write((uint16_t)NO_SUSPENDED_RESULT_SET);

	// if the query processed ok then send a result set header and return...
	returnResultSetHeader(cursor);
	if (!returnResultSetData(cursor,false)) {
		return false;
	}
	return true;
}

bool sqlrcontroller_svr::getListByQuery(sqlrcursor_svr *cursor,
						int which,
						const char *table,
						const char *wild) {

	// build the appropriate query
	const char	*query=NULL;
	bool		havewild=charstring::length(wild);
	switch (which) {
		case 0:
			query=conn->getDatabaseListQuery(havewild);
			break;
		case 1:
			query=conn->getTableListQuery(havewild);
			break;
		case 2:
			query=conn->getColumnListQuery(table,havewild);
			break;
	}

	// FIXME: this can fail
	buildListQuery(cursor,query,wild,table);

	// run it like a normal query, but don't request the query,
	// binds or column info status from the client
	return handleQueryOrBindCursor(cursor,false,false,false);
}

bool sqlrcontroller_svr::buildListQuery(sqlrcursor_svr *cursor,
						const char *query,
						const char *wild,
						const char *table) {

	// clean up buffers to avoid SQL injection
	stringbuffer	wildbuf;
	escapeParameter(&wildbuf,wild);
	stringbuffer	tablebuf;
	escapeParameter(&tablebuf,table);

	// bounds checking
	cursor->querylength=charstring::length(query)+
					wildbuf.getStringLength()+
					tablebuf.getStringLength();
	if (cursor->querylength>maxquerysize) {
		return false;
	}

	// fill the query buffer and update the length
	if (tablebuf.getStringLength()) {
		charstring::printf(cursor->querybuffer,maxquerysize+1,
						query,tablebuf.getString(),
						wildbuf.getString());
	} else {
		charstring::printf(cursor->querybuffer,maxquerysize+1,
						query,wildbuf.getString());
	}
	cursor->querylength=charstring::length(cursor->querybuffer);
	return true;
}

void sqlrcontroller_svr::escapeParameter(stringbuffer *buffer,
						const char *parameter) {

	if (!parameter) {
		return;
	}

	// escape single quotes
	for (const char *ptr=parameter; *ptr; ptr++) {
		if (*ptr=='\'') {
			buffer->append('\'');
		}
		buffer->append(*ptr);
	}
}

bool sqlrcontroller_svr::getQueryTreeCommand(sqlrcursor_svr *cursor) {

	logDebugMessage("getting query tree");

	// get the tree as a string
	xmldomnode	*tree=(cursor->querytree)?
				cursor->querytree->getRootNode():NULL;
	stringbuffer	*xml=(tree)?tree->xml():NULL;
	const char	*xmlstring=(xml)?xml->getString():NULL;
	uint64_t	xmlstringlen=(xml)?xml->getStringLength():0;

	// send the tree
	clientsock->write((uint16_t)NO_ERROR_OCCURRED);
	clientsock->write(xmlstringlen);
	clientsock->write(xmlstring,xmlstringlen);
	clientsock->flushWriteBuffer(-1,-1);

	// clean up
	delete xml;

	return true;
}

void sqlrcontroller_svr::endSession() {

	logDebugMessage("ending session...");

	updateState(SESSION_END);

	logDebugMessage("aborting all cursors...");
	for (int32_t i=0; i<cursorcount; i++) {
		if (cur[i]) {
			cur[i]->abort();
		}
	}
	logDebugMessage("done aborting all cursors");

	// truncate/drop temp tables
	// (Do this before running the end-session queries becuase
	// with oracle, it may be necessary to log out and log back in to
	// drop a temp table.  With each log-out the session end queries
	// are run and with each log-in the session start queries are run.)
	truncateTempTables(cur[0]);
	dropTempTables(cur[0]);

	sessionEndQueries();

	// must set suspendedsession to false here so resumed sessions won't 
	// automatically re-suspend
	suspendedsession=false;

	// if we're faking transaction blocks and the session was ended but we
	// haven't ended the transaction block, then we need to rollback and
	// end the block
	if (intransactionblock) {

		rollback();
		intransactionblock=false;

	} else if (conn->isTransactional() && commitorrollback) {

		// otherwise, commit or rollback as necessary
		if (cfgfl->getEndOfSessionCommit()) {
			logDebugMessage("committing...");
			commit();
			logDebugMessage("done committing...");
		} else {
			logDebugMessage("rolling back...");
			rollback();
			logDebugMessage("done rolling back...");
		}
	}

	// reset database/schema
	if (dbselected) {
		// FIXME: we're ignoring the result and error,
		// should we do something if there's an error?
		conn->selectDatabase(originaldb);
		dbselected=false;
	}

	// reset autocommit behavior
	setAutoCommit(conn->autocommit);

	// set isolation level
	conn->setIsolationLevel(isolationlevel);

	// reset sql translation
	if (sqlt) {
		sqlt->endSession();
	}

	// shrink the cursor array, if necessary
	while (cursorcount>mincursorcount) {
		cursorcount--;
		deleteCursor(cur[cursorcount]);
		cur[cursorcount]=NULL;
	}

	// end the session
	conn->endSession();

	logDebugMessage("done ending session");
}

void sqlrcontroller_svr::dropTempTables(sqlrcursor_svr *cursor) {

	// some databases require us to re-login before dropping temp tables
	if (sessiontemptablesfordrop.getLength() &&
			conn->tempTableDropReLogIn()) {
		reLogIn();
	}

	// run through the temp table list, dropping tables
	for (stringlistnode *sln=sessiontemptablesfordrop.getFirstNode();
				sln; sln=(stringlistnode *)sln->getNext()) {
		dropTempTable(cursor,sln->getValue());
		delete[] sln->getValue();
	}
	sessiontemptablesfordrop.clear();
}

void sqlrcontroller_svr::dropTempTable(sqlrcursor_svr *cursor,
					const char *tablename) {

	stringbuffer	dropquery;
	dropquery.append("drop table ");
	dropquery.append(conn->tempTableDropPrefix());
	dropquery.append(tablename);

	// FIXME: I need to refactor all of this so that this just gets
	// run as a matter of course instead of explicitly getting run here
	// FIXME: freetds/sybase override this method but don't do this
	if (sqltr) {
		if (sqlp->parse(dropquery.getString())) {
			sqltr->runBeforeTriggers(conn,cursor,sqlp->getTree());
		}
	}

	// kind of a kluge...
	// The cursor might already have a querytree associated with it and
	// if it does then executeQuery below might cause some triggers to
	// be run on that tree rather than on the tree for the drop query
	// we intend to run.
	delete cursor->querytree;
	cursor->querytree=NULL;

	if (cursor->prepareQuery(dropquery.getString(),
					dropquery.getStringLength())) {
		executeQuery(cursor,dropquery.getString(),
					dropquery.getStringLength());
	}
	cursor->cleanUpData();

	// FIXME: I need to refactor all of this so that this just gets
	// run as a matter of course instead of explicitly getting run here
	// FIXME: freetds/sybase override this method but don't do this
	if (sqltr) {
		sqltr->runAfterTriggers(conn,cursor,sqlp->getTree(),true);
	}
}

void sqlrcontroller_svr::truncateTempTables(sqlrcursor_svr *cursor) {

	// run through the temp table list, truncating tables
	for (stringlistnode *sln=sessiontemptablesfortrunc.getFirstNode();
				sln; sln=(stringlistnode *)sln->getNext()) {
		truncateTempTable(cursor,sln->getValue());
		delete[] sln->getValue();
	}
	sessiontemptablesfortrunc.clear();
}

void sqlrcontroller_svr::truncateTempTable(sqlrcursor_svr *cursor,
						const char *tablename) {
	stringbuffer	truncatequery;
	truncatequery.append("delete from ")->append(tablename);
	if (cursor->prepareQuery(truncatequery.getString(),
					truncatequery.getStringLength())) {
		executeQuery(cursor,truncatequery.getString(),
					truncatequery.getStringLength());
	}
	cursor->cleanUpData();
}

void sqlrcontroller_svr::closeClientSocket() {

	// Sometimes the server sends the result set and closes the socket
	// while part of it is buffered but not yet transmitted.  This causes
	// the client to receive a partial result set or error.  Telling the
	// socket to linger doesn't always fix it.  Doing a read here should 
	// guarantee that the client will close its end of the connection 
	// before the server closes its end; the server will wait for data 
	// from the client (which it will never receive) and when the client 
	// closes its end (which it will only do after receiving the entire
	// result set) the read will fall through.  This should guarantee 
	// that the client will get the the entire result set without
	// requiring the client to send data back indicating so.
	//
	// Also, if authentication fails, the client could send an entire query
	// and bind vars before it reads the error and closes the socket.
	// We have to absorb all of that data.  We shouldn't just loop forever
	// though, that would provide a point of entry for a DOS attack.  We'll
	// read the maximum number of bytes that could be sent.
	logDebugMessage("waiting for client to close the connection...");
	uint16_t	dummy;
	uint32_t	counter=0;
	clientsock->useNonBlockingMode();
	while (clientsock->read(&dummy,idleclienttimeout,0)>0 &&
				counter<
				// sending auth
				(sizeof(uint16_t)+
				// user/password
				2*(sizeof(uint32_t)+USERSIZE)+
				// sending query
				sizeof(uint16_t)+
				// need a cursor
				sizeof(uint16_t)+
				// executing new query
				sizeof(uint16_t)+
				// query size and query
				sizeof(uint32_t)+maxquerysize+
				// input bind var count
				sizeof(uint16_t)+
				// input bind vars
				maxbindcount*(2*sizeof(uint16_t)+
							maxbindnamelength)+
				// output bind var count
				sizeof(uint16_t)+
				// output bind vars
				maxbindcount*(2*sizeof(uint16_t)+
							maxbindnamelength)+
				// get column info
				sizeof(uint16_t)+
				// skip/fetch
				2*sizeof(uint32_t)
				// divide by two because we're
				// reading 2 bytes at a time
				)/2) {
		counter++;
	}
	clientsock->useBlockingMode();
	
	logDebugMessage("done waiting for client to close the connection");

	// close the client socket
	logDebugMessage("closing the client socket...");
	if (proxymode) {

		logDebugMessage("(actually just signalling the listener)");

		// we do need to signal the proxy that it
		// needs to close the connection though
		signalmanager::sendSignal(proxypid,SIGUSR1);

		// in proxy mode, the client socket is pointed at the
		// handoff socket which we don't want to actually close
		clientsock->setFileDescriptor(-1);
	}
	clientsock->close();
	delete clientsock;
	logDebugMessage("done closing the client socket");
}

void sqlrcontroller_svr::closeSuspendedSessionSockets() {

	if (suspendedsession) {
		return;
	}

	// If we're no longer in a suspended session but had to open a set of
	// sockets to handle a suspended session, close those sockets here.
	if (serversockun || serversockin) {
		logDebugMessage("closing sockets from "
				"a previously suspended session...");
	}
	if (serversockun) {
		removeFileDescriptor(serversockun);
		delete serversockun;
		serversockun=NULL;
	}
	if (serversockin) {
		for (uint64_t index=0;
				index<serversockincount;
				index++) {
			removeFileDescriptor(serversockin[index]);
			delete serversockin[index];
			serversockin[index]=NULL;
		}
		delete[] serversockin;
		serversockin=NULL;
		serversockincount=0;
	}
	if (serversockun || serversockin) {
		logDebugMessage("done closing sockets from "
				"a previously suspended session...");
	}
}

void sqlrcontroller_svr::closeConnection() {

	logDebugMessage("closing connection...");

	if (inclientsession) {
		endSession();
		decrementOpenClientConnections();
		inclientsession=false;
	}

	// decrement the connection counter
	if (decrementonclose && cfgfl->getDynamicScaling() &&
						semset && idmemory) {
		decrementConnectionCount();
	}

	// deregister and close the handoff socket if necessary
	if (connected) {
		deRegisterForHandoff();
	}

	// close the cursors
	closeCursors(true);

	// try to log out
	logOut();

	// clear the pool
	removeAllFileDescriptors();

	// close, clean up all sockets
	delete serversockun;

	for (uint64_t index=0; index<serversockincount; index++) {
		delete serversockin[index];
	}
	delete[] serversockin;

	logDebugMessage("done closing connection");
}

void sqlrcontroller_svr::closeCursors(bool destroy) {

	logDebugMessage("closing cursors...");

	if (cur) {
		while (cursorcount) {
			cursorcount--;

			if (cur[cursorcount]) {
				cur[cursorcount]->cleanUpData();
				cur[cursorcount]->close();
				if (destroy) {
					deleteCursor(cur[cursorcount]);
					cur[cursorcount]=NULL;
				}
			}
		}
		if (destroy) {
			delete[] cur;
			cur=NULL;
		}
	}

	logDebugMessage("done closing cursors...");
}

void sqlrcontroller_svr::deleteCursor(sqlrcursor_svr *curs) {
	conn->deleteCursor(curs);
	decrementOpenDatabaseCursors();
}

bool sqlrcontroller_svr::createSharedMemoryAndSemaphores(const char *id) {

	size_t	idfilenamelen=tmpdir->getLength()+5+
					charstring::length(id)+1;
	char	*idfilename=new char[idfilenamelen];
	charstring::printf(idfilename,idfilenamelen,"%s/ipc/%s",
						tmpdir->getString(),id);

	debugstr.clear();
	debugstr.append("attaching to shared memory and semaphores ");
	debugstr.append("id filename: ")->append(idfilename);
	logDebugMessage(debugstr.getString());

	// connect to the shared memory
	logDebugMessage("attaching to shared memory...");
	idmemory=new sharedmemory();
	if (!idmemory->attach(file::generateKey(idfilename,1))) {
		char	*err=error::getErrorString();
		stderror.printf("Couldn't attach to shared memory segment: ");
		stderror.printf("%s\n",err);
		delete[] err;
		delete idmemory;
		idmemory=NULL;
		delete[] idfilename;
		return false;
	}
	shm=(shmdata *)idmemory->getPointer();
	if (!shm) {
		stderror.printf("failed to get pointer to shmdata\n");
		delete idmemory;
		idmemory=NULL;
		delete[] idfilename;
		return false;
	}

	// connect to the semaphore set
	logDebugMessage("attaching to semaphores...");
	semset=new semaphoreset();
	if (!semset->attach(file::generateKey(idfilename,1),11)) {
		char	*err=error::getErrorString();
		stderror.printf("Couldn't attach to semaphore set: ");
		stderror.printf("%s\n",err);
		delete[] err;
		delete semset;
		delete idmemory;
		semset=NULL;
		idmemory=NULL;
		delete[] idfilename;
		return false;
	}

	logDebugMessage("done attaching to shared memory and semaphores");

	delete[] idfilename;

	return true;
}

shmdata *sqlrcontroller_svr::getAnnounceBuffer() {
	return (shmdata *)idmemory->getPointer();
}

void sqlrcontroller_svr::decrementConnectedClientCount() {

	logDebugMessage("decrementing session count...");

	if (!semset->waitWithUndo(5)) {
		// FIXME: bail somehow
	}

	// increment the connections-in-use count
	if (shm->connectedclients) {
		shm->connectedclients--;
	}

	// update the peak connections-in-use count
	if (shm->connectedclients>shm->peak_connectedclients) {
		shm->peak_connectedclients=shm->connectedclients;
	}

	// update the peak connections-in-use over the previous minute count
	datetime	dt;
	dt.getSystemDateAndTime();
	if (shm->connectedclients>shm->peak_connectedclients_1min ||
		dt.getEpoch()/60>shm->peak_connectedclients_1min_time/60) {
		shm->peak_connectedclients_1min=shm->connectedclients;
		shm->peak_connectedclients_1min_time=dt.getEpoch();
	}

	if (!semset->signalWithUndo(5)) {
		// FIXME: bail somehow
	}

	logDebugMessage("done decrementing session count");
}

void sqlrcontroller_svr::acquireAnnounceMutex() {
	logDebugMessage("acquiring announce mutex");
	updateState(WAIT_SEMAPHORE);
	semset->waitWithUndo(0);
	logDebugMessage("done acquiring announce mutex");
}

void sqlrcontroller_svr::releaseAnnounceMutex() {
	logDebugMessage("releasing announce mutex");
	semset->signalWithUndo(0);
	logDebugMessage("done releasing announce mutex");
}

void sqlrcontroller_svr::signalListenerToRead() {
	logDebugMessage("signalling listener to read");
	semset->signal(2);
	logDebugMessage("done signalling listener to read");
}

void sqlrcontroller_svr::waitForListenerToFinishReading() {
	logDebugMessage("waiting for listener");
	semset->wait(3);
	// Reset this semaphore to 0.
	// It can get left incremented if another sqlr-connection is killed
	// between calls to signalListenerToRead() and this method.
	// It's ok to reset it here becuase no one except this process has
	// access to this semaphore at this time because of the lock on
	// AnnounceMutex (semaphore 0).
	semset->setValue(3,0);
	logDebugMessage("done waiting for listener");
}

void sqlrcontroller_svr::acquireConnectionCountMutex() {
	logDebugMessage("acquiring connection count mutex");
	semset->waitWithUndo(4);
	logDebugMessage("done acquiring connection count mutex");
}

void sqlrcontroller_svr::releaseConnectionCountMutex() {
	logDebugMessage("releasing connection count mutex");
	semset->signalWithUndo(4);
	logDebugMessage("done releasing connection count mutex");
}

void sqlrcontroller_svr::signalScalerToRead() {
	logDebugMessage("signalling scaler to read");
	semset->signal(8);
	logDebugMessage("done signalling scaler to read");
}

void sqlrcontroller_svr::initConnStats() {

	semset->waitWithUndo(9);

	// Find an available location in the connstats array.
	// It shouldn't be possible for sqlr-start or sqlr-scaler to start
	// more than MAXCONNECTIONS, so unless someone started one manually,
	// it should always be possible to find an open one.
	for (uint32_t i=0; i<MAXCONNECTIONS; i++) {
		connstats=&shm->connstats[i];
		if (!connstats->processid) {

			semset->signalWithUndo(9);

			// initialize the connection stats
			clearConnStats();
			updateState(INIT);
			connstats->index=i;
			connstats->processid=process::getProcessId();
			connstats->loggedinsec=loggedinsec;
			connstats->loggedinusec=loggedinusec;
			return;
		}
	}

	semset->signalWithUndo(9);

	// in case someone started a connection manually and
	// exceeded MAXCONNECTIONS, set this NULL here
	connstats=NULL;
}

void sqlrcontroller_svr::clearConnStats() {
	if (!connstats) {
		return;
	}
	rawbuffer::zero(connstats,sizeof(struct sqlrconnstatistics));
}

void sqlrcontroller_svr::updateState(enum sqlrconnectionstate_t state) {
	if (!connstats) {
		return;
	}
	connstats->state=state;
	timeval		tv;
	gettimeofday(&tv,NULL);
	connstats->statestartsec=tv.tv_sec;
	connstats->statestartusec=tv.tv_usec;
}

void sqlrcontroller_svr::updateClientSessionStartTime() {
	if (!connstats) {
		return;
	}
	timeval		tv;
	gettimeofday(&tv,NULL);
	connstats->clientsessionsec=tv.tv_sec;
	connstats->clientsessionusec=tv.tv_usec;
}

void sqlrcontroller_svr::updateCurrentQuery(const char *query,
						uint32_t querylen) {
	if (!connstats) {
		return;
	}
	uint32_t	len=querylen;
	if (len>STATSQLTEXTLEN-1) {
		len=STATSQLTEXTLEN-1;
	}
	charstring::copy(connstats->sqltext,query,len);
	connstats->sqltext[len]='\0';
}

void sqlrcontroller_svr::updateClientInfo(const char *info, uint32_t infolen) {
	if (!connstats) {
		return;
	}
	uint64_t	len=infolen;
	if (len>STATCLIENTINFOLEN-1) {
		len=STATCLIENTINFOLEN-1;
	}
	charstring::copy(connstats->clientinfo,info,len);
	connstats->clientinfo[len]='\0';
}

void sqlrcontroller_svr::updateClientAddr() {
	if (!connstats) {
		return;
	}
	if (clientsock) {
		char	*clientaddrbuf=clientsock->getPeerAddress();
		if (clientaddrbuf) {
			charstring::copy(connstats->clientaddr,clientaddrbuf);
			delete[] clientaddrbuf;
		} else {
			charstring::copy(connstats->clientaddr,"UNIX");
		}
	} else {
		charstring::copy(connstats->clientaddr,"internal");
	}
}

void sqlrcontroller_svr::incrementOpenDatabaseConnections() {
	semset->waitWithUndo(9);
	shm->open_db_connections++;
	shm->opened_db_connections++;
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::decrementOpenDatabaseConnections() {
	semset->waitWithUndo(9);
	if (shm->open_db_connections) {
		shm->open_db_connections--;
	}
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementOpenClientConnections() {
	semset->waitWithUndo(9);
	shm->open_cli_connections++;
	shm->opened_cli_connections++;
	semset->signalWithUndo(9);
	if (!connstats) {
		return;
	}
	connstats->nconnect++;
}

void sqlrcontroller_svr::decrementOpenClientConnections() {
	semset->waitWithUndo(9);
	if (shm->open_cli_connections) {
		shm->open_cli_connections--;
	}
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementOpenDatabaseCursors() {
	semset->waitWithUndo(9);
	shm->open_db_cursors++;
	shm->opened_db_cursors++;
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::decrementOpenDatabaseCursors() {
	semset->waitWithUndo(9);
	if (shm->open_db_cursors) {
		shm->open_db_cursors--;
	}
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementTimesNewCursorUsed() {
	semset->waitWithUndo(9);
	shm->times_new_cursor_used++;
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementTimesCursorReused() {
	semset->waitWithUndo(9);
	shm->times_cursor_reused++;
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementQueryCounts(sqlrquerytype_t querytype) {

	semset->waitWithUndo(9);

	// update total queries
	shm->total_queries++;

	// update queries-per-second stats...

	// re-init stats if necessary
	datetime	dt;
	dt.getSystemDateAndTime();
	time_t	now=dt.getEpoch();
	int	index=now%STATQPSKEEP;
	if (shm->timestamp[index]!=now) {
		shm->timestamp[index]=now;
		shm->qps_select[index]=0;
		shm->qps_update[index]=0;
		shm->qps_insert[index]=0;
		shm->qps_delete[index]=0;
		shm->qps_create[index]=0;
		shm->qps_drop[index]=0;
		shm->qps_alter[index]=0;
		shm->qps_custom[index]=0;
		shm->qps_etc[index]=0;
	}

	// increment per-query-type stats
	switch (querytype) {
		case SQLRQUERYTYPE_SELECT:
			shm->qps_select[index]++;
			break;
		case SQLRQUERYTYPE_INSERT:
			shm->qps_insert[index]++;
			break;
		case SQLRQUERYTYPE_UPDATE:
			shm->qps_update[index]++;
			break;
		case SQLRQUERYTYPE_DELETE:
			shm->qps_delete[index]++;
			break;
		case SQLRQUERYTYPE_CREATE:
			shm->qps_create[index]++;
			break;
		case SQLRQUERYTYPE_DROP:
			shm->qps_drop[index]++;
			break;
		case SQLRQUERYTYPE_ALTER:
			shm->qps_alter[index]++;
			break;
		case SQLRQUERYTYPE_CUSTOM:
			shm->qps_custom[index]++;
			break;
		case SQLRQUERYTYPE_ETC:
		default:
			shm->qps_etc[index]++;
			break;
	}

	semset->signalWithUndo(9);

	if (!connstats) {
		return;
	}
	if (querytype==SQLRQUERYTYPE_CUSTOM) {
		connstats->ncustomsql++;
	} else {
		connstats->nsql++;
	}
}

void sqlrcontroller_svr::incrementTotalErrors() {
	semset->waitWithUndo(9);
	shm->total_errors++;
	semset->signalWithUndo(9);
}

void sqlrcontroller_svr::incrementAuthenticateCount() {
	if (!connstats) {
		return;
	}
	connstats->nauthenticate++;
}

void sqlrcontroller_svr::incrementSuspendSessionCount() {
	if (!connstats) {
		return;
	}
	connstats->nsuspend_session++;
}

void sqlrcontroller_svr::incrementEndSessionCount() {
	if (!connstats) {
		return;
	}
	connstats->nend_session++;
}

void sqlrcontroller_svr::incrementPingCount() {
	if (!connstats) {
		return;
	}
	connstats->nping++;
}

void sqlrcontroller_svr::incrementIdentifyCount() {
	if (!connstats) {
		return;
	}
	connstats->nidentify++;
}

void sqlrcontroller_svr::incrementAutocommitCount() {
	if (!connstats) {
		return;
	}
	connstats->nautocommit++;
}

void sqlrcontroller_svr::incrementBeginCount() {
	if (!connstats) {
		return;
	}
	connstats->nbegin++;
}

void sqlrcontroller_svr::incrementCommitCount() {
	if (!connstats) {
		return;
	}
	connstats->ncommit++;
}

void sqlrcontroller_svr::incrementRollbackCount() {
	if (!connstats) {
		return;
	}
	connstats->nrollback++;
}

void sqlrcontroller_svr::incrementDbVersionCount() {
	if (!connstats) {
		return;
	}
	connstats->ndbversion++;
}

void sqlrcontroller_svr::incrementBindFormatCount() {
	if (!connstats) {
		return;
	}
	connstats->nbindformat++;
}

void sqlrcontroller_svr::incrementServerVersionCount() {
	if (!connstats) {
		return;
	}
	connstats->nserverversion++;
}

void sqlrcontroller_svr::incrementSelectDatabaseCount() {
	if (!connstats) {
		return;
	}
	connstats->nselectdatabase++;
}

void sqlrcontroller_svr::incrementGetCurrentDatabaseCount() {
	if (!connstats) {
		return;
	}
	connstats->ngetcurrentdatabase++;
}

void sqlrcontroller_svr::incrementGetLastInsertIdCount() {
	if (!connstats) {
		return;
	}
	connstats->ngetlastinsertid++;
}

void sqlrcontroller_svr::incrementDbHostNameCount() {
	if (!connstats) {
		return;
	}
	connstats->ndbhostname++;
}

void sqlrcontroller_svr::incrementDbIpAddressCount() {
	if (!connstats) {
		return;
	}
	connstats->ndbipaddress++;
}

void sqlrcontroller_svr::incrementNewQueryCount() {
	if (!connstats) {
		return;
	}
	connstats->nnewquery++;
}

void sqlrcontroller_svr::incrementReexecuteQueryCount() {
	if (!connstats) {
		return;
	}
	connstats->nreexecutequery++;
}

void sqlrcontroller_svr::incrementFetchFromBindCursorCount() {
	if (!connstats) {
		return;
	}
	connstats->nfetchfrombindcursor++;
}

void sqlrcontroller_svr::incrementFetchResultSetCount() {
	if (!connstats) {
		return;
	}
	connstats->nfetchresultset++;
}

void sqlrcontroller_svr::incrementAbortResultSetCount() {
	if (!connstats) {
		return;
	}
	connstats->nabortresultset++;
}

void sqlrcontroller_svr::incrementSuspendResultSetCount() {
	if (!connstats) {
		return;
	}
	connstats->nsuspendresultset++;
}

void sqlrcontroller_svr::incrementResumeResultSetCount() {
	if (!connstats) {
		return;
	}
	connstats->nresumeresultset++;
}

void sqlrcontroller_svr::incrementGetDbListCount() {
	if (!connstats) {
		return;
	}
	connstats->ngetdblist++;
}

void sqlrcontroller_svr::incrementGetTableListCount() {
	if (!connstats) {
		return;
	}
	connstats->ngettablelist++;
}

void sqlrcontroller_svr::incrementGetColumnListCount() {
	if (!connstats) {
		return;
	}
	connstats->ngetcolumnlist++;
}

void sqlrcontroller_svr::incrementGetQueryTreeCount() {
	if (!connstats) {
		return;
	}
	connstats->ngetquerytree++;
}

void sqlrcontroller_svr::incrementReLogInCount() {
	if (!connstats) {
		return;
	}
	connstats->nrelogin++;
}

void sqlrcontroller_svr::sessionStartQueries() {
	// run a configurable set of queries at the start of each session
	for (stringlistnode *node=
		cfgfl->getSessionStartQueries()->getFirstNode();
						node; node=node->getNext()) {
		sessionQuery(node->getValue());
	}
}

void sqlrcontroller_svr::sessionEndQueries() {
	// run a configurable set of queries at the end of each session
	for (stringlistnode *node=
		cfgfl->getSessionEndQueries()->getFirstNode();
						node; node=node->getNext()) {
		sessionQuery(node->getValue());
	}
}

void sqlrcontroller_svr::sessionQuery(const char *query) {

	// create the select database query
	size_t	querylen=charstring::length(query);

	sqlrcursor_svr	*cur=initCursor();

	// since we're creating a new cursor for this, make sure it
	// can't have an ID that might already exist
	if (cur->openInternal(cursorcount+1) &&
		cur->prepareQuery(query,querylen) &&
		executeQuery(cur,query,querylen)) {
		cur->cleanUpData();
	}
	cur->close();
	deleteCursor(cur);
}

const char *sqlrcontroller_svr::connectStringValue(const char *variable) {

	// If we're using password encryption and the password is requested,
	// and the password encryption module supports two-way encryption,
	// then return the decrypted version of the password, otherwise just
	// return the value as-is.
	const char	*peid=constr->getPasswordEncryption();
	if (sqlrpe && charstring::length(peid) &&
			!charstring::compare(variable,"password")) {
		sqlrpwdenc	*pe=sqlrpe->getPasswordEncryptionById(peid);
		if (!pe->oneWay()) {
			delete[] decrypteddbpassword;
			decrypteddbpassword=pe->decrypt(
				constr->getConnectStringValue(variable));
			return decrypteddbpassword;
		}
	}
	return constr->getConnectStringValue(variable);
}

void sqlrcontroller_svr::setUser(const char *user) {
	this->user=user;
}

void sqlrcontroller_svr::setPassword(const char *password) {
	this->password=password;
}

const char *sqlrcontroller_svr::getUser() {
	return user;
}

const char *sqlrcontroller_svr::getPassword() {
	return password;
}
void sqlrcontroller_svr::setAutoCommitBehavior(bool ac) {
	conn->autocommit=ac;
}

void sqlrcontroller_svr::setFakeTransactionBlocksBehavior(bool ftb) {
	faketransactionblocks=ftb;
}

void sqlrcontroller_svr::cleanUpAllCursorData() {
	logDebugMessage("cleaning up all cursors...");
	for (int32_t i=0; i<cursorcount; i++) {
		if (cur[i]) {
			cur[i]->cleanUpData();
		}
	}
	logDebugMessage("done cleaning up all cursors");
}

bool sqlrcontroller_svr::getColumnNames(const char *query,
					stringbuffer *output) {

	// sanity check on the query
	if (!query) {
		return false;
	}

	size_t		querylen=charstring::length(query);

	sqlrcursor_svr	*gcncur=initCursor();
	// since we're creating a new cursor for this, make sure it can't
	// have an ID that might already exist
	bool	retval=false;
	if (gcncur->openInternal(cursorcount+1) &&
		gcncur->prepareQuery(query,querylen) &&
		executeQuery(gcncur,query,querylen)) {

		// build column list...
		retval=gcncur->getColumnNameList(output);

	}
	gcncur->cleanUpData();
	gcncur->close();
	deleteCursor(gcncur);
	return retval;
}

void sqlrcontroller_svr::addSessionTempTableForDrop(const char *table) {
	sessiontemptablesfordrop.append(charstring::duplicate(table));
}

void sqlrcontroller_svr::addTransactionTempTableForDrop(const char *table) {
	transtemptablesfordrop.append(charstring::duplicate(table));
}

void sqlrcontroller_svr::addSessionTempTableForTrunc(const char *table) {
	sessiontemptablesfortrunc.append(charstring::duplicate(table));
}

void sqlrcontroller_svr::addTransactionTempTableForTrunc(const char *table) {
	transtemptablesfortrunc.append(charstring::duplicate(table));
}

void sqlrcontroller_svr::logDebugMessage(const char *info) {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_DEBUG,
			SQLRLOGGER_EVENTTYPE_DEBUG_MESSAGE,
			info);
}

void sqlrcontroller_svr::logClientConnected() {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_INFO,
			SQLRLOGGER_EVENTTYPE_CLIENT_CONNECTED,
			NULL);
}

void sqlrcontroller_svr::logClientConnectionRefused(const char *info) {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_WARNING,
			SQLRLOGGER_EVENTTYPE_CLIENT_CONNECTION_REFUSED,
			info);
}

void sqlrcontroller_svr::logClientDisconnected(const char *info) {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_INFO,
			SQLRLOGGER_EVENTTYPE_CLIENT_DISCONNECTED,
			info);
}

void sqlrcontroller_svr::logClientProtocolError(sqlrcursor_svr *cursor,
							const char *info,
							ssize_t result) {
	if (!sqlrlg) {
		return;
	}
	stringbuffer	errorbuffer;
	errorbuffer.append(info);
	if (result==0) {
		errorbuffer.append(": client closed connection");
	} else if (result==RESULT_ERROR) {
		errorbuffer.append(": error");
	} else if (result==RESULT_TIMEOUT) {
		errorbuffer.append(": timeout");
	} else if (result==RESULT_ABORT) {
		errorbuffer.append(": abort");
	}
	if (error::getErrorNumber()) {
		char	*error=error::getErrorString();
		errorbuffer.append(": ")->append(error);
		delete[] error;
	}
	sqlrlg->runLoggers(NULL,conn,cursor,
			SQLRLOGGER_LOGLEVEL_ERROR,
			SQLRLOGGER_EVENTTYPE_CLIENT_PROTOCOL_ERROR,
			errorbuffer.getString());
}

void sqlrcontroller_svr::logDbLogIn() {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_INFO,
			SQLRLOGGER_EVENTTYPE_DB_LOGIN,
			NULL);
}

void sqlrcontroller_svr::logDbLogOut() {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,NULL,
			SQLRLOGGER_LOGLEVEL_INFO,
			SQLRLOGGER_EVENTTYPE_DB_LOGOUT,
			NULL);
}

void sqlrcontroller_svr::logDbError(sqlrcursor_svr *cursor, const char *info) {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,cursor,
			SQLRLOGGER_LOGLEVEL_ERROR,
			SQLRLOGGER_EVENTTYPE_DB_ERROR,
			cursor->error);
}

void sqlrcontroller_svr::logQuery(sqlrcursor_svr *cursor) {
	if (!sqlrlg) {
		return;
	}
	sqlrlg->runLoggers(NULL,conn,cursor,
			SQLRLOGGER_LOGLEVEL_INFO,
			SQLRLOGGER_EVENTTYPE_QUERY,
			NULL);
}

void sqlrcontroller_svr::logInternalError(sqlrcursor_svr *cursor,
							const char *info) {
	if (!sqlrlg) {
		return;
	}
	stringbuffer	errorbuffer;
	errorbuffer.append(info);
	if (error::getErrorNumber()) {
		char	*error=error::getErrorString();
		errorbuffer.append(": ")->append(error);
		delete[] error;
	}
	sqlrlg->runLoggers(NULL,conn,cursor,
			SQLRLOGGER_LOGLEVEL_ERROR,
			SQLRLOGGER_EVENTTYPE_INTERNAL_ERROR,
			errorbuffer.getString());
}
