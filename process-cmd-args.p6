use v6;
use Test;

sub same-but-false ($what) {
	if $what ~~ Bool { return False };
	my $c = class {
		has $.orig;
		method Bool {return False};
		method Str {return $.orig};
		method Array {return $.orig};
	};
	return $c.new(orig=>$what);
}

sub process-cmd-args(@args, %named) {
	my (@positional-arguments, %named-arguments , $negate);
	while ( @args )  {
		my $passed_value = @args.shift;
		if substr($passed_value,0,2) eq '--' {
			my $arg = $passed_value.substr(2);
			if $arg.match(/^\//) { 
				$arg .= substr(1) ;
				$negate = $arg;
			}
			
			if $arg eq '' {
				@positional-arguments.push: @args;
				last;
			} elsif %named{$arg} ~~ Bool {
				%named-arguments{$arg}=True;
			} elsif %named{$arg} ~~ Array || ($passed_value.match( /\=/ ) &&  %named{$arg.split('=', 2)[0]} ~~ Array ) { 
				if $passed_value.match( /\=/ ) {
					my ($name , $value) = $arg.split('=', 2);
					if $negate {$negate=$name;} 
					%named-arguments{$name} = [$value.split(',')];
				} else {
					%named-arguments{$arg} = [@args.shift.split(',')];
				}
			} elsif $passed_value.match( /\=/ ) {
				my ($name , $value) = $arg.split('=', 2);
				if $negate {$negate=$name;} 
				if ($value.match(/^\'.*\'$/) || $value.match(/^\".*\"$/) ) {
					%named-arguments{$name} = $value.substr(1,-1);
				} elsif $value.match( /.\,./ ) { #--separator=, should not be an array by default but --values=1,2,3 should be
					%named-arguments{$name} = [$value.split(',')];
				} else {
					%named-arguments{$name} = $value;
				}
			} elsif $negate {
				%named-arguments{$arg} = False; 
				$negate='';
			} else {
				%named-arguments{$arg}=@args.shift;
			}
		} else {
			@positional-arguments.push: $passed_value;
		}

		if $negate {
			%named-arguments{$negate} = same-but-false( %named-arguments{$negate} );
			$negate = '';
		}
	}

    return @positional-arguments, %named-arguments;
}


plan *;

#Examples from the weekly contribution

is( process-cmd-args(<--verbose=2 /etc/password pw1 pw2 pw3>, {})
	, (</etc/password pw1 pw2 pw3> , {verbose=>2})
	, '--verbose=2 /etc/password pw1 pw2 pw3');

is( process-cmd-args(['--myname=23'], {})
	, (() , {myname=>'23'})
	, '--myname=23');

is( process-cmd-args(<--myoption foo>, {})
	, (() , {myoption=>'foo'})
	, '--myoption foo');

is( process-cmd-args(<--myoption foo>, {myoption=>Bool})
	, (<foo> , {myoption=>True})
	, '--myoption foo having myoption=>Bool');

is( process-cmd-args(<a b c d e>, {})
	, (<a b c d e> , {})
	, '<a b c d e>');

# after a -- the rest is considered positional arguments

is( process-cmd-args(<a -- --bcde f g>, {}),
        (<a --bcde f g>, {}),
        'after -- nothing is considered a switch');

#Spec examples:
is( process-cmd-args(['--name'], {name=>Bool})
	, ((), {name=>Bool::True})
	, '--name                     :name            # only if declared Bool');

is( process-cmd-args(['--name=value'], {name=>Bool})
	, ((), {name=>'value'})
	, "--name=value               :name<value>     # don't care (Bool)");

is( process-cmd-args(['--name=value'], {})
	, ((), {name=>'value'})
	, "--name=value               :name<value>     # don't care (not Bool)");

is( process-cmd-args(['--name', 'value'], {})
	, ((), {name=>'value'})
	, "--name value               :name<value>     # only if not declared Bool (not declared Bool)");

ok( process-cmd-args(['--name', 'value'], {name=>Bool}) !~~ process-cmd-args(['--name', 'value'], {})
	, "--name value               :name<value>     # only if not declared Bool (declared Bool different result)");

#Spacey values
is( process-cmd-args(['--name="spacey value"'], {})
	, ((), {name=>'spacey value'})
	, qq{--name="spacey value"      :name«'spacey value'»});

is( process-cmd-args(["--name='spacey value'"], {})
	, process-cmd-args(['--name="spacey value"'], {})
	, qq{--name='spacey value'      :name«'spacey value'»});

#Array options
is( process-cmd-args(['--name=val1'], {myoption=>Array})
	, (() , {name=>['val1']})
	, '--name=val1 having name=>Array');

is( process-cmd-args(['--name=val1,val2'], {name=>Array})
	, (() , {name=>['val1','val2']})
	, '--name=val1,val2 having name=>Array');

is( process-cmd-args(['--separator=,'], {})
	, (() , {separator=>','})
	, '--separator=, having separator not specified as array');

is( process-cmd-args(['--name=val1,val2'], {})
	, (() , {name=>['val1','val2']})
	, '--name=val1,val2 having name not specified as array');

is( process-cmd-args(['--name', 'val1,val2'], {name=>Array})
	, (() , {name=>['val1','val2']})
	, '--name val1,val2 having name specified as array');

skip {
is( process-cmd-args(["--name=val1,'val 2',etc"], {})
	, ((), {name=>("val1", "val 2", "etc")})
	, "--name=val1,'val 2',etc    :name«val1 'val 2' etc»");
}

skip {
is( process-cmd-args(["--name=val1", "'val 2'", "etc"], {name=>Array})
	, ((), {name=>("val1", "val 2", "etc")})
	, "--name val1 'val 2' etc    :name«val1 'val 2' etc» # only if declared @ (Declared Array)");
}

ok( process-cmd-args(["--name=val1", "'val 2'", "etc"], {})
	!~~ process-cmd-args(["--name=val1", "'val 2'", "etc"], {name=>Array})
	, "--name val1 'val 2' etc    :name«val1 'val 2' etc» # only if declared @ (not declared Array)");

is( process-cmd-args(["--name=val1", "val2", "etc"], {})
	, (('val2','etc'), {name=>"val1"})
	, "--name val1 'val 2' etc    :name<val1>  # when not declared Array)");

#Negation
is( process-cmd-args(['--/name'], {name=>Bool})
	, ((), {name=>Bool::False})
	, '--/name                    :!name');

is( process-cmd-args(['--/name'], {})
	, ((), {name=>Bool::False})
	, '--/name                    :!name');

my (@positional , %named);

@positional = process-cmd-args(['--/name=value'], {});
%named = @positional.pop;
is( @positional     , ()       , '--/name=value              :name<value> but False (no positional)');
is( ~%named<name>  , 'value' , '--/name=value              :name<value> but False (Got value)');
is( !!%named<name> , False     , '--/name=value              :name<value> but False (Got False) ');

@positional = process-cmd-args(['--/name=value','--/name2=value2'], {});
%named = @positional.pop;
is( @positional     , ()       , '--/name=value --/name2=value2   (no positional)');
is( ~%named<name>  , 'value' , '--/name=value --/name2=value2   :name<value> but False (Got value)');
is( !!%named<name> , False     , '--/name=value --/name2=value2   :name<value> but False (Got False) ');
is( ~%named<name2>  , 'value2' , '--/name=value --/name2=value2   :name<value2> but False (Got value)');
is( !!%named<name2> , False     , '--/name=value --/name2=value2   :name<value2> but False (Got False) ');

@positional = process-cmd-args(['--/name="spacey value"'], {});
%named = @positional.pop;
is( @positional     , ()       , '--/name="spacey value"     :name«\'spacey value\'» but False (no positional)');
is( ~%named<name>  , 'spacey value' , '--/name="spacey value"     :name«\'spacey value\'» but False (Got spacey value)');
is( !!%named<name> , False     , '--/name="spacey value"     :name«\'spacey value\'» but False (Got False) ');

@positional = process-cmd-args(["--/name='spacey value'"], {});
%named = @positional.pop;
is( @positional     , ()       , '--/name=\'spacey value\'     :name«\'spacey value\'» but False (no positional)');
is( ~%named<name>  , 'spacey value' , '--/name=\'spacey value\'     :name«\'spacey value\'» but False (Got spacey value)');
is( !!%named<name> , False     , '--/name=\'spacey value\'     :name«\'spacey value\'» but False (Got False) ');



done_testing();
=begin pod
	Things to support eventually:
    # Short names
    -n                         :name
    -n=value                   :name<value>
    -nvalue                    :name<value>     # only if not declared Bool
    -n="spacey value"          :name«'spacey value'»
    -n='spacey value'          :name«'spacey value'»
    -n=val1,'val 2',etc        :name«val1 'val 2' etc»
     # Long names
    --name                     :name            # only if declared Bool
    --name=value               :name<value>     # don't care
    --name value               :name<value>     # only if not declared Bool
     --name="spacey value"      :name«'spacey value'»
    --name "spacey value"      :name«'spacey value'» (SKIP: Needs more clarification)
    --name='spacey value'      :name«'spacey value'»
    --name 'spacey value'      :name«'spacey value'» (SKIP: Needs more clarification)
    --name=val1,'val 2',etc    :name«val1 'val 2' etc»
    --name val1 'val 2' etc    :name«val1 'val 2' etc» # only if declared @
    --                                          # end named argument processing
     # Negation
    --/name                    :!name
    --/name=value              :name<value> but False
    --/name="spacey value"     :name«'spacey value'» but False
    --/name='spacey value'     :name«'spacey value'» but False
    --/name=val1,'val 2',etc   :name«val1 'val 2' etc» but False
     # Native
    :name                      :name
    :/name                     :!name
    :name=value                :name<value>
    :name="spacey value"       :name«'spacey value'»
    :name='spacey value'       :name«'spacey value'»
    :name=val1,'val 2',etc     :name«val1 'val 2' etc»

=end pod


# infrastructure code for loading sub MAIN
# (not part of the challenge :-)

sub MAIN($first, *@rest, Bool :$verbose, :$outfile) {
    say "first: $first.perl()";
    say "rest:  @rest.perl()";
    say "named: verbose: $verbose.perl()";
    say "named: outfile: $outfile.perl()";
}

sub run-it($main) {
    my @named-params = $main.signature.params.grep: {.named && .type ~~ Bool};
    # the name still has a sigil, ie it's '$verbose', not 'verbose'
    my %named-params = @named-params».name».substr(1) Z=> @named-params».type;

    {
        my @*ARGS = <--verbose a b --outfile foo c d e>;
        my @positional = process-cmd-args(@*ARGS, %named-params);
        my %named = @positional.pop;
        $main(|@positional, |%named);
    }

}

# uncomment to actually run it
# run-it(&MAIN);

# vim: ft=perl6
