#!/usr/bin/perl -w
#
# Copyright (C) 2010, OMBT LLC and Mike A. Rumore
# All rights reserved.
# Contact: Mike A. Rumore, (mike.a.rumore@gmail.com)
#
#
use strict;
#
use FileHandle;
use File::Basename;
use Getopt::Std;
use LWP::Simple;
#
my $cmd = $0;
my $verbose = 0;
#
my $inputfile = '';
my $outputpath = '';
#
my $ylimits = '';
my $plotcmds = '';
#
my $startdate = '';
my $enddate = '';
my $period = 'daily';
#
my $uniqueid = 0;
#
sub shortusage {
	my ($arg0) = @_;
	print <<EOF;

usage: $arg0 [-?|-h] [-V]
	[-i input file]
	[-o [output directory|output file]]
	[-s [mm/dd/yyy|#|#d|#w|#m|#y]]
	[-e [mm/dd/yyy|#|#d|#w|#m|#y]]
	[-y [low:hi|*:hi|low:*|*:*]]
	[-d|-w|-m]
	[-p [type:price[:params][,type:price[:params][...]]]]
	sym1 [sym2 [...]]
where:
	type is from the set: ema, sma, smm, wma, cma, 
		round, sp, can, bb, conv. 

	prices are from the set: high, low, open, close, adjclose. 

	the parameters for each type are:

	type	| parameters
	---------------------------------------------------------------------
	ema	| alpha=X:tick=Y
	sma	| n=X:tick=Y
	smm	| n=X:tick=Y
	wma	| n=X:tick=Y
	cma	| tick=Y
	round	| tick=Y
	sp	| no parameters.
	can	| no parameters.
	conv	| n=N:w1=X1,w2=X2,...,wN=XN:tick=Y
	bb	| mat=M[:alpha=A]:n=X:k=Y:tick=Z

EOF
}
#
sub usage {
	my ($arg0) = @_;
	print <<EOF;

usage: $arg0 [-?|-h] [-V]
	[-i input file]
	[-o [output directory|output file]]
	[-s [mm/dd/yyy|#|#d|#w|#m|#y]]
	[-e [mm/dd/yyy|#|#d|#w|#m|#y]]
	[-y [low:hi|*:hi|low:*|*:*]]
	[-d|-w|-m]
	[-p [type:price[:params][,type:price[:params][...]]]]
	sym1 [sym2 [...]]

where:

	-i input file = path to input data file. the input file was
		written by this script or has the same format.
	-o [output directory|output file] = if the output
		directory is given, then the output file is written
		in the given directory with the name SYMBOL.PERIOD.csv.
		SYMBOL is the given symbol and PERIOD is weekly, daily
		or monthly. default action is to print to stdout.
	-s [mm/dd/yyy|#|#d|#w|#m|#y] = start date for getting data, or days, 
		weeks, months, or years back. default is the previous day.
	-e [mm/dd/yyy|#|#d|#w|#m|#y] = end date for getting data, or days, 
		weeks, months, or years back. default is the previous day.
	-y [low:hi|*:hi|low:*|*:*] = y-axis range limits where '*' means
		to automatically determine limits. auto low and hi is the default.
	-d|-w|-m = get daily or weekly or monthly quotes, the values are mutually
		exclusive. daily is the default.
	-p [type:prices[:params][,type:prices[:params][...]]] = means plot the data 
		for the given list of symbols.
	sym1 [sym2 [...]] = list of symbols to obtain data from yahoo and either
		plot or write the data out.

	the -p plot option consists of a comma-separated list of directions 
	describing the type of data, operations to perform on the data and 
	any required parameters. each string has the form: type:prices:parameters
	where type is one of the following:

	ema = exponential moving average
	sma = simple moving average
	smm = simple moving median
	wma = weighted moving average
	cma = cumulative moving average
	round = simple rounding
	sp = simple plot
	can = candlestick
	bb = bollinger bands
	conv = convolution

	prices is a list of one or more prices to display. it is a 
	plus-separated list of prices with the form: price[+price[...]].
	if more than one price is given, then the prices are added and averaged. 
	for type equal to can (candlestick), the prices can *only* be close 
	or adjclose, not both. for all other types, prices is a plus-separated 
	list of prices from the set: high, low, open, close, adjclose. 

	the last part of the directions is a list of parameters which corresponds
	to the chosen plot type. the parameters for each type are:

	type	| parameters
	---------------------------------------------------------------------
	ema	| alpha=X:tick=Y - exponential moving average with 0 < X < 1 
		| or X > 1, and tick >= 0. tick = 0 means there is NO rounding 
		| to the nearest tick multiple. tick > 0 means round to the 
		| nearest tick multiple. if X > 1, then alpha = 2/(X+1).
	---------------------------------------------------------------------
	sma	| n=X:tick=Y - simple moving average where n > 0 is the
		| number of measurements to average, and tick is the same 
		| as above.
	---------------------------------------------------------------------
	smm	| n=X:tick=Y - simple moving median where n > 1 is the 
		| number of measurements to search for the median, and tick 
		| is the same as above.
	---------------------------------------------------------------------
	wma	| n=X:tick=Y - weighted moving average where n > 0 is the
		| number of measurements to average, and tick is the same 
		| as above.
	---------------------------------------------------------------------
	cma	| tick=Y - cumulative moving average (no parameters). tick 
		| is the same as above.
	---------------------------------------------------------------------
	round	| tick=Y - only round to nearest tick. tick is the same
		| as above.
	---------------------------------------------------------------------
	sp	| simple plot has no parameters.
	---------------------------------------------------------------------
	can	| candle stick plot has not parameters.
	---------------------------------------------------------------------
	conv	| n=N:w1=X1,w2=X2,...,wN=XN:tick=Y - convolution of 
		| N (must be odd) points using constant weights W1, W2, ..., 
		| WN, and tick is the same as above.
	---------------------------------------------------------------------
	bb	| mat=M[:alpha=A]:n=X:k=Y:tick=Z - bollinger bands where M 
		| is the base moving average type, X is the number of days 
		| in the average, Y is the number of standard deviations for 
		| the upper and lower bands, and tick is described above. 
		| M can be any of these: ema, sma, smm, wma, cma, sp, or round. 
		| if mat = ema, then alpha must be given and 0 < A < 1 or 
		| A > 1.  if A > 1, then alpha = 2/(A+1).

EOF
}
#
sub previousworkday {
	my $mday;
	my $mon;
	my $year;
	my $wday;
	my $daysback = 0;
	do {
		$daysback += 1;
		($mday,$mon,$year,$wday) = (localtime (time - $daysback*24*60*60))[3,4,5,6];
	} while ($wday == 0 || $wday == 6);
	return sprintf("%02d/%02d/%04d", $mon+1, $mday, $year+1900);
}
#
sub formatdate {
	my ($type, $intdate) = @_;
	#
	if ($intdate =~ m/^[0-9][0-9]\/[0-9][0-9]\/[0-9]{4}/) {
		return $intdate;
	} elsif ($intdate =~ m/^([0-9\.]+)([dDwWmMyY]){0,1}$/) {
		my $number = ${1};
		my $unittype = ${2};
		if (defined($unittype)) {
			$unittype =~ tr/a-z/A-Z/;
			if ($unittype eq 'W') {
				$number *= 7;
			} elsif ($unittype eq 'M') {
				$number *= 30;
			} elsif ($unittype eq 'Y') {
				$number *= 365;
			}
		}
		my ($mday,$mon,$year) = 
			(localtime(time-$number*24*60*60))[3,4,5];
		return sprintf("%02d/%02d/%04d", $mon+1, $mday, $year+1900);
	} else {
		die "bad ${type} date format: <$intdate>";
		return "";
	}
}
#
sub readinputfile {
	my ($infile, $pcontent) = @_;
	#
	open(INFILE, "<${infile}") or 
		die "unable to open input file ${infile}: $!";
	my (@quotes) = <INFILE>;
	$$pcontent = join("", @quotes);
	close(INFILE); 
	#
	return;
}
#
sub normalize {
	my ($pdata) = @_;
	my @quotes = split(/\n/, $$pdata);
	my $header = $quotes[0];
	splice(@quotes, 0, 1);
	@quotes = reverse(@quotes);
	$$pdata = $header . "\n" . join("\n", @quotes);
}
#
sub queryyahoo {
	my ($symbol, $url, $pcontent) = @_;
	#
	print "Yahoo Query For ${symbol}: ${url}\n" if ($verbose);
	#
	for (my $i=1; $i<=5; $i++) {
		$$pcontent = get $url;
		last if (defined $$pcontent);
		print "Sleep and retry ...\n";
		sleep 1;
	}
	#
	if (defined $$pcontent) {
		normalize($pcontent);
	}
	#
	return;
}
#
sub getsymboldata {
	my ($symbol, $pcontent) = @_;
	#
	$symbol =~ tr/a-z/A-Z/;
	print "\nProcessing Symbol: $symbol \n";
	#
	my ($smon,$sday,$syear) = split(/\//, $startdate);
	my ($emon,$eday,$eyear) = split(/\//, $enddate);
	my $query = "http://ichart.finance.yahoo.com/table.csv?";
	#
	$sday += 0;
	$eday += 0;
	$smon = sprintf("%02d", $smon-1);
	$emon = sprintf("%02d", $emon-1);
	#
	$query .= "s=${symbol}";
	$query .= "&a=${smon}&b=${sday}&c=${syear}";
	$query .= "&d=${emon}&e=${eday}&f=${eyear}";
	#
	if ($period eq "weekly") {
		$query .= "&g=w";
	} elsif ($period eq "monthly") {
		$query .= "&g=m";
	} else {
		# daily is default
		$query .= "&g=d";
	}
	#
	queryyahoo($symbol, $query, $pcontent);
	#
	return;
}
#
sub writedata {
	my ($symbol, $data) = @_;
	#
	my $outfile = $outputpath;
	if ( -d "$outputpath") {
		$outfile = "${outputpath}/${symbol}.${period}.csv";
	} 
	print "${symbol} Data Output File: ${outfile}\n";
	#
	open(OUTFILE, ">${outfile}") or
		die "unable to open output file ${outfile}: $!";
	print OUTFILE $data;
	close(OUTFILE); 
	#
	return;
}
#
sub initplotcmds {
	my ($symbol, $data) = @_;
	#
	my $plotinitcmd = 'set term x11;';
	$plotinitcmd .= 'set xdata time;';
	$plotinitcmd .= 'set timefmt "%Y-%m-%d";';
	$plotinitcmd .= 'set datafile separator ",";';
	$plotinitcmd .= "set yrange [${ylimits}];" if ($ylimits ne '');
	$plotinitcmd .= 'set xlabel "Date: YY/MM/DD";';
	$plotinitcmd .= 'set ylabel "Price: $";';
	$plotinitcmd .= "set title 'Data for ${symbol}';";
	$plotinitcmd .= 'set multiplot;';
	#
	return $plotinitcmd;
}
#
sub execgnuplotcmd {
	my ($plotcmd) = @_;
	#
	open (GP, "|/usr/bin/gnuplot -persist") or die "no gnuplot";
	GP->autoflush(1);
	print GP $plotcmd;
	print GP "\n";
	close GP;
	#
	return;
}
#
sub parsedata {
	my ($data, $pallprices) = @_;
	#
	my @quotes = split(/\n/, $data);
	splice(@quotes, 0, 1);
	#
	# Date,Open,High,Low,Close,Volume,Adj Close
	$$pallprices{date} = ();
	$$pallprices{open} = ();
	$$pallprices{high} = ();
	$$pallprices{low} = ();
	$$pallprices{close} = ();
	$$pallprices{volume} = ();
	$$pallprices{adjclose} = ();
	#
	foreach my $prices (@quotes) {
		print "PRICES: $prices \n" if ($verbose);
		my (@onedayprices) = split(/,/, $prices);
		push @{$$pallprices{date}}, $onedayprices[0];
		push @{$$pallprices{open}}, $onedayprices[1];
		push @{$$pallprices{high}}, $onedayprices[2];
		push @{$$pallprices{low}}, $onedayprices[3];
		push @{$$pallprices{close}}, $onedayprices[4];
		push @{$$pallprices{volume}}, $onedayprices[5];
		push @{$$pallprices{adjclose}}, $onedayprices[6];
	}
	#
	return;
}
#
sub combineprices {
	my ($pcombinedprices, $pallprices, $ndata, $pricestr) = @_;
	#
	for (my $i=0; $i<$ndata; $i++) {
		$pcombinedprices->[$i] = 0;
	}
	#
	my @prices = split(/\+/, $pricestr);
	my $nprices = scalar @prices;
	foreach my $price (@prices) {
		my $pdata = $pallprices->{$price};
		for (my $i=0; $i<$ndata; $i++) {
			$pcombinedprices->[$i] += $pdata->[$i]/$nprices;
		}
	}
}
#
sub copy {
	my ($psmoothed, $pdata) = @_;
	@{$psmoothed} =  @{$pdata};
}
#
my %bb_matypes = (
	"ema" => \&exponential_moving_average,
	"sma" => \&simple_moving_average,
	"smm" => \&simple_moving_median,
	"wma" => \&weighted_moving_average,
	"cma" => \&cumulative_moving_average,
	"round" => \&round_only,
);
#
sub bollinger_bands {
	my ($psmoothed, $pdata, $href) = @_;
	#
	die "bb: missing mat parameter." unless (exists($href->{mat}));
	die "bb: missing n parameter." unless (exists($href->{n}));
	die "bb: missing k parameter." unless (exists($href->{k}));
	die "bb: missing tick parameter." unless (exists($href->{tick}));
	#
	my $matype = $href->{mat};
	my $n = $href->{n};
	my $k = $href->{k};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	die "$matype is unknown." unless (exists($bb_matypes{$matype}));
	#
	my @madata = ();
	$href->{tick} = 0;
	&{$bb_matypes{$matype}}(\@madata, $pdata, $href);
	$href->{tick} = $tick;
	#
	my $sum = 0;
	for (my $i=0; $i<$n; $i++) {
		my $diff = $pdata->[$i] - $madata[$n-1];
		$sum += $diff * $diff;
	}
	my $sd2 = $sum/$n;
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	# backfill using what we have
	for (my $i=0; $i<$n; $i++) {
		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
	}
	#
	for (my $i=$n; $i<$nd; $i++) {
		my $sum = 0;
		for (my $j=0; $j<$n; $j++) {
			my $diff = $pdata->[$i-$j] - $madata[$i];
			$sum += $diff * $diff;
		}
		my $sd2 = $sum/$n;
		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
	}
	#
	return;
}
#
sub exponential_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	die "ema: missing alpha parameter." unless (exists($href->{alpha}));
	die "ema: missing tick parameter." unless (exists($href->{tick}));
	#
	my $alpha = $href->{alpha};
	if ($alpha > 1.0) {
		$alpha = 2/($alpha+1);
	}
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $ema = $pdata->[0];
	$psmoothed->[0] = &{${rounding}}($ema, $tick);
	for (my $i=1; $i<$nd; $i++) {
		$ema = $alpha*$pdata->[$i] + (1.0-$alpha)*$ema;
		$psmoothed->[$i] = &{${rounding}}($ema, $tick);
	}
	#
	return;
}
#
sub simple_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	die "sma: missing n parameter." unless (exists($href->{n}));
	die "sma: missing tick parameter." unless (exists($href->{tick}));
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $sum = 0;
	for (my $i=0; $i<$n; $i++) {
		$sum += $pdata->[$i];
	}
	my $sma = $sum/$n;
	#
	$psmoothed->[$n-1] = &{${rounding}}($sma, $tick);
	for (my $i=$n; $i<$nd; $i++) {
		$sma = $sma - $pdata->[$i-$n]/$n + $pdata->[$i]/$n;
		$psmoothed->[$i] = &{${rounding}}($sma, $tick);
	}
	#
	return;
}
#
sub simple_moving_median {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	die "smm: missing n parameter." unless (exists($href->{n}));
	die "smm: missing tick parameter." unless (exists($href->{tick}));
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	for (my $i=$n; $i<$nd; $i++) {
		my @unsorted = @{$pdata}[($i-$n) .. ($i-1)];
		my @sorted = sort { $a <=> $b } @unsorted;
		my $smm = $sorted[int($n/2+0.5)];
		$psmoothed->[$i] = &{${rounding}}($smm, $tick);
	}
	#
	return;
}
#
sub weighted_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	copy($psmoothed, $pdata);
	#
	die "wma: missing n parameter." unless (exists($href->{n}));
	die "wma: missing tick parameter." unless (exists($href->{tick}));
	#
	my $n = $href->{n};
	my $tick = $href->{tick};
	my $divisor = ${n}*(${n}+1);
	$divisor = ($divisor-($divisor%2))/2;
	my $nd = scalar @{$pdata};
	#
	return if ($nd <= $n);
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $total = 0;
	my $numerator = 0;
	for (my $i=0; $i<$n; $i++) {
		$total += $pdata->[$i];
		$numerator += ($i+1)*$pdata->[$i];
	}
	my $wma = $numerator/$divisor;
	#
	$psmoothed->[$n-1] = &{${rounding}}($wma, $tick);
	for (my $i=$n; $i<$nd; $i++) {
		$total = $total - $pdata->[$i-$n] + $pdata->[$i];
		$numerator = $numerator + $n*$pdata->[$i] - $total;
		$wma = $numerator/$divisor;
		$psmoothed->[$i] = &{${rounding}}($wma, $tick);
	}
	#
	return;
}
#
sub cumulative_moving_average {
	my ($psmoothed, $pdata, $href) = @_;
	#
	die "cma: missing tick parameter." unless (exists($href->{tick}));
	#
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	my $cma = $pdata->[0];
	$psmoothed->[0] = &{${rounding}}($cma, $tick);
	for (my $i=1; $i<$nd; $i++) {
		$cma = $cma + ($pdata->[$i] - $cma)/($i+1);
		$psmoothed->[$i] = &{${rounding}}($cma, $tick);
	}
	#
	return;
}
#
sub round_only {
	my ($psmoothed, $pdata, $href) = @_;
	#
	die "round: missing tick parameter." unless (exists($href->{tick}));
	#
	my $tick = $href->{tick};
	my $nd = scalar @{$pdata};
	#
	my $rounding = sub { return shift; };
	if ($tick > 0) {
		$rounding = sub { 
			my ($x, $tick) = @_;
			return int(($x+($tick/2.0))/$tick)*$tick;
		};
	}
	#
	for (my $i=0; $i<$nd; $i++) {
		$psmoothed->[$i] = &{${rounding}}($pdata->[$i], $tick);
	}
	return;
}
#
sub naive_convolution {
	my ($psmoothed, $pdata, $href) = @_;
	copy($psmoothed, $pdata);
	return;
}
#
#sub bollinger_bands_plot {
#	my ($psmoothed, $pdata, $href) = @_;
#	#
#	die "bb: missing matype parameter." unless (exists($href->{matype}));
#	die "bb: missing n parameter." unless (exists($href->{n}));
#	die "bb: missing k parameter." unless (exists($href->{k}));
#	die "bb: missing tick parameter." unless (exists($href->{tick}));
#	#
#	my $matype = $href->{matype};
#	my $n = $href->{n};
#	my $k = $href->{k};
#	my $tick = $href->{tick};
#	my $nd = scalar @{$pdata};
#	#
#	die "$matype is unknown." unless (exists($bb_matypes{$matype}));
#	#
#	my @madata = ();
#	$href->{tick} = 0;
#	&{$bb_matypes{$matype}}(\@madata, $pdata, $href);
#	$href->{tick} = $tick;
#	#
#	my $sum = 0;
#	for (my $i=0; $i<$n; $i++) {
#		my $diff = $pdata->[$i] - $madata[$n-1];
#		$sum += $diff * $diff;
#	}
#	my $sd2 = $sum/$n;
#	#
#	my $rounding = sub { return shift; };
#	if ($tick > 0) {
#		$rounding = sub { 
#			my ($x, $tick) = @_;
#			return int(($x+($tick/2.0))/$tick)*$tick;
#		};
#	}
#	#
#	# backfill using what we have
#	for (my $i=0; $i<$n; $i++) {
#		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
#	}
#	#
#	for (my $i=$n; $i<$nd; $i++) {
#		my $sum = 0;
#		for (my $j=0; $j<$n; $j++) {
#			my $diff = $pdata->[$i-$j] - $madata[$i];
#			$sum += $diff * $diff;
#		}
#		my $sd2 = $sum/$n;
#		$psmoothed->[$i] = &{${rounding}}($madata[$i]+$k*sqrt($sd2), $tick);
#	}
#	#
#	return;
#}
#
sub generateplotcmds {
	my ($prefix, $symbol, $price, $name, $pdates, $pprices) = @_;
	#
	$uniqueid += 1;
	my $tmpfile = "/tmp/${prefix}.smoothed.${symbol}.dat.${uniqueid}.$$";
	print "TMP Smoothed Data File: $tmpfile\n";
	open(TMPFILE, ">${tmpfile}") or die "unable to open output file ${tmpfile}: $!";
	for (my $i=0; $i<scalar @{$pdates}; $i++) {
		print TMPFILE $$pdates[$i] . "," . $$pprices[$i] . "\n";
	}
	close(TMPFILE);
	#
	my $plotcmd = "'${tmpfile}' using 1:2 index 0 title \"${name} - ${price}\" with lines";
	#
	return "$plotcmd";
}
#
my %type_handlers = (
	"ema" => \&exponential_moving_average_plot,
	"sma" => \&simple_moving_average_plot,
	"smm" => \&simple_moving_median_plot,
	"wma" => \&weighted_moving_average_plot,
	"cma" => \&cumulative_moving_average_plot,
	"round" => \&round_only_plot,
	"conv" => \&naive_convolution_plot,
	"bb" => \&bollinger_band_plot,
	"sp" => \&simple_plot,
	"can" => \&candle_stick_plot,
);
#
sub exponential_moving_average_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	exponential_moving_average(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("ema", $symbol, $pricestr, "exponential moving average", $$pallprices{date}, \@smoothedprices);
}
#
sub simple_moving_average_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	simple_moving_average(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("sma", $symbol, $pricestr, "simple moving average", $$pallprices{date}, \@smoothedprices);
}
#
sub simple_moving_median_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	simple_moving_median(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("smm", $symbol, $pricestr, "simple moving median", $$pallprices{date}, \@smoothedprices);
}
#
sub weighted_moving_average_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	weighted_moving_average(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("wma", $symbol, $pricestr, "weighted moving average", $$pallprices{date}, \@smoothedprices);
}
#
sub cumulative_moving_average_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	cumulative_moving_average(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("cma", $symbol, $pricestr, "cumulative moving average", $$pallprices{date}, \@smoothedprices);
}
#
sub round_only_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	round_only(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("ro", $symbol, $pricestr, "round-only", $$pallprices{date}, \@smoothedprices);
}
#
sub naive_convolution_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my @smoothedprices = ();
	naive_convolution(\@smoothedprices, $pcombinedprices, $pparams);
	#
	return generateplotcmds("conv", $symbol, $pricestr, "naive convolution", $$pallprices{date}, \@smoothedprices);
}
#
sub bollinger_band_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	my $matype = $$pparams{mat};
	#
	my @smoothedprices = ();
	bollinger_bands(\@smoothedprices, $pcombinedprices, $pparams);
	my $plotcmd = generateplotcmds("bb+k.${matype}", $symbol, $pricestr, "bollinger band - ${matype}", $$pallprices{date}, \@smoothedprices);
	#
	$plotcmd .= "," . &{$type_handlers{$matype}}($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams);
	#
	@smoothedprices = ();
	$$pparams{k} *= -1;;
	bollinger_bands(\@smoothedprices, $pcombinedprices, $pparams);
	$$pparams{k} *= -1;;
	$plotcmd .= "," . generateplotcmds("bb-k.${matype}", $symbol, $pricestr, "bollinger band - ${matype}", $$pallprices{date}, \@smoothedprices);
	#
	return $plotcmd;
}
#
sub simple_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	return generateplotcmds("sp", $symbol, $pricestr, "plot", $$pallprices{date}, $pcombinedprices);
}
#
sub candle_stick_plot {
	my ($symbol, $pallprices, $pcombinedprices, $pricestr, $pparams) = @_;
	#
	$uniqueid += 1;
	my $tmpfile = "/tmp/can.smoothed.${symbol}.dat.${uniqueid}.$$";
	print "TMP Smoothed Data File: $tmpfile\n";
	#
	open(TMPFILE, ">${tmpfile}") or die "unable to open output file ${tmpfile}: $!";
	for (my $i=0; $i<scalar @{$$pallprices{date}}; $i++) {
		print TMPFILE $$pallprices{date}[$i] . ",";
		print TMPFILE $$pallprices{open}[$i] . ",";
		print TMPFILE $$pallprices{high}[$i] . ",";
		print TMPFILE $$pallprices{low}[$i] . ",";
		print TMPFILE $$pallprices{close}[$i] . ",";
		print TMPFILE $$pallprices{volume}[$i] . ",";
		print TMPFILE $$pallprices{adjclose}[$i] . "\n";
	}
	close(TMPFILE); 
	#
	my $plotcmd = '';
	if ($pricestr eq 'adjclose') {
		$plotcmd = "'${tmpfile}' using 1:2:4:3:7 index 0 title \"adjclose\" with candlesticks";
	} else {
		$plotcmd = "'${tmpfile}' using 1:2:4:3:5 index 0 title \"close\" with candlesticks";
	}
	#
	return $plotcmd;
}
#
sub makeparams {
	my ($pcmds, $pparams) = @_;
	foreach my $cmd (@$pcmds) {
		my ($name,$value) = split(/=/, $cmd);
		$pparams->{$name} = $value;
	}
	return;
}
#
sub genplotcmds {
	my ($symbol, $data, $pallprices, $plotcmd) = @_;
	#
	# type:prices:parameter[,parameter[...]]
	my @cmds = split(/:/, $plotcmd);
	return undef if ((scalar @cmds) < 2);
	#
	my $type = $cmds[0];
	#
	my $pricestr = $cmds[1];
	my @combinedprices = ();
	combineprices(\@combinedprices, $pallprices, scalar @{$$pallprices{date}}, $pricestr);
	#
	splice(@cmds, 0, 2);
	my %params = ();
	makeparams(\@cmds, \%params);
	#
	die "$type handler does not exist." unless (exists($type_handlers{$type}));
	#
	return &{$type_handlers{$type}}($symbol, $pallprices, \@combinedprices, $pricestr, \%params);
}
#
sub plotdata {
	my ($symbol, $data) = @_;
	#
	my %allprices = ();
	parsedata($data, \%allprices);
	#
	my $prefix = "plot ";
	my $gnuplotcmds = initplotcmds($symbol, $data);
	foreach my $plotcmd (split(/,/, $plotcmds)) {
		my $gnuplotcmd = genplotcmds($symbol, $data, \%allprices, $plotcmd);
		if ($gnuplotcmd eq "") {
			print "\nERROR: plot of $symbol failed.\nSkipping it.\n";
			return;
		}
		$gnuplotcmds .= $prefix . $gnuplotcmd;
		$prefix = ",";
	}
	execgnuplotcmd($gnuplotcmds);
	#
	return;
}
#
sub handledata {
	my ($symbol, $content) = @_;
	#
	my $usedefault = 1;
	if (!defined ${content}) {
		print "\nNO DATA FOR ${symbol}\n";
		return;
	}
	if ($outputpath ne '') {
		$usedefault = 0;
		writedata($symbol, $content);
	}
	if ($plotcmds ne '') {
		$usedefault = 0;
		plotdata($symbol, $content);
	}
	if ($usedefault) {
		print "\nDATA for $symbol: " . $content . "\n";
	}
	#
	return;
}
#
$startdate = previousworkday();
$enddate = previousworkday();
$period = 'daily';
#
my %opts;
if (getopts('?hVi:o:s:e:y:dwmp:', \%opts) != 1) {
	usage($cmd);
	exit 2;
}
#
foreach my $opt (%opts) {
	if ($opt eq "h") {
		shortusage($cmd);
		exit 0;
	} elsif ($opt eq "?") {
		usage($cmd);
		exit 0;
	} elsif ($opt eq "V") {
		$verbose = 1;
	} elsif ($opt eq "i") {
		$inputfile = $opts{$opt};
	} elsif ($opt eq "o") {
		$outputpath = $opts{$opt};
	} elsif ($opt eq "s") {
		$startdate = $opts{$opt};
	} elsif ($opt eq "e") {
		$enddate = $opts{$opt};
	} elsif ($opt eq "y") {
		$ylimits = $opts{$opt};
	} elsif ($opt eq "d") {
		$period = "daily";
	} elsif ($opt eq "w") {
		$period = "weekly";
	} elsif ($opt eq "m") {
		$period = "monthly";
	} elsif ($opt eq "p") {
		$plotcmds = $opts{$opt};
	}
}
#
$startdate = formatdate('start', $startdate);
$enddate = formatdate('end', $enddate);
#
if ($inputfile ne '') {
	my $content = '';
	readinputfile($inputfile, \$content);
	handledata($inputfile, $content);
} else {
	if (scalar(@ARGV) == 0) {
		print "\nNo symbols given.\n";
		shortusage($cmd);
		exit 2;
	}
	#
	print "\n";
	print "Start Date: ${startdate}\n";
	print "End   Date: ${enddate}\n";
	#
	foreach my $symbol (@ARGV) {
		$symbol =~ tr/a-z/A-Z/;
		my $content = '';
		getsymboldata($symbol, \$content);
		handledata($symbol, $content);
	}
}
#
exit 0;
