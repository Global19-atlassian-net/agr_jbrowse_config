#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Find::Rule;
#use URI::Escape;

my %mod_mapping ={
    WormBase => 'WormBase/c_elegans_PRJNA13758',
    FlyBase  => 'FlyBase/fruitfly',
    zfin     => 'zfin/zebrafish-11',
    SGD      => 'SGD/yeast',
    RGD      => 'RGD/rat',
    human    => 'human',
};

my ($AWS, $BUCKET, $LOCAL, $REMOTE, $PROFILE,$SKIPFILECOUNT,$SKIPSEQ);

GetOptions(
    'aws=s'         => \$AWS,
    'bucket=s'      => \$BUCKET,
    'local=s'       => \$LOCAL,
    'remote=s'      => \$REMOTE,
    'profile=s'     => \$PROFILE,
    'skipfilecount' => \$SKIPFILECOUNT,
    'skipseq'       => \$SKIPSEQ
) or ( system( 'pod2text', $0 ), exit -1 );

$AWS    ||= '/usr/local/bin/aws';
$BUCKET ||= 'agrjbrowse';
($LOCAL && $REMOTE) or die 'need to supply --local and --remote options';

if ($REMOTE =~ s/\/$//) {
  warn "please leave the trailing slash off the remote path";
}

if ($LOCAL =~ s/\/$//) {
  warn "please leave the trailing slash off the local path";
}


if ($PROFILE) {
    $AWS = "$AWS --profile $PROFILE ";
}

my $REMOTEPATH = "s3://$BUCKET/$REMOTE";

#chdir($LOCAL) or die "unable to cd to $LOCAL";

my (@remotetrack_result, @remotenames_result);
###
#uncomment after the local file globbing is sorted
# @remotetrack_result = `$AWS s3 ls --recursive $REMOTEPATH/tracks |grep -v htaccess`;
# @remotenames_result = `$AWS s3 ls --recursive $REMOTEPATH/names |grep -v htaccess`;

unless ($SKIPFILECOUNT) {
#check tracks
    my @localtrack_result = `ls -Rl $LOCAL/tracks |grep -P "^-"|wc -l`;
    my $remote_count = scalar @remotetrack_result;
    if ($localtrack_result[0] != $remote_count) {
        warn "WARNING: file count differs between local and remote tracks directories\nLOCAL: $localtrack_result[0]\nREMOTE: $remote_count\n";
    }
    else {
        warn "File counts agree in tracks.\n";
    }

#check names
    my @localnames_result = `ls -Rl $LOCAL/names |grep -P "^-"|wc -l`;

    $remote_count = scalar @remotenames_result;
    if ($localnames_result[0] != $remote_count) {
        warn "WARNING: file count differs between local and remote names directories\nLOCAL: $localnames_result[0]\nREMOTE: $remote_count\n";
    }
    else {
        warn "File counts agree in names.\n";
    }
}

warn "starting md5 comparison...\n";

#get local file tree
my @localfiles = File::Find::Rule->in("$LOCAL/tracks/");
push @localfiles, File::Find::Rule->in("$LOCAL/names/");
for my $file (@localfiles)  {
    next if $file =~ /htaccess/;
    my ($root, $stem);
    if ($file =~ /^(.*jbrowse\/data\/)(.*)$/) {
        $root = $1;
        $stem = $2;
        if ($stem =~ /(txt|jsonz|json)$/) {
            my $localstem = my $remotestem = $stem;
            $localstem =~ s/ /\\ /g;
            my ($localmd5) = `md5sum $root$localstem`;        
            $remotestem =~ s/ /%20/g; 
            my $remotemd5 = get_remote_md5($REMOTE . '/' . $remotestem );
            if ($localmd5 ne $remotemd5) {
                warn "$stem didn't match: $localmd5 $remotemd5\n";
            }
        }
        else {
            next;
        }
    }
}
die;

warn $remotetrack_result[0];
warn "\n$remotetrack_result[1]\n";

my (undef,undef,undef,$path1,$path2) = split(/\s+/, $remotetrack_result[0]);
my $path;
if ($path2) {
    $path = "$path1%20$path2";
}
else {
    $path = $path1;
}

my $result = get_remote_md5($path);
warn $result;

exit(0);


sub get_remote_md5 {
    my $path = shift;

    my $url = "https://s3.amazonaws.com/agrjbrowse/$path";

    warn $url;

    my @remote_header = `curl -I $url`;

    my $sum;
    for my $line (@remote_header) {
        if ($line =~ /ETag:\s*"(.*)"/) {
            $sum = $1;
        } 
    }

    die "couldn't get md5 sum for $path\n" unless $sum;

    return $sum;

}