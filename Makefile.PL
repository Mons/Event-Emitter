use 5.008008;
use ExtUtils::MakeMaker;

our $AUTHOR = -e '.git';
if ($AUTHOR) {
	#system( 'pod2text ... > README' ) and die "$!";
}
unlink 'META.yml';

WriteMakefile(
	NAME              => 'Event::Emitter',
	VERSION_FROM      => 'lib/Event/Emitter.pm',
	ABSTRACT_FROM     => 'lib/Event/Emitter.pm',
	PREREQ_PM         => {  },
	AUTHOR            => 'Mons Anderson <mons@cpan.org>',
	META_ADD          => { license => 'perl' },
	PL_FILES          => {
		"Kit.pm.PL" => '$(INST_LIB)/Event/Emitter/Kit.pm',
		#$AUTHOR ? (
		#	"Kit.pm.PL" => 'lib/Event/Emitter/Kit.pm',
		#) : ()
	},
	clean             => { FILES => "Kit.pm" },
);

__END__
use inc::Module::Install;

my $MI  = $Module::Install::MAIN;
name           'Event-Emitter';
all_from       'lib/Event/Emitter.pm';
#author         'Mons Anderson <mons@cpan.org>';
license        'perl';

build_requires 'Test::More';
build_requires 'lib::abs',  '0.90';

requires 'common::sense',    2;
requires 'Scalar::Util';
# requires 'uni::perl';

auto_provides;
auto_install;

WriteAll;

print STDERR "Generated makefile for ".$MI->load('name')->name."-".$MI->load('version')->version."\n";
