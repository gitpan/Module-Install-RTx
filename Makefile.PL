# $File: //member/autrijus/Module-Install-RTx/Makefile.PL $ $Author: autrijus $
# $Revision: #3 $ $Change: 9317 $ $DateTime: 2003/12/15 05:10:12 $

use inc::Module::Install;

name	    ('Module-Install-RTx');
abstract    ('RT extension installer');
version_from('lib/Module/Install/RTx.pm');
requires    ('Module::Install::Admin' => 0.29);
license	    ('perl');

&WriteAll( check_nmake => 0, sign => 1 );
