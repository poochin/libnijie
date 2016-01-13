#!/usr/bin/env perl
use strict;
use utf8;

# 指定したユーザのブックマーク済みのイラストを全て保存します。

use File::Basename qw(basename);
use Path::Class qw(file dir);
use LWP::UserAgent;

use Encode;

use libnijie;

my $ua = new LWP::UserAgent;

my $nijie = new libnijie;

my $email = '';  # ログインに使用するメールアドレス
my $pass  = '';  # ログインに使用するパスワード

my $user_id = 21590;  # ブックマークのユーザID

$nijie->login($email, $pass);

my @bookmarks = $nijie->get_user_bookmarks($user_id);

my $bookmark_count = scalar @bookmarks;
my $current_count = 1;

my %counter = {};

foreach my $bookmark (@bookmarks) {
    print STDERR encode('utf-8', "${current_count} / ${bookmark_count} 件の処理中\n");

    my $m_id = $bookmark->{member_id};

    if (! defined $counter{ $m_id } ) {
        $counter{ $m_id } = 1;
    }
    else {
        $counter{ $m_id }++;
    }

    my $illust_info = $nijie->get_illust_page_info($bookmark->{illust_id});
    my $ua = new LWP::UserAgent;

    my @image_urls    = @{ $illust_info->{image_urls} };
    my $illust_id     = $illust_info->{illust_id};
    my $illust_title  = $illust_info->{illust_title};

    $illust_title =~ s/\///g;

    my $dir = dir('./save', "${illust_id}_${illust_title}");
    $dir->mkpath;

    print STDERR '  Download: ', $illust_info->{illust_title}, "\n";
    
    foreach my $url (@image_urls) {
        my $basename = basename $url;
        my $path = file($dir, $basename);

        print STDERR "    save: ${url} to \n";
        print STDERR "          " . $path->stringify . "\n";
        $ua->get($url, ':content_file' => ( decode('utf-8', $path->stringify) ));
    }

    print "\n";
    $current_count++;
}


