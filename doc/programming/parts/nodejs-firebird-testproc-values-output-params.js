cur.prepareQuery("execute procedure testproc ?, ?, ?");
cur.inputBind("1",1);
cur.inputBind("2",1.1,2,1);
cur.inputBind("3","hello");
cur.defineOutputBindInteger("1");
cur.defineOutputBindDouble("2");
cur.defineOutputBindString("3",20);
cur.executeQuery();
var     out1=cur.getOutputBindInteger("1");
var     out2=cur.getOutputBindDouble("2");
var     out3=cur.getOutputBindString("3");
