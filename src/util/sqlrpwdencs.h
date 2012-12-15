// Copyright (c) 2012  David Muse
// See the file COPYING for more information

#ifndef SQLRPWDENCS_H
#define SQLRPWDENCS_H

#include <rudiments/xmldom.h>
#include <rudiments/linkedlist.h>
#include <rudiments/dynamiclib.h>
#include <sqlrpwdenc.h>

class sqlrpwdencplugin {
	public:
		sqlrpwdenc		*pe;
		rudiments::dynamiclib	*dl;
};

class sqlrpwdencs {
	public:
			sqlrpwdencs();
			~sqlrpwdencs();

		bool		loadPasswordEncryptions(const char *pwdencs);
		sqlrpwdenc	*getPasswordEncryptionById(const char *id);
	private:
		void	unloadPasswordEncryptions();
		void	loadPasswordEncryption(rudiments::xmldomnode *pwdenc);

		rudiments::xmldom	*xmld;
		rudiments::linkedlist< sqlrpwdencplugin * >	llist;
};

#endif
