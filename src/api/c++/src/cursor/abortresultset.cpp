// Copyright (c) 1999-2001  David Muse
// See the file COPYING for more information

#include <config.h>
#include <sqlrelay/sqlrclient.h>
#include <defines.h>

void sqlrcursor::closeResultSet() {
	closeResultSet(true);
}

void sqlrcursor::closeResultSet(bool closeremote) {

	// If the end of the previous result set was never reached, abort it.
	// If we're caching data to a local file, get the rest of the data; we
	// won't have to abort the result set in that case, the server will
	// do it.
	if (sqlrc->debug) {
		sqlrc->debugPreStart();
		sqlrc->debugPrint("Aborting Result Set For Cursor: ");
		sqlrc->debugPrint((int64_t)cursorid);
		sqlrc->debugPrint("\n");
		sqlrc->debugPreEnd();
	}

	if (sqlrc->connected || cached) {
		if (cachedest && cachedestind) {
			if (sqlrc->debug) {
				sqlrc->debugPreStart();
				sqlrc->debugPrint("Getting the rest of the result set, since this is a cached result set.\n");
				sqlrc->debugPreEnd();
			}
			while (!endofresultset) {
				clearRows();

				// if we're not fetching from a cached result 
				// set tell the server to send one 
				if (!cachesource && !cachesourceind) {
					sqlrc->cs->write((uint16_t)
							FETCH_RESULT_SET);
					sqlrc->cs->write(cursorid);
				}

				// parseData should call finishCaching when
				// it hits the end of the result set, but
				// if it or skipAndFetch return a -1 (network
				// error) we'll have to call it ourselves.
				if (!skipAndFetch(true,0) || !parseData()) {
					finishCaching();
					return;
				}
			}
		} else if (closeremote) {
			sqlrc->cs->write((uint16_t)ABORT_RESULT_SET);
			sqlrc->cs->write((uint16_t)DONT_NEED_NEW_CURSOR);
			sqlrc->cs->write(cursorid);
			sqlrc->flushWriteBuffer();
		}
	}
}
