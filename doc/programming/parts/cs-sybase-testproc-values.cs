cur.prepareQuery("exec exampleproc");
cur.inputBind("in1", 1);
cur.inputBind("in2", 1.1, 2, 1);
cur.inputBind("in3", "hello");
cur.defineOutputBindInteger("out1");
cur.defineOutputBindDouble("out2");
cur.defineOutputBindString("out3", 20);
cur.executeQuery();
Int64 out1=cur.getOutputBindInteger("out1");
Double out2=cur.getOutputBindDouble("out2");
String out3=cur.getOutputBindString("out3");
