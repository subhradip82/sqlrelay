// Copyright (c) 1999-2018  David Muse
// All rights reserved

#include <sqlrelay/sqlrserver.h>
#include <rudiments/regularexpression.h>
#include <rudiments/linkedlist.h>
#include <rudiments/error.h>
#include <rudiments/snooze.h>

#define NEED_IS_BIND_DELIMITER 1
#include <bindvariables.h>

class SQLRSERVER_DLLSPEC sqlrtrigger_upsert : public sqlrtrigger {
	public:
		sqlrtrigger_upsert(sqlrservercontroller *cont,
						sqlrtriggers *ts,
						domnode *parameters);

		bool	run(sqlrserverconnection *sqlrcon,
						sqlrservercursor *icur,
						bool before,
						bool *success);
	private:
		bool	errorEncountered(sqlrservercursor *icur);
		domnode	*tableEncountered(const char *table);
		bool	insertToUpdate(const char *table,
					const char * const *cols,
					uint64_t colcount,
					const char *autoinccolumn,
					const char *primarykeycolumn,
					const char *values,
					domnode *tablenode,
					stringbuffer *query);
		bool	isBind(const char *var);
		bool	copyInputBinds(sqlrservercursor *dest,
					sqlrservercursor *source);
		void	copyInputBind(memorypool *pool,
					bool where,
					sqlrserverbindvar *dest,
					sqlrserverbindvar *source);
		void	deleteCols(char **cols, uint64_t colcount);

		sqlrservercontroller	*cont;

		bool	debug;

		domnode	*errors;
		domnode	*tables;

		dictionary<const char *, const char *>	wherebinds;
};

sqlrtrigger_upsert::sqlrtrigger_upsert(sqlrservercontroller *cont,
					sqlrtriggers *ts,
					domnode *parameters) :
					sqlrtrigger(cont,ts,parameters) {
	this->cont=cont;

	debug=cont->getConfig()->getDebugTriggers();

	errors=parameters->getFirstTagChild("errors");
	tables=parameters->getFirstTagChild("tables");
}

bool sqlrtrigger_upsert::run(sqlrserverconnection *sqlrcon,
						sqlrservercursor *icur,
						bool before,
						bool *success) {

	// in the before phase, don't do anything
	if (before) {
		return *success;
	}

	// in the after phase...

	// get the query and query type
	//
	// NOTE: for now queryType() groups simple insert, multi-insert,
	// insert/select and select-into into SQLRQUERYTYPE_INSERT
	const char		*query=icur->getQueryBuffer();
	uint32_t		querylen=icur->getQueryLength();
	sqlrquerytype_t		querytype=icur->queryType(query,querylen);

	if (debug) {
		stdoutput.printf("upsert {\n");
		stdoutput.printf("	triggering query:\n%.*s\n",
							querylen,query);
	}

	// bail if the query wasn't an insert, or if the insert didn't
	// encounter an error that should trigger an update
	if (querytype!=SQLRQUERYTYPE_INSERT) {
		if (debug) {
			stdoutput.printf("	query was not an insert\n}\n");
		}
		return *success;
	}

	// bail if insert didn't encounter an
	// error that should trigger an update
	if (!errorEncountered(icur)) {
		if (debug) {
			stdoutput.printf("	no matching error found\n}\n");
		}
		return *success;
	}

	// parse the query
	// NOTE: parseInsert will populate querytype with a more specific value
	char		*table=NULL;
	char		**cols=NULL;
	uint64_t	colcount=0;
	const char	*autoinccolumn=NULL;
	const char	*primarykeycolumn=NULL;
	const char	*values=NULL;
	cont->parseInsert(query,querylen,&querytype,
				&table,&cols,&colcount,NULL,
				&autoinccolumn,NULL,
				&primarykeycolumn,NULL,
				&values);

	if (debug) {
		stdoutput.printf("	table: %s\n",table);
		stdoutput.printf("	columns:\n");
		for (uint64_t i=0; i<colcount; i++) {
			stdoutput.printf("		%s\n",cols[i]);
		}
		stdoutput.printf("	auto-increment column: %s\n",
							autoinccolumn);
		stdoutput.printf("	primary key column (from db): %s\n",
							primarykeycolumn);
		stdoutput.printf("	values: %s\n",values);
	}

	// bail if the query wasn't a simple insert
	if (querytype!=SQLRQUERYTYPE_INSERT) {
		if (debug) {
			stdoutput.printf("	not a simple insert\n}\n");
		}
		deleteCols(cols,colcount);
		delete[] table;
		return *success;
	}

	// bail if the table isn't one that we want to update
	domnode	*tablenode=tableEncountered(table);
	if (!tablenode) {
		if (debug) {
			stdoutput.printf("	table not "
					"configured for upsert\n}\n");
		}
		deleteCols(cols,colcount);
		delete[] table;
		return *success;
	}

	// if parseInsert didn't find a primary key
	// then try to get it from the table node
	if (!primarykeycolumn) {
		primarykeycolumn=tablenode->
					getFirstTagChild("primarykey")->
					getAttributeValue("name");
		if (debug) {
			stdoutput.printf("	primary key column "
						"(from config): %s\n",
						primarykeycolumn);
		}
	}

	// convert the insert to an update
	stringbuffer		update;
	*success=insertToUpdate(table,cols,colcount,
				autoinccolumn,primarykeycolumn,
				values,tablenode,&update);
	if (!*success && debug) {
		stdoutput.printf("	failed to convert insert to update\n");
	}

	// Create an update cursor to run the update.
	// Preserve the insert cursor in case the
	// client wants to reexecute the insert.
	sqlrservercursor	*ucur=NULL;
	if (*success) {
		ucur=cont->newCursor();
		if (!ucur) {
			*success=false;
		}
	}

	// open the cursor
	if (*success) {
		*success=cont->open(ucur);
		if (!*success && debug) {
			stdoutput.printf("	failed to open cursor\n");
		}
	}

	// copy input binds from icur to ucur
	if (*success) {
		*success=copyInputBinds(ucur,icur);
		if (!*success && debug) {
			stdoutput.printf("	failed to copy input binds\n");
		}
	}

	// prepare the query
	if (*success) {
		*success=cont->prepareQuery(ucur,update.getString(),
						update.getStringLength());
		if (!*success && debug) {
        		const char      *errorstring;
        		uint32_t        errorlength;
        		int64_t         errnum;
        		bool            liveconnection;
        		cont->errorMessage(ucur,&errorstring,
							&errorlength,
                                        		&errnum,
							&liveconnection);
			stdoutput.printf("	failed to prepare "
						"update query:\n%.*s\n",
						errorlength,errorstring);
		}
	}

	// execute the query
	if (*success) {
		*success=cont->executeQuery(ucur);
		if (!*success && debug) {
        		const char      *errorstring;
        		uint32_t        errorlength;
        		int64_t         errnum;
        		bool            liveconnection;
        		cont->errorMessage(ucur,&errorstring,
							&errorlength,
                                        		&errnum,
							&liveconnection);
			stdoutput.printf("	failed to execute "
						"update query:\n%.*s\n",
						errorlength,errorstring);
		}
	}


	// FIXME: copy affected rows to icur

	if (*success) {
		cont->clearError();
		cont->clearError(icur);
	} else {
		// FIXME: currently icur has the error that triggered
		// the upsert, copy ucur's error over to icur
	}

	if (debug) {
		stdoutput.printf("}\n");
	}

	// clean up
	if (ucur) {
		cont->closeResultSet(ucur);
		cont->close(ucur);
		cont->deleteCursor(ucur);
	}
	deleteCols(cols,colcount);
	delete[] table;
	return *success;
}

bool sqlrtrigger_upsert::errorEncountered(sqlrservercursor *icur) {

	// look through the errors and see if we find
	// one that matches the icur's error
	// FIXME: maybe cache the number using
	// domnode::setData() for future lookups
	for (domnode *node=errors->getFirstTagChild("error");
				!node->isNullNode();
				node=node->getNextTagSibling("error")) {
		const char	*string=node->getAttributeValue("string");
		const char	*number=node->getAttributeValue("number");
		if ((string && charstring::contains(
					icur->getErrorBuffer(),string)) ||
			(number && icur->getErrorNumber()==
					charstring::toInteger(number))) {
			return true;
		}
	}
	return false;
}

domnode *sqlrtrigger_upsert::tableEncountered(const char *table) {

	// look through the tables and see if we find one that matches "table"
	for (domnode *node=tables->getFirstTagChild("table");
				!node->isNullNode();
				node=node->getNextTagSibling("table")) {
		if (!charstring::compare(
				node->getAttributeValue("name"),table)) {
			return node;
		}
	}
	return NULL;
}

bool sqlrtrigger_upsert::insertToUpdate(const char *table,
					const char * const *cols,
					uint64_t colcount,
					const char *autoinccolumn,
					const char *primarykeycolumn,
					const char *values,
					domnode *tablenode,
					stringbuffer *query) {

	// split values
	char		**vals;
	uint64_t	valscount;
	// FIXME: use a split that considers quoting and ignores the trailing )
	char	*tempvalues=charstring::duplicate(values);
	tempvalues[charstring::length(tempvalues)-1]='\0';
	charstring::split(tempvalues,",",false,&vals,&valscount);
	delete[] tempvalues;

	// begin building the update query
	query->append("update ")->append(table)->append(" set ");

	// build the set clause and map column names to values
	dictionary<const char *,const char *>	valuemap;
	bool	first=true;
	for (uint64_t i=0; i<colcount; i++) {

		// get the column/value pair
		const char	*col=cols[i];
		const char	*val=vals[i];

		// don't attempt to set auto-increment or primary key columns
		if (!charstring::compare(col,autoinccolumn) ||
			!charstring::compare(col,primarykeycolumn)) {
			continue;
		}

		// append the column/value pair to the set clause
		if (first) {
			first=false;
		} else {
			query->append(',');
		}
		query->append(col)->append('=')->append(val);

		// map column -> value for use in the where clause later
		valuemap.setValue(col,val);
	}

	// begin building the where clause
	query->append(" where ");

	// build the where clause
	bool	retval=true;
	first=true;
	for (domnode *node=tablenode->getFirstTagChild("column");
				!node->isNullNode();
				node=node->getNextTagSibling("column")) {

		// get the column/value pair
		const char	*col=node->getAttributeValue("name");
		const char	*val;
		if (!valuemap.getValue(col,&val)) {
			// bail if we didn't find a value for this column
			// FIXME: maybe we should set an error here, if we
			// don't then the original error that the insert failed
			// with will still be the error, and the fact that it
			// didn't contain a column that we need to perform the
			// update won't be immediately obvious
			if (debug) {
				stdoutput.printf("	no value found "
							"for column: %s\n",col);
			}
			retval=false;
			break;
		}

		// append them to the where clause
		if (!first) {
			query->append(" and ");
		}
		query->append(col)->append('=');

		if (isBind(val)) {
			// if val is a bind then use the
			// where-clause version of it
			// FIXME: does the bind name include the delimiter?
			query->append(wherebinds.getValue(val));
		} else {
			query->append(val);
		}
		first=false;
	}

	if (debug) {
		stdoutput.printf("	update query:\n%s\n",
						query->getString());
	}

	// clean up
	for (uint64_t i=0; i<valscount; i++) {
		delete[] vals[i];
	}
	delete[] vals;
	
	return retval;
}

bool sqlrtrigger_upsert::isBind(const char *var) {
	return var && isBindDelimiter(var,
				cont->getConfig()->
				getBindVariableDelimiterQuestionMarkSupported(),
				cont->getConfig()->
				getBindVariableDelimiterColonSupported(),
				cont->getConfig()->
				getBindVariableDelimiterAtSignSupported(),
				cont->getConfig()->
				getBindVariableDelimiterDollarSignSupported());
}

bool sqlrtrigger_upsert::copyInputBinds(sqlrservercursor *dest,
					sqlrservercursor *source) {

	// make 2 copies of source's input binds in dest:
	// * one of each bind to use in the set clause
	// * one of each bind to use in the where clause

	// count source's binds and make sure we
	// can allocate twice as many in dest
	uint16_t	incount=source->getInputBindCount();
	if (incount*2>cont->getConfig()->getMaxBindCount()) {
		// FIXME: set an error, like too many binds or something
		return false;
	}

	// copy the input binds, making two copies of each in dest
	memorypool		*destpool=cont->getBindPool(dest);
	sqlrserverbindvar	*sinvars=source->getInputBinds();
	sqlrserverbindvar	*dinvars=dest->getInputBinds();
	for (uint16_t i=0; i<incount; i++) {
		copyInputBind(destpool,
				false,&(dinvars[i]),&(sinvars[i]));
		copyInputBind(destpool,
				true,&(dinvars[incount+i]),&(sinvars[i]));
	}

	// set dest's input bind count
	dest->setInputBindCount(incount*2);

	return true;
}

void sqlrtrigger_upsert::copyInputBind(memorypool *pool, bool where,
						sqlrserverbindvar *dest,
						sqlrserverbindvar *source) {

	// byte-copy everything
	bytestring::copy(dest,source,sizeof(sqlrserverbindvar));

	// The shallow-copy above will aim the variable, value.stringval,
	// and value.dateval.buffer pointers to the strings stored in the
	// main cursor's memorypool.  There's no need to make a copy of
	// those strings, as they will persist for as long as these binds do.

	// So, for the copy of the bind that we'll use in the set clause,
	// we can bail here.
	if (!where) {
		return;
	}

	// We do need to rename the variable for the copy of the bind that
	// we'll use in the where clause though....

	// prepend "where_" to the variable name
	// FIXME: not all db's support named binds
	// FIXME: does "variable" include the delimiter?
	dest->variablesize+=6;
	dest->variable=(char *)pool->allocate(6+dest->variablesize+1);
	charstring::copy(dest->variable,"where_");
	charstring::append(dest->variable,source->variable);

	// map the source -> dest variable name for
	// easier lookup when building the update query
	wherebinds.setValue(source->variable,dest->variable);
}

void sqlrtrigger_upsert::deleteCols(char **cols, uint64_t colcount) {
	for (uint64_t i=0; i<colcount; i++) {
		delete[] cols[i];
	}
	delete[] cols;
}

extern "C" {
	SQLRSERVER_DLLSPEC
	sqlrtrigger	*new_sqlrtrigger_upsert(sqlrservercontroller *cont,
						sqlrtriggers *ts,
						domnode *parameters) {

		return new sqlrtrigger_upsert(cont,ts,parameters);
	}
}
