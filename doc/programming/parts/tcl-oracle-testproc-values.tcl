$cur prepareQuery "begin testproc(:in1,:in2,:in3,:out1,:out2,:out3); end;"
$cur inputBind "in1" 1
$cur inputBind "in2" 1.1 2 1
$cur inputBind "in3" "hello"
$cur defineOutputBindInteger "out1"
$cur defineOutputBindDouble "out2"
$cur defineOutputBindString "out3" 20
$cur executeQuery
set out1 [$cur getOutputBindInteger "out1"]
set out2 [$cur getOutputBindDouble "out2"]
set out3 [$cur getOutputBindString "out3"]
