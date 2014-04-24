use Test::More tests => 5;

BEGIN { use_ok( Math::Currency ); }

use Math::BigFloat;

# For subsequent testing, we need to make sure that format is default US
Math::Currency->format('USD');

my $bf = Math::BigFloat->new("5343.45453");
isa_ok ($bf, 'Math::BigFloat');

my $object = Math::Currency->new("102.23");
isa_ok ($object, 'Math::Currency');

my $rbf = $bf->copy->badd($object);
my $cbf = $object->badd($bf);

is ( $rbf, '5445.6845', '5343.45453 + $102.23 = 5445.6845' );
is ( $cbf, '$5,445.68', '$102.23 + 5343.45453 = $5445.6845' );


