package Helpers::Default;
use common::sense;
use POSIX qw(strftime ceil);
use XML::Simple;

sub setup {
    my ($name, $self) = @_;

    # издания
    $self->app->helper( 'edition_normal' => \&edition_normal );
    $self->app->helper( 'edition_full'   => \&edition_full );

    # премии
    $self->app->helper( 'award_item'   => \&award_item );
    $self->app->helper( 'contest_item' => \&contest_item );

    # Layout
    $self->app->helper( 'pm_friend_title' => \&pm_friend_title );
    $self->app->helper( 'pm_friend_icon'  => \&pm_friend_icon );

    $self->app->helper( 'forum_topic_icon'  => \&forum_topic_icon );
    $self->app->helper( 'blog_topic_comments_read'   => \&blog_topic_comments_read );
    $self->app->helper( 'work_autor_name'   => \&work_autor_name );
    $self->app->helper( 'print_autor_genre' => \&print_autor_genre );
    $self->app->helper( 'page_links'        => \&page_links );
    $self->app->helper( 'print_response'    => \&print_response );
    $self->app->helper( 'letter_links'      => \&letter_links );

    $self->app->helper( 'print_message'    => \&print_message );

    $self->app->helper( 'user_avatar_block'    => \&user_avatar_block );
    $self->app->helper( 'user_rang_picture'    => \&user_rang_picture );

    $self->app->helper( 'editor_buttons'            => \&editor_buttons );
    $self->app->helper( 'editor_specsymbol_buttons' => \&editor_specsymbol_buttons );
    $self->app->helper( 'editor_navdb_buttons'      => \&editor_navdb_buttons );

    $self->app->helper( 'blogs_naviline'    => \&blogs_naviline );
    $self->app->helper( 'admin_naviline'    => \&admin_naviline );
    #TODO: deprecated
    $self->app->helper( 'referrer'   => \&referrer );
    $self->app->helper( 'render_xml' => \&render_xml );
}

sub render_news_block {
    my $self = shift;

    my $lastnews_array = BD::News->last_news_home();

    $self->stash(lastnewsblock => $lastnews_array);
}

sub forum_topic_icon {
    my ($self, $topic) = @_;

    my $icon_name = $topic->{topic_type_id} == 1 ? 'topic' : 'opros';
    $icon_name = 'pinned' if $topic->{is_pinned} == 1;

    $icon_name .= '-close' if $topic->{is_closed};
    $icon_name .= '-read' if Profile->id and $topic->{unread_count} == 0;

    return $icon_name;
}

# получить ссылку с количеством прочитанных и непрочитанных комментариев для топика
sub blog_topic_comments_read {
    my ($self, $topic) = @_;
    my $unread_comments = $topic->{unread_comments};
    my $comment_count = $topic->{comment_count};

    my $unread_class = $unread_comments > 0 ? 'noreadcomment' : '';
    my $com = $comment_count;
    if ($unread_comments > 0 and $unread_comments != $comment_count) { $com .= ", +$unread_comments"; }

    my $link = "/blogarticle$topic->{topic_id}";
    $link .= "page$topic->{page}" if $topic->{page};
    $link .= $topic->{min_parent_id} > 0 ? "#comment$topic->{min_parent_id}" : '#comments';

    my $text = qq{<a href="$link" class="$unread_class"><nobr>($com)</nobr></a>};

    return $text;
}

# получить имя автора по его work_id
sub work_autor_name {
    my ($self, $work_id, $aslink, $disable_eng, $rod_padeg, $only_eng_name) = @_;
    return unless $work_id;

    $rod_padeg = 0 unless $rod_padeg;

    my $name_field = $rod_padeg == 1 ? 'rusname_rp' : 'rusname';

    my $hr = BD::Work->get_work_autors($work_id);
    my $res = '';

    foreach my $i ('','2','3','4','5') {
        if ($disable_eng != 1) {
            if ($hr->{"autor${i}_name"}) {
                $hr->{"autor${i}_name"} = ""
            }
        }
        elsif ($only_eng_name and $hr->{"autor${i}_name"}) {
            $hr->{"autor${i}_$name_field"} = $hr->{"autor${i}_name"};
            $hr->{"autor${i}_name"} = '';
        }
        else {
            $hr->{"autor${i}_name"} = '';
        }

        if ($hr->{"autor${i}_$name_field"}) {
            if ($aslink and $hr->{"autor${i}_is_opened"} > 0) {
                $res .= ( $i ? ", " : "" ) . "<a href='/autor".$hr->{"autor${i}_id"}."'>".$hr->{"autor${i}_$name_field"}.$hr->{"autor${i}_name"}."</a>";
            }
            elsif ($aslink and Profile->can_add_edit_autors) {
                $res .= ( $i ? ", " : "" ) . "<a href='/autor".$hr->{"autor${i}_id"}."' class=agray>".$hr->{"autor${i}_$name_field"}.$hr->{"autor${i}_name"}."</a>";
            }
            else {
                $res .= ( $i ? ", " : "" ) . $hr->{"autor${i}_$name_field"} . $hr->{"autor${i}_name"};
            }
        }
    }

    $res =~ s/\'\/autor10\'/\'\/autorseries\'/;
    $res =~ s/\'\/autor40\'/\'\/anthologies\'/;
    return $res;
}

# вывод жанров для авторов
sub print_autor_genre {
    my ($self, $wg_name, $ag_count, $ag_total) = @_;

    my $percent10 = sprintf("%.0f", $ag_count * 10 / $ag_total);
    my $percent100 = sprintf("%.2f%%", $ag_count * 100 / $ag_total);

    my $color = '#3178A8';
    my $width1 = $percent10+1;
    my $width2 = 10-$percent10;

    my $image = qq{ <img src="/images/spacer.gif" style='width:${width2}px; height: 5px; border:1px solid $color; border-left:${width1}px solid $color' title='$ag_count из $ag_total ($percent100)'>};
    return "$wg_name $image";
}

# TODO: используется только при авторизации
# TODO: заменить на redirect_url
sub referrer {
    my $c = shift;
    my $link = $c->req->headers->referrer;
    return "/" if $link && $link eq '';

    $link = URI->new($c->req->headers->referrer)->path;
    $link =~ s/^\/(.*?)//;
    return $link;
}

# Layout. иконка возле пользователя
sub pm_friend_icon {
    my ($self, $sex, $is_birthday) = @_;

    # иконка возле пользователя
    my $icon_class;
        $icon_class = 'pm_day' if $is_birthday;

    unless ($icon_class) {
        $icon_class = $sex == 1 ? "pm_m" : "pm_w";
    }

    return $icon_class;
}

# Layout. подсказки к друзьям в блоке личной переписки
sub pm_friend_title {
    my ($self, $online, $is_birthday, $real_name) = @_;

    my $link_title = "";

    if ($real_name) { $link_title .= $real_name }

    if ($online) {
        if ($link_title) { $link_title .= '. ' }
        $link_title .= "Сейчас на сайте";
    }
    
    if ($is_birthday) {
        if ($link_title) { $link_title .= '. ' }
        $link_title = "Сегодня день рождения!";
    }

    return $link_title;
}

# выводит номера страниц
sub page_links {
    my ($self, $total_items, $items_per_page, $current_page, $page_url, $options) = @_;
    my $total_pages = ceil($total_items / $items_per_page);

    $options = {} if (!defined($options));
    
    # обработчики ошибок
    return '' if ($total_items <= $items_per_page);
    $current_page = 1 if (($current_page == 0) && !(defined($options->{all_link}) && ($options->{all_link} eq '1')));
    $current_page = $total_pages if ($current_page > $total_pages);

    my $html_string = "";
    my $url = Mojo::URL->new($page_url);

    for my $page_num (1..$total_pages) {
        # странный алгоритм, который работает
        unless ($page_num <= 5 || $page_num > $total_pages - 5 || abs($page_num - $current_page) < 4) {
            $html_string .= '.';
            next;
        }

        if ($current_page == $page_num) {
            $html_string .= $self->link_to($page_num, $url->query([page => $page_num]), class => 'page-selected');
        }
        else {
            $html_string .= $self->link_to($page_num, $url->query([page => $page_num]));
        }
    }

    if (defined($options->{all_link}) && ($options->{all_link} eq '1')) {
      if ($current_page eq '0') {
        $html_string .= $self->link_to('все', $url->query([page => 0]), class => 'page-selected');
      } else {
        $html_string .= $self->link_to('все', $url->query([page => 0]));
      };
    };
    
    # заменяем точки на троеточия
    $html_string =~ s/\.+/\.\.\. /g;
    $html_string = "<span class='page-links'>$html_string</span>";

    return $html_string;
}

sub render_xml {
    my ($self, $xml_in) = @_;

    my $xs = XML::Simple->new(KeepRoot => 1, NoAttr => 1);
    my $xml_out = $xs->XMLout($xml_in, XMLDecl => qq{<?xml version="1.0" encoding="utf-8"?>});
    $self->render(text => $xml_out, format => 'xml');
}

# вывод изданий (обычный)
# используется на странице автора, произведения, художника, диктора
sub edition_normal {
    my ($self, $edition) = @_;

    my $cover_url = $self->config->{imageurl} . '/editions/small/' . $edition->{edition_id};
    my $correct_color = $self->config->{correct_color}->{$edition->{correct}};

    my $html = qq{
      <div class="edition-block-normal $correct_color">
        <a href="/edition$edition->{edition_id}">
        <img src="$cover_url" alt="$edition->{name}"></a>
        <br>
        <span>$edition->{year} г.</span>
      </div>
    };
}

# вывод издания (расширенный)
# используется на странице серии, издательства
sub edition_full {
    my ($self, $edition, $i) = @_;

    my $autors = $self->process_bbcode($edition->{autors});
    my $edition_name = $self->process_bbcode($edition->{name});
    my $publisher = $self->process_bbcode($edition->{publisher});
    my $description = $self->process_text($edition->{description}, 1, 1);
    my $cover_url = $self->config->{imageurl} . '/editions/small/' . $edition->{edition_id};
    my $correct_color = $self->config->{correct_color}->{$edition->{correct}};

    my $html = qq{
      <table class="edition-block-full">
          <tr>
            <td class="edition-block-cover $correct_color">
              <a href="/edition$edition->{edition_id}"><img src="$cover_url"></a>
            </td>
            <td class="edition-block-descr">
              <div>
                <span>$autors</a></span>
                <span>№$i</span>
                <br clear="all">
              </div>
              <div>
                <p class="edition-block-name"><a href="/edition$edition->{edition_id}"><b>$edition_name</b></a></p>
                <p>$edition->{year} год</p>
                <p>Издательство: $publisher</p>
                <p><b>Описание:</b> $description</p>
              </div>
            </td>
          </tr>
      </table>
    };

    return $html;
}

# элемент премии
# показывается на странице персон, фильмов, издательств
sub award_item {
    my ($self, $award) = @_;

    my $award_icon = $self->config->{imageurl} . '/awards/icons/' . "$award->{award_id}_icon";

    my $award_fullname;
    if ($award->{award_rusname} && $award->{award_name}) {
        $award_fullname = "$award->{award_rusname} / $award->{award_name}, $award->{contest_name}";
    }
    elsif ($award->{award_rusname}) {
        $award_fullname = "$award->{award_rusname}, $award->{contest_name}";
    }
    else {
        $award_fullname = "$award->{award_name}, $award->{contest_name}";
    }

    my $nomi_fullname = $award->{nomi_rusname} || $award->{nomi_name};
    if ($nomi_fullname) {
        $nomi_fullname = "<span> // $nomi_fullname" . ($award->{cw_prefix} ? ". $award->{cw_prefix}" : "") . ($award->{cw_postfix} ? ". $award->{cw_postfix}" : "") . "</span>";
    }

    my $work_fullname;
    if ($award->{work_rusname} && $award->{work_name}) {
        $work_fullname = "<a href='/work$award->{work_id}'>$award->{work_rusname}</a> / <a href='/work$award->{work_id}'>$award->{work_name}</a>";
    }
    elsif ($award->{work_rusname}) {
        $work_fullname = "<a href='/work$award->{work_id}'>$award->{work_rusname}</a>";
    }
    else {
        $work_fullname = "<a href='/work$award->{work_id}'>$award->{work_name}</a>";
    }

    if ($award->{work_year} > 0) {
        $work_fullname .= " ($award->{work_year})";
    }

    my $full_name = "<a href='/award$award->{award_id}#c$award->{contest_id}'>$award_fullname</a>$nomi_fullname".($award->{work_rusname} || $award->{work_name} ? "<br>→ $work_fullname" : "");

    my $nomiclass = qq{ class="} . ($award->{cw_is_winner} != 1 ? "cw_nomi" : "") . ($award->{award_is_opened}  != 1 ? " cw_nomi2" : "") . qq{"};
    if ($nomiclass eq "class=\"\"") { $nomiclass = ""; }

    my $html = qq{
        <tr $nomiclass>
          <td><img src="$award_icon" title="$award_fullname" alt=""></td>
          <td>$full_name</td>
        </tr>
    };

    return $html;
}

# элемент конкурса
# mode:
## 1 - конкурс на странице премии;
## 2 - конкурс на странице конкурса;
## 3 - конкурс в новостях и блогах;
sub contest_item {
    my ($self, $contest, $mode) = @_;
    my $imageurl = $self->config->{imageurl};

    if ($contest->{award_rusname} && $contest->{award_name}) {
        $contest->{fullname} = qq{<a href="/award$contest->{award_id}#c$contest->{contest_id}">$contest->{award_rusname}</a> / ($contest->{award_name}) $contest->{contest_name}</a>};
    }
    elsif ($contest->{award_rusname}) {
        $contest->{fullname} = qq{<a href="/award$contest->{award_id}#c$contest->{contest_id}">$contest->{award_rusname} $contest->{contest_name}</a>};
    }
    else {
        $contest->{fullname} = qq{<a href="/award$contest->{award_id}#c$contest->{contest_id}">$contest->{award_name} $contest->{contest_name}</a>};
    }

    #вывод краткого комментария
    if ($contest->{date} =~ /^(....)-(..)-(..)/) { $contest->{contest_date_short} = $2 eq '00' ? $1 : "$1-$2-$3"; }
    $contest->{date} = $self->format_date($contest->{date});
    my $contest_short_description = ($contest->{place} ? "$contest->{place}" : "");
    $contest_short_description .= ($contest->{date} && $contest_short_description ? ", $contest->{date}" : "$contest->{date}") || ($contest->{date} && !$contest->{place} ? "$contest->{date}" : "");
    $contest_short_description .= ($contest->{short_description} && $contest_short_description ? ", $contest->{short_description}" : "$contest->{short_description}") || ($contest->{short_description} && $contest->{date} ? "$contest->{short_description}" : "");

    # TODO: ссылка "Подробнее"
    my $details_link;
    if ($mode == 1) {
        $details_link = qq{<p style="float:right"><img src="/img/detail.gif" alt=""> <a href="/contest$contest->{contest_id}">Подробнее</a></p>};
    }

    # ссылка в заголовке конкурса
    my $contest_title_link;
    if ($mode == 1) {
        $contest_title_link = qq{ <a name="c$contest->{contest_id}">$contest->{name}</a> };
    }
    elsif ($mode == 3) {
        $contest_title_link = qq{ <a href="contest$contest->{contest_id}">$contest->{award_rusname}. $contest->{name}</a>};
    }

    # фиксированная ширина столбца номинаций
    my $nomination_class = 'cw-nomination-fixed';
    $nomination_class = 'cw-nomination' if $mode == 3;

    my $works_html;
    my $old_nomination_name;
    foreach my $cw (@{$contest->{contest_works}}) {
        # название произведения
        if ($cw->{autor_rusname} && $cw->{work_rusname} ) {
            $cw->{cw_rusname} = qq{$cw->{autor_rusname} "$cw->{work_rusname}"};
        }
        elsif ($cw->{autor_rusname}) {
            $cw->{cw_rusname} = $cw->{autor_rusname};
        }
        elsif ($cw->{work_rusname}) {
            $cw->{cw_rusname} = $cw->{work_rusname};
        }

        $cw->{nomination_name} = $cw->{nomination_rusname} || $cw->{nomination_name};

        # иконка
        if ($cw->{cw_winner}) {
            $cw->{work_icon} = qq {$imageurl/awards/icons/$contest->{award_id}_icon};
        }
        else {
            $cw->{work_icon} = qq {/img/nominate.gif};
        }

        # полное имя произведения
        if ($cw->{cw_rusname} && $cw->{cw_name}) {
            if ($cw->{cw_prefix}) {
                $cw->{cw_fullname} .= "$cw->{cw_prefix}<br>"
            }
            if ($cw->{cw_link_type} ne 'NULL' && $cw->{cw_link_id} != 'NULL') {
                $cw->{cw_fullname} .= "<a href='/$cw->{cw_link_type}$cw->{cw_link_id}'>$cw->{cw_rusname}</a>"
            }
            else {
                $cw->{cw_fullname} .= $cw->{cw_rusname}
            }
            if ($cw->{cw_postfix}) {
                $cw->{cw_fullname} .= ". $cw->{cw_postfix}"
            }
            $cw->{cw_fullname} .= '<br>';
            if ($cw->{cw_link_type} ne 'NULL' && $cw->{cw_link_id} != 'NULL') {
                $cw->{cw_fullname} .= "<a href='/$cw->{cw_link_type}$cw->{cw_link_id}'>$cw->{cw_name}</a>"
            }
            else {
                $cw->{cw_fullname} .= $cw->{cw_name}
            }
        }
        elsif ($cw->{cw_rusname}) {
            if ($cw->{cw_prefix}) {
                $cw->{cw_fullname} .= "$cw->{cw_prefix}<br>"
            }
            if ($cw->{cw_link_type} ne 'NULL' && $cw->{cw_link_id} != 'NULL') {
                $cw->{cw_fullname} .= "<a href='/$cw->{cw_link_type}$cw->{cw_link_id}'>$cw->{cw_rusname}</a>"
            }
            else {
                $cw->{cw_fullname} .= $cw->{cw_rusname}
            }
            if ($cw->{cw_postfix}) {
                $cw->{cw_fullname} .= ". $cw->{cw_postfix}"
            }
        }
        else {
            if ($cw->{cw_prefix}) {
                $cw->{cw_fullname} .= "$cw->{cw_prefix}<br>"
            }
            if ($cw->{cw_link_type} ne 'NULL' && $cw->{cw_link_id} != 'NULL') {
                $cw->{cw_fullname} .= "<a href='/$cw->{cw_link_type}$cw->{cw_link_id}'>$cw->{cw_name}</a>"
            }
            else {
                $cw->{cw_fullname} .= $cw->{cw_name}
            }
            if ($cw->{cw_postfix}) {
                $cw->{cw_fullname} .= ". $cw->{cw_postfix}"
            }
        }

        # стиль разделителя для номинаций
        if ($cw->{nomination_name} ne $old_nomination_name) {
            $cw->{nomination_name_text} = "$cw->{nomination_name}:";
            $cw->{nomination_name_style} = "class='nomi'";
        }

        $works_html .= qq{
          <tr $cw->{nomination_name_style}>
            <td class="$nomination_class">$cw->{nomination_name_text}</td>
            <td class="cw-icon"><img src="$cw->{work_icon}" alt=""></td>
            <td class="cw-fullname">$cw->{cw_fullname}</td>
          </tr>
        };

        $old_nomination_name = $cw->{nomination_name};
    }

    my $html = qq{
        <div class="contest">
          <p>$contest_title_link</p>
          <div class="contest_short_info">
            <p style="float:left">$contest_short_description</p>
            $details_link
          </div>
          <table class="contestworks_list">
            $works_html
          </table>
        </div>
    };

    $html .= qq{
<style>
.contest > p a {
  margin-left: 4px;
  font-weight: bold;
}

.contest_short_info {
  height: 24px;
  background-color: WhiteSmoke;
  border-top: 1px solid #E5E5E5;
  border-bottom: 1px solid #DDD;
}

.contest_short_info p {
  margin: 4px;
  text-indent: 0;
}

.contestworks_list {
  width: 100%;
  border-spacing: 0;
}

.contestworks_list td {
  padding: 4px;
}

.contestworks_list .nomi:first-child td {
  border-top: none;
}

.contestworks_list .nomi td {
  border-top: 1px solid #D8E1E6;
}

.contestworks_list .cw-nominationfixed {
  width: 190px;
  padding-left: 21px;
}

.contestworks_list .cw-nomination {
  padding-left: 21px;
}

.contestworks_list .cw-icon {
  text-align: center;
  width: 5px;
}

.contestworks_list .cw-icon img {
  max-width: 40px;
  max-height: 30px;
}

.contestworks_list tr {
  min-height: 37px;
  height: 37px;
}
</style>
};

    return $html;
}

# вывод отзыва
sub print_response {
    my ($self, $response, $cut_response, $can_vote) = @_;
    my $response_id = $response->{response_id};
    my $user_id = Profile->id;

    if ($response->{work_type_id} == 17) {
        $response->{autors} = 'Антология';
    }
    elsif ($response->{work_type_id} == 26) {
        $response->{autors} = 'Журнал';
    }
    else {
        $response->{autors} = $self->work_autor_name($response->{work_id}, 0, 1);
    }

    $response->{book_name} = $self->in_quota($response->{rusname} ? $response->{rusname} : $response->{name});
    $response->{posted_date} = $self->format_datetime($response->{posted_date}, 2);

#    $response->{posted_text} = "отзыв написал" . ($response->{user_sex} ? '' : 'а');

    if ($response->{user_id} > 0) {
        $response->{posted_user} = "<a href='/user$response->{user_id}'>$response->{user_name}</a>";
    }
    else {
        if ($response->{user_name} && $response->{user_name} !~ /^\s+$/) {
            $response->{posted_user} = $response->{user_name};
        }
        else {
            $response->{posted_user} = 'Гость';
        }
    }

    # получение оценки
    my $mark_hr = BD::User->get_user_mark($response->{user_id}, $response->{work_id});
    $response->{mark} = $mark_hr->{mark};
    $response->{mark} = 'нет' unless $response->{mark};

    # обрезание отзыва (используется на главной)
    if ($cut_response) {
        # обрезание спойлеров
        my $spoiler;
        if ( $response->{response_text} =~ s/\[spoiler\](.+?)\[\/spoiler\]//g ) {
            $spoiler = 1;
        }
        else { $spoiler = 0; }

        $response->{response_text} = $self->remove_tags($response->{response_text});

        # склеивание в один абзац и форматирование
        $response->{response_text} =~ s/\n//g;
        $response->{response_text} = $self->process_text($response->{response_text}, 1);

        my $max_response_length = $self->config->{max_response_length};

        if (length($response->{response_text}) > $max_response_length) {
            $response->{response_text} =~ s/^(.{$max_response_length}).+$/$1/s;
            $response->{response_text} =~ s/\s[^\s]+?$//s;
            $response->{response_text} .= "...  <a href='\/work$response->{work_id}?sort=date#responses'><nobr>читать весь отзыв &gt;&gt;<\/nobr><\/a>";
        }
        # для текстов со спойлерами нужно покузывать "читать весь отзыв", даже если текст меньше 700 символов
        elsif ($spoiler) {
            $response->{response_text} .= "...  <a href='\/work$response->{work_id}?sort=date#responses'><nobr>читать весь отзыв &gt;&gt;<\/nobr><\/a>";
        }
    }
    else {
        # обработка текста отзыва
        $response->{response_text} = $self->process_text($response->{response_text}, 1);
        $response->{response_text} = BBQ->new(set => [qw(spoiler)])->parse($response->{response_text});
    }

    # панелька голосования за отзыв
    my $vote_html;
    if ($can_vote) {
        my $vote = $response->{vote_plus} + $response->{vote_minus};

        my $vote_color;
        if ($vote) {
            $vote_color = 'gray';
        }
        else {
            $vote_color = ($vote ? 'green' : 'red' )
        }

        my ($v_minus, $v_plus);
        if (Profile->id) {
            # проверка не было ли голоса уже
            # запрет голосовать за свой отзыв
            my $resp_hide;
            if ($response->{user_voted} or (Profile->id == $response->{user_id}) ) { $resp_hide = "display:none"; }

            $v_minus = "<a id='minus$response_id' style='color:red;cursor:pointer;$resp_hide' onclick=\"return vote($response_id,'minus');\">&ndash;&nbsp;</a>";
            $v_plus = "<a id='plus$response_id' style='color:green;cursor:pointer;$resp_hide' onclick=\"return vote($response_id,'plus');\">&nbsp;+</a>";

            # запрет ставить минусы злобным минусовщикам
            if (Profile->no_vote_minus) {
                $v_minus = "<span id='minus$response_id' style='color:#bbb;cursor:pointer;$resp_hide' onclick=\"return voteminno('$user_id');\">&ndash;&nbsp;</span>";
            }
            #запрет ставить минусы если у вас низкий рейтинг
            elsif (Profile->user_rating < $self->config->{user_rating_forminus} ) {
                $v_minus = "<span id='minus$response_id' style='color:#bbb;cursor:pointer;$resp_hide' onclick=\"return votemin(you_vote_rating);\">&ndash;&nbsp;</span>";
            }
        }
        else
        {
            $v_minus = "<a id='minus$response_id' href='/regform' style='color:#bbb;cursor:pointer;' onclick=\"return votereg();\">&ndash;&nbsp;</a>";
            $v_plus = "<a id='plus$response_id' href='/regform' style='color:green;cursor:pointer;' onclick=\"return votereg();\">&nbsp;+</a>";
        }

        $vote_html = qq{
          <div class="response-votetab">
            <input type="hidden" name="work_id" value="$response->{response_id}">
            <p>$v_minus&nbsp;[&nbsp;</p>
            <p style="color:$vote_color">$vote</p>
            <p>&nbsp;]&nbsp;$v_plus</p>
          </div>
        };
    }

    # правка отзыва для админа
    my $admin_html;
    if (Profile->can_edit_responses || Profile->id == $response->{user_id}) {
        $admin_html = qq{
            <p style="float:left"><a href="/newresppage1/editresponse$response->{response_id}">правка</a></p>
        }
    }

    # скрытие отзывов на конкурс
    if ($self->config->{flcontest_is_going} == 1 && $response->{autor_id} == $self->config->{flcontest_autor_id}) { $response->{mark} = "?"; }

    my $html = qq{
        <div class="response-item">
          $vote_html
          <p class="response-work-info"><a href="/work$response->{work_id}?sort=date#responses">$response->{autors} $response->{book_name}</a></p>
          <p class="response-autor-info">$response->{posted_user}, $response->{posted_date}</p>
          <div class="response-body-home">
            $response->{response_text}
          </div>
          <div class="clearfix">
            $admin_html
            <p class="response-autor-mark"><b>Оценка: $response->{mark}</b></p>
          </div>
        </div>
    };

    return $html;
}

# вывод сообщения лички, мультипереписки,
# TODO: режим предпросмотра сообщения (верстка готова)
# TODO: режим для печати (осталась нумерация сообщений)
# TODO: сообщение форума (развитие пользователя, пол пользователя, аватарка со ссылкой, при клике на имя - оно цитируется, подпись)
# TODO: комментарий в блоге
# TODO: оптимизация под мобильники (vad)
# TODO: помечать сообщения прочитанными (трудно унифицировать)
# TODO: кеш сообщения (трудно унифицировать)
# ????: как читаются черновики
# ????: где идет разбивка на страницы и на 10 последних сообщений
## print_mode - включаем режим печати
## mode - тип сообщения: forum, private, multi, bloganswer
sub print_message {
    my ($self, $message, $mode, $print_mode) = @_;

    $mode = 'forum';
    $print_mode = 1;

    # TODO: тестовые данные
    $message->{message_text} = "Привет, подскажи, плиз: добавила pm-файл. Хочу проверить, как он формирует страницу. Как его \"вызвать\" чтобы в браузере увидеть страницу? Подскажи - где почитать про формирование адресов.... Пожалуйста.\n";
    $message->{user_sex} = 1;
    $message->{user_class_number} = 3;
    $message->{user_class} = 'пасечник';
    $message->{sign} = "что-то умное";

    # класс для режима печати
    my $print_class = $print_mode ? 'printmode' : '';

    # сообщение
    $message->{message_text} = $self->process_text($message->{message_text}, 1);
    $message->{message_text} = BBQ->new()->parse($message->{message_text});

    my $noread = $message->{is_read} ? '' : 'noread';

    # блок пользователя
    if ($print_mode && $mode ne 'forum') {
        $message->{avatar_image} = "<b>$message->{user_login}</b>";
    }
    elsif ($print_mode && $mode eq 'forum') {
        $message->{avatar_image} .= $self->user_avatar_block($message->{user_id}, $message->{user_login}, $message->{user_sex}, $message->{user_photo_number}, 6);
        $message->{avatar_image} .= "<br>$message->{user_class}<br>";
    }
    elsif ($mode eq 'private' || $mode eq 'multi') {
        $message->{avatar_image} = $self->user_avatar_block($message->{user_id}, $message->{user_login}, undef, $message->{user_photo_number}, 2);
    }
    elsif ($mode eq 'forum') {
        $message->{avatar_image} .= $self->user_avatar_block($message->{user_id}, $message->{user_login}, $message->{user_sex}, $message->{user_photo_number}, 5);
        $message->{avatar_image} .= "$message->{user_class}<br>";
        $message->{avatar_image} .= "<nobr>" . $self->user_rang_picture($message->{user_class_number}) . "</nobr>";
    }

    # верхняя часть сообщения
    my $posted_html;
    my $posted_class;
    if ($message->{preview_mode}) {
        $posted_html = qq{<b>Предпросмотр</b>};
        $posted_class = 'preview';
    }
    else {
        $posted_html = qq{
          <span class="message-posted">
            <img src='http://data.fantlab.ru/images/posted.gif'>Отправлено: $message->{date_of_add}
          </span>
          <span class="message-quote">
            <a href='javascript://' onmousedown ='quote("$message->{user_login}", $message->{private_message_id})'>
              <img src='http://data.fantlab.ru/images/quote.gif'><span>цитировать</span>
            </a>
          </span>
        };
    }

    # аттачи
    my $attach_html;
    if (scalar @{$message->{attachments}}) {
        foreach my $attach (@{$message->{attachments}}) {
            $attach_html .= qq{<span><a href="$attach->{filepath}">$attach->{filename}</a><span> ($attach->{filesize} Kb)</span></span>};
        }

        $attach_html = qq{
          <tr class="message-layout-bottom">
            <td>
              Файлы:
              <span class="message-attaches">
                $attach_html
              </span>
            </td>
          </tr>
        };
    }

    my $edit_html;
    # превью сообщения
    if ($message->{preview_mode}) {
        $edit_html = qq{
          <tr class="message-layout-bottom-preview">
            <td>
              <a class="message-submit" href='/submitpmpreview'>подтвердить</a>
              |
              <a class="message-cancel" href='/cancelpmpreview'>отменить</a>
            </td>
          </tr>
        };
    }
    # правка сообщения
    # TODO: магическое число 24 - убрать
    elsif (($message->{user_id} == Profile->id && ($message->{time_left} <= 24 or !$message->{is_read})) || Profile->can_edit_f_private_messages) {
        $edit_html = qq{
          <tr class="message-layout-bottom-edit">
            <td>
              <a class="message_edit" href='/editprivatemessage$message->{private_message_id}'>правка</a>
            </td>
          </tr>
        };
    }

    $message->{date_of_add} = $self->format_datetime($message->{date_of_add});

    # подпись (форум)
    my $sign_html;
    if ($mode eq 'forum' && $message->{sign}) {
        $sign_html = qq{
          <tr class="message-layout-bottom-sign">
            <td><span>&ndash;&ndash;&ndash;<br>$message->{sign}</span></td>
          </tr>
        };
    }

    my $html =
qq{    <table class="message $noread $posted_class $print_class">
        <tr>
          <td class="message-user-info">
            $message->{avatar_image}
          </td>
          <td class="message-layout">
            <table>
              <tr class="message-layout-top">
                <td>
                  $posted_html
                </td>
              </tr>
              <tr class="message-text">
                <td>$message->{message_text}</td>
              </tr>
              $sign_html
              $attach_html
              $edit_html
            </table>
          </td>
        </tr>
      </table>};

    return $html;
}

# вывод блока с именем юзера и его аватарой.
# TODO: обновить верстку
sub user_avatar_block {
    my ( $self, $user_id, $user_name, $user_sex, $photo_number, $type_view ) = @_;

    $photo_number ||= 0;
    $type_view ||= 1;

    return "(автор удален)" unless ($user_id);

    my $width = 80;
    #if($self->stash('nano_mode')) { $width = 60 }

    my $autor;
    my $sex_pic = ($user_sex == 1) ? 'male.gif' : 'female.gif';

    my $avatar = "${user_id}_$photo_number";
    # солнышко вместо аватара для попадающих в список заменяющих.
    if (scalar grep {$_ eq $user_id} split ',', Profile->disable_some_avatars) { $avatar = "good_avatar.gif"; }

    # переход на юзеринфо (автор поста блога)
    if ($type_view == 0) {
        # аватар с ссылкой
        if (Profile->disable_photos == 1) {
            $autor = "<nobr><a href='/user$user_id'><b>$user_name</b></a> <img src='/img/$sex_pic'></nobr><br>";
        }
        else {
            $autor = "<nobr><a href='/user$user_id'><b>$user_name</b></a> <img src='/img/$sex_pic'></nobr><br>";
            $autor.= "<a href=/user$user_id><img src='".$self->config->{imageurl}."/users/$avatar' width=$width style='margin:4px' class='user-avatar-image'></a><br>";
        }
    }
    # подставка ника внизу в форму (для комментов блога)
    elsif ($type_view == 1) {
        if (Profile->disable_photos == 1) {
            $autor = "<nobr><a href='javascript:username(\"$user_name\")' title='Скопировать имя в форму для ответа'><b>$user_name</b></a>&nbsp;<img src='/img/$sex_pic'></nobr><br>";
            $autor.= "<br>(<a href='/user${user_id}'>инфо</a>)<br><br>";
        }
        else {
            $autor = "<nobr><a href='javascript:username(\"$user_name\")' title='Скопировать имя в форму для ответа'><b>$user_name</b></a>&nbsp;<img src='/img/$sex_pic'></nobr><br>";
            $autor.= "<a href=/user$user_id><img src='".$self->config->{imageurl}."/users/$avatar' width=$width style='margin:4px' class='user-avatar-image'></a><br>";
        }
    }
    # ничего (для лички) + нет гендера (без ссылки)
    elsif ($type_view == 2) {
        if (Profile->disable_photos == 1) {
            $autor = ($self->stash('nano_mode')?"<small><b>$user_name</b></small>":"<b>$user_name</b>");
        }
        else {
            $autor = ($self->stash('nano_mode')?"<small><b>$user_name</b></small>":"<b>$user_name</b>");
            $autor.= "<img src='".$self->config->{imageurl}."/users/$avatar' width=$width style='margin:4px;display:block' class='user-avatar-image'>";
        }
    }
    # мелкая 30х30 для полок на странице издания (без ссылки)
    elsif ($type_view == 3) {
        if (Profile->disable_photos == 1) {
            $autor = "";
        }
        else {
            $autor = "<img src='".$self->config->{imageurl}."/users/$avatar' width=30 style='margin:4px;max-width:30px;max-height:40px;display:block' class='user-avatar-image'>";
        }
    }

    # для полок на странице издания (без ссылки)
    elsif ($type_view == 4) {
        if (Profile->disable_photos == 1) {
            $autor = "";
        }
        else {
            $autor = "<img src='".$self->config->{imageurl}."/users/$avatar' width=$width style='margin:4px;display:block' class='user-avatar-image'>";
        }
    }

    # для форума
    elsif ($type_view == 5) {
        if (Profile->disable_photos == 1) {
            #$autor = "<nobr><a href='javascript:username(\"$user_name\")' title='Скопировать имя в форму для ответа'><b>$user_name</b></a>&nbsp;<img src='/img/$sex_pic'></nobr><br>";
            $autor = "<br>(<a href='/user${user_id}'>инфо</a>)<br><br>";
        }
        else {
            $autor = "<nobr><a href='javascript:username(\"$user_name\")' title='Скопировать имя в форму для ответа'><b>$user_name</b></a>&nbsp;<img src='/img/$sex_pic'></nobr><br>";
            $autor .= "<a href='/user$user_id' title='Информация о $user_name, частная переписка'><img src='".$self->config->{imageurl}."/users/$avatar' width=$width style='margin:4px;' class='user-avatar-image'></a>";
        }
    }

    # для форума (версия для печати)
    elsif ($type_view == 6) {
        $autor = "<b>$user_name</b>&nbsp;";
        $autor .= $user_sex == 1 ? 'м' : 'ж';
    }

    return $autor;
}

# вывод ранга пользователя
# TODO: обновить верстку
sub user_rang_picture {
    my ( $self, $user_class_number, $is_inline ) = @_;

    my $element = $is_inline == 1 ? 'span' : 'p';
    my $res = "<$element style='margin:0;margin-top:4px;margin-bottom:4px'>";

    for my $i (0..6) {
        my $margin = $i > 0 ? 'margin-left:1px' : '';

        if ($i < $user_class_number) {
            $res .= "<img src='/img/rangfilled.gif' style='display:inline-block;width:8px;height:8px;$margin'>";
        }
        else {
            $res .= "<img src='/img/rangempty.gif' style='display:inline-block;width:8px;height:8px;$margin'>";
        }
    }

    $res .= "</$element>";
    return $res;
}

# копия функции "Functions::Buttons"
sub editor_buttons {
    my ($self, $obj) = @_;
    my $html;

    if (Profile->access_group_id > 1 ) {
        $obj = "message" unless ($obj);
        $html = qq{
        <input type=button accesskey='b' name='tag_b' value=' B ' title='Жирный (Alt+b)' onclick="javascript:inTag(document.getElementById('$obj'),'[b]','[/b]');" >
        <input type=button accesskey='i' name='tag_i' value=' I ' title='Курсив (Alt+i)' onclick="javascript:inTag(document.getElementById('$obj'),'[i]','[/i]');" >
        <input type=button accesskey='u' name='tag_u' value=' U ' title='Подчёркнутый (Alt+u)' onclick="javascript:inTag(document.getElementById('$obj'),'[u]','[/u]');" >
        <input type=button accesskey='s' name='tag_s' value=' S ' title='Зачёркнутый (Alt+s)' onclick="javascript:inTag(document.getElementById('$obj'),'[s]','[/s]');" >
        <input type=button accesskey='h' name='tag_h' value='Скрытый' title='Скрытый (Alt+h)' onclick="javascript:inTag(document.getElementById('$obj'),'[h]','[/h]');" >
        <input type=button accesskey='q' name='tag_q' value='Цитата' title='Цитата (Alt+q)' onclick="javascript:inTag(document.getElementById('$obj'),'[q]','[/q]');" >
        <input type=button accesskey='l' name='tag_list' value='Список' title='Список (Alt+l)' onclick="simpletag('list','$obj')" style='width:60px'>
        <input type=button accesskey='p' name='tag_img' value='Картинка' title='Картинка (Alt+p)' onclick="image('$obj')" style='width:70px'>
        <input type=button accesskey='w' name='tag_url' value='Ссылка' title='Ссылка (Alt+w)' onclick="url('$obj')" style='width:60px'>
        };


    } else { # старый код

        my $addobj = '';
        if ($obj) {
            $addobj = ",\"$obj\"";
            $obj="\"$obj\""
        }

        $html = qq{
        <input type=button accesskey='b' name='tag_b' value=' B ' title='Жирный (Alt+b)' onclick='simpletag(\"b\"$addobj)'>
        <input type=button accesskey='i' name='tag_i' value=' I ' title='Курсив (Alt+i)' onclick='simpletag(\"i\"$addobj)'>
        <input type=button accesskey='u' name='tag_u' value=' U ' title='Подчёркнутый (Alt+u)' onclick='simpletag(\"u\"$addobj)'>
        <input type=button accesskey='s' name='tag_s' value=' S ' title='Зачёркнутый (Alt+s)' onclick='simpletag(\"s\"$addobj)'>
        <!-- input type=button accesskey='a' name='tag_p' value='Абзац' title='Абзац (Alt+a)' onclick='simpletag(\"p\"$addobj)' -->
        <input type=button accesskey='q' name='tag_q' value='Цитата' title='Цитата (Alt+q)' onclick='simpletag(\"q\"$addobj)'>
        <input type=button accesskey='h' name='tag_h' value='Скрытый' title='Скрытый (Alt+h)' onclick='simpletag(\"h\"$addobj)'>
        <input type=button accesskey='l' name='tag_list' value='Список' title='Список (Alt+l)' onclick='simpletag(\"list\"$addobj)' style='width:60px'>
        <input type=button accesskey='p' name='tag_img' value='Картинка' title='Картинка (Alt+p)' onclick='image($obj)' style='width:70px'>
        <input type=button accesskey='w' name='tag_url' value='Ссылка' title='Ссылка (Alt+w)' onclick='url($obj)' style='width:60px'>
        };
    }

    # Prevent escaping
    return Mojo::ByteStream->new($html);
}

# копия функции "Functions::SpecSymbolButtons"
sub editor_specsymbol_buttons {
    my ($self, $obj) = @_;
    my $html;

    if (Profile->access_group_id > 1 ) {
        $obj = "message" unless ($obj);
        $html = qq{
        <input type=button accesskey='1' value='&laquo;&raquo;' title='Кавычка открывающаяся (Alt+1)' onclick="javascript:inTag(document.getElementById('$obj'),'«','»');" >
        <input type=button accesskey='-' value='&mdash;' title='Тире (Alt+-)' onclick="javascript:inTag(document.getElementById('$obj'),'&mdash;','');">
        <input type=button accesskey='2' value='&bull;'  title='Жирная точка (Alt+2)' onclick="javascript:inTag(document.getElementById('$obj'),'&bull;','');">
        <input type=button accesskey='3' value='&copy;'  title='Копирайт (Alt+3)' onclick="javascript:inTag(document.getElementById('$obj'),'&copy;','');">
        <input type=button accesskey='4' value='&sect;'  title='Параграф (Alt+4)' onclick="javascript:inTag(document.getElementById('$obj'),'§','');">
        };
#        if ($obj eq "plandesc") {
#            $html .= qq{
#                <input type=button value='Жанр' onclick="javascript:inTag(document.getElementById('$obj'),'[genre]','[/genre]');">
#            };
#        }


    # старый вызов JS кнопок. убить после успешного тестирования на админах
    } else { 
        my $addobj = '';
        if ($obj) {
            $addobj = ",\"$obj\""
        }

        $html = qq{
        <input type=button accesskey='1' value='&laquo;' title='Кавычка открывающаяся (Alt+1)' onclick='doInsert(\"&laquo;\",\"\",false$addobj)' style='width:20px'>
        <input type=button accesskey='2' value='&raquo;' title='Кавычка закрывающаяся (Alt+2)' onclick='doInsert(\"&raquo;\",\"\",false$addobj)' style='width:20px'>
        <input type=button accesskey='-' value='&mdash;' title='Тире (Alt+-)' onclick='doInsert(\"&mdash;\",\"\",false$addobj)' style='width:20px;padding-left:3px'>
        <input type=button accesskey='3' value='&copy;'  title='Копирайт (Alt+3)' onclick='doInsert(\"&copy;\",\"\",false$addobj)' style='width:20px;padding-left:3px'>
        <!-- input type=button accesskey='4' value='&hellip;' title='Многоточие (Alt+4)' onclick='doInsert(\"&hellip;\",\"\",false$addobj)' style='width:20px;padding-left:4px' -->
        };

#        if ($obj eq "plandesc") {
#            $html .= qq{
#                <input type=button value='Жанр' onclick='simpletag(\"genre\"$addobj)'>
#            };
#        }
    }

    # Prevent escaping
    return Mojo::ByteStream->new($html);
}

sub editor_navdb_buttons {
    my ($self, $obj) = @_;
    my $html;

    if (Profile->access_group_id > 1 ) {
        $obj = "message" unless ($obj);
        $html = qq{
            <input type=button name='tag_work' value='work=' title='Ссылка на произведение' onclick="javascript:inTag(document.getElementById('$obj'),'[work=]','[/work]',6);">
            <input type=button name='tag_work_t' value='work_t=' title='Ссылка на произведение с типом' onclick="javascript:inTag(document.getElementById('$obj'),'[work_t=]','[/work]',8);">
            <input type=button name='tag_edition' value='edition=' title='Ссылка на издание' onclick="javascript:inTag(document.getElementById('$obj'),'[edition=]','[/edition]',9);">
            <input type=button name='tag_autor' value='autor=' title='Ссылка на автора' onclick="javascript:inTag(document.getElementById('$obj'),'[autor=]','[/autor]',7);">
            <input type=button name='tag_translator' value='translator=' title='Ссылка на переводчика' onclick="javascript:inTag(document.getElementById('$obj'),'[translator=]','[/translator]',12);">
            <input type=button name='tag_art' value='art=' title='Ссылка на художника' onclick="javascript:inTag(document.getElementById('$obj'),'[art=]','[/art]',5);">
            <input type=button name='tag_dictor' value='dictor=' title='Ссылка на диктора' onclick="javascript:inTag(document.getElementById('$obj'),'[dictor=]','[/dictor]',7);">
            <input type=button name='tag_series' value='series=' title='Ссылка на серию' onclick="javascript:inTag(document.getElementById('$obj'),'[seires=]','[/seires]',7);">
            <input type=button name='tag_pub' value='pub=' title='Ссылка на издательство' onclick="javascript:inTag(document.getElementById('$obj'),'[pub=]','[/pub]',5);">
            <input type=button name='tag_film' value='film=' title='Ссылка на фильм' onclick="javascript:inTag(document.getElementById('$obj'),'[film=]','[/film]',6);">
            <input type=button name='tag_award' value='award=' title='Ссылка на премию' onclick="javascript:inTag(document.getElementById('$obj'),'[award=]','[/award]',7);">
            <input type=button name='tag_user' value='user=' title='Ссылка на юзера' onclick="javascript:inTag(document.getElementById('$obj'),'[user=]','[/user]',6);">
            <input type=button name='tag_link' value='link=' title='Ссылка на страницу сайта' onclick="javascript:inTag(document.getElementById('$obj'),'[link=]','[/link]',6);">
        };

    # старый вызов JS кнопок. убить после успешного тестирования на админах
    } else { 
        my $addobj = '';
        if ($obj) {
            $addobj = ",\"$obj\""
        }
    
        my $html = qq{
            <input type=button name='tag_work' value='work=' title='Ссылка на произведение' onclick='simpletag("work"$addobj)'>
            <input type=button name='tag_work_t' value='work_t=' title='Ссылка на произведение с типом' onclick='simpletag("work_t"$addobj)'>
            <input type=button name='tag_edition' value='edition=' title='Ссылка на издание' onclick='simpletag("edition"$addobj)'>
            <input type=button name='tag_autor' value='autor=' title='Ссылка на автора' onclick='simpletag("autor"$addobj)'>
            <input type=button name='tag_translator' value='translator=' title='Ссылка на переводчика' onclick='simpletag("translator"$addobj)'>
            <input type=button name='tag_art' value='art=' title='Ссылка на художника' onclick='simpletag("art"$addobj)'>
            <input type=button name='tag_dictor' value='dictor=' title='Ссылка на диктора' onclick='simpletag("dictor"$addobj)'>
            <input type=button name='tag_series' value='series=' title='Ссылка на серию' onclick='simpletag("series"$addobj)'>
            <input type=button name='tag_pub' value='pub=' title='Ссылка на издательство' onclick='simpletag("pub"$addobj)'>
            <input type=button name='tag_film' value='film=' title='Ссылка на фильм' onclick='simpletag("film"$addobj)'>
            <input type=button name='tag_award' value='award=' title='Ссылка на премию' onclick='simpletag("award"$addobj)'>
            <input type=button name='tag_user' value='user=' title='Ссылка на юзера' onclick='simpletag("user"$addobj)'>
            <input type=button name='tag_link' value='link=' title='Ссылка на страницу сайта' onclick='simpletag("link"$addobj)'>
        };
    }

    # Prevent escaping
    return Mojo::ByteStream->new($html);
}

# строка навигации в блогах
sub blogs_naviline {
    my ($self, $text, $is_myblog, $show_tags) = @_;

    my $show_tags_html;
    if ($show_tags) {
        $show_tags_html = qq{
          <td></td>
          <td valign=middle style="border:1px solid #D8E1E6">
            <nobr>
              <a href='javascript://' onclick='if (document.all["tagsdiv"].style.display == "block") { document.all["tagsdiv"].style.display="none" } else { document.all["tagsdiv"].style.display="block" } '><img align=absmiddle src='/img/tagcloud.gif'> облако тегов</a>
            </nobr>
          </td>
        };
    }

    my $my_blog_html;
    if (Profile->can_create_blog && !$is_myblog) {
        my $user_id = Profile->id;
        $my_blog_html = qq{
            <td></td>
            <td valign=middle style=\"border:1px solid #D8E1E6\">
              <nobr><a href=/user$user_id/blog><img align=absmiddle src='/img/blog.gif'> моя колонка</a></nobr>
            </td>
        };
    }

    my $html = qq{
        <table cellspacing=0 cellpadding=4 class=v9b border=0 width=100% style='margin-bottom:10px'>
          <tr bgcolor=#F9FAFB class=v9b valign=top>
            <td width=100% style="border:1px solid #D8E1E6">Вы здесь: <b><a href="/blogs">Авторские колонки FantLab.ru</a> &gt; $text</b></td>
            $show_tags_html
            $my_blog_html
          </tr>
        </table>
    };

    return $html;
}

# навигация для администраторских функций
sub admin_naviline {
    my ($self) = @_;

    my @nav = split(/\//, $self->url_for);

    my $link_full;
    my $links;
    foreach my $desc_nav (@nav) {
        next unless $desc_nav;
        $link_full .= "/$desc_nav";
        my $link = qq{<a href="$link_full" style="font-weight:bold">$desc_nav</a>};
        $links .=  "$link > ";
    }
    chop $links;chop $links;

    my $html = qq{
        <table cellspacing=0 cellpadding=4 class=v9b border=0 width=100% style='margin-bottom:10px'>
          <tr bgcolor=#F9FAFB class=v9b valign=top>
            <td width=100% style="border:1px solid #D8E1E6"><b>Навигация</b>: $links</td>
          </tr>
        </table>
    };

    return $html;
}

# генерация алфавита со ссылками
sub letter_links {
    my ($self, $page_url, $sel_letter, $eng_letters, $param, $letters) = @_;
    $sel_letter = 'ВСЕ' if $sel_letter eq '';
    my @symbols = ('А','Б','В','Г','Д','Е','Ж','З','И','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Э','Ю','Я','ВСЕ');
    if ($eng_letters)
    {
        my @symbols_eng = ('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','V','W','X','Y','Z');
        push (@symbols_eng, @symbols);
        @symbols = @symbols_eng;
    }
    
    if(scalar @$letters)
    {
        my %original = ();        
        map { $original{$_} = 1 } @symbols;
        @symbols = grep { $original{$_} } @$letters;
        push (@symbols, 'ВСЕ');
    }
    
    my ($letters, $other_letters) = ("","");

    my $url = Mojo::URL->new($page_url);

    for my $letter ( @symbols ) {
        my $letter_link = '';
        if ( $url =~ /\?.*/ ) {
            $letter_link = "&letter=$letter".($param ? "&$param" : "") unless $url =~ s/letter=.*?(?=&|$)/letter=$letter/
        }
        else { $letter_link = "?letter=$letter".($param ? "&$param" : "") }
        my $lastletter;

        if ($letter eq "ВСЕ") {
            $lastletter = "&nbsp;&nbsp;&nbsp;";
            $letter_link = "".($param ? "?$param" : "");
        }
        
        my $temp;
        
        if ($letter ne $sel_letter) {
            $temp = qq{ $lastletter<a href="$url$letter_link">$letter</a> };
        }
        else {
            $temp = "$lastletter [$letter]";
        }
        
        if($letter =~ /ВСЕ/ ){
            $other_letters .= $temp;
        }elsif($letter =~ /[А-я]/ ){
            $letters .= $temp;
        }else{
            $other_letters .= $temp;
        }
    }

    return $letters."<br><span class='link_gray'>".$other_letters."</span>";
}

1;