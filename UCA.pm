package Sort::UCA;

use 5.006;
use strict;
use warnings;
use Carp;
use Lingua::KO::Hangul::Util;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ();
our @EXPORT_OK = ();
our @EXPORT = ();
our $VERSION = '0.03';

(our $Path = $INC{'Sort/UCA.pm'}) =~ s/\.pm$//;
our $KeyFile = "allkeys.txt";

use constant Min2 => 0x20; # minimum weight at level 2
use constant Min3 => 0x02; # minimum weight at level 3

##
## constructor
##
sub new
{
  my $class = shift;
  my $self = bless { @_ }, $class;

  # default alternate
  $self->{alternate} ||= 'shifted';

  # default collation level
  $self->{level} ||= $self->{alternate} =~ /shift/ ? 4 : 3;

  # backwards in an arrayref
  $self->{backwards} ||= [];
  $self->{backwards} = [ $self->{backwards} ] if ! ref $self->{backwards};

  # rearrange in an arrayref
  $self->{rearrange} ||= [];
  $self->{rearrange} = [ $self->{rearrange} ] if ! ref $self->{rearrange};

  # open the table file
  my $file = defined $self->{table} ? $self->{table} : $KeyFile;
  open my $fk, "<$Path/$file" or croak "File does not exist at $Path/$file";

  while(<$fk>){
    next if /^\s*#/;
    if(/^\s*\@/){
       if(/^\@version\s*(\S*)/){
         $self->{version} ||= $1;
       }
       elsif(/^\@alternate\s+(.*)/){
         $self->{alternate} ||= $1;
       }
       elsif(/^\@backwards\s+(.*)/){
         push @{ $self->{backwards} }, $1;
       }
       elsif(/^\@rearrange\s+(.*)/){
         push @{ $self->{rearrange} }, _getHexArray($1);
       }
       next;
    }
    $self->parseEntry($_);
  }
  close $fk;
  if($self->{entry}){
    $self->parseEntry($_) foreach split /\n/, $self->{entry};
  }

  # keys of $self->{rearrangeHash} are $self->{rearrange}.
  $self->{rearrangeHash} = {};
  @{ $self->{rearrangeHash} }{ @{ $self->{rearrange} } } = ();

  return $self;
}

##
## "hhhh hhhh hhhh" to (dddd, dddd, dddd)
##
sub _getHexArray
{
  my $str = shift;
  map hex(), $str =~ /([0-9a-fA-F]+)/g;
}

##
## get $line, parse it, and write an entry in $self
##
sub parseEntry
{
  my $self = shift;
  my $line = shift;
  my($name, $ele, @key);

  return if $line !~ /^\s*[0-9A-Fa-f]/;

  # get name
  $name = $1 if $line =~ s/#\s*(.*)//;
  return if defined $self->{ignoreName} && $name =~ /$self->{ignoreName}/;

  # get element
  my($e, $k) = split /;/, $_;
  my @e = _getHexArray($e);
  $ele = pack('U*', @e);
  return if defined $self->{ignoreChar} && $ele =~ /$self->{ignoreChar}/;

  # get sort key
  foreach my $arr ($k =~ /\[(\S+)\]/g)
  {
    my $var = $arr =~ /\*/;
    push @key, $self->getCE( $var, _getHexArray($arr) );
  }
  $self->{entries}{$ele} = \@key;
  $self->{maxlength}{ord $ele} = scalar @e if @e > 1;
}


##
## list to collation element
##
sub getCE
{
  my $self = shift;
  my $var  = shift;
  my @c    = @_;

  $self->{alternate} eq 'blanked' ?
     $var ? [0,0,0] : [ @c[0..2] ] :
  $self->{alternate} eq 'non-ignorable' ? [ @c[0..2] ] :
  $self->{alternate} eq 'shifted' ?
    $var ? [0,0,0,$c[0] ] : [ @c[0..2], 0xFFFF ] :
  $self->{alternate} eq 'shift-trimmed' ?
    $var ? [0,0,0,$c[0] ] : [ @c[0..2], 0 ] :
   \@c;
}

##
## to debug
##
sub viewSortKey
{
  my $self = shift;
  my $key  = $self->getSortKey(@_);
  join ' ', map {
    '['.join(',', map sprintf("%04X", $_), @$_).']';
  } @$key;
}

##
## sort key
##
sub getSortKey
{
  my $self = shift;
  my $code = $self->{preprocess};
  my $ent  = $self->{entries};
  my $max  = $self->{maxlength};
  my $cjk  = $self->{overrideCJK};
  my $hang = $self->{overrideHangul};
  my $back = $self->{backwards};
  my $rear = $self->{rearrangeHash};
  my $uplw = $self->{upper_before_lower};

  my $str = ref $code ? &$code(shift) : shift;
  my(@src, @buf);
  @src = unpack('U*', $str);

  # rearrangement
  for(my $i = 0; $i < @src; $i++)
  {
     ($src[$i], $src[$i+1]) = ($src[$i+1], $src[$i])
        if $rear->{ $src[$i] };
     $i++;
  }

  for(my $i = 0; $i < @src; $i++)
  {
    my $ch;
    my $u  = $src[$i];

    if($max->{$u})
    {
      for(my $j = $max->{$u}; $j >= 1; $j--)
      { # contract
        next unless $i+$j-1 < @src;
        $ch = pack 'U*', @src[$i .. $i+$j-1];
        $i += $j-1, last if $ent->{$ch};
      }
    }
    else {  $ch = pack('U', $u) }

    push @buf,
      $ent->{$ch}
        ? @{ $ent->{$ch} }
        : _isHangul($u)
          ? $hang
            ? &$hang($u)
            : map(@{ $ent->{pack('U', $_)} }, decomposeHangul($u))
          : _isCJK($u)
            ? $cjk ? &$cjk($u) : $self->getCE( 0, ($u, Min2, Min3) )
            : ();
  }

  my @ret = ([],[],[],[]);
  foreach my $lv (0..3){
    foreach my $b (@buf){
      push @{ $ret[$lv] }, $b->[$lv] if $b->[$lv];
    }
  }
  foreach (@$back){
    my $lv = $_ - 1;
    @{ $ret[$lv] } = reverse @{ $ret[$lv] };
  }
  if($uplw){ # upper_before_lower : tertiary weight is modified.
    foreach (@{ $ret[2] }){
      if(0x8 <= $_ && $_ <= 0xC){
        $_ -= 6;
      }
      elsif(0x2 <= $_ && $_ <= 0x6){
        $_ += 6;
      }
      elsif($_ == 0x1C){
        $_ += 1;
      }
      elsif($_ <= 0x1D){
        $_ -= 1;
      }
    }
  }
  return \@ret;
}

##
## compare two sort keys
##
sub cmpSortKey
{
  my $obj = shift;
  my $a   = shift;
  my $b   = shift;
  my $lv  = $obj->{level};
  for my $lv (0..$lv-1){
    my $n = @$a > @$b ? @$a - 1 : @$b - 1;
    foreach my $j (0..$n){
      my $r = ((defined $a->[$lv][$j] ? $a->[$lv][$j] : 0)
           <=> (defined $b->[$lv][$j] ? $b->[$lv][$j] : 0));
        return $r if $r;
     }
  }
  return 0;
}

##
## cmp
##
sub cmp
{
  my $obj = shift;
  my $a   = shift;
  my $b   = shift;
  $obj->cmpSortKey(
     $obj->getSortKey($a),
     $obj->getSortKey($b),
    );
}

##
## sort
##
sub sort
{
  my $obj = shift;

  map { $_->[1] }
  sort{ $obj->cmpSortKey($a->[0], $b->[0]) }
  map [ $obj->getSortKey($_), $_ ], @_;
}


##
##  CJK Unified Ideographs
##
sub _isCJK
{
  my $code = shift;
  return 0x3400  <= $code && $code <= 0x4DB5  
      || 0x4E00  <= $code && $code <= 0x9FA5  
      || 0x20000 <= $code && $code <= 0x2A6D6;
}

##
## Hangul Syllables
##
sub _isHangul
{
  my $code = shift;
  return 0xAC00 <= $code && $code <= 0xD7A3;
}

1;
__END__

=head1 NAME

Sort::UCA - use UCA (Unicode Collation Algorithm)

=head1 SYNOPSIS

  use Sort::UCA;

  #construct
  $uca = Sort::UCA->new(%tailoring);

  #sort
  @sorted = $uca->sort(@not_sorted);

  #compare
  $result = $uca->cmp($a, $b); # returns 1, 0, or -1. 

=head1 DESCRIPTION

=head2 Constructor and Tailoring

   $uca = Sort::UCA->new(
      alternate => $alternate,
      backwards => $levelNumber, # or \@levelNumbers
      entry => $element,
      ignoreName => qr/regex/,
      ignoreChar => qr/regex/,
      level => $collationLevel,
      overrideCJK => \&overrideCJK,
      overrideHangul => \&overrideHangul,
      preprocess => \&preprocess,
      rearrange => \@charList,
      table => $filename,
      upper_before_lower => $bool,
   );

=over 4

=item alternate

-- see 3.2.2 Alternate Weighting, UTR #10.

   alternate => 'shifted', 'blanked', 'non-ignorable', or 'shift-trimmed'.

By default (if specification is omitted), 'shifted' is adopted.

=item backwards

-- see 3.1.2 French Accents, UTR #10.

     backwards => $levelNumber or \@levelNumbers

Weights in reverse order; ex. level 2 (diacritic ordering) in French.
If omitted, forwards at all the levels.

=item entry

-- see 3.1 Linguistic Features; 3.2.1 File Format, UTR #10.

Override a default order or add a new element

  entry => <<'ENTRIES', # use the UCA file format
00E6 ; [.0861.0020.0002.00E6] [.08B1.0020.0002.00E6] # ligature <ae> as <a e>
0063 0068 ; [.0893.0020.0002.0063]      # "ch" in traditional Spanish
0043 0068 ; [.0893.0020.0008.0043]      # "Ch" in traditional Spanish
ENTRIES

=item ignoreName or ignoreChar

-- see 6.3.4 Reducing the Repertoire, UTR #10.

  ignoreName => qr/\bDINGBAT\b/,
     # Elements the name of which matches the regex are ignored.

  ignoreChar => qr/^(?:\p{InDingbat}|\p{Lm})$/,
     # Elements which matches the regex are ignored.

When 'a' and 'e' are ignored,
'element' is equal to 'lament' (or 'lmnt').

But, it'd be better to ignore characters
unfamiliar to you (and maybe never used).

=item level

-- see 4.3 Form a sort key for each string, UTR #10.

Set the maximum level.
Any higher levels than the specified one are ignored.

  Level 1: alphabetic ordering
  Level 2: diacritic ordering
  Level 3: case ordering
  Level 4: tie-breaking (e.g. in the case when alternate is 'shifted')

  ex.level => 2,

=item overrideCJK or overrideHangul

-- see 7.1 Derived Collation Elements, UTR #10.

By default, mapping of CJK Unified Ideographs
uses the Unicode codepoint order
and Hangul Syllables are decomposed into Hangul Jamo.

The mapping of CJK Unified Ideographs
or Hangul Syllables may be overrided.

ex. CJK Unified Ideographs in the JIS codepoint order.

  overrideCJK => sub {
    my $u = shift;               # get unicode codepoint
    my $b = pack('n', $u);       # to UTF-16BE
    my $s = your_unicode_to_sjis_converter($b); # convert
    my $n = unpack('n', $s);     # convert sjis to short
    [ $n, 1, 1 ];                # return collation element
  },

=item preprocess

-- see 5.1 Preprocessing, UTR #10.

If specified, the coderef is used to preprocess
before the formation of sort keys.

ex. dropping English articles, such as "a" or "the". 
Then, "the pen" is before "a pencil".

     preprocess => sub {
           my $str = shift;
           $str =~ s/\b(?:an?|the)\s+//g;
           $str;
        },

=item rearrange

-- see 3.1.3 Rearrangement, UTR #10.

Characters that are not coded in logical order and to be rearranged.
By default, 

    rearrange => [ 0x0E40..0x0E44, 0x0EC0..0x0EC4],

=item table

-- see 3.2 Default Unicode Collation Element Table, UTR #10.

You can use another element table if desired.
The table file must be in your C<lib/Sort/UCA> directory.

By default, the file C<lib/Sort/UCA/allkeys.txt> is used.

=item upper_before_lower

-- see 6.6 Case Comparisons; 7.3.1 Tertiary Weight Table, UTR #10.

By default, lowercase is before uppercase.
If upper_before_lower is true, this is reversed.

=back

=head2 EXPORT

None by default.

=head1 AUTHOR

SADAHIRO Tomoyuki, E<lt>SADAHIRO@cpan.orgE<gt>

  http://homepage1.nifty.com/nomenclator/perl/

  Copyright(C) 2001, SADAHIRO Tomoyuki. Japan. All rights reserved.

  This program is free software; you can redistribute it and/or 
  modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>.

L<Lingua::KO::Hangul::Util>.

L<UCA> - Unicode TR #10

http://www.unicode.org/unicode/reports/tr10/

=cut
