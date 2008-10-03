#!/usr/bin/perl

#
# Reads in a fortran module file
# parses the declared variables (only default types)
# and generates a subroutine that dumps them out
# distinguishing scalars static and allocatable arrays.
# Arrays are written as FILE.arrays and scalars like
# FILE.scalars
#
# Syntax: dumpf90modvars.pl  module_file routine_file module_name
#
# Author: S. Sagmeister | 19/06/2006 | GPL
#

use strict;
use warnings;
use File::Basename;

# input file
my $infile = shift;
open(INFILE, $infile) or die "Can't open input file $infile: $!";

# output file
my $outfile_nam = shift;
my $outfile = ">$outfile_nam";
open(OUTFILE, $outfile) or die "Can't open output file $outfile: $!";

# variables for printing to file
# module name
my $modnam = shift;
my $routine_symb = "dump_$modnam";
my $date = `date`;
$date =~ s/\n//;
my$scriptnam = fileparse $0;

print
"
Scanning input file $infile for variable declarations
and generating output file $outfile_nam:
";

# write prolog code
print " * Writing prolog to $outfile_nam...\n";
print OUTFILE 
"
!
! Automatically generated by $scriptnam - script
! Date: $date
!

subroutine $routine_symb(fnam,fu_in)
use $modnam
implicit none
! file name to dump into
character(*), intent(in) :: fnam
! file unit
integer, intent(in) :: fu_in(2)

! local variables
integer :: fu_scal, fu_arr
character(256) :: fnam_scalars, fnam_arrays

! set file units
fu_scal = fu_in(1)
fu_arr  = fu_in(2)

! set file names
fnam_scalars = fnam // '.scalars'
fnam_arrays = fnam // '.arrays'

! open file for scalars
open(fu_scal,file=trim(fnam_scalars), action='write', status='replace')

! open file for arrays
open(fu_arr,file=trim(fnam_arrays), action='write', status='replace')

";

my @arrs;
my @scals;
my $varpatt = '[a-zA-Z]+[a-zA-Z0-9_]*';

print " * Writing main part to $outfile_nam...\n";
while (<INFILE>)
{
    # remove comments
    $_ =~ s/!.*//;

    # remove special words
    $_ =~ s/^ *module *.*//;
    $_ =~ s/^ *end.*//;
    $_ =~ s/^ *implicit +.*//;
    $_ =~ s/^ *save.*//;
    $_ =~ s/^ *public.*//;
    $_ =~ s/^ *private.*//;
    $_ =~ s/^ *namelist.*//;
    $_ =~ s/^ *data +.*//;
    
    # if reached contains block skip
    if ($_ =~ /^ *contains */ )
    {
	goto ENDWHILE;
    }

    # case of parameters
    if ( $_ =~ /, *parameter( *|::|,)/ )
    {
	# remove blanks
	$_ =~ s/ *//g;

	# remove :: operator and everything to the left of it
	$_ =~ s/^.*:://g;

	# remove (/ ..... /) contructs in assignments
	$_ =~ s/\(\/[^()]*\/\)//g;

	# match for arrays (workaround below)
	@arrs = ($_ =~ /($varpatt\(([0-9]+,?|[a-zA-Z]+,?)+\)),?/g );
	
	# check again if array
	foreach (@arrs) 
	{ 
	    # workaround for arrays like a(1,22,333) to match 'blabla(...)
            # since I don't know how to match them exactley:
            # here also '333' would appear as matched pattern from above.
	    if ( $_ =~ /\(.*\)/ )
	    {
		$_ =~ s/\(.*\)//;
		#print "static array: $_\n";
		#
		# code fragment
		#
		print OUTFILE
"! static array
write(fu_arr,*) '$_: shape(static):', shape($_), ' data below'
write(fu_arr,*) $_
"
	    }
	}

	# scalars
	@scals = ($_ =~ /$varpatt *=/g );

	foreach (@scals)
	{
	    # remove = from string
	    $_ =~ s/=//g;
	    #print "scalar: $_\n";
	    #
	    # code fragment
	    #
	    print OUTFILE
"! scalar
write(fu_scal,*) '$_: ', $_
"
	}
    }

    # case of allocatable arrays
    elsif ( $_ =~ /, *allocatable( *|::|,)/ )
    {
	# remove :: operator from line
	$_ =~ s/^.*:://g;

	# split
	@arrs = split(/,/,$_);

	foreach (@arrs)
	{
	    # remove : ( and )
	    $_ =~ s/:|\(|\)//g;
	    # check again for regexp
	    if ($_ =~ /($varpatt)/ )
	    {
		#print "allocatable array: $1\n";
		#
		# code fragment
		#
		print OUTFILE
"! allocatable array
if (allocated($1)) then
write(fu_arr,*) '$1: shape(allocatable):', shape($1), ' data below'
write(fu_arr,*) $1
else
write(fu_arr,*) '$1: dimension(allocatable):', size(shape($1)), ': not allocatad'
end if
"
	    }   
	}
    }

    # no :: operator in line
    elsif ( $_ !~ /::/ )
    {
	# remove data type
	$_ =~ s/(integer|real|complex|logical|character)(\( *[a-zA-Z0-9]+ *\))?//g;

	# remove spaces
	$_ =~ s/ *//g;

	# match for arrays (workaround below)
	@arrs = ($_ =~ /($varpatt\(([0-9]+,?|[a-zA-Z]+,?)+\)),?/g );
	
	# check again if array
	foreach (@arrs) 
	{ 
	    # workaround for arrays like a(1,22,333)
	    if ( $_ =~ /\(.*\)/ )
	    {
		$_ =~ s/\(.*\)//;
		#print "static array: $_\n";
		#
		# code fragment
		#
		print OUTFILE
"! static array
write(fu_arr,*) '$_: shape(static):', shape($_), ' data below'
write(fu_arr,*) $_
"
             }
	}
	# scalars
	@scals = ($_ =~ /(^ *$varpatt *$|^ *$varpatt,|,$varpatt,|,$varpatt *$)/g );

	foreach (@scals)
	{
	    # remove commas
	    $_ =~ s/,//g;
	    #print "scalar: $_\n";
	    #
	    # code fragment
	    #
	    print OUTFILE
"! scalar
write(fu_scal,*) '$_: ', $_
"
	}
    }
}

# a label, ok it is a workaround
ENDWHILE:

# write epilog code
print " * Writing epilog to $outfile_nam...\n";
print OUTFILE 
"
! close file for scalars
close(fu_scal)

! close file for arrays
close(fu_arr)

end subroutine $routine_symb

";

# close outfile
close OUTFILE;

print "done.\n\n";

# end of script
