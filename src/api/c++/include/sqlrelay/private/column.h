// Copyright (c) 1999-2001  David Muse
// See the COPYING file for more information.

#ifndef COLUMN_H
#define COLUMN_H

class column {
	friend class sqlrcursor;
	private:
		char		*name;
		// these 3 should be made into a union
		unsigned short	type;
		char		*typestring;
		unsigned short	typestringlength;
		unsigned long	length;
		int		longest;
		unsigned char	longdatatype;
		unsigned long	precision;
		unsigned long	scale;
		unsigned short	nullable;
		unsigned short	primarykey;
		unsigned short	unique;
};

#endif
