// Copyright (c) 2001  David Muse
// See the file COPYING for more information.

import com.firstworks.sqlrelay.SQLRConnection;
import com.firstworks.sqlrelay.SQLRCursor;


class lago {
	
	
	
	
	
	
	private static void checkSuccess(String value, String success) {
	
		if (success==null) {
			if (value==null) {
				System.out.println("success ");
				return;
			} else {
				System.out.println("failure ");
				
				
				System.exit(0);
			}
		}
	
		if (value.equals(success)) {
			System.out.println("success ");
		} else {
			System.out.println("failure ");
			
			
			System.exit(0);
		}
	}
	
	private static void checkSuccess(long value, int success) {
	
		if (value==success) {
			System.out.println("success ");
		} else {
			System.out.println("failure ");
			
			
			System.exit(0);
		}
	}
	
	public static void	main(String[] args) {
	
		String	dbtype;
		String[]	subvars={"var1","var2","var3"};
		String[]	subvalstrings={"hi","hello","bye"};
		long[]	subvallongs={1,2,3};
		double[]	subvaldoubles={10.55,10.556,10.5556};
		int[]	precs={4,5,6};
		int[]	scales={2,3,4};
		String	numvar;
		String	stringvar;
		String	floatvar;
		String[]	cols;
		String[]	fields;
		int	port;
		String	socket;
		int	id;
		String	filename;
		long[]	fieldlens;
	
		// usage...
		if (args.length<5) {
			System.out.println("usage: java lago host port socket user password");
			System.exit(0);
		}
	
	
		// instantiation
		SQLRConnection con=new SQLRConnection(args[0],Integer.parseInt(args[1]), 
						args[2],args[3],args[4],0,1);
		SQLRCursor cur=new SQLRCursor(con);
	
		// get database type
		System.out.println("IDENTIFY: ");
		checkSuccess(con.identify(),"lago");
		System.out.println();
	
		// ping
		System.out.println("PING: ");
		checkSuccess(con.ping(),1);
		System.out.println();
	
		// drop existing table
		cur.sendQuery("drop table testtable");
	
		System.out.println("CREATE TEMPTABLE: ");
		checkSuccess(cur.sendQuery("create table testtable (testsmallint smallint, testint int, testfloat float, testdouble double, testdecimal decimal(1,1), testchar char(40), testvarchar varchar(40), testdate date, testtime time, testtimestamp timestamp)"),1);
		System.out.println();
	
		System.out.println("INSERT: ");
		checkSuccess(cur.sendQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (1,1,1.1,1.1,1.1,'testchar1','testvarchar1','20010101','010000')"),1);
		checkSuccess(cur.sendQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (2,2,2.1,2.1,2.1,'testchar2','testvarchar2','20020101','020000')"),1);
		checkSuccess(cur.sendQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (3,3,3.1,3.1,3.1,'testchar3','testvarchar3','20030101','030000')"),1);
		checkSuccess(cur.sendQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (4,4,4.1,4.1,4.1,'testchar4','testvarchar4','20040101','040000')"),1);
		System.out.println();
	
		System.out.println("AFFECTED ROWS: ");
		checkSuccess(cur.affectedRows(),-1);
		System.out.println();
	
		System.out.println("BIND BY NAME: ");
		cur.prepareQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (:var1,:var2,:var3,:var4,:var5,:var6,:var7,:var8,:var9)");
		cur.inputBind("var1",5);
		cur.inputBind("var2",5);
		cur.inputBind("var3",5.1,2,1);
		cur.inputBind("var4",5.1,2,1);
		cur.inputBind("var5",5.1,2,1);
		cur.inputBind("var6","testchar5");
		cur.inputBind("var7","testvarchar5");
		cur.inputBind("var8","20050101");
		cur.inputBind("var9","050000");
		checkSuccess(cur.executeQuery(),1);
		cur.clearBinds();
		cur.inputBind("var1",6);
		cur.inputBind("var2",6);
		cur.inputBind("var3",6.1,2,1);
		cur.inputBind("var4",6.1,2,1);
		cur.inputBind("var5",6.1,2,1);
		cur.inputBind("var6","testchar6");
		cur.inputBind("var7","testvarchar6");
		cur.inputBind("var8","20060101");
		cur.inputBind("var9","060000");
		checkSuccess(cur.executeQuery(),1);
		cur.clearBinds();
		cur.inputBind("var1",7);
		cur.inputBind("var2",7);
		cur.inputBind("var3",7.1,2,1);
		cur.inputBind("var4",7.1,2,1);
		cur.inputBind("var5",7.1,2,1);
		cur.inputBind("var6","testchar7");
		cur.inputBind("var7","testvarchar7");
		cur.inputBind("var8","20070101");
		cur.inputBind("var9","070000");
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("BIND BY NAME WITH VALIDATION: ");
		cur.clearBinds();
		cur.inputBind("var1",8);
		cur.inputBind("var2",8);
		cur.inputBind("var3",8.1,2,1);
		cur.inputBind("var4",8.1,2,1);
		cur.inputBind("var5",8.1,2,1);
		cur.inputBind("var6","testchar8");
		cur.inputBind("var7","testvarchar8");
		cur.inputBind("var8","20080101");
		cur.inputBind("var9","080000");
		cur.inputBind("var10","junkvalue");
		cur.validateBinds();
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("SELECT: ");
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		System.out.println();
	
		System.out.println("COLUMN COUNT: ");
		checkSuccess(cur.colCount(),10);
		System.out.println();
	
		System.out.println("COLUMN NAMES: ");
		checkSuccess(cur.getColumnName(0),"testsmallint");
		checkSuccess(cur.getColumnName(1),"testint");
		checkSuccess(cur.getColumnName(2),"testfloat");
		checkSuccess(cur.getColumnName(3),"testdouble");
		checkSuccess(cur.getColumnName(4),"testdecimal");
		checkSuccess(cur.getColumnName(5),"testchar");
		checkSuccess(cur.getColumnName(6),"testvarchar");
		checkSuccess(cur.getColumnName(7),"testdate");
		checkSuccess(cur.getColumnName(8),"testtime");
		checkSuccess(cur.getColumnName(9),"testtimestamp");
		cols=cur.getColumnNames();
		checkSuccess(cols[0],"testsmallint");
		checkSuccess(cols[1],"testint");
		checkSuccess(cols[2],"testfloat");
		checkSuccess(cols[3],"testdouble");
		checkSuccess(cols[4],"testdecimal");
		checkSuccess(cols[5],"testchar");
		checkSuccess(cols[6],"testvarchar");
		checkSuccess(cols[7],"testdate");
		checkSuccess(cols[8],"testtime");
		checkSuccess(cols[9],"testtimestamp");
		System.out.println();
	
		System.out.println("COLUMN TYPES: ");
		checkSuccess(cur.getColumnType(0),"SMALLINT");
		checkSuccess(cur.getColumnType("testsmallint"),"SMALLINT");
		checkSuccess(cur.getColumnType(1),"INT");
		checkSuccess(cur.getColumnType("testint"),"INT");
		checkSuccess(cur.getColumnType(2),"FLOAT");
		checkSuccess(cur.getColumnType("testfloat"),"FLOAT");
		checkSuccess(cur.getColumnType(3),"DOUBLE");
		checkSuccess(cur.getColumnType("testdouble"),"DOUBLE");
		checkSuccess(cur.getColumnType(4),"DOUBLE");
		checkSuccess(cur.getColumnType("testdecimal"),"DOUBLE");
		checkSuccess(cur.getColumnType(5),"CHAR");
		checkSuccess(cur.getColumnType("testchar"),"CHAR");
		checkSuccess(cur.getColumnType(6),"VARCHAR");
		checkSuccess(cur.getColumnType("testvarchar"),"VARCHAR");
		checkSuccess(cur.getColumnType(7),"DATE");
		checkSuccess(cur.getColumnType("testdate"),"DATE");
		checkSuccess(cur.getColumnType(8),"TIME");
		checkSuccess(cur.getColumnType("testtime"),"TIME");
		checkSuccess(cur.getColumnType(9),"TIMESTAMP");
		checkSuccess(cur.getColumnType("testtimestamp"),"TIMESTAMP");
		System.out.println();
	
		System.out.println("COLUMN LENGTH: ");
		checkSuccess(cur.getColumnLength(0),2);
		checkSuccess(cur.getColumnLength("testsmallint"),2);
		checkSuccess(cur.getColumnLength(1),4);
		checkSuccess(cur.getColumnLength("testint"),4);
		checkSuccess(cur.getColumnLength(2),4);
		checkSuccess(cur.getColumnLength("testfloat"),4);
		checkSuccess(cur.getColumnLength(3),8);
		checkSuccess(cur.getColumnLength("testdouble"),8);
		checkSuccess(cur.getColumnLength(4),8);
		checkSuccess(cur.getColumnLength("testdecimal"),8);
		checkSuccess(cur.getColumnLength(5),40);
		checkSuccess(cur.getColumnLength("testchar"),40);
		checkSuccess(cur.getColumnLength(6),40);
		checkSuccess(cur.getColumnLength("testvarchar"),40);
		checkSuccess(cur.getColumnLength(7),4);
		checkSuccess(cur.getColumnLength("testdate"),4);
		checkSuccess(cur.getColumnLength(8),4);
		checkSuccess(cur.getColumnLength("testtime"),4);
		checkSuccess(cur.getColumnLength(9),4);
		checkSuccess(cur.getColumnLength("testtimestamp"),4);
		System.out.println();
	
		System.out.println("LONGEST COLUMN: ");
		checkSuccess(cur.getLongest(0),1);
		checkSuccess(cur.getLongest("testsmallint"),1);
		checkSuccess(cur.getLongest(1),1);
		checkSuccess(cur.getLongest("testint"),1);
		checkSuccess(cur.getLongest(2),3);
		checkSuccess(cur.getLongest("testfloat"),3);
		checkSuccess(cur.getLongest(3),3);
		checkSuccess(cur.getLongest("testdouble"),3);
		checkSuccess(cur.getLongest(4),3);
		checkSuccess(cur.getLongest("testdecimal"),3);
		checkSuccess(cur.getLongest(5),40);
		checkSuccess(cur.getLongest("testchar"),40);
		checkSuccess(cur.getLongest(6),12);
		checkSuccess(cur.getLongest("testvarchar"),12);
		checkSuccess(cur.getLongest(7),11);
		checkSuccess(cur.getLongest("testdate"),11);
		checkSuccess(cur.getLongest(8),8);
		checkSuccess(cur.getLongest("testtime"),8);
		System.out.println();
	
		System.out.println("ROW COUNT: ");
		checkSuccess(cur.rowCount(),8);
		System.out.println();
	
		System.out.println("TOTAL ROWS: ");
		checkSuccess(cur.totalRows(),8);
		System.out.println();
	
		System.out.println("FIRST ROW INDEX: ");
		checkSuccess(cur.firstRowIndex(),0);
		System.out.println();
	
		System.out.println("END OF RESULT SET: ");
		checkSuccess(cur.endOfResultSet(),1);
		System.out.println();
	
		System.out.println("FIELDS BY INDEX: ");
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(0,1),"1");
		checkSuccess(cur.getField(0,2),"1.1");
		checkSuccess(cur.getField(0,3),"1.1");
		checkSuccess(cur.getField(0,4),"1.1");
		checkSuccess(cur.getField(0,5),"testchar1                               ");
		checkSuccess(cur.getField(0,6),"testvarchar1");
		checkSuccess(cur.getField(0,7)," 1-Jan-2001");
		checkSuccess(cur.getField(0,8),"01:00:00");
		System.out.println();
		checkSuccess(cur.getField(7,0),"8");
		checkSuccess(cur.getField(7,1),"8");
		checkSuccess(cur.getField(7,2),"8.1");
		checkSuccess(cur.getField(7,3),"8.1");
		checkSuccess(cur.getField(7,4),"8.1");
		checkSuccess(cur.getField(7,5),"testchar8                               ");
		checkSuccess(cur.getField(7,6),"testvarchar8");
		checkSuccess(cur.getField(7,7)," 1-Jan-2008");
		checkSuccess(cur.getField(7,8),"08:00:00");
		System.out.println();
	
		System.out.println("FIELD LENGTHS BY INDEX: ");
		checkSuccess(cur.getFieldLength(0,0),1);
		checkSuccess(cur.getFieldLength(0,1),1);
		checkSuccess(cur.getFieldLength(0,2),3);
		checkSuccess(cur.getFieldLength(0,3),3);
		checkSuccess(cur.getFieldLength(0,4),3);
		checkSuccess(cur.getFieldLength(0,5),40);
		checkSuccess(cur.getFieldLength(0,6),12);
		checkSuccess(cur.getFieldLength(0,7),11);
		checkSuccess(cur.getFieldLength(0,8),8);
		System.out.println();
		checkSuccess(cur.getFieldLength(7,0),1);
		checkSuccess(cur.getFieldLength(7,1),1);
		checkSuccess(cur.getFieldLength(7,2),3);
		checkSuccess(cur.getFieldLength(7,3),3);
		checkSuccess(cur.getFieldLength(7,4),3);
		checkSuccess(cur.getFieldLength(7,5),40);
		checkSuccess(cur.getFieldLength(7,6),12);
		checkSuccess(cur.getFieldLength(7,7),11);
		checkSuccess(cur.getFieldLength(7,8),8);
		System.out.println();
	
		System.out.println("FIELDS BY NAME: ");
		checkSuccess(cur.getField(0,"testint"),"1");
		checkSuccess(cur.getField(0,"testsmallint"),"1");
		checkSuccess(cur.getField(0,"testfloat"),"1.1");
		checkSuccess(cur.getField(0,"testdouble"),"1.1");
		checkSuccess(cur.getField(0,"testdecimal"),"1.1");
		checkSuccess(cur.getField(0,"testchar"),"testchar1                               ");
		checkSuccess(cur.getField(0,"testvarchar"),"testvarchar1");
		checkSuccess(cur.getField(0,"testdate")," 1-Jan-2001");
		checkSuccess(cur.getField(0,"testtime"),"01:00:00");
		System.out.println();
		checkSuccess(cur.getField(7,"testint"),"8");
		checkSuccess(cur.getField(7,"testsmallint"),"8");
		checkSuccess(cur.getField(7,"testfloat"),"8.1");
		checkSuccess(cur.getField(7,"testdouble"),"8.1");
		checkSuccess(cur.getField(7,"testdecimal"),"8.1");
		checkSuccess(cur.getField(7,"testchar"),"testchar8                               ");
		checkSuccess(cur.getField(7,"testvarchar"),"testvarchar8");
		checkSuccess(cur.getField(7,"testdate")," 1-Jan-2008");
		checkSuccess(cur.getField(7,"testtime"),"08:00:00");
		System.out.println();
	
		System.out.println("FIELD LENGTHS BY NAME: ");
		checkSuccess(cur.getFieldLength(0,"testint"),1);
		checkSuccess(cur.getFieldLength(0,"testsmallint"),1);
		checkSuccess(cur.getFieldLength(0,"testfloat"),3);
		checkSuccess(cur.getFieldLength(0,"testdouble"),3);
		checkSuccess(cur.getFieldLength(0,"testdecimal"),3);
		checkSuccess(cur.getFieldLength(0,"testchar"),40);
		checkSuccess(cur.getFieldLength(0,"testvarchar"),12);
		checkSuccess(cur.getFieldLength(0,"testdate"),11);
		checkSuccess(cur.getFieldLength(0,"testtime"),8);
		System.out.println();
		checkSuccess(cur.getFieldLength(7,"testint"),1);
		checkSuccess(cur.getFieldLength(7,"testsmallint"),1);
		checkSuccess(cur.getFieldLength(7,"testfloat"),3);
		checkSuccess(cur.getFieldLength(7,"testdouble"),3);
		checkSuccess(cur.getFieldLength(7,"testdecimal"),3);
		checkSuccess(cur.getFieldLength(7,"testchar"),40);
		checkSuccess(cur.getFieldLength(7,"testvarchar"),12);
		checkSuccess(cur.getFieldLength(7,"testdate"),11);
		checkSuccess(cur.getFieldLength(7,"testtime"),8);
		System.out.println();
	
		System.out.println("FIELDS BY ARRAY: ");
		fields=cur.getRow(0);
		checkSuccess(fields[0],"1");
		checkSuccess(fields[1],"1");
		checkSuccess(fields[2],"1.1");
		checkSuccess(fields[3],"1.1");
		checkSuccess(fields[4],"1.1");
		checkSuccess(fields[5],"testchar1                               ");
		checkSuccess(fields[6],"testvarchar1");
		checkSuccess(fields[7]," 1-Jan-2001");
		checkSuccess(fields[8],"01:00:00");
		System.out.println();
	
		System.out.println("FIELD LENGTHS BY ARRAY: ");
		fieldlens=cur.getRowLengths(0);
		checkSuccess(fieldlens[0],1);
		checkSuccess(fieldlens[1],1);
		checkSuccess(fieldlens[2],3);
		checkSuccess(fieldlens[3],3);
		checkSuccess(fieldlens[4],3);
		checkSuccess(fieldlens[5],40);
		checkSuccess(fieldlens[6],12);
		checkSuccess(fieldlens[7],11);
		checkSuccess(fieldlens[8],8);
		System.out.println();
	
		System.out.println("INDIVIDUAL SUBSTITUTIONS: ");
		cur.sendQuery("drop table testtable1");
		checkSuccess(cur.sendQuery("create table testtable1 (col1 int, col2 varchar(40), col3 real)"),1);
		cur.prepareQuery("insert into testtable1 (col1, col2, col3) values ($(var1),'$(var2)',$(var3))");
		cur.substitution("var1",1);
		cur.substitution("var2","hello");
		cur.substitution("var3",10.5556,6,4);
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("FIELDS: ");
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(0,1),"hello");
		checkSuccess(cur.getField(0,2),"10.5556");
		checkSuccess(cur.sendQuery("delete from testtable1"),1);
		System.out.println();
	
		System.out.println("ARRAY SUBSTITUTIONS: ");
		cur.sendQuery("drop table testtable1");
		cur.sendQuery("create table testtable1 (col1 char(2), col2 char(5), col3 char(3))");
		cur.prepareQuery("insert into testtable1 (col1, col2, col3) values ('$(var1)','$(var2)','$(var3)')");
		cur.substitutions(subvars,subvalstrings);
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("FIELDS: ");
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"hi");
		checkSuccess(cur.getField(0,1),"hello");
		checkSuccess(cur.getField(0,2),"bye");
		System.out.println();
	
		System.out.println("ARRAY SUBSTITUTIONS: ");
		cur.sendQuery("drop table testtable1");
		cur.sendQuery("create table testtable1 (col1 int, col2 int, col3 int)");
		cur.prepareQuery("insert into testtable1 (col1, col2, col3) values ($(var1),$(var2),$(var3))");
		cur.substitutions(subvars,subvallongs);
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("FIELDS: ");
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(0,1),"2");
		checkSuccess(cur.getField(0,2),"3");
		System.out.println();
	
		System.out.println("ARRAY SUBSTITUTIONS: ");
		cur.sendQuery("drop table testtable1");
		cur.sendQuery("create table testtable1 (col1 real, col2 real, col3 real)");
		cur.prepareQuery("insert into testtable1 (col1, col2, col3) values ($(var1),$(var2),$(var3))");
		cur.substitutions(subvars,subvaldoubles,precs,scales);
		checkSuccess(cur.executeQuery(),1);
		System.out.println();
	
		System.out.println("FIELDS: ");
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"10.55");
		checkSuccess(cur.getField(0,1),"10.556");
		checkSuccess(cur.getField(0,2),"10.5556");
		checkSuccess(cur.sendQuery("delete from testtable1"),1);
		System.out.println();
	
		System.out.println("nullS as Nulls: ");
		cur.sendQuery("drop table testtable1");
		cur.sendQuery("create table testtable1 (col1 char(1), col2 char(1), col3 char(1))");
		cur.getNullsAsNulls();
		checkSuccess(cur.sendQuery("insert into testtable1 (col1, col2, col3) values ('1',null,null)"),1);
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(0,1),null);
		checkSuccess(cur.getField(0,2),null);
		cur.getNullsAsEmptyStrings();
		checkSuccess(cur.sendQuery("select * from testtable1"),1);
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(0,1),"");
		checkSuccess(cur.getField(0,2),"");
		checkSuccess(cur.sendQuery("drop table testtable1"),1);
		System.out.println();
	
		System.out.println("RESULT SET BUFFER SIZE: ");
		checkSuccess(cur.getResultSetBufferSize(),0);
		cur.setResultSetBufferSize(2);
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getResultSetBufferSize(),2);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),0);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),2);
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(1,0),"2");
		checkSuccess(cur.getField(2,0),"3");
		System.out.println();
		checkSuccess(cur.firstRowIndex(),2);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),4);
		checkSuccess(cur.getField(6,0),"7");
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
		checkSuccess(cur.firstRowIndex(),6);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),8);
		checkSuccess(cur.getField(8,0),null);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),8);
		checkSuccess(cur.endOfResultSet(),1);
		checkSuccess(cur.rowCount(),8);
		System.out.println();
	
		System.out.println("DONT GET COLUMN INFO: ");
		cur.dontGetColumnInfo();
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getColumnName(0),null);
		checkSuccess(cur.getColumnLength(0),0);
		checkSuccess(cur.getColumnType(0),null);
		cur.getColumnInfo();
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getColumnName(0),"testsmallint");
		checkSuccess(cur.getColumnLength(0),2);
		checkSuccess(cur.getColumnType(0),"SMALLINT");
		System.out.println();
	
		System.out.println("SUSPENDED SESSION: ");
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		checkSuccess(con.resumeSession(port,socket),1);
		System.out.println();
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(1,0),"2");
		checkSuccess(cur.getField(2,0),"3");
		checkSuccess(cur.getField(3,0),"4");
		checkSuccess(cur.getField(4,0),"5");
		checkSuccess(cur.getField(5,0),"6");
		checkSuccess(cur.getField(6,0),"7");
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		checkSuccess(con.resumeSession(port,socket),1);
		System.out.println();
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(1,0),"2");
		checkSuccess(cur.getField(2,0),"3");
		checkSuccess(cur.getField(3,0),"4");
		checkSuccess(cur.getField(4,0),"5");
		checkSuccess(cur.getField(5,0),"6");
		checkSuccess(cur.getField(6,0),"7");
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		checkSuccess(con.resumeSession(port,socket),1);
		System.out.println();
		checkSuccess(cur.getField(0,0),"1");
		checkSuccess(cur.getField(1,0),"2");
		checkSuccess(cur.getField(2,0),"3");
		checkSuccess(cur.getField(3,0),"4");
		checkSuccess(cur.getField(4,0),"5");
		checkSuccess(cur.getField(5,0),"6");
		checkSuccess(cur.getField(6,0),"7");
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
	
		System.out.println("SUSPENDED RESULT SET: ");
		cur.setResultSetBufferSize(2);
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getField(2,0),"3");
		id=cur.getResultSetId();
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		checkSuccess(con.resumeSession(port,socket),1);
		checkSuccess(cur.resumeResultSet(id),1);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),4);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),6);
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
		checkSuccess(cur.firstRowIndex(),6);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),8);
		checkSuccess(cur.getField(8,0),null);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),8);
		checkSuccess(cur.endOfResultSet(),1);
		checkSuccess(cur.rowCount(),8);
		cur.setResultSetBufferSize(0);
		System.out.println();
	
		System.out.println("CACHED RESULT SET: ");
		cur.cacheToFile("cachefile1");
		cur.setCacheTtl(200);
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		filename=cur.getCacheFileName();
		checkSuccess(filename,"cachefile1");
		cur.cacheOff();
		checkSuccess(cur.openCachedResultSet(filename),1);
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
	
		System.out.println("COLUMN COUNT FOR CACHED RESULT SET: ");
		checkSuccess(cur.colCount(),10);
		System.out.println();
	
		System.out.println("COLUMN NAMES FOR CACHED RESULT SET: ");
		checkSuccess(cur.getColumnName(0),"testsmallint");
		checkSuccess(cur.getColumnName(1),"testint");
		checkSuccess(cur.getColumnName(2),"testfloat");
		checkSuccess(cur.getColumnName(3),"testdouble");
		checkSuccess(cur.getColumnName(4),"testdecimal");
		checkSuccess(cur.getColumnName(5),"testchar");
		checkSuccess(cur.getColumnName(6),"testvarchar");
		checkSuccess(cur.getColumnName(7),"testdate");
		checkSuccess(cur.getColumnName(8),"testtime");
		checkSuccess(cur.getColumnName(9),"testtimestamp");
		cols=cur.getColumnNames();
		checkSuccess(cols[0],"testsmallint");
		checkSuccess(cols[1],"testint");
		checkSuccess(cols[2],"testfloat");
		checkSuccess(cols[3],"testdouble");
		checkSuccess(cols[4],"testdecimal");
		checkSuccess(cols[5],"testchar");
		checkSuccess(cols[6],"testvarchar");
		checkSuccess(cols[7],"testdate");
		checkSuccess(cols[8],"testtime");
		checkSuccess(cols[9],"testtimestamp");
		System.out.println();
	
		System.out.println("CACHED RESULT SET WITH RESULT SET BUFFER SIZE: ");
		cur.setResultSetBufferSize(2);
		cur.cacheToFile("cachefile1");
		cur.setCacheTtl(200);
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		filename=cur.getCacheFileName();
		checkSuccess(filename,"cachefile1");
		cur.cacheOff();
		checkSuccess(cur.openCachedResultSet(filename),1);
		checkSuccess(cur.getField(7,0),"8");
		checkSuccess(cur.getField(8,0),null);
		cur.setResultSetBufferSize(0);
		System.out.println();
	
		System.out.println("FROM ONE CACHE FILE TO ANOTHER: ");
		cur.cacheToFile("cachefile2");
		checkSuccess(cur.openCachedResultSet("cachefile1"),1);
		cur.cacheOff();
		checkSuccess(cur.openCachedResultSet("cachefile2"),1);
		checkSuccess(cur.getField(7,0),"8");
		checkSuccess(cur.getField(8,0),null);
		System.out.println();
	
		System.out.println("FROM ONE CACHE FILE TO ANOTHER WITH RESULT SET BUFFER SIZE: ");
		cur.setResultSetBufferSize(2);
		cur.cacheToFile("cachefile2");
		checkSuccess(cur.openCachedResultSet("cachefile1"),1);
		cur.cacheOff();
		checkSuccess(cur.openCachedResultSet("cachefile2"),1);
		checkSuccess(cur.getField(7,0),"8");
		checkSuccess(cur.getField(8,0),null);
		cur.setResultSetBufferSize(0);
		System.out.println();
	
		System.out.println("CACHED RESULT SET WITH SUSPEND AND RESULT SET BUFFER SIZE: ");
		cur.setResultSetBufferSize(2);
		cur.cacheToFile("cachefile1");
		cur.setCacheTtl(200);
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getField(2,0),"3");
		filename=cur.getCacheFileName();
		checkSuccess(filename,"cachefile1");
		id=cur.getResultSetId();
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		System.out.println();
		checkSuccess(con.resumeSession(port,socket),1);
		checkSuccess(cur.resumeCachedResultSet(id,filename),1);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),4);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),6);
		checkSuccess(cur.getField(7,0),"8");
		System.out.println();
		checkSuccess(cur.firstRowIndex(),6);
		checkSuccess(cur.endOfResultSet(),0);
		checkSuccess(cur.rowCount(),8);
		checkSuccess(cur.getField(8,0),null);
		System.out.println();
		checkSuccess(cur.firstRowIndex(),8);
		checkSuccess(cur.endOfResultSet(),1);
		checkSuccess(cur.rowCount(),8);
		cur.cacheOff();
		System.out.println();
		checkSuccess(cur.openCachedResultSet(filename),1);
		checkSuccess(cur.getField(7,0),"8");
		checkSuccess(cur.getField(8,0),null);
		cur.setResultSetBufferSize(0);
		System.out.println();
	
		System.out.println("COMMIT AND ROLLBACK: ");
		SQLRConnection secondcon=new SQLRConnection(args[0],Integer.parseInt(args[1]), 
						args[2],args[3],args[4],0,1);
		SQLRCursor secondcur=new SQLRCursor(secondcon);
		checkSuccess(secondcur.sendQuery("select * from testtable"),1);
		checkSuccess(secondcur.getField(0,0),"1");
		checkSuccess(con.commit(),1);
		checkSuccess(secondcur.sendQuery("select * from testtable"),1);
		checkSuccess(secondcur.getField(0,0),"1");
		checkSuccess(con.autoCommitOn(),1);
		checkSuccess(cur.sendQuery("insert into testtable (testsmallint, testint, testfloat, testdouble, testdecimal, testchar, testvarchar, testdate, testtime) values (10,10,10.1,10.1,10.1,'testchar10','testvarchar10','20100101','100000')"),1);
		checkSuccess(secondcur.sendQuery("select * from testtable"),1);
		checkSuccess(secondcur.getField(8,0),"10");
		checkSuccess(con.autoCommitOff(),1);
		System.out.println();

		System.out.println("FINISHED SUSPENDED SESSION: ");
		checkSuccess(cur.sendQuery("select * from testtable"),1);
		checkSuccess(cur.getField(4,0),"5");
		checkSuccess(cur.getField(5,0),"6");
		checkSuccess(cur.getField(6,0),"7");
		checkSuccess(cur.getField(7,0),"8");
		id=cur.getResultSetId();
		cur.suspendResultSet();
		checkSuccess(con.suspendSession(),1);
		port=con.getConnectionPort();
		socket=con.getConnectionSocket();
		checkSuccess(con.resumeSession(port,socket),1);
		checkSuccess(cur.resumeResultSet(id),1);
		checkSuccess(cur.getField(4,0),null);
		checkSuccess(cur.getField(5,0),null);
		checkSuccess(cur.getField(6,0),null);
		checkSuccess(cur.getField(7,0),null);
		System.out.println();
	
		// drop existing table
		cur.sendQuery("drop table testtable");
	
		// invalid queries...
		System.out.println("INVALID QUERIES: ");
		checkSuccess(cur.sendQuery("select * from testtable"),0);
		checkSuccess(cur.sendQuery("select * from testtable"),0);
		checkSuccess(cur.sendQuery("select * from testtable"),0);
		checkSuccess(cur.sendQuery("select * from testtable"),0);
		System.out.println();
		checkSuccess(cur.sendQuery("insert into testtable values (1,2,3,4)"),0);
		checkSuccess(cur.sendQuery("insert into testtable values (1,2,3,4)"),0);
		checkSuccess(cur.sendQuery("insert into testtable values (1,2,3,4)"),0);
		checkSuccess(cur.sendQuery("insert into testtable values (1,2,3,4)"),0);
		System.out.println();
		checkSuccess(cur.sendQuery("create table testtable"),0);
		checkSuccess(cur.sendQuery("create table testtable"),0);
		checkSuccess(cur.sendQuery("create table testtable"),0);
		checkSuccess(cur.sendQuery("create table testtable"),0);
		System.out.println();
	}
}
