use strict;
use Test::More;

use CHI;
use CHI::Cascade;

plan skip_all => 'Not installed CHI::Driver::File'
  unless eval "use CHI::Driver::File; 1";

plan tests => 14;


$SIG{__DIE__} = sub {
    `{ rm -rf t/file_cache; } >/dev/null 2>&1`;
    $SIG{__DIE__} = 'IGNORE';
};

`{ rm -rf t/file_cache; } >/dev/null 2>&1`;

my $cascade = CHI::Cascade->new(
    chi => CHI->new(
	driver		=> 'File',
	root_dir	=> 't/file_cache'
    )
);

isa_ok( $cascade, 'CHI::Cascade');

$cascade->rule(
    target		=> 'big_array',
    code		=> sub {
	return [ 1 .. 1000 ];
    }
);

$cascade->rule(
    target		=> qr/^one_page_(\d+)$/,
    depends		=> 'big_array',
    code		=> sub {
	my ($rule) = @_;

	my ($page) = $rule->target =~ /^one_page_(\d+)$/;

	my $ret = [ @{$rule->dep_values->{big_array}}[ ($page * 10) .. (( $page + 1 ) * 10 - 1) ] ];
	$ret;
    }
);

ok( $cascade->{stats}{recompute} == 0, 'recompute stats - 1');

is_deeply( $cascade->run('one_page_0'), [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ], '0th page from cache');
ok( $cascade->{stats}{recompute} == 2, 'recompute stats - 2');

is_deeply( $cascade->run('one_page_1'), [ 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 ], '1th page from cache');
ok( $cascade->{stats}{recompute} == 3, 'recompute stats - 3');

is_deeply( $cascade->run('one_page_0'), [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ], '0th page from cache');
ok( $cascade->{stats}{recompute} == 3, 'recompute stats - 4');

sleep 1;

# To force recalculate dependencied
$cascade->touch('big_array');

is_deeply( $cascade->run('one_page_0'), [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ], '0th page from cache after touching');
cmp_ok( $cascade->{stats}{recompute}, '==', 4, 'recompute stats - 5');

is_deeply( $cascade->run('one_page_1'), [ 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 ], '1th page from cache after touching');
cmp_ok( $cascade->{stats}{recompute}, '==', 5, 'recompute stats - 6');

is_deeply( $cascade->run('one_page_0'), [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ], '0th page from cache');
cmp_ok( $cascade->{stats}{recompute}, '==', 5, 'recompute stats - 7');

$SIG{__DIE__}->();
