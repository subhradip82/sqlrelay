// Copyright (c) 1999-2010  David Muse
// See the file COPYING for more information

#include <config.h>
#include <sqlrelay/sqlrcontroller.h>
#include <rudiments/process.h>
#include <rudiments/signalclasses.h>
#include <rudiments/stdio.h>

sqlrcontroller_svr	*cont=NULL;
volatile sig_atomic_t	shutdowninprogress=0;
signalhandler		shutdownhandler;
bool			shutdownalready=false;

void shutDown(int32_t signum) {

	// Various situations can cause this function to get looped up, such as
	// bugs in functions set to run at exit.  Detect a loop and just exit
	// if that's happening.
	if (shutdownalready) {
		stderror.printf("(pid=%ld) Shutdown loop detected, exiting.\n",
						(long)process::getProcessId());
		process::exit(0);
	}

	shutdownalready=true;

	if (!signalhandler::isSignalHandlerIntUsed()) {
		delete cont;
		process::exit(0);
	}

	// Since this handler is established for more than one kind of signal,
	// it might still get invoked recursively by delivery of some other kind
	// of signal.  Use a static variable to keep track of that.
	if (shutdowninprogress) {
		return;
	}
	shutdowninprogress=1;

	int	exitcode=1;
	switch (signum) {
		case SIGINT:
		#ifdef SIGQUIT
		case SIGQUIT:
		#endif
			// These signals indicate normal termination
			stderror.printf("(pid=%ld) Process terminated "
					"with signal %d\n",
					(long)process::getProcessId(),signum);
			break;

		case SIGTERM:
			// Shutdown
		#ifdef SIGALRM
		case SIGALRM:
			// Timeout
			stderror.printf("(pid=%ld) Process terminated "
					"with signal %d\n",
					(long)process::getProcessId(),signum);
			exitcode=0;
			break;
		#endif

		default:
			// Other signals are bugs
			stderror.printf("(pid=%ld) Abnormal termination: "
					"signal %d received\n",
					(long)process::getProcessId(),signum);
			delete cont;
			// Now reraise the signal.  We reactivate the signal's
		   	// default handling, which is to terminate the process.
		   	// We could just call exit or abort,
		   	// but reraising the signal sets the return status
		   	// from the process correctly.
			signal(signum,SIG_DFL);
			signalmanager::raiseSignal(signum);
	}

	delete cont;
	process::exit(exitcode);
}

void handleSignals(void (*shutdownfunction)(int32_t)) {

	// handle kill and crash signals
	process::handleShutDown(shutdownfunction);
	process::handleCrash(shutdownfunction);

	// handle various other shutdown conditions
	shutdownhandler.setHandler(shutdownfunction);
	// timeouts
	#ifdef SIGALRM
	shutdownhandler.handleSignal(SIGALRM);
	#endif
	// CPU consumption soft limit
	#ifdef SIGXCPU
	shutdownhandler.handleSignal(SIGXCPU);
	#endif
	// File size limit exceeded
	#ifdef SIGXFSZ
	shutdownhandler.handleSignal(SIGXFSZ);
	#endif
	// power failure
	#ifdef SIGPWR
	shutdownhandler.handleSignal(SIGPWR);
	#endif

	// ignore others
	signalset	set;
	set.addAllSignals();
	set.removeShutDownSignals();
	set.removeCrashSignals();
	#ifdef SIGALRM
	set.removeSignal(SIGALRM);
	#endif
	// CPU consumption soft limit
	#ifdef SIGXCPU
	set.removeSignal(SIGXCPU);
	#endif
	// File size limit exceeded
	#ifdef SIGXFSZ
	set.removeSignal(SIGXFSZ);
	#endif
	// power failure
	#ifdef SIGPWR
	set.removeSignal(SIGPWR);
	#endif
	signalmanager::ignoreSignals(&set);
}

int main(int argc, const char **argv) {

	// set up default signal handling
	process::exitOnCrashOrShutDown();

	#include <version.h>

	// create the controller
	cont=new sqlrcontroller_svr;

	// handle signals more particularly
	handleSignals(shutDown);

	// connect to the db
	bool	result=cont->init(argc,argv);
	if (result) {
		// wait for client connections
		result=cont->listen();
	}

	// If sqlr-stop has been run, we may be here because the sqlr-listener
	// has been killed.  In that case, we'll get a SIGINT soon, but we
	// want to ignore it and just let the shutdown proceed normally,
	// otherwise we could be halfway through cleanUp() below when we
	// get it, which will ultimately run cleanUp() again and result in
	// double-free's and a crash.  If we happen to receive the SIGINT
	// before this point, then the shutdown will proceed that way.
	shutdowninprogress=1;

	// unsuccessful completion
	delete cont;

	// return successful or unsuccessful completion based on listenresult
	process::exit((result)?0:1);
}
