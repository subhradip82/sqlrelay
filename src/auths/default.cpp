// Copyright (c) 1999-2014  David Muse
// See the file COPYING for more information

#include <sqlrauth.h>
#include <rudiments/charstring.h>

class defaultauth : public sqlrauth {
	public:
			defaultauth(xmldomnode *usersnode,
					sqlrpwdencs *sqlrpe);
		bool	authenticate(const char *user, const char *password);
	private:
		const char	**users;
		const char	**passwords;
		const char	**passwordencryptions;
		uint64_t	usercount;
};

defaultauth::defaultauth(xmldomnode *usersnode,
				sqlrpwdencs *sqlrpe) :
				sqlrauth(usersnode,sqlrpe) {

	users=NULL;
	passwords=NULL;
	passwordencryptions=NULL;
	usercount=usersnode->getChildCount();
	if (!usercount) {
		return;
	}

	// create an array of users and passwords and store the
	// users and passwords from the config file in them
	// this is faster than running through the xml over and over
	users=new const char *[usercount];
	passwords=new const char *[usercount];
	passwordencryptions=new const char *[usercount];

	xmldomnode *user=usersnode->getFirstTagChild("user");
	for (uint64_t i=0; i<usercount; i++) {

		users[i]=user->getAttributeValue("user");
		passwords[i]=user->getAttributeValue("password");
		passwordencryptions[i]=
			user->getAttributeValue("passwordencryption");

		user=user->getNextTagSibling("user");
	}
}

bool defaultauth::authenticate(const char *user, const char *password) {

	// run through the user/password arrays...
	for (uint32_t i=0; i<usercount; i++) {

		// if the user matches...
		if (!charstring::compare(user,users[i])) {

			if (sqlrpe &&
				charstring::length(passwordencryptions[i])) {

				// if password encryption is being used...

				// get the module
				sqlrpwdenc	*pe=
					sqlrpe->getPasswordEncryptionById(
							passwordencryptions[i]);
				if (!pe) {
					return false;
				}

				// For one-way encryption, encrypt the password
				// that was passed in and compare it to the
				// encrypted password in the config file.
				// For two-way encryption, decrypt the password
				// from the config file and compare ot to the
				// password that was passed in...

				bool	retval=false;
				char	*pwd=NULL;
				if (pe->oneWay()) {

					// encrypt the password
					// that was passed in
					pwd=pe->encrypt(password);

					// compare it to the encrypted
					// password from the config file
					retval=!charstring::compare(
							pwd,passwords[i]);

				} else {

					// decrypt the password
					// from the config file
					pwd=pe->decrypt(passwords[i]);

					// compare it to the password
					// that was passed in
					retval=!charstring::compare(
							password,pwd);
				}

				// clean up
				delete[] pwd;

				// return true/false
				return retval;

			} else {

				// if password encryption isn't being used,
				// return true if the passwords match
				return !charstring::compare(password,
								passwords[i]);
			}
		}
	}
	return false;
}

extern "C" {
	sqlrauth *new_default(xmldomnode *users, sqlrpwdencs *sqlrpe) {
		return new defaultauth(users,sqlrpe);
	}
}
