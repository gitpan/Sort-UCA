use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Sort::UCA',
    'VERSION_FROM'	=> 'UCA.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	Lingua::KO::Hangul::Util => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'UCA.pm', # retrieve abstract from module
       AUTHOR     => 'SADAHIRO Tomoyuki <SADAHIRO@cpan.org>') : ()),
    'PM' => {
	'Makefile.PL' => 'Makefile',
	'UCA.pm' => 'blib/lib/Sort/UCA.pm',
	'keys.txt' => 'blib/lib/Sort/UCA/keys.txt',
	},
);
