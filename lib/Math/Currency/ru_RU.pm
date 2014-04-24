package Math::Currency::ru_RU;
use utf8;
use Exporter;
use Math::Currency qw($LC_MONETARY $FORMAT);
use vars qw($VERSION @ISA $LANG);

$VERSION = 0.47;
$LANG    = 'ru_RU';
@ISA     = qw(Exporter Math::Currency);

$LC_MONETARY->{ru_RU} = {
    INT_CURR_SYMBOL   => 'RUB ',
    CURRENCY_SYMBOL   => 'руб.',
    MON_DECIMAL_POINT => ',',
    MON_THOUSANDS_SEP => ' ',
    MON_GROUPING      => '3',
    POSITIVE_SIGN     => '',
    NEGATIVE_SIGN     => '-',
    INT_FRAC_DIGITS   => '2',
    FRAC_DIGITS       => '2',
    P_CS_PRECEDES     => '0',
    P_SEP_BY_SPACE    => '1',
    N_CS_PRECEDES     => '1',
    N_SEP_BY_SPACE    => '0',
    P_SIGN_POSN       => '1',
    N_SIGN_POSN       => '1',
};

1;