using System;
using SQLRClient;

namespace SQLRExamples
{
	class SQLRExample
	{
		public static void Main()
		{
			... get the filename from the previous page ...

        		... get the page to display from the previous page ...

			SQLRConnection con = new SQLRConnection("sqlrserver", 9000, "/tmp/example.socket", "user", "password", 0, 1);
			SQLRCursor cur = new SQLRCursor(con);

        		cur.openCachedResultSet(filename);
        		con.endSession();

        		for (UInt64 row=pagetodisplay*20; row&lt;(pagetodisplay+1)*20; row++)
			{
                		for (UInt32 col=0; col&lt;cur.colCount(); col++)
				{
                        		Console.Write(cur.getField(row,col));
					Console.Write(",");
                		}
				Console.Write("\n");
        		}
		}
	}
}
