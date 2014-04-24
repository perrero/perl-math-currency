#!/usr/bin/perl -w
# vim:ts=4:sw=4:et:at:
#
# PROGRAM:	Math::Currency.pm	# - 04/26/00 9:10:AM
# PURPOSE:	Perform currency calculations without floating point
#
#------------------------------------------------------------------------------
#   Copyright (c) 2001-2008 John Peacock
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file,
#   with the exception that it cannot be placed on a CD-ROM or similar media
#   for commercial distribution without the prior approval of the author.
#------------------------------------------------------------------------------
eval 'exec /usr2/local/bin/perl -S $0 ${1+"$@"}'
  if 0;

package Math::Currency;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $PACKAGE $FORMAT $LC_MONETARY
  $accuracy $precision $div_scale $round_mode $use_int $always_init);
use Exporter;
use Math::BigFloat 1.60;
use overload '""' => \&bstr;
use POSIX qw(locale_h);

@ISA = qw(Exporter Math::BigFloat);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
);

@EXPORT_OK = qw(
  $LC_MONETARY
  $FORMAT
  Money
);

$VERSION = 0.47;

$PACKAGE = __PACKAGE__;

$LC_MONETARY = {
    en_US => {
        INT_CURR_SYMBOL   => 'USD ',
        CURRENCY_SYMBOL   => '$',
        MON_DECIMAL_POINT => '.',
        MON_THOUSANDS_SEP => ',',
        MON_GROUPING      => '3',
        POSITIVE_SIGN     => '',
        NEGATIVE_SIGN     => '-',
        INT_FRAC_DIGITS   => '2',
        FRAC_DIGITS       => '2',
        P_CS_PRECEDES     => '1',
        P_SEP_BY_SPACE    => '0',
        N_CS_PRECEDES     => '1',
        N_SEP_BY_SPACE    => '0',
        P_SIGN_POSN       => '1',
        N_SIGN_POSN       => '1',
    },
};
$LC_MONETARY->{USD} = $LC_MONETARY->{en_US};

unless ( localize() )    # no locale information available
{
    $FORMAT = $LC_MONETARY->{en_US};
}

# Set class constants
$round_mode = 'even';    # Banker's rounding obviously
$accuracy   = undef;
$precision = $FORMAT->{FRAC_DIGITS} > 0 ? -$FORMAT->{FRAC_DIGITS} : 0;
$div_scale = 40;
$use_int   = 0;
$always_init = 0;        # should the localize() happen every time?

# Preloaded methods go here.
############################################################################
sub new                  #05/10/99 3:13:PM
############################################################################

{
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $parent = $proto if ref($proto);

    my $value = shift || 0;

    $value =~ tr/-()0-9.//cd;    #strip any formatting characters
    $value = "-$value" if $value =~ s/(^\()|(\)$)//g;    # handle parens

    if ( (caller)[0] =~ /Math\::BigInt/ )    # only when called from objectify()
    {
        return Math::BigFloat->new($value);
    }

    my $self;
    my $currency = shift;
    my $format;

    if ( not defined $currency and $class->isa($PACKAGE) ) {

        # must be one of our subclasses
        $currency = $1 if ($class =~ /$PACKAGE\:\:(\w+)/);
    }

    if ( defined $currency )    #override default currency type
    {
        unless ( defined $LC_MONETARY->{$currency} ) {
            eval "require Math::Currency::$currency";
            unknown_currency($currency) if $@;
        }
        $format = $LC_MONETARY->{$currency};
    }

    if ($format) {
        $self =
          Math::BigFloat->new( $value, undef, -( $format->{FRAC_DIGITS} + 2 ) );
        bless $self, $class;
        $self->format($format);
    }
    elsif ( $parent
        and defined $parent->{format} ) # if we are cloning an existing instance
    {
        $self =
          Math::BigFloat->new( $value, undef,
            -( $parent->format->{FRAC_DIGITS} + 2 ) );
        bless $self, $class;
        $self->format( $parent->format );
    }
    else {
        $self =
          Math::BigFloat->new( $value, undef, -( $FORMAT->{FRAC_DIGITS} + 2 ) );
        bless $self, $class;
    }
    return $self;
}    ##new

############################################################################
sub Money    #05/10/99 4:16:PM
############################################################################

{
    return $PACKAGE->new(@_);
}            ##Money

############################################################################
sub bstr     #05/10/99 3:52:PM
############################################################################

{
    my $self     = shift;
    my $myformat = $self->format();
    my $value    = $self->as_float();
    my $neg      = ( $value =~ tr/-//d );
    my $dp       = index( $value, "." );
    my $sign     = $neg
      ? $myformat->{NEGATIVE_SIGN}
      : $myformat->{POSITIVE_SIGN};
    my $curr = $use_int
      ? $myformat->{INT_CURR_SYMBOL}
      : $myformat->{CURRENCY_SYMBOL};
    my $digits = $use_int
      ? $myformat->{INT_FRAC_DIGITS}
      : $myformat->{FRAC_DIGITS};
    my $formtab = [
        [
            [ '($value$curr)',    '($value $curr)',    '($value $curr)' ],
            [ '$sign$value$curr', '$sign$value $curr', '$sign$value $curr' ],
            [ '$value$curr$sign', '$value $curr$sign', '$value$curr $sign' ],
            [ '$value$sign$curr', '$value $sign$curr', '$value$sign $curr' ],
            [ '$value$curr$sign', '$value $curr$sign', '$value$curr $sign' ],
        ],
        [
            [ '($curr$value)',    '($curr $value)',    '($curr $value)' ],
            [ '$sign$curr$value', '$sign$curr $value', '$sign $curr$value' ],
            [ '$curr$value$sign', '$curr $value$sign', '$curr$value $sign' ],
            [ '$sign$curr$value', '$sign$curr $value', '$sign $curr$value' ],
            [ '$curr$sign$value', '$curr$sign $value', '$curr $sign$value' ],
        ],
    ];

    if ( $dp < 0 ) {
        $value .= '.' . '0' x $digits;
    }
    elsif ( ( length($value) - $dp - 1 ) < $digits ) {
        $value .= '0' x ( $digits - $dp );
    }

    ( $value = reverse "$value" ) =~ s/\+//;

    # make sure there is a leading 0 for values < 1
    if ( substr( $value, -1, 1 ) eq '.' ) {
        $value .= "0";
    }
    $value =~ s/\./$myformat->{MON_DECIMAL_POINT}/;
    $value =~
s/(\d{$myformat->{MON_GROUPING}})(?=\d)(?!\d*\.)/$1$myformat->{MON_THOUSANDS_SEP}/g;
    $value = reverse $value;

    eval '$value = "'
      . (
          $neg
        ? $formtab->[ $myformat->{N_CS_PRECEDES} ][ $myformat->{N_SIGN_POSN} ]
          [ $myformat->{N_SEP_BY_SPACE} ]
        : $formtab->[ $myformat->{P_CS_PRECEDES} ][ $myformat->{P_SIGN_POSN} ]
          [ $myformat->{P_SEP_BY_SPACE} ]
      )
      . '"';

    if ( substr( $value, -1, 1 ) eq '.' ) {    # trailing bare decimal
        chop($value);
    }

    return $value;
}    ##stringify

############################################################################
sub format    #05/17/99 1:58:PM
############################################################################

{
    my $self  = shift;
    my $key   = shift;    # do they want to display or set?
    my $value = shift;    # did they supply a value?
    localize() if $always_init;    # always reset the global format?
    my $source = \$FORMAT;         # default format rules

    if ( ref($self) ) {
        if ( defined $self->{format} ) {
            if ( defined $key and $key eq '' ) {
                delete $self->{format};
                $source = \$FORMAT;
            }
            else {
                $source = \$self->{format};
            }
        }
        elsif ( defined $key )     # get/set a parameter
        {
            if ( defined $value
                or ref($key) eq "HASH" )    # have to copy global format
            {
                while ( my ( $k, $v ) = each %{$FORMAT} ) {
                    $self->{format}{$k} = $v;
                }
                $source = \$self->{format};
            }
        }
    }
    else { # called as class method to set the default currency
	if ( defined $key && not exists $FORMAT->{$key} ) {
	    unless ( defined $LC_MONETARY->{$key} ) {
		eval "require Math::Currency::$key";
		unknown_currency($key) if $@;
	    }
	    $FORMAT = $LC_MONETARY->{$key};
	    return $FORMAT;
	}
    }


    if ( defined $key )                     # otherwise just return
    {
        if ( ref($key) eq "HASH" )          # must be trying to replace all
        {
            $$source = $key;
        }
        else                                # get/set just one parameter
        {
            return $$source->{$key} unless defined $value;
            $$source->{$key} = $value;
        }
    }
    return $$source;
}    ##format

sub as_float {
    my $self   = shift;
    my $format = $self->format;
    my $string = $self->copy->bfround( -$format->{FRAC_DIGITS} )->SUPER::bstr();
    return $string;
}

sub copy {
    my $self = shift;

    # grab the builtin formatting
    my $myformat = ( defined $self->{format} ? $self->{format} : undef );

    # let Math::BigFloat do it's thing
    my $new = $self->SUPER::copy(@_);

    if ($myformat) {

        # make sure we keep the original formatting
        $new->format($myformat);
    }

    # done...
    return $new;
}

sub as_int {
    my $self = shift;
    (my $str = $self->as_float) =~ s/\.//o;
    $str =~ s/^(\-?)0+/$1/o;
    return $str eq '' ? '0' : $str;
}

# we override the default here because we only want to compare the precision of
# the currency we're dealing with, not the precision of the underlying object
sub bcmp {
    my $class = shift;

    # make sure we're dealing with two Math::Currency objects
    my ( $x, $y ) =
      map { ref $_ ne $class ? $class->new($_) : $_ } @_[ 0, 1 ];
    return $x->as_float <=> $y->as_float;
}

############################################################################
sub localize    #08/17/02 7:58:PM
############################################################################

{
    my $self   = shift;
    my $format = shift || \$FORMAT;

    my $localeconv = POSIX::localeconv(); 

    # so you can test to see if locale was effective
    return 0 if ! exists $localeconv->{'currency_symbol'};

    $$format = {
        INT_CURR_SYMBOL   => $localeconv->{'int_curr_symbol'}   || '',
        CURRENCY_SYMBOL   => $localeconv->{'currency_symbol'}   || '',
        MON_DECIMAL_POINT => $localeconv->{'mon_decimal_point'} || '',
        MON_THOUSANDS_SEP => $localeconv->{'mon_thousands_sep'} || '',
        MON_GROUPING      => (
            exists $localeconv->{'mon_grouping'}
              and defined $localeconv->{'mon_grouping'}
              and ord( $localeconv->{'mon_grouping'} ) < 47
            ? ord( $localeconv->{'mon_grouping'} )
            : $localeconv->{'mon_grouping'}
          )
          || 0,
        POSITIVE_SIGN   => $localeconv->{'positive_sign'}   || '',
        NEGATIVE_SIGN   => $localeconv->{'negative_sign'}   || '-',
        INT_FRAC_DIGITS => $localeconv->{'int_frac_digits'} || 0,
        FRAC_DIGITS     => $localeconv->{'frac_digits'}     || 0,
        P_CS_PRECEDES   => $localeconv->{'p_cs_precedes'}   || 0,
        P_SEP_BY_SPACE  => $localeconv->{'p_sep_by_space'}  || 0,
        N_CS_PRECEDES   => $localeconv->{'n_cs_precedes'}   || 0,
        N_SEP_BY_SPACE  => $localeconv->{'n_sep_by_space'}  || 0,
        P_SIGN_POSN     => $localeconv->{'p_sign_posn'}     || 1,
        N_SIGN_POSN     => $localeconv->{'n_sign_posn'}     || 0,
    };

    return 1;
}

############################################################################
sub unknown_currency    #02/03/05 4:37am
############################################################################

{
    my ($currency) = @_;
    $DB::single=1;
    open LOCALES, "-|", "locale -a";
    while (my $LOCALE = <LOCALES>) {
        chomp($LOCALE);
        setlocale( LC_ALL, $LOCALE );
        my $localeconv = POSIX::localeconv();
	if ( $LOCALE eq $currency || 
	    (defined $localeconv->{'int_curr_symbol'}
             and $localeconv->{'int_curr_symbol'} =~ /$currency/ )
	   )
        {
            my $format = \$LC_MONETARY->{$currency};
            Math::Currency->localize($format);
	    (my $int_curr = $$format->{'INT_CURR_SYMBOL'}) =~  s/ //g;
	    $LC_MONETARY->{$int_curr} = $LC_MONETARY->{$currency}
		unless exists $LC_MONETARY->{$int_curr};	
	    eval <<"EOP";
package Math::Currency::${LOCALE};
use vars qw(\$VERSION \@ISA \$LANG);

\$VERSION = $Math::Currency::VERSION;
\$LANG  = '$LOCALE';
\@ISA = qw/Math::Currency/;
1;
package Math::Currency::${int_curr};
use vars qw(\$VERSION \@ISA \$LANG);

\$VERSION = $Math::Currency::VERSION;
\$LANG  = '$LOCALE';
\@ISA = qw/Math::Currency/;
1;
EOP
            last;
        }
    }
    close LOCALES;
}

# additional methods needed to get/set package globals

sub always_init {
    my ($class) = shift;
    $always_init = shift if @_;
    return $always_init;
}

sub use_int {
    my ($class) = shift;
    $use_int = shift if @_;
    return $use_int;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Math::Currency - Exact Currency Math with Formatting and Rounding

=head1 SYNOPSIS

 use Math::Currency qw(Money $LC_MONETARY);
 $dollar = Math::Currency->new("$12,345.67");
 $taxamt = $dollar * 0.28;
 # this sets the default format for all objects w/o their own format
 Math::Currency->format('EUR');
 $euro = Money(12345.67);
 $euro_string = Money(12345.67)->bstr();
 # or if you already have a Math::Currency object
 $euro_string = "$euro";

=head1 DESCRIPTION

Currency math is actually more closely related to integer math than it is to
floating point math.  Rounding errors on addition and subtraction are not
allowed and division/multiplication should never create more accuracy than the
original values.  All currency values should round to the closest cent or
whatever the local equivalent should happen to be.

However, repeated mathematical operations on currency values can lead to
inaccurate results, if rounding is performed at each intermediate step.
In order to preserve appropriate accuracy, the Math::Currency values are
stored with an additional two places of accuracy internally and only
rounded to the "correct" precision when the value is displayed (either by
the default stringification or through the use of L<as_float> or L<as_int>).

All common mathematical operations are overloaded, so once you initialize a
currency variable, you can treat it like any number and the module will do
the right thing.  This module is a thin layer over Math::BigFloat which
is itself a layer over Math::BigInt.

=head1 Important Note on Input Values

Since the point of this module is to perform currency math and not floating
point math, it is important to understand how the initial value passed to new()
may have nasty side effects if done improperly.  Most of the time, the following
two objects are identical:

        $cur1 = new Math::Currency 1000.01;
        $cur2 = new Math::Currency "1000.01";

However, only the second is guaranteed to do what you think it should do.  The
reason for that lies in how Perl treats bare numbers as opposed to strings.  The
first new() will receive the Perl-stringified representation of the number
1000.01, whereas the second new() will receive the string "1000.01" instead.
With most locale settings, this will be largely identical.  However, with many
European locales (like fr_FR), the first new() will receive the string
"1 000,01" and this will cause Math::BigFloat to report this as NAN (Not A
Number) because of the odd posix driven formatting.

For this reason, it is always recommended that input values be quoted at all
times, even if your POSIX locale does not have this unfortunate side effect.

=head1 Output Formatting

Each currency value can have an individual format or the global currency
format can be changed to reflect local usage.  I used the suggestions in Tom
Christiansen's L<PerlTootC|http://www.perl.com/language/misc/perltootc.html#Translucent_Attributes>
to implement translucent attributes.  If you have set your locale values
correctly, this module will pick up your local settings or US standards if you
haven't.  You can also specify an output format using one of the predefined
Locale formats or your own custom format.

=head2 Locale Support

This module uses the builtin locale support provided by your operating system
to generate the appropriate currency formatting.  Much of this support will
happen automagically if you have your LANG environment setting correct.  If you
chose not to install multiple locales when you installed your operating system,
you will only be able to use your default locale format or one of the
L<Predefined Locales> included in the distribution.

The automatic locale support will take effect if you request a locale by name
in the for lc_CC (language/country code) like fr_CA (French Canadian) or 
en_NZ (English New Zealand).  If you pregenerate your L<Custom Locale>, an 
alias class will be added so that you can refer to the currency by either
the locale name or the INT_CURR_SYMBOL (e.g. USD or GBP).

B<IMPORTANT NOTE>: there are multiple locales which implement the EUR (Euro)
currency, each with slightly different formatting rules (aren't standards
wonderful).  If you C<use> multiple currencies that represent EUR, the last
one loaded will be available as the INT_CURR_SYMBOL shortcut.  You should
always use the locale name to refer to these currencies, if you are mixing
them in a single program.

=head2 Predefined Locales

There are currently four predefined Locale formats:

    en_US = United States dollars (the default if no locale)
    en_GB = British Pounds Sterling
    ja_JP = Japanese Yen 
    de_DE = German Euro

These currency formats are implemented using subclasses for easy extension 
(see L<Custom Locales> for details on creating new subclasses for
unsupported locales).  If you are using a locale in a country that uses the
Euro, you should create your own local format file using your default LANG 
setting, since the Euro formatting rules are country specific.

B<IMPORTANT NOTE>: the predefined locales have been generated using non-UTF-8
locales (since all of the above currencies have a native ASCII character
available).  If you use a UTF-8 locale (common with more modern Linux distros),
then the non-UTF-8 version will be used if found.  Some locales require the
use of UTF-8 to represent their L<local currency|Currency Symbol>, so you must
generate your own L<Custom Locale> to fully support that usage.

If you want to use any locale other than your default in a single script, there
are two different ways to specify which currency format you wish to use, with
somewhat subtle differences:

=over 4

=item * Additional parameter to new()

If you need a single currency of a different type than the others in your
program, use this mode:

  use Math::Currency;
  my $dollars = Math::Currency->new("1.23"); # default behavior
  my $euros = Math::Currency->new("1.23", "de_DE"); # different format

The last line above will automatically load the applicable subclass and
use that formatting for that specific object.  These formats can either use
a pre-generated subclass or will automatically generate an automatic
L<Custom Locale>, 

=back

=over 4

=item * Directly calling the subclass

If all (or most) of your currency values should be formatted using the same
rules, create the objects directly using the subclass:

  use Math::Currency::ja_JP; # Japanese Yen
  my $yen = Math::Currency::JPY->new("1.345"); # compatibility class
  my $yen2 = $yen->new("3.456"); # you can use an existing object

=back

=head2 Currency Symbol

The locale definition includes two different Currency Symbol strings: one
is the native character(s), like $ or � or �; the other is the three
character string defined by the ISO4217 specification followed by the
normal currency separation character (frequently space).  The default
behavior is to always display the native CURRENCY_SYMBOL unless a global
parameter is set:

    $Math::Currency::use_int = 1; # print the currency symbol text

where the INT_CURR_SYMBOL text will used instead.

=head2 Custom Locales 

The included file, scripts/new_currency, will automatically create a new
currency formatting subclass, based on your current locale, or any
arbitrary locale supported by your operating system.  For most unix-like
O/S's, the following command will list the locale files installed:

    locale -a

and any of those installed locales can [potentially] be used to create a
new locale formatting file. 

It is not I<necessary> to do this, since using the L<format> command to
switch to a locale which doesn't already have a subclass defined for it
will attempt to generate a locale format on the fly.  However, it should be
noted that the automated generation method will merely look for the first
locales that uses the requested INT_CURR_SYMBOL.  There may be several locales
which use that same currency symbol, with subtle differences (this is
especially true of the EUR format), so it is best to pre-generate all
of the POSIX currency subclasses you expect, based on the locales you wish
to support, to utilize when installing this module, instead of relying on
the autogeneration methods.

To create a new locale formatting subclass, change to the top level build
directory for Math::Currency and run the following command:

    scripts/new_currency [xx_XX]

where xx_XX is the locale name obtained from the `locale -a` command.  This
will create a new locale subclass in the lib/Math/Currency/ directory, and
this file will be installed when `./Build install` is next run.

If you run the script without any commandline option, it will take the contents
of your LANG environment variable and generate your default locale.  NOTE that
if you are using a UTF-8 locale, the generated file will also be UTF-8 (which
may not be what you want).  You probably always want to specify the locale
name when generating new classes.

The new_currency script will function from within the current build
directory, and doesn't depend the current version of Math::Currency 
being already installed, so you can build all of your commonly used
locale files and install them at once.

=head2 Global Format

Global formatting can be changed by setting the package global format like
this:

    Math::Currency->format('USD');

=head2 POSIX Locale Global Formatting

In addition to the four predefined formats listed above, you can also use
the POSIX monetary format for a locale which you are not currently running
(e.g. for a web site).  You can set the global monetary format in effect
at any time by using:

    use POSIX qw( locale_h );
    setlocale(LC_ALL,"en_GB");   # some locale alias
    Math::Currency->localize;    # reinitialize global format

If you don't want to always have to remember to reinitialize the POSIX settings
when you switch locales, you can set the global parameter:

    $Math::Currency::always_init = 1;

and every single time a M::C object is printed, the global $FORMAT will be
updated to the locale current at that time.  This may be a performance hit.  It
would be better if you followed the first method of manually updating the global
format immediately after you reset the locale.

NOTE: This function will reset only the global format and will not have
effect on objects created with their own overridden formats, even if they were
originally based on the global format.

NOTE 2: You must have all the locale files in question already loaded; the list
reported by `locale -a` is not always a reliable judge of what files you
might actually have installed.  If you try and set a nonexistant locale,
or set the same locale as is already active, the module will silently retain
the current locale settings.

=head2 Object Formats

Any object can have it's own format different from the current global format,
like this:

    $pounds  = Math::Currency->new(1000, 'GBP');
    $dollars = Math::Currency->new(1000); # inherits default US format
    $dollars->format( 'USD' ); # explicit object format

=head2 Format Parameters

The format must contains all of the commonly configured LC_MONETARY
Locale settings.  For example, these are the values of the default US format
(with comments):
  {
    INT_CURR_SYMBOL    => 'USD',  # ISO currency text
    CURRENCY_SYMBOL    => '$',    # Local currency character
    MON_DECIMAL_POINT  => '.',    # Decimal seperator
    MON_THOUSANDS_SEP  => ',',    # Thousands seperator
    MON_GROUPING       => '3',    # Grouping digits
    POSITIVE_SIGN      => '',     # Local positive sign
    NEGATIVE_SIGN      => '-',    # Local negative sign
    INT_FRAC_DIGITS    => '2',    # Default Intl. precision
    FRAC_DIGITS        => '2',    # Local precision
    P_CS_PRECEDES      => '1',    # Currency symbol location
    P_SEP_BY_SPACE     => '0',    # Space between Currency and value
    N_CS_PRECEDES      => '1',    # Negative version of above
    N_SEP_BY_SPACE     => '0',    # Negative version of above
    P_SIGN_POSN        => '1',    # Position of positive sign
    N_SIGN_POSN        => '1',    # Position of negative sign
  }

See chart below for how the various sign character and location settings
interact.

Each of the formatting parameters can be individually changed at the object
or class (global) level; if an object is currently sharing the global format,
all the global parameters will be copied prior to setting the overrided
parameters.  For example:

    $dollars = Math::Currency->new(1000); # inherits default US format
    $dollars->format('CURRENCY_SYMBOL',' Bucks'); # now has its own format
    $dollars->format('P_CS_PRECEDES',0); # now has its own format
    print $dollars; # displays as "1000 Bucks"

Or you can also set individual elements of the current global format:

    Math::Currency->format('CURRENCY_SYMBOL',' Bucks'); # global changed

The [NP]_SIGN_POSN parameter determines how positive and negative signs are
displayed.  [NP]_CS_PRECEEDS determines where the currency symbol is shown.
[NP]_SEP_BY_SPACE determines whether the currency symbol cuddles the value
or not.  The following table shows the relationship between these three
parameters:

                                               p_sep_by_space
                                         0          1          2

 p_cs_precedes = 0   p_sign_posn = 0    (1.25$)    (1.25 $)   (1.25 $)
                     p_sign_posn = 1    +1.25$     +1.25 $    +1.25 $
                     p_sign_posn = 2     1.25$+     1.25 $+    1.25$ +
                     p_sign_posn = 3     1.25+$     1.25 +$    1.25+ $
                     p_sign_posn = 4     1.25$+     1.25 $+    1.25$ +

 p_cs_precedes = 1   p_sign_posn = 0   ($1.25)   ($ 1.25)   ($ 1.25)
                     p_sign_posn = 1   +$1.25    +$ 1.25    + $1.25
                     p_sign_posn = 2    $1.25+    $ 1.25+     $1.25 +
                     p_sign_posn = 3   +$1.25    +$ 1.25    + $1.25
                     p_sign_posn = 4   $+1.25    $+ 1.25    $ +1.25

(the negative variants are similar).

=head2 Additional Object Methods

There are times when you would like to take a Math::Currency object and use
it with some other module or external agent which doesn't understand the
currency formatting.  

=over 4

=item $m->as_float - bare floating point notation without currency formatting

When storing the value into a database, you often need a string which
corresponds to the value of the currency as a floating point number, but
without the special currency formatting.  That is what this object method
produces.  Be sure and use e.g. DECIMAL(10,2) in MySQL, to ensure that you
don't have any floating point rounding issues going from/to the database.

=item $m->as_int - bare integer number of "minimum value" 

Some US credit card gateways require all transactions to be expressed in
pennies (because their software isn't running Math::Currency!).  This
object method returns an integer value that corresponds to the currency
value multiplied by 10 to the power of the number of decimal places of
precision.  Essentially, this expresses the currency amount in the smallest
discrete value allowed with that currency, so for currency expressed in 
dollars, this method returns the same value in pennies.

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-Math-Currency@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

John Peacock <jpeacock@cpan.org>

=head1 SEE ALSO

 perl(1).
 perllocale
 Math::BigFloat
 Math::BigInt

=cut
