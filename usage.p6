use v6;
use Test;
plan *;

sub USAGE ($sub=&MAIN) {
	my @help-msgs;
	if ($sub ~~ Multi ) {
		for $sub.candidates -> $single {
			@help-msgs.push( USAGE-one-sub ($single) );
		}
	} else {
		@help-msgs.push( USAGE-one-sub ($sub) );
	}
	return  "Usage\n" ~ @help-msgs.join("\nor\n");
}
sub USAGE-one-sub ($sub=&MAIN) {
	my $sig = $sub.signature;
	my @arguments;
	for $sig.params -> $param {
		my $argument;
		if ($param.named) {
			$argument = "--"
					~ $param.name.substr(1)
					~ ($param.type ~~ Bool ?? '' !! "=value-of-{$param.name.substr(1)}")
					;
		} else {
			$argument = $param.name.substr(1);
			if ($param.slurpy) {
				$argument ~= " [more [...]]";
			}
		}
		$argument = "[$argument]" if $param.optional;
		@arguments.push($argument);
	}

	return  $*PROGRAM_NAME ~ ' '  ~ @arguments.join(' ');

}

my $common = "Usage\n$*PROGRAM_NAME";

sub MAIN($first,$second) {...}
is( USAGE() , "$common first second" , 'By default we introspect MAIN');

my $main ;
$main = sub ($first?) {...}
is( USAGE($main) , "$common [first]" , 'Optional');

$main = sub (:$named) {...}
is( USAGE($main) , "$common [--named=value-of-named]" , 'named optional');

$main = sub (:$named!) {...}
is( USAGE($main) , "$common --named=value-of-named" , 'named mandatory');

$main = sub (Bool :$named) {...}
is( USAGE($main) , "$common [--named]" , 'Bool optional');

$main = sub (Bool :$named!) {...}
is( USAGE($main) , "$common --named" , 'Bool mandatory');

$main = sub (*@files) {...}
is( USAGE($main) , "$common files [more [...]]" , 'Slurpy shows "more"');

$main = sub ($first, *@rest, Bool :$verbose, :$outfile) {...}
is( USAGE($main) , "$common first rest [more [...]] [--verbose] [--outfile=value-of-outfile]" , 'Mix of params');

multi sub MULTIMAIN($first,$second) {...}
multi sub MULTIMAIN($first, Bool :$verbose, :$outfile) {...}
is( USAGE(&MULTIMAIN) , "$common first second\nor\n$*PROGRAM_NAME first [--verbose] [--outfile=value-of-outfile]" , 'Multi sub test');


done_testing();