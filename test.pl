# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 9 };
use Sort::UCA;
ok(1); # If we made it this far, we're ok.

#########################

my $uca = Sort::UCA->new(
  table => 'keys.txt',
);

ok(ref $uca, "Sort::UCA");

ok(
  join(':', $uca->sort( 
    qw/ lib strict Carp ExtUtils CGI Time warnings  Math overload Pod CPAN /
  ) ),
  join(':',
    qw/ Carp CGI CPAN ExtUtils lib Math overload Pod strict Time warnings /
  ),
);

my $tr = Sort::UCA->new(
  table => 'keys.txt',
  ignoreName => qr/^(?:HANGUL|HIRAGANA|KATAKANA|BOPOMOFO)$/,
  entry => <<'ENTRIES',
0063 0068 ; [.0893.0020.0002.0063]  # "ch" in traditional Spanish
0043 0068 ; [.0893.0020.0008.0043]  # "Ch" in traditional Spanish
ENTRIES
);

ok(
  join(':', $tr->sort( 
    qw/ acha aca ada acia acka /
  ) ),
  join(':',
    qw/ aca acia acka acha ada /
  ),
);

ok(
  join(':', $uca->sort( 
    qw/ acha aca ada acia acka /
  ) ),
  join(':',
    qw/ aca acha acia acka ada /
  ),
);

my $old_level = $uca->{level};

$uca->{level} = 2;

ok( $uca->cmp("ABC","abc"), 0);

$uca->{level} = $old_level;

$uca->{upper_before_lower} = 1;

ok( $uca->cmp("ABC","abc"), -1);

$uca->{upper_before_lower} = 0;

ok( $uca->cmp("ABC","abc"), 1);

my $ign = Sort::UCA->new(
  table => 'keys.txt',
  ignoreName => qr/^(?:HANGUL|HIRAGANA|KATAKANA|BOPOMOFO)$/,
  ignoreChar => qr/^[ae]$/,
);

ok( $ign->cmp("element","lament"), 0);
