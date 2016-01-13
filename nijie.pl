#!/usr/bin/env perl
use strict;
use utf8;

use libnijie;

my $nijie = new libnijie;

my $email = '';
my $pass  = '';


$nijie->login($email, $pass);
my $user_info = $nijie->get_user_info(21590);


# 同人ページのイラスト情報を取得
# 
# my $illust_info = $nijie->get_illust_page_info(72762);
# foreach my $url (@{ $illust_info->{image_urls} }) {
#     print $url, "\n";
# }


# ユーザ投稿のお題一覧を取得
#
# my @user_illusts = $nijie->get_user_odais(383930);
# foreach my $i_info (@user_illusts) {
#     printf ("%d illusted %s(%d)\n", $i_info->{member_id}, $i_info->{illust_title}, $i_info->{illust_id});
# }


# ユーザの同人一覧を取得する
# 
# my @user_illusts = $nijie->get_user_dojins(3154);
# foreach my $i_info (@user_illusts) {
#     printf ("%d illusted %s(%d)\n", $i_info->{member_id}, $i_info->{illust_title}, $i_info->{illust_id});
# }


# ユーザのイラスト一覧を取得する
#
# my @user_illusts = $nijie->get_user_illusts(3154);
# foreach my $i_info (@user_illusts) {
#     printf ("%d illusted %s(%d)\n", $i_info->{member_id}, $i_info->{illust_title}, $i_info->{illust_id});
# }


# ユーザのブックマークを取得する
# 
# my @bookmarks = $nijie->get_user_bookmarks(21590);
# 
# foreach my $b (@bookmarks) {
#   printf ("%d illusted %s(%d)\n", $b->{member_id}, $b->{illust_title}, $b->{illust_id});
# }


# ユーザがフォローしているメンバーのIDと名前を取得する
#
# my @following_members = $nijie->get_user_following(21590);
# foreach my $member_info (@following_members) {
#     printf ("%8d: %s\n", $member_info->{member_id}, $member_info->{member_name});
# }


# イラスト情報取得
# 
# my $page_info = $nijie->get_illust_page_info(73237);
# 
# foreach my $key (keys(%$page_info)) {
#     if ($page_info->{$key} =~ /^ARRAY/) {
#         print $key, ": ", join(', ', @{ $page_info->{$key} }), "\n";
#     }
#     else {
#         print $key, ": ", $page_info->{$key}, "\n";
#     }
# }

