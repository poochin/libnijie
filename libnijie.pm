#!/usr/bin/env perl
package libnijie;

use strict;
use utf8;

use Encode;

use XML::LibXML;
use XML::LibXML::QuerySelector;

use WWW::Curl::Easy;
use WWW::Curl::Form;

my $cookie_path = 'curl_cookie.txt';

my $CRLF = "\015\012";

# プロトタイプ宣言
sub path_to_user_id;

sub new {
    my $class = shift;
    my $name  = shift;

    my $curl  = new WWW::Curl::Easy;
    my $curlf = new WWW::Curl::Form;

    return bless {
        name  => $name,
        curl  => $curl,
        curlf => $curlf,
    }, $class;
}

# (self, email, password) => (return_code)
sub login {
    my $self = shift;
    my ($email, $pass) = @_;

    my $url = 'https://nijie.info/login_int.php';
    my $response_body;

    my $curl  = $self->{curl};
    my $curlf = $self->{curlf};

    $curlf->formadd('email',    $email);
    $curlf->formadd('password', $pass);
    $curlf->formadd('save',     'on');

    $curl->setopt(CURLOPT_HEADER,    1);
    $curl->setopt(CURLOPT_POST,      1);
    $curl->setopt(CURLOPT_HTTPPOST,  $curlf);
    $curl->setopt(CURLOPT_COOKIEJAR, $cookie_path);
    $curl->setopt(CURLOPT_URL,       $url);
    $curl->setopt(CURLOPT_FILE,     \$response_body);

    if ($curl->perform() != 0 ) {
        print STDERR "Failed :" . $curl->errbuf . "\n";
        return 1;
    } $curl->cleanup();

    return 0;
}

# (self, illust_id) => (illust_page_obj)
sub get_illust_page_info {
    my $self = shift;
    my $illust_id = shift;

    return $self->parse_illust_page($self->fetch_illust_page($illust_id));
}

# (self, string) => ({})
sub parse_illust_page {
    my $self = shift;
    my $html_str = shift;

    my $doc = parse_html_string($html_str);

    # 同人ページはレイアウトが異なるため、別処理を返す
    if ($doc->querySelector('#dojin_left')) {
        return $self->parse_dojin_page($html_str);
    }

    my $member_id   = toUtf8($doc->querySelector('.mozamoza')->getAttribute('user_id'));
    my $member_name = toUtf8($doc->querySelector('.user_icon img')->getAttribute('alt'));

    my $is_following   = (!!$doc->querySelector('.bookmark-user'));
    my $is_bookmarking = (!!$doc->querySelector('#bukuma'));

    my $illust_id    = toUtf8($doc->querySelector('.mozamoza')->getAttribute('illust_id'));
    my $illust_title = toUtf8($doc->querySelector('.illust_title')->textContent);
    my $description  = toUtf8($doc->querySelector('#view-honbun .m-bottom15:last-child')->textContent);

    my @image_urls =
        map correct_nijie_url(),
        map trim_small_light(),
        map { $_->getAttribute('src') } ($doc->querySelectorAll('#gallery .mozamoza'));

    my @tags = map toUtf8(), (map { $_->textContent } $doc->querySelectorAll('.tag_name'));

    my $fapped_count = int(toUtf8($doc->querySelector('#nuita_cnt')->textContent));
    my $good_count   = int(toUtf8($doc->querySelector('#good_cnt')->textContent));
    my $view_count   = int(toUtf8($doc->querySelector('#js_view_count')->textContent));

    my $next_illust_elem = $doc->querySelector('a#nextIllust');
    my $next_illust_id;
    my $next_illust_title;
    if ($next_illust_elem) {
        $next_illust_id = path_to_illust_id($next_illust_elem->getAttribute('href'));
        $next_illust_title = toUtf8(querySelector($next_illust_elem, 'img')->getAttribute('alt'));
    }

    my $back_illust_elem = $doc->querySelector('a#backIllust');
    my $back_illust_id;
    my $back_illust_title;
    if ($back_illust_elem) {
        $back_illust_id = path_to_illust_id($back_illust_elem->getAttribute('href'));
        $back_illust_title = toUtf8(querySelector($back_illust_elem, 'img')->getAttribute('alt'));
    }

    return {
        illust_id         =>  $illust_id,
        illust_title      =>  $illust_title,
        member_id         =>  $member_id,
        member_name       =>  $member_name,
        is_following      => ($is_following   ? 1 : 0),
        is_bookmarking    => ($is_bookmarking ? 1 : 0),
        next_illust_id    =>  $next_illust_id,
        next_illust_title =>  $next_illust_title,
        back_illust_id    =>  $back_illust_id,
        back_illust_title =>  $back_illust_title,
        image_urls        => \@image_urls,
        description       =>  $description,
        tags              => \@tags,
        fapped_count      =>  $fapped_count,
        good_count        =>  $good_count,
        view_count        =>  $view_count,
    };
}

# (self, string) => ({})
sub parse_dojin_page {
    my $self = shift;
    my $html_str = shift;

    my $doc = parse_html_string($html_str);

    my $member_id   = toUtf8($doc->querySelector('.mozamoza')->getAttribute('user_id'));
    my $member_name = toUtf8($doc->querySelector('#dojin_left  .right .text span')->textContent);

    my $is_following   = 0;
    my $is_bookmarking = (!!$doc->querySelector('.bookmark_button.button_orange'));

    my $illust_id    = toUtf8($doc->querySelector('.mozamoza')->getAttribute('illust_id'));
    my $illust_title = toUtf8($doc->querySelector('#dojin_header .title')->textContent);
    my $description  = toUtf8($doc->querySelector('#dojin_text > p:last-child')->textContent);

    my @image_urls =
        map correct_nijie_url(),
        map trim_sample_path(),
        map { $_->getAttribute('src') }
        $doc->querySelectorAll('.dojin_gallery img');

    my @tags =
        map toUtf8(),
        map { $_->textContent }
        $doc->querySelectorAll('#tag .tag');

    my $fapped_count = int(toUtf8($doc->querySelector('#nuita_cnt')->textContent));
    my $good_count   = int(toUtf8($doc->querySelector('#good_cnt')->textContent));
    my $view_count   = int(toUtf8($doc->querySelector('#js_view_count')->textContent));

    my $next_illust_elem = $doc->querySelector('a#nextIllust');
    my $next_illust_id;
    my $next_illust_title;
    if ($next_illust_elem) {
        $next_illust_id = path_to_illust_id($next_illust_elem->getAttribute('href'));
        $next_illust_title = toUtf8(querySelector($next_illust_elem, 'img')->getAttribute('alt'));
    }

    my $back_illust_elem = $doc->querySelector('a#backIllust');
    my $back_illust_id;
    my $back_illust_title;
    if ($back_illust_elem) {
        $back_illust_id = path_to_illust_id($back_illust_elem->getAttribute('href'));
        $back_illust_title = toUtf8(querySelector($back_illust_elem, 'img')->getAttribute('alt'));
    }


    return {
        illust_id         =>  $illust_id,
        illust_title      =>  $illust_title,
        member_id         =>  $member_id,
        member_name       =>  $member_name,
        is_following      => ($is_following   ? 1 : 0),  # 取得できない
        is_bookmarking    => ($is_bookmarking ? 1 : 0),
        next_illust_id    =>  $next_illust_id,
        next_illust_title =>  $next_illust_title,
        back_illust_id    =>  $back_illust_id,
        back_illust_title =>  $back_illust_title,
        image_urls        => \@image_urls,
        description       =>  $description,
        tags              => \@tags,
        fapped_count      =>  $fapped_count,
        good_count        =>  $good_count,
        view_count        =>  $view_count,
    };
}


# (self, illust_id) => ()
sub fetch_illust_page {
    my $self = shift;
    my $illust_id = shift;

    my $url = 'http://nijie.info/view.php?id=' . $illust_id;

    my $response = $self->fetch_page($url);

    return $response->{body};
}


# 処理は結構長いです
sub get_user_info {
    my $self = shift;
    my $user_id = shift;

    # TODO: 後で取得用コードを書く
    my $member_name = "";

    # 勲章情報の取得
    my @user_emblems = $self->get_user_emblems($user_id);

    # フォロー一覧を取得
    my @following_members = $self->get_user_following($user_id);

    # お気に入り一覧を取得
    my @bookmarks = $self->get_user_bookmarks($user_id);

    # イラスト一覧を取得
    my @illusts = $self->get_user_illusts($user_id);

    # 同人一覧を取得
    my @dojin_illusts = $self->get_user_dojins($user_id);

    # お題一覧を取得
    my @odais = $self->get_user_odais($user_id);

    return {
        id                => $user_id,
        name              => $member_name,
        emblems           => \@user_emblems,
        following_members => \@following_members,
        bookmarks         => \@bookmarks,
        illusts           => \@illusts,
        dojin_illusts     => \@dojin_illusts,
        odais             => \@odais,
    };
}

# (self, user_id) => ([emblems])
sub get_user_emblems {
    my $self = shift;
    my $user_id = shift;

    my $emblem_url = 'https://nijie.info/members_emblem.php?id=' . $user_id;
    my $emblem_elem = parse_html_string($self->fetch_page($emblem_url)->{body});
    my @user_emblems =
        map { 
            split(/(?<=章)\s/);
        }
        grep { querySelector($_, 'img')->getAttribute('alt') ne '未取得'; }
        querySelectorAll($emblem_elem, '.nijie-emblem');

    return @user_emblems;
}

# (self, user_id) => ([user_id])
sub get_user_following {
    my $self = shift;
    my $user_id = shift;

    my @following_members = ();

    my $following_count = $self->get_user_following_count($user_id);

    my $page_max = int($following_count / 50) + 1;

    my $following_url_base = 'https://nijie.info/user_like_view.php?id=' . $user_id . '&p=';

    for (my $i = 1; $i <= $page_max; $i++) {
        my $following_url = $following_url_base . $i;
        my $following_page_elem = parse_html_string($self->fetch_page($following_url)->{body});

        my @page_members = 
            map { 
                {
                    member_id   => path_to_user_id($_->getAttribute('href')),
                    member_name => toUtf8(querySelector($_, 'img')->getAttribute('alt')),
                };
            }
            querySelectorAll($following_page_elem, '.nijie-okini a');

        push(@following_members, @page_members);
    }

    return @following_members;
}

# (self, user_id) => (int)
sub get_user_following_count {
    my $self = shift;
    my $user_id = shift;

    my $following_url = 'https://nijie.info/user_like_view.php?id=' . $user_id;

    my $following_page_elem = parse_html_string($self->fetch_page($following_url)->{body});

    my $following_count = int(toUtf8(querySelector($following_page_elem, 'h4 em')->textContent));

    return $following_count;
}

# (self, user_id) => ([{}])
sub get_user_bookmarks {
    my $self = shift;
    my $user_id = shift;

    my @bookmarks = ();

    my $bookmark_count = $self->get_user_bookmark_count($user_id);

    print STDERR toUtf8($bookmark_count . "件\n");

    my $page_max = int($bookmark_count / 48) + 1;

    my $bookmark_url_base = 'https://nijie.info/user_like_illust_view.php?id=' . $user_id . '&p=';

    for (my $i = 1; $i <= $page_max; $i++) {
        my $url = $bookmark_url_base . $i;
        my $bookmark_page_elem = parse_html_string($self->fetch_page($url)->{body});

        my @page_bookmarks = 
            map {
                my $img = querySelector($_, 'img');

                {
                    illust_title => toUtf8($_->getAttribute('title')),
                    illust_id    => toUtf8($img->getAttribute('illust_id')),
                    member_id    => toUtf8($img->getAttribute('user_id')),
                }
            }
            querySelectorAll($bookmark_page_elem, '.nijiedao > a');

        push (@bookmarks, @page_bookmarks);
    }

    return @bookmarks;
}

# (self, user_id) => (int)
sub get_user_bookmark_count {
    my $self = shift;
    my $user_id = shift;

    my $bookmark_url = 'https://nijie.info/user_like_illust_view.php?id=' . $user_id;

    my $bookmark_page_elem = parse_html_string($self->fetch_page($bookmark_url)->{body});

    my $bookmark_count = int(toUtf8(querySelector($bookmark_page_elem, '.mem-indent em')->textContent));

    return $bookmark_count;
}


# (self, user_id) => ([{}])
sub get_user_illusts {
    my $self = shift;
    my $user_id = shift;

    my $illust_url = 'https://nijie.info/members_illust.php?id=' . $user_id;

    my $illust_page_elem = parse_html_string($self->fetch_page($illust_url)->{body});

    my @user_illusts = 
        map {
            my $img = querySelector($_, 'img');

            {
                illust_id    => toUtf8($img->getAttribute('illust_id')),
                illust_title => toUtf8($img->getAttribute('alt')),
                member_id    => toUtf8($img->getAttribute('user_id')),
            }
        }
        $illust_page_elem->querySelectorAll('.nijiedao');

    return @user_illusts;
}


# (self, user_id) => ([{}])
sub get_user_dojins {
    my $self = shift;
    my $user_id = shift;

    my $dojin_url = 'https://nijie.info/members_dojin.php?id=' . $user_id;

    my $dojin_page_elem = parse_html_string($self->fetch_page($dojin_url)->{body});

    my @user_dojins =
        map {
            my $img = querySelector($_, 'img');

            {
                illust_id    => toUtf8($img->getAttribute('illust_id')),
                illust_title => toUtf8($img->getAttribute('alt')),
                member_id    => toUtf8($img->getAttribute('user_id')),
            }
        }
        $dojin_page_elem->querySelectorAll('.nijiedao');

    return @user_dojins;
}

# (self, user_id) => ([{}])
sub get_user_odais {
    my $self = shift;
    my $user_id = shift;

    my $odai_url = 'https://nijie.info/members_odai.php?id=' . $user_id;

    my $odai_page_elem = parse_html_string($self->fetch_page($odai_url)->{body});

    my @user_odais = 
        map {
            {
                illust_id    => path_to_illust_id($_->getAttribute('href')),
                illust_title => toUtf8(querySelector($_, '.title')->textContent),
                member_id    => $user_id,
                res_count    => toUtf8(querySelector($_, '.res')->textContent),
            }
        }
        $odai_page_elem->querySelectorAll('#members_odai > a');

    return @user_odais;
}

# (self, url) => ({header, body})
sub fetch_page {
    my $self = shift;
    my $url  = shift;

    my $response_body;

    my $curl = $self->{curl};

    $curl->setopt(CURLOPT_HEADER,    1);
    $curl->setopt(CURLOPT_COOKIEJAR, $cookie_path);
    $curl->setopt(CURLOPT_URL,       $url);
    $curl->setopt(CURLOPT_FILE,     \$response_body);

    if ($curl->perform() != 0 ) {
        print STDERR "Failed :" . $curl->errbuf . "\n";
        return 1;
    }

    $curl->cleanup();

    my @response_separator =split(/$CRLF$CRLF/m, $response_body);

    # HTTP 100 Continue を外す
    # TODO: 100 Continue かどうかをチェックする
    shift @response_separator;

    my $header = shift @response_separator;
    my $body   = join("$CRLF$CRLF", @response_separator);

    return {
        header => $header,
        body   => $body,
    };
}


# (string) => (int)
sub path_to_illust_id {
    # my ($path) = ($_) || @_;
    my $path = shift;

    $path =~ /(?<=id=)\d+$/;
    return $&;
}

# (string) => (int)
sub path_to_user_id {
    # my ($path) = ($_) || @_;
    my $path = shift;

    $path =~ /(?<=id=)\d+$/;
    return $&;
}

# querySelectorへのショートハンド
# (elem, selector) => (elem)
sub querySelector {
    return XML::LibXML::QuerySelector::querySelector(@_);
}

# querySelectorAllへのショートハンド
# (elem, selector) => ([elem])
sub querySelectorAll {
    return XML::LibXML::QuerySelector::querySelectorAll(@_);
}

# parse_html_stringへのショートハンド
# (html_str) => (html document object)
sub parse_html_string {
    my $html_str = shift;

    my $parser = new XML::LibXML;
    $parser->recover_silently(1);

    return $parser->parse_html_string($html_str);
}

# encode('utf-8', ...) へのショートハンド
# (string) => (string)
sub toUtf8 {
    # my ($str) = ($_) || @_;
    my $str = shift;

    return encode('utf-8', $str);
}

# (string) => (string)
sub correct_nijie_url {
    my ($yet_another_url) = ($_) || @_;

    my $addition;

    # ドメインを追加
    if (!($yet_another_url =~ /nijie\.info/)) {
        $addition = '//.nijie.info';
    }

    # http schemeを追加
    if (!($yet_another_url =~ /^http:/)) {
        $addition = 'http:' . $addition;
    }

    return ($addition . $yet_another_url);
}

# (string) => (string)
sub trim_small_light {
    my ($path) = ($_) || @_;
    $path =~ s/small_light[^\/]+\///g;
    $path;
}

# (string) => (string);
sub trim_sample_path {
    my ($path) = ($_) || @_;

    $path =~ s/(?<=dojin_sam)\/sam//g;
    $path;
}



1;

