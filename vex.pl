#! /usr/bin/perl -w

# Copyright 2005 john saylor

# This file is part of vex.

# vex is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# vex is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with vex.  If not, see <http://www.gnu.org/licenses/>.  

use strict;
use lib ( '/home/johns/lib/perl' );

use CGI;
use Text::Template;
use MIDI::Simple;
use IO::File;

my $q = new CGI;
my %params = $q->Vars;

my $template = Text::Template->new (
                                     TYPE => 'FILE',
				     SOURCE => 'vex.html',
				     DELIMITERS => [ '_START', 'END_' ]
                                   );
$T::msg = '';
my $html = '';
if (
     ( ! exists $params{repetitions} )
     ||
     ( ! exists $params{output} )
   )
{
  $T::msg = 'plain';
}
elsif ( $params{repetitions} !~ /^\d+$/ )
{
  $T::msg = 'not an integer: ' . $params{repetitions};
}
elsif (
        ( $params{repetitions} < 16 )
	||
	( $params{repetitions} > 9999 )
      )
{
  $T::msg = 'out of range: ' . $params{repetitions};
}
elsif (
        ( $params{output} ne 'browser' )
	&&
	( $params{output} ne 'file' )
      )
{
  $T::msg = 'unknown format: ' . $params{output} ;
}

if ( $T::msg ne '' )
{
  if ( $T::msg eq 'plain' )
  {
    $T::msg = '';
  }
  
  $html = $template->fill_in ( PACKAGE => 'T' );
  
  if (
       ( ! defined $html )
       ||
       ( length $html < 1 )
     )
  {
    print "Content-type: text/plain\n\n", 
          "ERROR with template: $Text::Template::ERROR";
    exit;
  }
  
  print "Content-type: text/html\n\n$html";
  exit;
}


my $loopCount = $params{repetitions} - 16;

my @cantus = (
                60,
                57,
                61,
                58,
                63,
                55,
                62,
                60,
                63,
                54,
                61,
                53,
                59,
                54,
                63,
                59,
                64,
                64,
                undef
             );

my @voice0 = (
                63,
                65,
                64,
                67,
                66,
                64,
                65,
                69,
                66,
                63,
                64,
                63,
                62,
                63,
                66,
                68,
                67,
                67,
                undef
             );

my @voice1 = (
                69,
                73,
                70,
                73,
                72,
                70,
                71,
                75,
                72,
                69,
                70,
                69,
                68,
                69,
                72,
                74,
                73,
                73,
                undef
             );
	     
my @durations = (	     
                  2,
                  1,
                  1,
                  2,
                  2,
                  1,
                  1,
                  1,
                  1,
                  2,
                  2,
                  1,
                  1,
                  1,
                  1,
                  2,
                  1,
                  2,
                  1
                );


my $score = MIDI::Simple->new_score ();
$score->copyright_text_event ( 'attribution share alike' );
$score->noop ( 'c1' );

&vexBeginning ( $score );

if ( $loopCount )
{
  &vexMiddle ( $score, $loopCount );
}

&vexEnd ( $score );

$score->text_event ( 'erikSatie -> johnCage -> johnSaylor' );

# shouldn't need to write to disk ...
my $filename = sprintf ( "vex_%04d.mid", $loopCount );
$score->write_score ( "/tmp/$filename.$$" );

my $fh = new IO::File "/tmp/$filename.$$", 'r';
my $midi;

while ( <$fh> )
{
  $midi .= $_;
}
$fh->close;
unlink ( "/tmp/$filename.$$" );

if ( $params{output} eq 'file' )
{

  $T::msg = "$filename generated successfully, should download momentarily";
  $html = $template->fill_in ( PACKAGE => 'T' );

  my $boundary = 'HANDROLLED_MIME_BOUNDARY';
  print qq(Content-type: multipart/mixed;boundary="$boundary"\nContent-disposition: attachment\n\n),
        "--$boundary\nContent-type: text/html\nContent-disposition: inline\n\n",
	$html, "\n",
	qq(--$boundary\nContent-type: audio-midi\nContent-disposition: attachment; filename="$filename"\n\n),
	$midi,
	"--$boundary--\n";
	
}
elsif ( $params{output} eq 'browser' )
{
  print qq(Content-type: audio/x-midi\n\n$midi);
}
else
{
  print "Content-type: text/plain\n\nunknown output format: $params{output}\n";
}

exit;


sub vexBeginning
{
  my $score = shift;

  if ( ! defined $score ) { die 'undefined arg passed in' }
  
  my $tempo = 60;
  my $patch = 1;
	     
  $score->set_tempo  ( int ( 60_000_000 / $tempo ) );
  $score->patch_change ( 1, $patch );

  my $velocity = 96;
  my ( $melody, $harmony0, $harmony1, $duration, $durationExtra );

  my $loop = 0;
  while ( $loop < 10 )
  {
  
    my $loopVar = $loop % 5;
  
    my $c;
    for ( $c = 0; $c < scalar @cantus; $c++ )
    {
     
      if ( $durations[ $c ] == 1 )
      {
        # 48 = eighth note
        $duration = 48;
      }
      elsif ( $durations[ $c ] == 2 )
      {
        $duration = 96
      }
      else
      {
        warn 'skipping unknown duration value: ', $durations[ $c ];
        next;
      }
     
      if ( defined $cantus[ $c ] )
      {
        $melody = $cantus[ $c ];
        $harmony0 = $voice0[ $c ];
        $harmony1 = $voice1[ $c ];
      }
      else
      {
        $score->r ( 'd' . $duration );
	next;
      }
  
      # extend pulse & decrease volume arithmetically
      # change instrument transpose out
      # 2nd set
      if ( $loop > 4 )
      {
        $durationExtra += 1;
        $duration += $durationExtra;
  
        $velocity -= 1;

        my $rnd = int rand 3;

	if ( ! $rnd )
	{
          $score->patch_change ( 1, &pickInstrument );
        }

        my ( $intervalOffset, $range );
	
	if ( $loop == 5 )
	{
          $intervalOffset = 12;
	  $range = 2;
	}
	elsif ( $loop == 6 )
        {
          $intervalOffset = 6;
	  $range = 3;
        }
        elsif ( $loop == 7 )
        {
          $intervalOffset = 3;
          $range = 4;
        }
        elsif ( $loop == 8 )
        {
          $intervalOffset = 3;
          $range = 6;
        }
        elsif ( $loop == 9 )
        {
          $intervalOffset = 1;
          $range = 8;
        }

	$melody = &modifyPitch ( $melody, $intervalOffset, $range );
	$harmony0 = &modifyPitch ( $harmony0, $intervalOffset, $range );
	$harmony1 = &modifyPitch ( $harmony1, $intervalOffset, $range );
      }

      # solo cantus
      if ( 
           ( $loopVar == 0 )
           ||
  	   ( $loopVar == 2 )
           ||
  	   ( $loopVar == 4 )
         )
      {
          
        $score->n (
                   'n' . $melody,
  		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 1  )
      {
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 3  )
      {
        $harmony0 = ( $harmony0 - 12 ) % 128;
    
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      else
      {
        warn 'skipping unknown looping control [$loop, $loop % 5, $loopVar]: ',
             join ( ', ', $loop, $loop % 5, $loopVar );
        next;	   
      }
    }
  
    $loop += 1;
  }
  
  return $loop;
}


sub vexMiddle
{
  my $score = shift;
  my $loopCount = shift;

  if ( ! defined $score ) { die 'undefined $score arg passed in' }
  if ( ! defined $loopCount ) { die 'undefined $loopCount arg passed in' }
  if ( $loopCount !~ /^\d+$/ ) { die 'loopCount arg not an integer' }

  my ( $melody, $harmony0, $harmony1, $duration, $rnd );
 
  my $velocity = 64;

  my $velocityData = {
                       max => 112,
		       min => 48,
		       direction => -1,
		       range => 0.05,
		       current => 96
                     };
		
  my $tempoData = {
                    max => 192,
		    min => 24,
		    direction => 1,
		    range => 0.12,
		    current => 40
                  };

  my @intervalOffsets = ( 12, 6, 3, 1 );
  
  $score->set_tempo  ( int ( 60_000_000 / $tempoData->{current} ) );
  
  my $patch = &pickInstrument ();
  $score->patch_change ( 1, $patch );

  my $randomInstrument = 0;
  my $durationExtra = { unit => 0, tally => 0 };
  my $rangeShift = 0;
  
  my $loop = 0;
  while ( $loop < $loopCount )
  {
    
    my $loopVar = $loop % 5;
  
    ## per set changes go here
    if ( ! $loopVar )
    {
      
      $rnd = int rand ( 7 );
      
      if ( $rnd )
      {
        
	# if 0, pick random instrument
	$rnd = int rand ( 11 );

	if ( $rnd )
	{
	  $randomInstrument = 0;
	  $patch = &pickInstrument ( $loop );
	}
	else
	{
	  $randomInstrument = 1;
	  $patch = &pickInstrument ( );
	}
	
        # patch change actually happens below in per loop section
      }
      
      $rnd = int rand ( 5 );
      
      if ( $rnd )
      {
        &modifyParam ( $tempoData );
        $score->set_tempo  ( int ( 60_000_000 / $tempoData->{modified} ) );
	$tempoData->{current} = delete $tempoData->{modified};
      }
    }
  
    ## per loop changes go here

    $rnd = int rand ( 11 );

    if ( ! $rnd )
    {
      $durationExtra->{unit} = ( int rand ( 5 ) ) - 2;
    }
    else
    {
      $durationExtra = { unit => 0, tally => 0 };
    }
    
    $rnd = int rand ( 5 );

    if ( ! $rnd )
    {
      # 4 octaves [up or down] possible
      $rangeShift += ( ( int rand ( 9 ) ) - 4 ) * 12;
    }
    else
    {
      $rangeShift = 0;
    }

    my $patchData = { orig => $patch,
                      offsetFromStart => $patch % 8 };

    if ( ! $randomInstrument )
    {

      $rnd = int rand ( 2 );

      if ( $rnd )
      {
        $patchData->{startOfFamily} = $patch - $patchData->{offsetFromStart};
        $patchData->{modified} = ( int rand ( 8 ) ) + $patchData->{startOfFamily};
    
        $score->patch_change ( 1, $patchData->{modified} );
      }
    }

    my $rndLimit;
    
    my $c;
    for ( $c = 0; $c < scalar @cantus; $c++ )
    {
     
      if ( $durations[ $c ] == 1 )
      {
        # 48 = eighth note
        $duration = 48;
      }
      elsif ( $durations[ $c ] == 2 )
      {
        $duration = 96
      }
      else
      {
        warn 'skipping unknown duration value: ', $durations[ $c ];
        next;
      }

      if ( $durationExtra->{unit} != 0 )
      {
	$durationExtra->{tally} += $durationExtra->{unit};
        $duration += $durationExtra->{tally};

	if ( $duration < 6 )
	{
	  $duration = 6;
	}
      }
     
      if ( defined $cantus[ $c ] )
      {
        $melody = ( $cantus[ $c ] + $rangeShift ) % 128;
        $harmony0 = ( $voice0[ $c ] + $rangeShift ) % 128;
        $harmony1 = ( $voice1[ $c ] + $rangeShift ) % 128;
      }
      else
      {
        $score->r ( 'd' . $duration );
	next;
      }
  
      ## per note changes go here
      if ( $randomInstrument )
      {
        $rnd = int rand ( 5 );

	if ( ! $rnd )
	{
          my $inst = &pickInstrument ();
	  $score->patch_change ( 1, $inst );
	}
      }

      $rndLimit = sprintf ( "%d", ( $loopCount / ( $loop + 1 ) ) * 19 );
      $rnd = int rand ( $rndLimit );

      if ( ! $rnd )
      {
        $rnd = ( int rand ( 3 ) ) + 1;
        $duration *= $rnd;
      }
      
      $rnd = int rand ( 7 );
      
      if ( ! $rnd )
      {
        &modifyParam ( $velocityData );
        $velocity = $velocityData->{modified};
	$velocityData->{current} = delete $velocityData->{modified};
      }

      $rnd = int rand ( 13 );
        
      # punch note up or down
      if ( ! $rnd )
      {	
	my $punch = ( int rand ( 49 ) ) - 24;
	$velocity += $punch;
      }
        
      $velocity = $velocity % 128;
      
      # moves toward 1 as loops continue
      $rndLimit = sprintf ( "%d", $loopCount / ( $loop + 1 ) );
      $rnd = int rand ( $rndLimit );

      if ( ! $rnd )
      {
        $rndLimit = sprintf ( "%d", ( $loop * ( scalar @intervalOffsets ) ) / $loopCount );
        my $idx = int rand ( $rndLimit );

	$rndLimit = sprintf ( "%d", ( $loop * 9 ) / $loopCount );
	my $range = int rand ( $rndLimit );
	
        if ( $range )
	{
	  $melody = &modifyPitch ( $melody, $intervalOffsets[ $idx ], $range );
	
	  $rnd = int rand ( 3 );     
	  if ( $rnd )
	  {
	    $harmony0 = &modifyPitch ( $harmony0, $intervalOffsets[ $idx ], $range );
        
	    $rnd = int rand ( 5 );
	    if ( $rnd )
	    {
	      $harmony1 = &modifyPitch ( $harmony1, $intervalOffsets[ $idx ], $range );
	    }
	  }
	}
      }
      
      # solo cantus
      if ( 
           ( $loopVar == 0 )
           ||
  	   ( $loopVar == 2 )
           ||
  	   ( $loopVar == 4 )
         )
      {
          
        $score->n (
                   'n' . $melody,
  		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 1  )
      {
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 3  )
      {
        $harmony0 = ( $harmony0 - 12 ) % 128;
    
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      else
      {
        warn 'skipping unknown looping control [$loop, $loop % 5, $loopVar]: ',
             join ( ', ', $loop, $loop % 5, $loopVar );
        next;	   
      }
    }
  
    $loop += 1;
  }
  
  return $loop;
}

sub vexEnd
{
  my $score = shift;

  if ( ! defined $score ) { die 'undefined arg passed in' }
  
  # reset
  my $tempo = 60;
  my $patch = 1;
	     
  $score->set_tempo  ( int ( 60_000_000 / $tempo ) );
  $score->patch_change ( 1, $patch );

  # 'silent' loop
  my $duration = 0;
  foreach ( @durations )
  {
    $duration += ( $_ * 48 );
  }
  
  $score->r ( 'd' . $duration );
  
  my $velocity = 96;
  my $loop = 0;
  my ( $melody, $harmony0, $harmony1 );

  while ( $loop < 5 )
  {
  
    my $loopVar = $loop % 5;
    
    my $c;
    for ( $c = 0; $c < scalar @cantus; $c++ )
    {
     
      if ( $durations[ $c ] == 1 )
      {
        # 48 = eighth note
        $duration = 48;
      }
      elsif ( $durations[ $c ] == 2 )
      {
        $duration = 96
      }
      else
      {
        warn 'skipping unknown duration value: ', $durations[ $c ];
        next;
      }
     
      if ( defined $cantus[ $c ] )
      {
        $melody = $cantus[ $c ]; 
        $harmony0 = $voice0[ $c ];
        $harmony1 = $voice1[ $c ];
      }
      else
      {
        $score->r ( 'd' . $duration );
	next;
      }
  
      # solo cantus
      if ( 
           ( $loopVar == 0 )
           ||
  	   ( $loopVar == 2 )
           ||
  	   ( $loopVar == 4 )
         )
      {
          
        $score->n (
                   'n' . $melody,
  		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 1  )
      {
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      elsif ( $loopVar == 3  )
      {
        $harmony0 = ( $harmony0 - 12 ) % 128;
    
        $score->n (
                   'n' . $melody,
    		   'n' . $harmony0,
    		   'n' . $harmony1,
    		   'd' . $duration,
  		   'v' . $velocity
                 );
      }
      else
      {
        warn 'skipping unknown looping control [$loop, $loop % 5, $loopVar]: ',
             join ( ', ', $loop, $loop % 5, $loopVar );
        next;	   
      }
    }
  
    $loop += 1;
  }
  
  return $loop;
}


# $instNum = pickInstrument ( [$loop] );
#  optional arg is loop number: for ordered progression
#  if no loop, just picks random
sub pickInstrument
{
  my $loop = shift;

  my $patch;
  
  if ( defined $loop )
  {
 
    my $instFamStart = ( $loop % 8 ) + 1;
    my $inst = int rand 8;
    $patch = ( ( $instFamStart * 16 ) - 15 ) + $inst;
    
    # choice of 2 families [8 groups each] of instruments
    my $rnd = int rand 2;
    if ( $rnd )
    {
      $patch += 8;
    }
  }
  else 
  {
    $patch = int rand 128;
    $patch += 1;
  }

  return $patch;
} 

# $newPitchNumber = &modifyPitch ( $oldPitchNumber, $intervalOffset, $range )
# $intervalOffset 
#   value, possible substitutions:
#      12, octave
#       6, tritone
#       4, major third
#       3, minor third
#       2, whole step
#       1, half step
# $range is how many possible octaves to offset  
sub modifyPitch
{

  my $startVal = shift || 0;
  my $intervalOffset = shift || 0;
  my $range = shift || 0;

  my $octaveDivisions = 0;
  
  if ( $intervalOffset )
  {
    $octaveDivisions = sprintf ( "%d", 12 / $intervalOffset );
  }
  else
  {
    return $startVal;
  }

  my $rndLimit = $octaveDivisions * $range;
  my $rnd = int rand ( $rndLimit );

  my $offset = 0;
  
  if ( $range > 0 )
  {
    $offset = $rnd - ( int $rndLimit / 2 );
    
    # multiply by reciprocal to get back to chromatic scale
    $offset *= ( 12 / $octaveDivisions );
  }
  
  my $transVal = $startVal + $offset;
  
  return $transVal % 128;
}


# &modifyParam ( $hashRef )
#   changes value gradually
# $hashRef MUST have these keys
#   max [maximum possible value
#   min [minimum possible value
#   direction [integer; 
#              if > 0, value will increase (to max); 
#              if < 0, value will decrease (to min)]
#   range [multiplier to get scope of new values,
#          1 means use complete range of current value
#          0 means no change]
#   current [current value]
# returns modified value [also sets 'modified' in hash ref to be new value]  
sub modifyParam
{
  my $hashRef = shift;

  if ( ref $hashRef ne 'HASH' )
  {
    warn 'arg is not hash reference: ', ref $hashRef;
    return undef;
  }

  my @requiredKeys = qw(
                         max
			 min
			 direction
			 range
			 current
		       );
  
  foreach my $key ( @requiredKeys )
  {
    if ( ! exists $hashRef->{ $key } )
    {
      warn "$key not found in hash ref, cannot process";
      return undef;
    }
  }

  my $rndLimit = sprintf ( "%d", $hashRef->{current} * $hashRef->{range} );
  my $offset = int rand ( $rndLimit );

  if ( $hashRef->{direction} < 0 )
  {
    $offset *= -1;
  }
  
  my $modified = $hashRef->{current} + $offset;

  if ( $modified < $hashRef->{min} )
  {
    $modified = $hashRef->{min};
    $hashRef->{direction} = 1;
  }
  elsif ( $modified > $hashRef->{max} )
  {
    $modified = $hashRef->{max};
    $hashRef->{direction} = -1;
  }
  
  $hashRef->{modified} = $modified;
  
  return $modified;
}

