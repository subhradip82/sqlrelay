my $sth=$dbh->prepare("execute procedure exampleproc ?, ?, ?");
$sth->bind_param("1",1);
$sth->bind_param("2",1.1,2,1);
$sth->bind_param("3","hello");
my $out1;
my $out2;
my $out3;
$sth->bind_inout_param("1",\$out1,20);
$sth->bind_inout_param("2",\$out2,20);
$sth->bind_inout_param("3",\$out3,20);
$sth->execute();
