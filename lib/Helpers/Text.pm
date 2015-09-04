package Helpers::Text;
use common::sense;
use POSIX qw(strftime);
use Mojo::Util qw(trim);

use Film;
use Functions;

sub setup {
    my ($name, $self) = @_;

    # форматирование текста
    $self->app->helper( 'process_text'      => \&process_text );
    $self->app->helper( 'process_bbcode'    => \&process_bbcode );
    $self->app->helper( 'in_quota'          => \&in_quota );
    $self->app->helper( 'remove_tags'       => \&remove_tags );
    $self->app->helper( 'number'            => \&number );

    # дата и время
    $self->app->helper( 'format_date'        => \&format_date );
    $self->app->helper( 'format_datetime'    => \&format_datetime );
    $self->app->helper( 'user_timer_convert' => \&user_timer_convert );
    $self->app->helper( 'date_extract_year'  => \&date_extract_year );
    $self->app->helper( 'format_datetime_admin'  => \&format_datetime_admin );

    # форматирование текста (особые случаи)
    $self->app->helper( 'process_text_news'        => \&process_text_news );
    $self->app->helper( 'process_text_article'     => \&process_text_article );
    $self->app->helper( 'process_text_award'       => \&process_text_award );
    $self->app->helper( 'process_text_contest'     => \&process_text_contest );
    $self->app->helper( 'process_text_contestwork' => \&process_text_contestwork );
    $self->app->helper( 'process_text_blog_topic'  => \&process_text_blog_topic );
    $self->app->helper( 'process_text_person_sites'  => \&process_text_person_sites );
}

# обработка текста: разбивка на абзацы, удаление переносов строк, замена кавычек и тире
sub process_text {
    my ($self, $message, $make_para, $allow_bbcode) = @_;

    return '' unless $message;

    # разбивка на абзацы и удаление переносов строк
    if ($make_para) {
        $message =~ s/(([^\n]+))/<p>$1<\/p>\n/ig;
        $message =~ s/\n//g;
    }

    # замена кавычек вначале и вконце строк
    $message =~ s/^\"/«/g;
    $message =~ s/\"$/»/g;
    $message =~ s/([\s\r\n\-\,\:\+\[\(\{])\"/$1«/gs;
    $message =~ s/\"([\s\-\,\.\?\:\+\]\)\}\r\n\<])/»$1/gs;
    $message =~ s/([^=])\"([абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯA-Za-z0-9\!\?\.])/$1«$2/g;
    $message =~ s/([абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯA-Za-z0-9\!\?\.])\"/$1»/g;

    # замена тире и дефисов
    $message =~ s/([\s\]])\xad([\s\[])/$1-$2/gs; # дефис
    $message =~ s/([\s\]])\x2d([\s\[])/$1—$2/gs; # короткое тире
    $message =~ s/([\s\]])\x96([\s\[])/$1—$2/gs; # среднее тире
    $message =~ s/([\s\]])\x97([\s\[])/$1—$2/gs; # длинное тире

    if ($allow_bbcode) {
        $message = BBQ->new->parse($message);
    }

    return $message;
}

# обработка BB-кодов
sub process_bbcode {
    my ($self, $text, $set) = @_;

    my $bbq = $set ? BBQ->new(set => $set) : BBQ->new;

    return $bbq->parse($text);
}

# кавычки вокруг всего текста
sub in_quota {
    my ($self, $str) = @_;
    $str = '«' . $str if $str !~ /^\«/;
    $str = $str . '»' if $str !~ /\»$/;
    return $str;
}

# удаление всех тэгов
sub remove_tags {
    my ($self, $message) = @_;

    $message =~ s/\[[a-z]{1,8}=[^\]]{1,256}\]//ig;
    $message =~ s/\[(\/)?[a-z]{1,8}\]//ig;

    return $message;
}

# обработка чисел
sub number {
    my ($self, $num, $str1, $str2, $str3) = @_;
    my $val = $num % 100;

    return $num .' '. $str3 if $val > 10 && $val < 20;
    $val = $num % 10;

    if ( $val == 1 ) {
        return $num .' '. $str1;
    }
    elsif ( $val > 1 && $val < 5 ) {
        return $num .' '. $str2;
    }
    else {
        return $num .' '. $str3;
    }
}

# форматирование даты в форматах: 21 июня 1989 г., июнь 1989 г., 1989 г., 21 июня.
sub format_date {
    my ($self, $date) = @_;
    my @months = @{$self->config->{months}};
    my @months_rp = @{$self->config->{months_rp}};

    $date =~ s/\s.*//;  # удаление времени из даты
    $date =~ s/\-00//g; # удаление нулей из даты

    if ($date =~ /^(\d{4})$/) {
        $date = "$1 г.";
    }
    elsif ($date =~ /^(\d{4})-(\d{2})$/) {
        $date = "$months[$2] $1 г.";
    }
    elsif ( $date =~ /^0000-(\d{2})-(\d{2})$/ ) {
        $date = int($2) . " $months_rp[$1]";
    }
    elsif ( $date =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $date = int($3) . " $months_rp[$2] $1 г.";
    }

    return $date;
}

# форматирование даты и времени, коррекции часового пояса уже должны быть внесены
# аналог старой функции Functions::DateToString и Functions::DateToStringShort
# TODO: не работает с часовыми поясами
sub format_datetime {
    my ($self, $date, $is_short) = @_;
    my @months_rp = @{$self->config->{months_rp}};

    my $f_date = $date;
    if ( $date =~ /^(\d{4})\-(\d{2})\-(\d{2}) (\d{2})\:(\d{2})\:(\d{2})$/ ) {
        my $today = strftime("%Y%m%d", localtime(time));
        my $year = strftime("%Y", localtime(time));
        my $yesterday = strftime("%Y%m%d", localtime(time-60*60*24));
        my $yesterday2 = strftime("%Y%m%d", localtime(time-60*60*24*2));

        if ("$1$2$3" eq $today) {
            unless ($is_short == 2) {
                $f_date = "сегодня в $4:$5";
            }
            else {
                $f_date = "в $4:$5";
            }
        }
        elsif ("$1$2$3" eq $yesterday) {
            $f_date = "вчера в $4:$5";
        }
        elsif ("$1$2$3" eq $yesterday2) {
            $f_date = "позавчера в $4:$5";
        }
        else {
            unless ($is_short == 1) {
                $f_date = int($3) . " " . $months_rp[$2] . " " . ($1 eq $year ? '' : "$1 г. ") . "$4:$5";
            }
            else {
                $f_date = int($3) . " " . $months_rp[$2];
            }
        }
    }

    return $f_date;
}

# вывод в часах и минутах числа в секундах
sub user_timer_convert {
    my ($self, $s) = @_;
    my $m = sprintf("%02d", $s / 60);
    my ( $h, $hh );
    my $mm = " м.";

    if ( $m > 60 ) {
        $h  = sprintf("%2d", $m / 60);
        $hh = " ч. ";
    }

    my $m = sprintf("%02d", $m - ( $h * 60) );
    return "$h$hh$m$mm";

}

# получить год из даты
sub date_extract_year {
    my ($self, $date) = @_;

    $date =~ s/(\d{4})-(\d{2})-(\d{2})/$1/;
    return $date;
}

sub format_datetime_admin {
    my ($self, $date) = @_;

    $date =~ s/^..//;
    $date =~ s/...$//;

    return $date;
}

# обработка текста новости
sub process_text_news {
    my ($self, $message, $news_id, $read_full) = @_;

    # TODO: убрать хардкод
    my $imagedir = $self->config->{imagedir};
    my $imageurl = $self->config->{imageurl};

    # обрабатываем тэг "Читать далее"
    if ( $message =~ /\[readmore\]/i ) {
        if ( $read_full == 1 ) {
            $message =~ s/.*?\[readmore\]\s*(.*?)/$1/im;
        }
        else {
            $message =~ s/(\[readmore\].*?$)//im;
            $message .= "<p><a href='/news$news_id'><b>читать далее &gt;&gt;</b></a></p><br>";
        }
    }

    $message = $self->process_text($message, 1, 0);
    $message = BBQ->new(format => 'news')->parse($message);

    # блок премий
    # while ($message =~ /\[print_contest=([0-9]+)\]/i) {
    #     my $contest = Award::ViewContestSimple($1);
    #     $message =~ s/\[print_contest=([0-9]+)\]/$contest/i
    # }

    # обработка фотографий
    # TODO: переделать работу с фотографиями
    my $i = 0;
    while ( $message =~ /\[PHOTO(\d+)\]/i
            or $message =~ /\[PHOTO(\d+)\:([^\]]+)\]/i
            or $message =~ /\[PHOTO(\d+)CENTER\]/i
            or $message =~ /\[PHOTO(\d+)CENTER:([^\]]+)\]/i
            or $message =~ /\[PHOTO(\d+)LEFT\]/i
            or $message =~ /\[PHOTO(\d+)LEFT:([^\]]+)\]/i
            or $message =~ /\[PHOTO(\d+)RIGHT\]/i
            or $message =~ /\[PHOTO(\d+)RIGHT:([^\]]+)\]/i)
    {
        $i++;
        last if ( $i > 100 );
        my $file = "$imagedir/news/${news_id}_$1";
        my $ext='.jpg';

        if ( -f "$file.jpg" ) {
            $ext = '.jpg';
        }
        elsif ( -f "$file.gif" ) {
            $ext = '.gif';
        }
        elsif ( -f "$file.jpeg" ) {
            $ext = '.jpeg';
        }
        elsif ( -f "$file.bmp" ) {
            $ext = '.bmp';
        }
        elsif ( -f $file ) {
            $ext = '';
        }

        $message =~ s/\[PHOTO(\d+)\]/<img src="$imageurl\/news\/${news_id}_$1$ext" alt='$2' style='margin-left:8px; border: 0' alt=''>/i;
        $message =~ s/\[PHOTO(\d+)\:([^\]]+)\]/<img src="$imageurl\/news\/${news_id}_$1$ext" style='border: 0' alt=''>/ig;
        $message =~ s/\[PHOTO(\d+)CENTER\]/<center><img src="$imageurl\/news\/${news_id}_$1$ext" style='border: 0' alt=''><\/center>/ig;
        $message =~ s/\[PHOTO(\d+)CENTER:([^\]]+)\]/<center><img src="$imageurl\/news\/${news_id}_$1$ext" title='$2' style='border: 0' alt=''><\/center>/ig;
        $message =~ s/\[PHOTO(\d+)LEFT\]/<img src="$imageurl\/news\/${news_id}_$1$ext" style='margin-right:8px;float:left;border:0' alt=''>/ig;
        $message =~ s/\[PHOTO(\d+)LEFT:([^\]]+)\]/<img src="$imageurl\/news\/${news_id}_$1$ext" title='$2'style='margin-right:8px;float:left;border:0' alt=''>/ig;
        $message =~ s/\[PHOTO(\d+)RIGHT\]/<img src="$imageurl\/news\/${news_id}_$1$ext" style='margin-left:8px;float:right;border:0' alt=''>/ig;
        $message =~ s/\[PHOTO(\d+)RIGHT:([^\]]+)\]/<img src="$imageurl\/news\/${news_id}_$1$ext" title='$2' style='margin-left:8px;float:right;border:0' alt=''>/ig;
    }

    return $message;
}

# обработка текста статьи
sub process_text_article {
    my ($self, $text, $article_id) = @_;
    my $imageurl = $self->config->{imageurl};

    # форматирование текста
    $self->process_text($text);

    # обработка прикрепленных фотографий
    $text =~ s/\[PHOTO(\d+)\]/<img src="$imageurl\/articles\/${article_id}_$1" alt='$2'>/ig;
    $text =~ s/\[PHOTO(\d+)\:([^\]]+)\]/<img src="$imageurl\/articles\/${article_id}_$1">/ig;
    $text =~ s/\[PHOTO(\d+)CENTER\]/<center><img src="$imageurl\/articles\/${article_id}_$1" align=$2><\/center>/ig;
    $text =~ s/\[PHOTO(\d+)CENTER:([^\]]+)\]/<center><img src="$imageurl\/articles\/${article_id}_$1" alt='$2'><\/center>/ig;
    $text =~ s/\[PHOTO(\d+)LEFT\]/<img src="$imageurl\/articles\/${article_id}_$1" align=left style='margin-right:10px'>/ig;
    $text =~ s/\[PHOTO(\d+)LEFT:([^\]]+)\]/<img src="$imageurl\/articles\/${article_id}_$1" align=left alt='$2' style='margin-right:10px'>/ig;
    $text =~ s/\[PHOTO(\d+)RIGHT\]/<img src="$imageurl\/articles\/${article_id}_$1" align=right style='margin-right:10px'>/ig;
    $text =~ s/\[PHOTO(\d+)RIGHT:([^\]]+)\]/<img src="$imageurl\/articles\/${article_id}_$1" align=right alt='$2' style='margin-right:10px'>/ig;

    # обработка еще одних фоток
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)(\:(.*?)|)\]/<table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><a href='\/$imageurl\/articles\/${article_id}_$2' title='$4' rel='lightbox'><img src='\/$imageurl\/articles\/${article_id}_$2_sm'><\/a><br>$4<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)CENTER(\:(.*?)|)\]/\<center><table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><a href='\/$imageurl\/$2' title='$4' rel='lightbox'><img src='\/$imageurl\/$2_sm'><\/a><br>$4<\/td><\/tr><\/table><\/center>/gi;
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)(LEFT|RIGHT|)(\:(.*?)|)\]/<table align='$3' style='margin:5px;width:100px'><tr><td class=c style='padding:7px;' align=center><a href='\/$imageurl\/$2' title='$5' rel='lightbox'><img src='\/$imageurl\/$2_sm'><\/a><br>$5<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)(\:(.*?)|)\]/<table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><img src='\/$imageurl\/$2'><br>$4<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)CENTER(\:(.*?)|)\]/\<center><table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><img src='\/$imageurl\/$2'><\/a><br>$4<\/td><\/tr><\/table><\/center>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)(LEFT|RIGHT|)(\:(.*?)|)\]/<table align='$3' style='margin:5px;width:100px'><tr><td class=c style='padding:7px;' align=center><img src='\/$imageurl\/$2'><br>$5<\/td><\/tr><\/table>/gi;

    # TODO: обработка тэга [code]
    # Functions::ProcessTextCode($text);

    # обработка каких-то тэгов
    # TODO: перенести в BBQ
    $text =~ s/\[SUBTITLE\](.+?)\[\/SUBTITLE\]/<div class='t2'>$1<\/div>/ig;
    $text =~ s/\[BIG\](.+?)\[\/BIG\]/<big>$1<\/big>/ig;
    $text =~ s/\[NAME=(.+?)\]/<a name='$1'><\/a>/ig;
    $text =~ s/\[HR\]/<br clear=all><hr size=1 width=80% color=gray><br>/ig;

    return $text;
}

# обработка текста поста в блоге
# TODO: автоматически обрезать текст, если нет тэга [cut]
sub process_text_blog_topic {
    my ($self, $text, $topic_id) = @_;

    $text = $self->process_text($text, 1, 0);
    $text = BBQ->new(format => 'blog')->parse($text);

    return $text;

    my $dir = $self->config->{fileblogurl}."/b$topic_id/img";
    # фотки
    $text =~ s/\[PHOTO(\d+)\]/<img src="$dir\/$1">/ig;
    $text =~ s/\[PHOTO(\d+)\:([^\]]+)\]/<img src="$dir\/$1" alt='$2'>/ig;
    $text =~ s/\[PHOTO(\d+)CENTER\]/<div align=\"center\"><img src="$dir\/$1"><\/div>/ig;
    $text =~ s/\[PHOTO(\d+)CENTER:([^\]]+)\]/<div align=\"center\"><img src="$dir\/$1" alt='$2'><\/div>/ig;
    $text =~ s/\[PHOTO(\d+)LEFT\]/<img src="$dir\/$1" align=left style='margin-right:10px'>/ig;
    $text =~ s/\[PHOTO(\d+)LEFT:([^\]]+)\]/<img src="$dir\/$1" align=left style='margin-right:10px' alt='$2'>/ig;
    $text =~ s/\[PHOTO(\d+)RIGHT\]/<img src="$dir\/$1" align=right style='margin-left:10px'>/ig;
    $text =~ s/\[PHOTO(\d+)RIGHT:([^\]]+)\]/<img src="$dir\/$1" align=right style='margin-left:10px' alt='$2'>/ig;

    # превьюхи
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)(\:(.*?)|)\]/<table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><a href='$dir\/$2' title='$4' rel='lightbox'><img src='$dir\/$2_sm'><\/a><br>$4<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)CENTER(\:(.*?)|)\]/\<center><table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><a href='$dir\/$2' title='$4' rel='lightbox'><img src='$dir\/$2_sm'><\/a><br>$4<\/td><\/tr><\/table><\/center>/gi;
    $text =~ s/\[PHOTO(SMALL|BIG)([0-9]+)(LEFT|RIGHT|)(\:(.*?)|)\]/<table align='$3' style='margin:5px;width:100px'><tr><td class=c style='padding:7px;' align=center><a href='$dir\/$2' title='$5' rel='lightbox'><img src='$dir\/$2_sm'><\/a><br>$5<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)(\:(.*?)|)\]/<table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><img src='$dir\/$2'><br>$4<\/td><\/tr><\/table>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)CENTER(\:(.*?)|)\]/\<center><table style='display:inline-block'><tr><td class=c style='padding:7px;' align=center><img src='$dir\/$2'><\/a><br>$4<\/td><\/tr><\/table><\/center>/gi;
    $text =~ s/\[PHOTO(FRAME|)([0-9]+)(LEFT|RIGHT|)(\:(.*?)|)\]/<table align='$3' style='margin:5px;width:100px'><tr><td class=c style='padding:7px;' align=center><img src='$dir\/$2'><br>$5<\/td><\/tr><\/table>/gi;

    # доп.тэги для авт.колонок

    # TODO: перенести в BBQ
    $text =~ s/\[LINK=\#(.+?)\]/[LINK=\/blogarticle$topic_id\#$1\]/ig;
    $text =~ s/\[NAME=(.+?)\]/<a name='$1'><\/a>/ig;

    while ($text =~ /\[print_film=(\d+)(\:([a-z]+)|)\]/i) {
        my $p = $3 || 'full';
        my $contest = Film::Film($1,$p);
        $contest =~ s/\n//ig;
        $contest =~ s/\s{2,3200}/ /ig;
        $text =~ s/\[print_film=(\d+)(\:([a-z]+)|)\]/$contest/i;
    }

    while ($text =~ /\[fl_film(\d+)(|noframe)\]/i) {
        my $contest = Film::Film($1, 'small');
        $contest =~ s/\n//ig;
        $contest =~ s/\s{2,3200}/ /ig;
        unless ("\L$2" eq "noframe") {
            $contest = "<div style='padding:7px;margin:5px;width:auto;background:url(/img/ico_film.gif) right top no-repeat' class=c>$contest</div>";
        }
        $text =~ s/\[fl_film(\d+)(|noframe)\]/$contest/i;
    }

    while ($text =~ /\[fl_work(\d+)(|noframe)\]/i) {
        my $contest = Functions::PrintOneWork($1);
        $contest =~ s/\n//ig;
        $contest =~ s/\s{2,3200}/ /ig;
        unless ("\L$2" eq "noframe") {
            $contest = "<div style='padding:7px;margin:5px;width:auto;background:url(/img/ico_work.gif) right top no-repeat' class=c>$contest</div>";
        }
        $text =~ s/\[fl_work(\d+)(|noframe)\]/$contest/i;
    }

    while ($text =~ /\[fl_edition(\d+)(|noframe)(|\n\#(.+?))(|\n\:a(\+|)\:(.+?))(|\n\:d(\+|)\:(.+?|\s))\]/i) {
        my $edition_id = trim($1);
        my $noframe = ( trim("\L$2") eq "noframe" ? 1 : 0 );

        my $aplus = $6;
        my $a = $7;
        my $dplus = $9;
        my $d = $10;

        my $contest = Functions::PrintOneEdition($edition_id, $aplus, $a, $dplus, $d);
        $contest =~ s/\n//ig;
        $contest =~ s/\s{2,3200}/ /ig;

        unless ($noframe) {
            $contest = "<div style='padding:7px;margin:5px;width:auto;background:url(/img/ico_edit.gif) right top no-repeat' class=c>$contest</div>";
        }
        $text =~ s/\[fl_edition(\d+)(|noframe)(|\n\#(.+?))(|\n\:a(\+|)\:(.+?))(|\n\:d(\+|)\:(.+?|\s))\]/$contest/i;
    }

    while ( $text =~ /\[code(?:=?(.*?))?\](.+?)\[\/code\]/is ) {
        my $n = $1 || '';
        my $c = $2 || '';
        $c =~ s/\[/&#091;/ig;
        $c =~ s/\]/&#093;/ig;
        $c =~ s/\</&lt;/ig;
        $c =~ s/\>/&gt;/ig;
        $c =~ s/\t/        /ig;
        $text =~ s/\[code(?:=?.*?)?\].+?\[\/code\]/<fieldset class='q pre'><legend>$n<\/legend>$c<\/fieldset>/is;
    }

    return $text;
}

# обработка списка сайтов, связанных с персоной
sub process_text_person_sites {
    my ($self, $sites) = @_;

    $sites =~ s/http\:\/\///g;
    $sites =~ s/https\:\/\///g;

    my ($site_links, $forum_links);
    while ($sites =~ /\[url=(.*)\](.+?)\[\/url\]\s*(\((.*)\))*/g) {
        my $url = $1;
        my $text = $2;
        my $descr = $4;

        if ($url =~ /(vk.com|vkontakte.ru)/) {
            push (@$site_links, { url => $url, text=> $text, icon => 'pl_vk.png', hint => 'ВКонтакте' });
        }
        elsif ($url =~ /livejournal\.(com|ru)/) {
            push (@$site_links, { url => $url, text=> $text, icon => 'pl_livejournal.gif', hint => 'LiveJournal' });
        }
        elsif ($url =~ /twitter.com/) {
            push (@$site_links, { url => $url, text=> $text, icon => 'pl_twitter.png', hint => 'Twitter' });
        }
        elsif ($url =~ /facebook.com/) {
            push (@$site_links, { url => $url, text=> $text, icon => 'pl_facebook.png', hint => 'Facebook' });
        }
        elsif ($url =~ /fantlab\.(ru|org)\/forum/) {
            push (@$forum_links, { url => $url, text=> $text, icon => 'spacer.gif' });
        }
        elsif ($descr =~ /официальный сайт/) {
            push (@$site_links, { url => $url, text=> $text, icon => 'pl_home.png', hint => 'официальный сайт', descr => 'официальный сайт' });
        }
        else {
            push (@$site_links, { url => $url, text=> $text, icon => 'spacer.gif', descr => $descr });
        }
    }

    return ($site_links, $forum_links);
}

1;