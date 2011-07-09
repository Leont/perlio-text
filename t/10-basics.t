# perl

use strict;
use warnings FATAL => 'all';
use utf8;

use Test::More;
use Test::Exception;

use Data::Dumper;
use Encode qw/encode/;
use Errno qw/EINVAL/;
use File::Slurp qw/read_file/;
use PerlIO::Layers qw/query_handle get_layers/;

my $win32 = $^O eq 'MSWin32';
my $force_crlf = 0;
my $crlf = $win32 || $force_crlf ? 1 : 0;
my $not_crlf = int !$crlf;

my $filename = 'foo';
my $lineend = $crlf ? "\r\n" : "\n";

END { unlink $filename }

my @lines = qw/foo bar báz/;

{
	my $ret = open my $fh, '>:text', $filename;
	ok !defined $ret, 'Can\'t open :text without an argument';
	is $!+0, EINVAL, 'Error is EINVAL';
}


{
	open my $fh, '>:text(UTF-16LE)', $filename;

	check_handle($fh, buffered => 1);
	check_handle($fh, crlf => $crlf);
	check_handle($fh, layer => { unix => 1, crlf => $crlf, encoding => 1}, utf8 => 1);

	print $fh join "\n", @lines;

	close $fh;

	my $content = read_file($filename) or die "Couldn't read test file: $!";
	is $content, encode 'UTF-16LE', join $lineend, @lines;
}


done_testing;

sub check_handle {
	my ($fh, $test_type, $expected) = @_;
	if (ref($expected)) {
		my %compound = %{ $expected };
		for my $subtype (keys %compound) {
			my $expected = $compound{$subtype};
			is query_handle($fh, $test_type, $subtype), $expected, "query_handle should return $expected on test $test_type($subtype)" or diag Dumper get_layers($fh);
		}
	}
	else {
		is query_handle($fh, $test_type), $expected, "query_handle should return $expected" or diag explain get_layers($fh);
	}
}

