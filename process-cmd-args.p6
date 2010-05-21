use v6;
use Test;

sub process-cmd-args(@args, %boolean-names) {
	my (@positional-arguments, %named-arguments);
	my $looking_for;
	for @args -> $passed_value {
		if $looking_for {
			%named-arguments{$looking_for}=$passed_value;
			$looking_for='';

		} elsif substr($passed_value,0,2) eq '--' {

			my $arg = $passed_value.substr(2);
			if %boolean-names{$arg} {
				%named-arguments{$arg}=True;
			} elsif $passed_value.match( /\=/ ) {
				my @parts = $arg.split('=', 2);
				%named-arguments{@parts[0]} = @parts[1];
			} else {
				$looking_for=$arg;
			}

		} else {
			@positional-arguments.push: $passed_value;
		}
	}

	if $looking_for {
		%named-arguments{$looking_for} = '';
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

is( process-cmd-args(<--myoption foo>, {myoption=>'Bool'})
	, (<foo> , {myoption=>True})
	, '--myoption foo having myoption=>Bool');

is( process-cmd-args(<a b c d e>, {})
	, (<a b c d e> , {})
	, '<a b c d e>');

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
    --name "spacey value"      :name«'spacey value'»
    --name='spacey value'      :name«'spacey value'»
    --name 'spacey value'      :name«'spacey value'»
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
    my @named-bool = $main.signature.params.grep: {.named && .type ~~ Bool};
    # the name still has a sigil, ie it's '$verbose', not 'verbose'
    my %named-bool = @named-bool».name».substr(1) Z=> (1 xx +@named-bool);
    say %named-bool.perl;

    {
        my @*ARGS = <--verbose a b --outfile foo c d e>;
        my @positional = process-cmd-args(@*ARGS, %named-bool);
        my %named = @positional.pop;
        $main(|@positional, |%named);
    }

}

# uncomment to actually run it
# run-it(&MAIN);

# vim: ft=perl6
