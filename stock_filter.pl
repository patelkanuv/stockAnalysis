#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw (tv_interval gettimeofday);
use Try::Tiny;
use Text::CSV::Simple;
use Getopt::Long;

#filter values, 
#negative value means less than or equal to
#positive value means greater than or equal to

my ($name, $cap, $pb, $pe, $margin, $one_year, $three_year, $five_year, $ten_year); 

GetOptions ( "name=s"   => \$name,    # numeric
             "cap=s"    => \$cap,     # string
             "pe=i"     => \$pe,
             "pb=i"     => \$pb,
             "margin=i" => \$margin,
             "1Y=i"     => \$one_year,
             "3Y=i"     => \$three_year,
             "5Y=i"     => \$five_year,
             "10Y=i"     => \$ten_year)     # 
           or die("Error in command line arguments\n");

my @stock_records       = read_records_file();
my @filtered_results    = filter_records(@stock_records);

print_records(@filtered_results);

sub read_records_file {
    my $parser = Text::CSV::Simple->new();
    $parser->field_map(qw/Name industry MyView price change change_perc volume PE 
                          PB Cap Revenue Profit NetMargin ROE 1M 3M 1Y 3Y 5Y 10Y/);
    my @data = $parser->read_file("Reports/stock_report.csv");
    
    return @data;    
}

sub filter_records {
    my (@records) = @_;
    
    @records    = name_filter($name, @records) if defined $name;
    @records    = cap_filter($cap, @records) if defined $cap;
    @records    = pe_filter($pe, @records) if defined $pe;
    @records    = pb_filter($pb, @records) if defined $pb;
    @records    = margin_filter($margin, @records) if defined $margin;
    @records    = year_filter($one_year, '1Y', @records) if defined $one_year;
    @records    = year_filter($three_year, '3Y', @records) if defined $three_year;
    @records    = year_filter($five_year, '5Y', @records) if defined $five_year;
    @records    = year_filter($ten_year, '10Y', @records) if defined $ten_year;
    
    return @records;    
}

sub name_filter {
    my ($name, @records)    = @_;
    
    my @filtered_records;
    
    foreach my $rec (@records) {
        $rec->{Name} =~ s/^\s+|\s+$//g;
        if($rec->{Name} =~ /$name/gxi) {
            push(@filtered_records, $rec);
        }    
    }
    return @filtered_records; 
}

sub cap_filter {
    my ($cap, @records)    = @_;
    
    my @filtered_records;
    
    foreach my $rec (@records) {
        my $c_name = 'S';
        my $m_cap   = decommify($rec->{Cap});
        if( $m_cap >= 20000) {
            $c_name = 'L';
        }
        elsif ($m_cap  >= 5000 && $m_cap  <= 20000) {
            $c_name = 'M';
        }
        
        if($c_name =~ /$cap/gx) {
            push(@filtered_records, $rec);
        }    
    }
    return @filtered_records; 
}

sub pb_filter {
    my ($pb, @records)    = @_;
    
    return master_filter($pb, 'PB', @records); 
}

sub pe_filter {
    my ($pe, @records)    = @_;
    
    return master_filter($pe, 'PE', @records);
}

sub margin_filter {
    my ($margin, @records)    = @_;
    
    return master_filter($margin, 'NetMargin', @records);
}

sub year_filter {
    my ($year, $year_key, @records)    = @_;
    
    return master_filter($year, $year_key, @records);
}

sub master_filter {
    my($filter_value, $filter_key, @records) = @_;
    
    my @filtered_records;    
    
    if($filter_value < 0) {
        foreach my $rec (@records) {
            my $rec_value   = decommify($rec->{$filter_key});
            if($rec_value <= abs($filter_value) ) {
                push(@filtered_records, $rec);
            }
        }
    }
    else { 
        foreach my $rec (@records) {
            my $rec_value   = decommify($rec->{$filter_key});       
            if($rec_value >= $filter_value ) {
                push(@filtered_records, $rec);
            }    
        }
    }
    
    return @filtered_records;
}

sub print_records {
    my (@records) = @_;
    
    my $header  = sprintf ("\n%-20s %-10s %10s %9s %7s %11s %7s %7s  %12s %9s %7s %7s %7s %7s %7s\n", 
                  "Name", 'Industry','Price  ', 'Change ', 'Ch %', ' Volume', '  PE ', ' PB ', 'M-Cap  ', 'Margin ', "ROE ", "1Y  ", "3Y  ", "5Y  ", "10Y ");
    print $header;
    
    print("-" x 151, "\n");
    if(scalar(@records) == 0) {
        print "No record matches your search\n\n\n";
        return;
    }
    foreach my $rec (@records) {
        next if ($rec->{Name} eq 'Name');
        my $record_line    = sprintf ("%-20s %-10s %10s %9s %5.2f%1s %11s %7s %7s %12s %9s %7s %7s %7s %7s %7s\n", 
            substr($rec->{Name},0,20),
            substr($rec->{industry},0,10),
            $rec->{price},
            $rec->{change},
            decommify($rec->{change_perc}),
            '%',
            $rec->{volume},
            $rec->{PE},
            $rec->{PB},
            $rec->{Cap},
            $rec->{NetMargin},
            $rec->{ROE},
            $rec->{'1Y'},
            $rec->{'3Y'},
            $rec->{'5Y'},
            $rec->{'10Y'}
        );
        print $record_line;
        print("-" x 151, "\n");
    }
}

sub decommify { 
    my ( $number ) = @_;
    $number =~ tr/,|%//d;
  return $number
}
