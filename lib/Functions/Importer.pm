package Functions::Importer;
use common::sense;
use Mojo::Util qw/trim/;
use Mojo::DOM;
use XML::Simple;
use Image::Magick;
use URI::Escape;
use Image::Size qw/imgsize/;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Functions::AmazonAPI;
use Functions::Util;

sub import_edition {
    my $shop_url = shift;
    my $importer_hash = {};

    if ( $shop_url =~ /ozon\.ru\/context\/detail\/id\/([0-9]+)/ ) {
         $importer_hash = import_edition_ozon($1);
    }
    elsif ( $shop_url =~ /my\-shop\.ru\/shop\/books\/([0-9]+)\.html/ ) {
        # интересно, где обработчик этого добра?
        my $param_myshop_id = $1;
    }
    elsif ( $shop_url =~ /bgshop\.ru\/Details.aspx\?id=([0-9]+)/ ) {
        $importer_hash = import_edition_bgshop($1);
    }
    elsif ( $shop_url =~ /amazon\.(co\.uk|com|de|it|es|ca|fr).+?(dp|ASIN|gp).*?([A-Z0-9]+)/ ) {
        $importer_hash = import_edition_amazon($3, $1);
    }
    elsif ( $shop_url =~ /isfdb\.org\/cgi-bin\/pl.cgi\?([0-9]+)/ ) {
        $importer_hash = import_edition_isfdb($1);
    }
    elsif ( $shop_url =~ /esensja\.pl\/.*?\/obiekt.html\?rodzaj_obiektu=2\&idobiektu=([0-9]+)/ ) {
        $importer_hash = import_edition_esensja($1);
    }

    return $importer_hash;
}

# Импорт с ОЗОНа
sub import_edition_ozon {
    my $ozon_id = shift;
    return unless $ozon_id;

    my $site = Functions::Util::get_file_from_url("http://www.ozon.ru/context/detail/id/$ozon_id/");

    return unless $site;

    my $dom = Mojo::DOM->new($site);

    # название
    my $title = $dom->find('h1[itemprop=name]')->map('text')->join;

    # авторы
    my $autors = $dom->find('p[itemprop=author] a')->map('text')->join;

    # тип издания
    my $type = 10;

    if ($site =~ /<p class="tov_prop">Антология<\/p>/) {
        $type = 15;
    }
    if ($site =~ /<p class="tov_prop">Авторский сборник<\/p>/) {
        $type = 11;
    }

    # издательство
    my @publishers;
    $dom->find('p[itemprop=publisher] a')->each( sub { push @publishers, shift->text } );
    my $publishers = join(', ', @publishers);

    # серия
    my $series;
    if ($site =~ /Серия:\s+<a href=\'\/context\/detail\/id\/([0-9]+)\/\'[^>]+?>(.+?)<\/a>/) {
        $series = $2;
    }

    # тип обложки
    my $book_format = $dom->find('span[itemprop=bookFormat]')->map('text')->join;
    my $cover_type = 0;
    my $super_cover = 0;
    if ($book_format eq "Твердый переплет") {
        $cover_type = 2;
    }
    elsif ($book_format eq "Мягкая обложка") {
        $cover_type = 1;
    }
    elsif ($book_format eq "Твердый переплет, суперобложка" || $book_format eq "Суперобложка") {
        $cover_type = 2;
        $super_cover = 1;
    }

    # формат
    my $format;
    if ($site =~ /Формат.*?\<span.*?>(.*?)(\s|\<\/span>)/s) {
        $format = $1;
        $format =~ s/х/x/g;
    }

    # страницы
    my $pages = $dom->find('span[itemprop=numberOfPages]')->map('text')->join;
    $pages =~ s/\s.*//;

    # ISBN и год
    my $isbn = $dom->find('p[itemprop=isbn]')->map('text')->join;
    my $release_year;
    if ($isbn =~ /ISBN(.+?);(.*)г\./s) {
        $isbn = trim $1;
        $release_year = trim $2;
    }
    elsif ($isbn =~ /(\d{4})/s) {
        $release_year = $1;
    }

    # тираж
    my $count;
    if ($site =~ /Тираж.*?([0-9]+) экз\./s) {
        $count = $1;
    }

    # язык издания
    my $lang = $dom->find('p[itemprop=inLanguage]')->map('text')->join;
    $lang = lc($lang);
    $lang =~ s/языки\:\s//;

    if ( $lang eq 'русский' || $lang eq '' ) {
        $lang = 1;
    }
    elsif ( $lang eq 'английский' ) {
        $lang = 2;
    }
    else {
        $lang = 0;
    }

    my $big_picture;

    # граббер картинки c myshop
    foreach my $c_isbn (split(', ', $isbn)) {
        my $img_site = Functions::Util::get_file_from_url("http://my-shop.ru/shop/search/b/sort/a/page/1.html?f9_=1&f33=1&f22=$c_isbn&send=ok");

        if ($img_site =~ /\ssrc=\"(\/_files\/product\/.+?)\" width=\"80\"/) {
            my $tmp_cover = "http://my-shop.ru$1";
            $tmp_cover =~ s/\/1\//\/2\//;

            my $file = Functions::Util::get_file_from_url($tmp_cover);
            my $image = Image::Magick->New();
            $image->BlobToImage($file);
            my ($ox, $oy) = $image->Get('base-columns','base-rows');

            if ($ox >= 200) {
                $big_picture = $tmp_cover;
                last;
            }
        }
    }

    # граббер картинки c bgshop
    # TODO: убрать использование старых функций
    foreach my $c_isbn (split(', ', $isbn)) {
        last if $big_picture;

        # тут создает post запрос на поиск по bgshop по isbn. в ответ получить должны редирект на книгу.
        my $url = "http://www.bgshop.ru/ExpandedSearch.aspx?"
        ."__VIEWSTATE=".uri_escape_utf8("/wEPDwUKMTU0OTU2MjA1NQ9kFgJmD2QWBAIBD2QWBgIBDxYCHgdjb250ZW50BZMD0JrQvdC40LbQvdGL0Lkg0LjQvdGC0LXRgNC90LXRgi3QvNCw0LPQsNC30LjQvSDCq9CR0JjQkdCb0JjQni3Qk9Cb0J7QkdCj0KHCuyDigJMg0LrRg9C/0LjRgtGMINC60YPQv9C40YLRjCDQutC90LjQs9C4LCDRg9GH0LXQsdC90YvQtSDQuNC30LTQsNC90LjRjywg0LjQs9GA0YssINC80YPQt9GL0LrRgywg0LLQuNC00LXQviwg0LjQs9GA0YssINGB0L7RhNGCLCDQvtGE0LjRgdC90YvQtSDRgtC+0LLQsNGA0YssINCx0LjQt9C90LXRgS3QsNC60YHQtdGB0YHRg9Cw0YDRiywg0Y3Qu9C10LrRgtGA0L7QvdC40LrRgywg0LDRg9C00LjQvtC60L3QuNCz0LgsINCw0L3RgtC40LrQstCw0YDQuNCw0YIsINGC0L7QstCw0YDRiyDQtNC70Y8g0LrQvtC70LvQtdC60YbQuNC+0L3QtdGA0L7Qsi4g0KHQutC40LTQutC4LmQCAw8WAh8ABZ4D0JrQvdC40LbQvdGL0Lkg0LjQvdGC0LXRgNC90LXRgiDQvNCw0LPQsNC30LjQvSDCq9CR0JjQkdCb0JjQni3Qk9Cb0J7QkdCj0KHCuywg0YjQuNGA0L7QutC40Lkg0LDRgdGB0L7RgNGC0LjQvNC10L3RgiDQutC90LjQsywg0YPRh9C10LHQvdGL0YUg0LjQt9C00LDQvdC40LksINC80YPQt9GL0LrQuCwg0LLQuNC00LXQviwg0LjQs9GALCDRgdC+0YTRgtCwLCDQutC90LjQsyDQvdCwINC40L3QvtGB0YLRgNCw0L3QvdGL0YUg0Y/Qt9GL0LrQsNGFLCDQsNC90YLQuNC60LLQsNGA0LjQsNGC0LAg0Lgg0YLQvtCy0LDRgNC+0LIg0LTQu9GPINC60L7Qu9C70LXQutGG0LjQvtC90LXRgNC+0LIsINGN0LvQtdC60YLRgNC+0L3QuNC60LguINCU0L7RgdGC0LDQstC60LAg0L/QviDQstGB0LXQvNGDINC80LjRgNGDLiDQodC60LjQtNC60LguZAIEDxYCHgRocmVmBSIuL0FwcF9UaGVtZXMvc3RhbmRhcnQvc3RhbmRhcnQuY3NzZAIDD2QWEgIDDw8WAh4JR29vZHNUeXBlBQlVbmRlZmluZWRkZAIFD2QWAmYPEGQPFglmAgECAgIDAgQCBQIGAgcCCBYJEAUG0JLRgdC1BQlVbmRlZmluZWRnEAUK0JrQvdC40LPQuAUEQm9va2cQBQzQnNGD0LfRi9C60LAFBUF1ZGlvZxAFCtCS0LjQtNC10L4FBVZpZGVvZxAFFNCY0LPRgNGLINC4INGB0L7RhNGCBQpNdWx0aW1lZGlhZxAFFtCQ0L3RgtC40LrQstCw0YDQuNCw0YIFCEFudGlxdWVzZxAFH9Ca0LDQvdGG0YLQvtCy0LDRgNGLINC4INC/0L4uLi4FBk9mZmljZWcQBSDQrdC70LXQutGC0YDQvtC90L3Ri9C1INC/0YDQuC4uLgULRWxlY3Ryb25pY3NnEAUU0JDRg9C00LjQvtC60L3QuNCz0LgFCUF1ZGlvYm9va2cWAWZkAgYPDxYCHwIFCVVuZGVmaW5lZGQWBAIFDw8WAh4ISW1hZ2VVcmwFL34vQXBwX1RoZW1lcy9zdGFuZGFydC9pbWFnZXMvYnV0dG9uU2VhcmNocnUuZ2lmZGQCCQ8PFgQeBFRleHQFIdCg0LDRgdGI0LjRgNC10L3QvdGL0Lkg0L/QvtC40YHQuh4LTmF2aWdhdGVVcmwFFC9FeHBhbmRlZFNlYXJjaC5hc3B4ZGQCCQ8PFgIfAgUJVW5kZWZpbmVkZGQCCg9kFgYCAQ8PFgIfAgUJVW5kZWZpbmVkZBYCZg8PFgIfBAUc0KHQutC+0YDQviDQsiDQv9GA0L7QtNCw0LbQtWRkAgMPDxYCHwIFCVVuZGVmaW5lZGQWAmYPDxYCHwQFINCd0L7QstC40L3QutC4INC30LAg0L3QtdC00LXQu9GOZGQCBQ8PFgIfAgUJVW5kZWZpbmVkZBYCZg8PFgIfBAUe0J3QvtCy0LjQvdC60Lgg0LfQsCDQvNC10YHRj9GGZGQCCw8PFgIfBAUW0JHQtdGB0YLRgdC10LvQu9C10YDRi2RkAgwPDxYCHwQFDtCa0LDRgtCw0LvQvtCzZGQCDQ8PFgIfBAUV0JrQsNGA0YLQsCDRgdCw0LnRgtCwZGQCDw9kFgYCAg8PFgIfBAUg0J/QvtC40YHQuiDQv9C+INGA0LDQt9C00LXQu9GDOiBkZAIDD2QWAmYPEGQPFglmAgECAgIDAgQCBQIGAgcCCBYJEAUG0JLRgdC1BQlVbmRlZmluZWRnEAUK0JrQvdC40LPQuAUEQm9va2cQBQzQnNGD0LfRi9C60LAFBUF1ZGlvZxAFCtCS0LjQtNC10L4FBVZpZGVvZxAFFNCY0LPRgNGLINC4INGB0L7RhNGCBQpNdWx0aW1lZGlhZxAFFtCQ0L3RgtC40LrQstCw0YDQuNCw0YIFCEFudGlxdWVzZxAFH9Ca0LDQvdGG0YLQvtCy0LDRgNGLINC4INC/0L4uLi4FBk9mZmljZWcQBSDQrdC70LXQutGC0YDQvtC90L3Ri9C1INC/0YDQuC4uLgULRWxlY3Ryb25pY3NnEAUU0JDRg9C00LjQvtC60L3QuNCz0LgFCUF1ZGlvYm9va2cWAWZkAgQPDxYCHwIFCVVuZGVmaW5lZGQWBAICD2QWFAIBDw8WAh4HVmlzaWJsZWdkFgICAQ8PFgIfBAUK0JDQstGC0L7RgGRkAgsPDxYCHwZnZBYCAgEPDxYCHwQFENCd0LDQt9Cy0LDQvdC40LVkZAIPD2QWAgIBDw8WAh8EBSnQmNC30LTQsNGC0LXQu9GML9CY0LfQs9C+0YLQvtCy0LjRgtC10LvRjGRkAhEPDxYCHwZoZGQCFQ8PFgIfBmdkFgICAQ8PFgIfBAUK0KHQtdGA0LjRj2RkAhkPZBYCAgEPDxYCHwQFBElTQk5kZAIbDw8WAh8GZ2QWAgIBDw8WAh8EBQbQk9C+0LRkZAIdDw8WAh8GZ2QWAgIBDw8WAh8EBQjQptC10L3QsGRkAh8PEA8WAh8EBR7QotC+0LvRjNC60L4g0LIg0L3QsNC70LjRh9C40LhkZGRkAiEPEA8WAh8EBTLQotC+0LvRjNC60L4g0Y3Qu9C10LrRgtGA0L7QvdC90YvQtSDQuNC30LTQsNC90LjRj2RkZGQCBA8PFgIfAwUvfi9BcHBfVGhlbWVzL3N0YW5kYXJ0L2ltYWdlcy9idXR0b25TZWFyY2hydS5naWZkZBgBBR5fX0NvbnRyb2xzUmVxdWlyZVBvc3RCYWNrS2V5X18WBwUdY3RsMDAkTXlDb25maWd1cmF0aW9uJGlidG5fZW4FH2N0bDAwJE15Q29uZmlndXJhdGlvbiRpYnRuX2JsdWUFHWN0bDAwJHVjU2VhcmNoQnJpZWYkYnV0U2VhcmNoBRxjdGwwMCR1Y1NlYXJjaEJyaWVmJGNiU3Ryb25nBShjdGwwMCRjcGgkdWNFeHBhbmRlZFNlYXJjaCRjaGJ4X3ByZXNlbmNlBSpjdGwwMCRjcGgkdWNFeHBhbmRlZFNlYXJjaCRjaGJ4X2Vib29rX29ubHkFJmN0bDAwJGNwaCR1Y0V4cGFuZGVkU2VhcmNoJGlidG5fc2VhcmNo1cgzQI9vFgkqtXoXsDkuJSg3AaQ=")."&"
        ."__EVENTVALIDATION=".uri_escape_utf8("/wEWJwKi97uOAwKk45uzDAKrn53qBgKv0c15Ao7Nh64DAsrCy8wCAvWpg6gCAtqxw7sCAu+0w/EKAsr5vdYHAtGrp9EKAtrHyJEGAruenF4CoM2G2QwCweXhtwkCj/3+oQoCseaMgwEC75Ts4w8C0P+khw8C/+fklA8CyuLk3gcC76+a+QoC9P2A/gcC/5HvvgsCnsi78Q0ChZuh9gECsbmp5gMCurqemAcC09yKpg0Cv6z97w4C6rOsqQsCiIvrpgECzeuSlQUC1evalAUC1N7Xzg0CjtXyPAKos4+9AQK11NDDDQLNtOyaCQBBFoDef17geX0X1fU/X9iXc1yd")."&"
        .uri_escape_utf8("ctl00\$cph\$ucGoodTypes\$ddl_goods_type")."=Book&"
        .uri_escape_utf8("ctl00\$cph\$ucExpandedSearch\$tbx_ISBN")."=".uri_escape_utf8($c_isbn)."&"
        .uri_escape_utf8("ctl00\$cph\$ucExpandedSearch\$ibtn_search.x")."=0&"
        .uri_escape_utf8("ctl00\$cph\$ucExpandedSearch\$ibtn_search.y")."=0";

        my $img_site = Functions::Util::get_file_from_url_post($url);

        if ($img_site =~ /<h2>Object moved to.*?Details.aspx%3fid%3d([0-9]+)\">here<\/a>.<\/h2>/) {
            my $bgshop_pic = $1;
            my $tmp_cover = "http://www.bgshop.ru/image.axd?id=${bgshop_pic}&type=big&goods=Book&theme=standart";

            # выкачиваем превью и смотрим что б она была не заглушкой (по размерам)
            my $file = Functions::Util::get_file_from_url($tmp_cover);
            my ($ox, $oy) = imgsize(\$file);
            if ($ox >= 200) {
                $big_picture = $tmp_cover;
                last;
            }
        }
    }

    # обложка
    if (!$big_picture && $site =~ /link rel=\"image_src\".*?\/multimedia\/books_covers\/c300\/(\d+).jpg\"/) {
        $big_picture = "http://static.ozone.ru/multimedia/books_covers/".$1.".jpg";
    }

    # аннотация
    my $annotation;
    if ($site =~ /\<\!-- Data\[ANNOTATION\] --\>(.+?)<\/td>/s) {
        $annotation = remove_tags($1);
        $annotation = trim($annotation);
    }

    my $importer_hash = {
        name         => $title,
        autors       => $autors,
        contributors => '',
        type         => $type,
        year         => $release_year,
        release_date => '',
        publishers   => $publishers,
        series       => $series,
        cover_type   => $cover_type,
        super_cover  => $super_cover,
        format       => $format,
        pages        => $pages,
        isbn         => $isbn,
        count        => $count,
        language     => $lang,
        plan_date    => '',
        description  => '',
        notes        => '',
        cover_url    => $big_picture,
        annotation   => $annotation,
        siteid       => $ozon_id
    };

    return $importer_hash;
}

# Испортер изданий с Amazon
# Не удалось импортировать книжную серию (недостаток API)
# Через API можно вытянуть только обложку с водяными знаками (вытаскиваем напрямую с Amazon.co.uk)
# Иллюстраторы и первоиздания работают только для англоязычных амазонов
# доделать планы издательств
sub import_edition_amazon {
    my ($amazonid, $amazondomain) = @_;

    my ($title, $autors, $type, $release_year, $publishers, $cover_type, $pages, $isbn, $annotation, $big_picture, $format,
        $contributors, $illustrators, $language, $release_date, $editionfirst, $description, $notes, $plan_date);

    my ($format_h, $format_w);

    unless (    $amazondomain eq "co.uk"
             || $amazondomain eq "de"
             || $amazondomain eq "es"
             || $amazondomain eq "fr"
             || $amazondomain eq "it"
             || $amazondomain eq "ca") {
        $amazondomain = "com";
    }

    my $myEndPoint = "webservices.amazon.".$amazondomain;

    #параметры запроса
    use constant myAWSId          => 'AKIAIJZYLYYRGDYERU4A';
    use constant myAWSSecret      => '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';
    use constant myAssociateTag   => 'fantlab04-20';

    # инициализация
    my $helper = Functions::AmazonAPI->new(
        +Functions::AmazonAPI::kAWSAccessKeyId => myAWSId,
        +Functions::AmazonAPI::kAWSSecretKey   => myAWSSecret,
        +Functions::AmazonAPI::kEndPoint       => $myEndPoint,
    );

    # запрос
    my $request = {
        Service       => 'AWSECommerceService',
        AssociateTag  => myAssociateTag,
        Operation     => 'ItemLookup',
        Version       => '2011-08-01',
        IdType        => 'ASIN',
        ItemId        => $amazonid,
        ResponseGroup => 'Large'
    };

    # Подпись запроса и приведение его к нормальному виду
    my $signedRequest = $helper->sign($request);
    my $queryString   = $helper->canonicalize($signedRequest);
    my $url = "http://" . $myEndPoint . "/onca/xml?" . $queryString;

    # Получение страницы и преобразование ее в XML
    my $ua        = LWP::UserAgent->new;
    my $response  = $ua->get($url);
    my $content   = $response->decoded_content;
    my $xmlParser = XML::Simple->new;
    my $xml = $xmlParser->XMLin(
        $content,
        ContentKey => '-Content',
        ForceArray => ['Author','Creator','Language']
    );

    # чтение данных из XML
    if ($response->is_success()) {
        $title = $xml->{Items}->{Item}->{ItemAttributes}->{Title};
        $title =~ s/\s\((.*?)\)//; #обрезка названия в скобках (тест)

        # читаем авторов
        foreach my $key ( @{$xml->{Items}->{Item}->{ItemAttributes}->{Author}}) {
            if ( $autors ne '') {  $autors .= ", ".$key; } else {  $autors .= $key; }
        }

        # читаем создателей
        foreach my $key ( @{$xml->{Items}->{Item}->{ItemAttributes}->{Creator}}) {
            if ($key->{Role} eq "Editor" || $key->{Role} eq "Contributor" ) { if ( $contributors ne '') {  $contributors .= ", ".$key->{Content}; } else {  $contributors .= $key->{Content}; } }
            if ($key->{Role} eq "Illustrator") { if ( $illustrators ne '') {  $illustrators .= ", ".$key->{Content}; } else {  $illustrators .= $key->{Content}; } }
        }

        foreach my $key (@{$xml->{Items}->{Item}->{ItemAttributes}->{Languages}->{Language}}) {
            if ($key->{Type} eq "Published" || $key->{Type} eq "Publicado" || $key->{Type} eq "Pubblicato") {
                $language = $key->{Name};
            }
        }

        $release_date = $xml->{Items}->{Item}->{ItemAttributes}->{PublicationDate};
        if ($release_date =~ /(\d{4}).*?/) { $release_year = $1; }
        $publishers = $xml->{Items}->{Item}->{ItemAttributes}->{Publisher};
        $cover_type = $xml->{Items}->{Item}->{ItemAttributes}->{Binding};
        $pages = $xml->{Items}->{Item}->{ItemAttributes}->{NumberOfPages};

        if ($xml->{Items}->{Item}->{ItemAttributes}->{ISBN} ne "" && $xml->{Items}->{Item}->{ItemAttributes}->{EAN} ne "") {
            $isbn = $xml->{Items}->{Item}->{ItemAttributes}->{ISBN} .", ". $xml->{Items}->{Item}->{ItemAttributes}->{EAN};
        }

        $editionfirst = $xml->{Items}->{Item}->{ItemAttributes}->{Edition};
        #$big_picture = $xml->{Items}->{Item}->{LargeImage}->{URL}; (с водяными знаками)

        $format_h = $xml->{Items}->{Item}->{ItemAttributes}->{PackageDimensions}->{Length}->{Content};
        $format_w = $xml->{Items}->{Item}->{ItemAttributes}->{PackageDimensions}->{Width}->{Content};
    }

    # настройки для английских изданий
    if ($amazondomain eq "com" || $amazondomain eq "co.uk" || $amazondomain eq "ca") {
        if ($cover_type eq "Hardcover") { $cover_type = 2; } elsif ($cover_type eq "Paperback" || $cover_type eq "Mass Market Paperback") { $cover_type = 1; }
        if ($editionfirst eq "1" || $editionfirst eq "1st" || $editionfirst eq "First Edition") { $editionfirst = 1; } else { $editionfirst = 0; }
        if ($illustrators ne "") { $description = "Illustrations by $illustrators"}
        if ($language eq "English") { $language = 2; } else { $language = 0; }

        if ($format_h > 0 && $format_w > 0) {
            $format_h = int($format_h/100*25.4);
            $format_w = int($format_w/100*25.4);
            $format .= "${format_w}x${format_h} mm";
            $notes .= "Dimensions: $format";
        }
    }

    # настройки для немецких изданий
    if ($amazondomain eq "de") {
        if ($cover_type eq "Gebundene Ausgabe") { $cover_type = 2; } elsif ($cover_type eq "Taschenbuch" || $cover_type eq "Broschiert") { $cover_type = 1; }
        if ($language eq "Deutsch") { $language = 3; } else { $language = 0; }
    }

    # настройки для испанских изданий
    if ($amazondomain eq "es") {
        if ($cover_type eq "Tapa dura") { $cover_type = 2; } elsif ($cover_type eq "Tapa blanda (reforzada)" || $cover_type eq "Tapa blanda" || $cover_type eq "Tapa blanda (bolsillo) ") { $cover_type = 1; }
        if ($language eq "Español") { $language = 4; } else { $language = 0; }
    }

    # настройки для франзцуских изданий
    if ($amazondomain eq "fr") {
        if ($cover_type eq "Relié") { $cover_type = 2; } elsif ($cover_type eq "Broché" || $cover_type eq "Poche") { $cover_type = 1; }
        if ($language eq "Français") { $language = 5; } else { $language = 0; }
    }

    # настройки для итальянских изданий
    if ($amazondomain eq "it") {
        if ($cover_type eq "Rilegato") { $cover_type = 2; } elsif ($cover_type eq "Brossura") { $cover_type = 1; }
        if ($language eq "Italiano") { $language = 7; } else { $language = 0; }

        if ($format_h > 0 && $format_w > 0) {
            my $format_h = int($format_h/100*25.4);
            my $format_w = int($format_w/100*25.4);
            $format .= "${format_w}x${format_h} mm";
            $notes .= "Edizione formato: $format";
        }
    }

    # планы издательств
    #if ($release_date)
    #{
    #  my ($y,$m,$d) = split ("-", $release_date);
    #  $date_unix = timelocal(0,0,0,$d,$m-1,$y);
    #  if ($date_unix > time) { $plan_date = $release_date; }
    #}

    # Антологии и сборники
    $type = 10;
    if ($contributors) {
        $type = 12;
        $autors = "";
    }

    #импорт картинки
    my $site = Functions::Util::get_file_from_url("http://www.amazon.co.uk/dp/".$amazonid);
    if ($site =~ /http:\/\/ecx.images-amazon.com\/images\/I\/(.+?)\..*?\.jpg/) {
        $big_picture = "http://ecx.images-amazon.com/images/I/".$1.".jpg";
    }

    my $importer_hash = {
        title               => $title,
        autors              => $autors,
        contributors        => $contributors,
        edition_type        => $type,
        release_year        => $release_year,
        release_date        => $release_date,
        publishers          => $publishers,
        series              => '',
        cover_type          => $cover_type,
        super_cover         => '',
        format              => '',
        pages               => $pages,
        isbn                => $isbn,
        count               => '',
        language            => $language,
        plan_date           => $plan_date,
        description         => $description,
        notes               => $notes,
        cover_url           => $big_picture,
        url => $url,
    };

    return $importer_hash;
}

# граббер c isfdb.org
sub import_edition_isfdb {
    my $param_isfdb_id = shift;
    my $sitelink = "http://www.isfdb.org/cgi-bin/pl.cgi?$param_isfdb_id";
    my $site = Functions::Util::get_file_from_url($sitelink);

    my ($title, $autors, $type, $release_year, $publishers, $series, $cover_type, $super_cover, $format, $pages,
        $isbn, $count, $annotation, $big_picture, $contributors, $cover_autor, $release_date, $description);

    # название
    if ($site =~ /<b>Publication:<\/b>\s(.*?)\n/msg) {
        $title = $1;
        $title =~ s/\s\((.*?)\)//; #обрезка названия в скобках (тест)
    }

    # автор
    if ($site =~ /<b>Authors:<\/b>(.*?)<li>/msg) {
        $autors = $1;
        $autors =~ s/<.+?>//g;
        $autors =~ s/\R//g;
        $autors = trim($autors);
    }

    # составители
    if ($site =~ /<b>Editors:<\/b>(.*?)<li>/msg) {
        $contributors = $1;
        $contributors =~ s/<.+?>//g;
        $contributors =~ s/\R//g;
        $contributors = trim($contributors);
    }

    $type = 10;
    if ($contributors) {
        $type = 12;
    }

    # дата издания
    if ($site =~ /<b>Year:<\/b>\s(\d{4}-\d{2}-\d{2})/) {
        $release_date = $1;
    }

    # год
    if ($site =~ /<b>Year:<\/b>\s(\d{4})/) {
        $release_year = $1;
    }

    # издательства
    if ($site =~ /<b>Publisher:<\/b>\s(.*?)\n/) {
        $publishers = $1;
        $publishers =~ s/\s(\/.*?)<\/a>//; #обрезка названия в скобках (тест)
        $publishers =~ s/<.+?>//g;
    }

    # страниц
    if ($site =~ /<b>Pages:<\/b>\s(.*?)\n/) {
        $pages = $1;
        if ($pages =~ /\[(.*?)\]\+(\d{1,4})/) { $pages = parse_roman(uc $1)+$2; }
        if ($pages =~ /(\d{1,4})\+(\d{1,4})/ ) { $pages = $1+$2; }
    }

    # isbn
    my $counter = 0;
    while ($site =~ s/<b>ISBN.*?:<\/b>\s(.*?)\n// and $counter<10) {
        $counter++;
        if ($isbn ne "") { $isbn .= ", ".$1; } else { $isbn .= $1; }
    }

    # обложка (переплет)
    if ($site =~ /<b>Binding:<\/b>\s(.*?)\n/) {
        if ($1 eq "hc") { $cover_type = 2; }
        elsif ($1 eq "tp" || $1 eq "pb") { $cover_type = 1; }
    }

    # обложка (картинка)
    if ($site =~ /<img src=\"(.+?)\".*? height=200/) {
        $big_picture = $1;
    }

    # обложка (художник)
    if ($site =~ /<b>Cover:<\/b>(.*?)<li>/s || $site =~ /<b><a.*>Cover<\/a>:<\/b>(.*?)<li>/s) {
        $cover_autor = $1;
        $cover_autor =~ s/<.+?>//g;
        $cover_autor =~ s/\n\s*//g;
        $description = "Cover art by $cover_autor";
    }

    my $importer_hash = {
        title               => $title,
        autors              => $autors,
        contributors        => $contributors,
        edition_type        => $type,
        release_year        => $release_year,
        release_date        => $release_date,
        publishers          => $publishers,
        series              => '',
        cover_type          => $cover_type,
        super_cover         => '',
        format              => '',
        pages               => $pages,
        isbn                => $isbn,
        count               => '',
        language            => 2,
        plan_date           => '',
        description         => $description,
        notes               => '',
        cover_url           => $big_picture,
    };

    return $importer_hash;
}

# Импорт с Esensja
# сопоставление форматов изданий
# планы издательств
sub import_edition_esensja {
    my $param_esensja_id = shift;
    my $sitelink = "http://esensja.pl/esensjopedia/obiekt.html?rodzaj_obiektu=2&idobiektu=$param_esensja_id";
    my $site = Functions::Util::get_file_from_url($sitelink);

    my ($title, $autors, $type, $release_year, $publishers, $series, $cover_type, $super_cover, $format,
        $pages, $isbn, $count, $annotation, $big_picture, $release_date, $notes, $date_year);

    # название
    if ($site =~ /<td class=\"val\" itemprop=\"name\">(.*?)<\/td>/) {
        $title = $1;
        $title =~ s/<.+?>//g;
    }

    # авторы
    if ($site =~ /<td class=\"val\" itemprop=\"author\">(.*?)<\/td>/) {
        $autors = $1;
        $autors =~ s/<.+?>//g;
    }

    # тип
    $type = 10;

    #год и дата
    if ($site =~ /<td>Data wydania<\/td><td class=\"val\"><meta itemprop=\"datePublished\" content=\"(.*?)\"/) {
        $release_date = $1;
        $release_year = $1;
        $release_year =~ s/-\d{2}//g;
        if ($release_date =~ /\d{4}$/) { $release_date = "$release_date-00-00"; }
    }

    # издательство
    if ($site =~ /<td class=\"val\" itemprop=\"publisher\">(.*?)<\/td>/) {
        $publishers = $1;
        $publishers =~ s/<.+?>//g;
        $publishers = trim($publishers);
    }

    # страницы
    if ($site =~ /<meta itemprop=\"bookFormat\" content=\".*?\" \/>(\d+)s.*?<\/td>/) {
        $pages = $1;
    }

    # формат
    if ($site =~ /<meta itemprop=\"bookFormat\" content=\".*?\" \/>.*?\s(\d{3}.*?)mm.*?<\/td>/ || $site =~ /<meta itemprop=\"bookFormat\" content=\".*?\" \/>(\d{3}.*?)mm.*?<\/td>/) {
        if ($1 eq "125×195" || $2 eq "125x195") {
            $format = "84x108/32";
        }
        else {
          $notes = "Format: $1mm";
        }
    }

    # тип обложки
    if ($site =~ /<meta itemprop=\"bookFormat\" content=\"(.*?)\" \/>/) {
        if ($1 eq "Paperback") { $cover_type = 1; } elsif ($1 eq "Hardcover") { $cover_type = 2; }
    }

    # суперобложка
    $super_cover = 0;
    if ($site =~ /<meta itemprop=\"bookFormat\" content=\".*?\" \/>.*?obwoluta/) {
        $super_cover = 1;
    }

    # isbn
    if ($site =~ /<td class=\"val\" itemprop=\"isbn\">(.*?)<\/td>/) {
        $isbn = $1;
    }

    # обложка
    if ($site =~ /<img class=\"img\" border=1 src=\"(.+?)\".*? /) {
        $big_picture = 'http://esensja.pl'.$1;
    }

    my $importer_hash = {
        title               => $title,
        autors              => $autors,
        contributors        => '',
        edition_type        => $type,
        release_year        => $release_year,
        release_date        => $release_date,
        publishers          => $publishers,
        series              => '',
        cover_type          => $cover_type,
        super_cover         => $super_cover,
        format              => $format,
        pages               => $pages,
        isbn                => $isbn,
        count               => '',
        language            => 22,
        plan_date           => '',
        description         => '',
        notes               => '',
        cover_url           => $big_picture,
    };

    return $importer_hash;
}

# граббер c bgshop.ru (deprecated)
# доделать определение типа обложки, импорт формата книги
sub import_edition_bgshop {
    my $param_bgshop_id = shift;
    my $sitelink = "http://www.bgshop.ru/Details.aspx?id=$param_bgshop_id";
    my $site = Functions::Util::get_file_from_url($sitelink);

    my ($title, $autors, $type, $release_year, $publishers, $series, $cover_type, $super_cover, $format, $pages, $isbn, $count, $annotation, $big_picture);

    # название
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lblGood_Title\".*?>(.*?)<\/span>/) {
        $title = $1;
        $title = remove_tags($title);
    }

    # автор
    if ($site =~ /<a id=\"ctl00_cph_ucGoodCard_AuthorSpecializedSearch_lbt_Search\".*?>(.+?)<\/a>/) {
        $autors = $1;
        $autors = trim($autors);
    }

    # год
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lbl_DatePublication\">(.+?)<\/span>/) {
        $release_year = $1;
    }

    # издательства
    if ($site =~ /<a id=\"ctl00_cph_ucGoodCard_PublisherSpecializedSearch_lbt_Search\".*?>(.+?)<\/a>/) {
        $publishers = $1;
        $publishers = trim($publishers);
        $publishers = remove_tags($publishers);
    }

    # серия
    if ($site =~ /<a id=\"ctl00_cph_ucGoodCard_SeriaSpecializedSearch_lbt_Search\".*?>(.+?)<\/a>/) {
        $series = $1;
        $series = remove_tags($series);
        $series = trim($series);
    }

    # переплет
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lbl_coverType\".*?>(.+?)<\/span>/) {
        $cover_type = $1;
        $cover_type =~ s/\(.+?\)//g;
        $cover_type = trim($cover_type);
        if ($cover_type eq "мягкая обложка") { $cover_type = 1; }
        elsif ($cover_type eq "тв. переплет") { $cover_type = 2; }
    }

    # формат
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lbl_Size\">(.+?)\(см\)<\/span>/) {
        my $format_ = $1;
        if ($format_ eq "13X21") { $format = "84x108/32"; }
    }

    # страниц
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lbl_CountPage\">([0-9]+)\sстр.<\/span>/) {
        $pages = $1;
    }

    # isbn
    if ($site =~ /<span id=\"ctl00_cph_ucGoodCard_lbl_IsbnAsIs\">(.+?)<\/span>/) {
       $isbn = $1;
    }

    # обложка
    if ($site =~ /<img id=\"ctl00_cph_ucGoodCard_img_title\" src=\"(.+?)\".*?>/) {
        $big_picture = "http://www.bgshop.ru/$1";

        # выкачтваем превью и смотрим что б она была не заглушкой (по размерам)
        my $file = Functions::Util::get_file_from_url("http://www.bgshop.ru/image.axd?id=".$param_bgshop_id."&type=small&goods=Book&theme=standart");
        my $image = Image::Magick->New();
        $image->BlobToImage($file);
        my ($ox,$oy)=$image->Get('base-columns','base-rows');
        if ($ox==71 and $oy==77) { $big_picture = ""; }
    }

    my $importer_hash = {
        title               => $title,
        autors              => $autors,
        contributors        => '',
        edition_type        => 10,
        release_year        => $release_year,
        release_date        => '',
        publishers          => $publishers,
        series              => $series,
        cover_type          => $cover_type,
        super_cover         => 0,
        format              => $format,
        pages               => $pages,
        isbn                => $isbn,
        count               => '',
        language            => 1,
        plan_date           => '',
        description         => '',
        notes               => '',
        cover_url           => $big_picture,
    };

    return $importer_hash;
}

sub import_kinopoisk {
    my $film_id = shift;

    # получение контента сайта
    my $site = Functions::Util::get_file_from_url("http://www.kinopoisk.ru/film/$film_id");
    my $dom =  Mojo::DOM->new($site);

    my $rusname = $dom->find('h1[itemprop=name]')->map('text')->join;
    my $origname = $dom->find('span[itemprop=alternativeHeadline]')->map('text')->join;

    # слоган
    my $tagline;
    if ($dom =~ /type\">слоган.+\>.+\>(.*)\<\/td>/) {
        if($1 ne "-") { $tagline = $1; }
    }

    # год
    my $release_year;
    my $serial_seasons_count;
    if ($dom =~ /type\".*?>год.+?\>.+?\>(.*?)<\/td>/igs) {
        $release_year = $1;
        if ($release_year =~ /\((\d+)\sсезон.+?\)/) { $serial_seasons_count = $1; } # получение количества сезонов у сериалов
        $release_year =~ s/\(.+?\)//g;  # удалить кол-во сезонов у сериалов
        $release_year = remove_tags($release_year);
        $release_year = trim($release_year);
    }

    # страны
    my $countries;
    if ($dom =~ /type\".*?>страна.+?\>.+?\>(.*?)<\/td>/igs) {
        $countries = $1;
        $countries = remove_tags($countries);
        $countries = trim($countries);
    }

    # продолжительность
    my $runtime;
    if ($dom =~ /type\">время.+?\>.+?\>(\d+).*?\<\/td>/) {
        $runtime = $1;
        $runtime = remove_tags($runtime);
        $runtime = trim($runtime);
    }

    my $budget;
    if ($dom =~ /type\".*?>бюджет.+?\>.+?\>(.*?)\<\/td>/igs) {
        $budget = $1;
        $budget = remove_tags($budget);
        $budget = trim($budget);
        $budget =~ s/\s//g; # удаление пробелов
    }

    # премьера
    my $release_world;
    if ($dom =~ /type\".*?>премьера \(мир\).+?\>.+?\>(.*?)\<\/a>/igs) {
        $release_world = $1;
        $release_world =~ s/&nbsp;/ /g; # замена пробелов
        $release_world = remove_tags($release_world);
        $release_world = trim($release_world);
    }

    my $release_russia;
    if ($dom =~ /type\".*?>премьера \(РФ\).+?\>.+?\>(.*?)\<\/a>/igs) {
        $release_russia = $1;
        $release_russia =~ s/&nbsp;/ /g; # замена пробелов
        $release_russia = remove_tags($release_russia);
        $release_russia = trim($release_russia);
    }

    my $release_digital;
    if ($dom =~ /type\".*?>релиз на DVD.+?\>.+?\>(.*?)\<\/a>/igs) {
        $release_digital = $1;
        $release_digital = remove_tags($release_digital);
        $release_digital = trim($release_digital);
    }

    # жанры
    my @genres;
    $dom->find('td[itemprop=genre] a')->each( sub { my $text = shift->text; last if $text eq "..."; push (@genres, $text) } );
    my $genre = join(', ', @genres);
    my $fant = 1 if ($genre =~ /(фантастика|фэнтези)/);

    # режиссеры
    my @directors;
    $dom->find('td[itemprop=director] a')->each( sub { my $text = shift->text; last if $text eq "..."; push (@directors, $text) } );
    my $director = join(', ', @directors);

    # продюсеры
    my @producers;
    $dom->find('td[itemprop=producer] a')->each( sub { my $text = shift->text; last if $text eq "..."; push (@producers, $text) } );
    my $producer = join(', ', @producers);

    # сценаристы
    my $screenwriter;
    if ($dom =~ /type\">режиссер.+?\>\<a .+?\>(.*?)\<\/td>/) {
        $screenwriter = $1;
        $screenwriter = remove_tags($screenwriter);
        $screenwriter = trim($screenwriter);
    }

    # актеры
    my @actors;
    $dom->find('li[itemprop=actors] a')->each( sub { my $text = shift->text; last if $text eq "..."; push (@actors, $text) } );
    my $cast = join(', ', @actors);

    my $description = $dom->find('div[itemprop=description]')->map('text')->join;
    my $notes = $dom->find('div[itemprop=description]')->map('text')->join;
    my $content_rating = $dom->find('meta[itemprop=contentRating]')->[0]->{content};
    my $rating_ball = $dom->find('.rating_ball')->map('text')->join;

    my $rating_count = $dom->find('span[itemprop=ratingCount]')->map('text')->join;
    $rating_count =~ s/\s//;

    my $cover_url = $dom->find('img[itemprop=image]')->[0]->{src};

    # TODO: тип фильма
    my $movie_type = 10;

    # сериал
    my $rusname_add = remove_tags($dom->find('h1[itemprop=name] span'));
    my $serial_year_end;

    if ($rusname_add =~ /\(сериал/) {
        $movie_type = 20;
        if ($rusname_add =~ /\(сериал\s\d+\s\–\s(\d{4})\)/) {
            $serial_year_end = $1;
        }
    }

    # получить imdb id
    my $imdb_site = Functions::Util::get_file_from_url("http://www.imdb.com/find?s=all&q=$origname%20$release_year");
    my $imdb_id;
    if ($imdb_site =~ /<td class=\"result_text\"> <a href=\"\/title\/tt(\d+)\/\?.*>$origname<\/a>\s\($release_year\)\s<\/td>/) {
        $imdb_id = $1;
    }

    # TODO: получить kinoafisha id
    my $kinoafisha_id = 0;

    # TODO: получить kinogovno id
    my $kinogovno_id = 0;

    # TODO: получить wikipedia id
    my $wikipedia_id = 0;

    # TODO: получить worldart id
    my $worldart_id = 0;

    my $importer_hash = {
        rusname                 => $rusname,
        origname                => $origname,
        tagline                 => $tagline,
        countries               => $countries,
        runtime                 => $runtime,
        release_year            => $release_year,
        release_world           => $release_world,
        release_russia          => $release_russia,
        release_digital         => $release_digital,
        budget                  => $budget,
        genre                   => $genre,
        director                => $director,
        producer                => $producer,
        screenwriter            => $screenwriter,
        cast                    => $cast,
        description             => $description,
        cover_url               => $cover_url,
        content_rating          => $content_rating,
        rating_ball             => $rating_ball,
        rating_count            => $rating_count,
        fant                    => $fant,
        movie_type              => $movie_type,
        kinopoisk_id            => $film_id,
        imdb_id                 => $imdb_id,
        kinoafisha_id           => $kinoafisha_id,
        kinogovno_id            => $kinogovno_id,
        wikipedia_id            => $wikipedia_id,
        worldart_id             => $worldart_id,
        serial_year_end         => $serial_year_end,
        serial_seasons_count    => $serial_seasons_count,

        rusname                 => $site,
    };

    return $importer_hash;
}




# преобразование римских чисел
sub parse_roman_helper {
    my ($fragment, $d) = shift;
    return 0 unless $fragment;

    if ($d==1) {
        $fragment=~tr/XLC/IVX/;
    }
    elsif ($d==2) {
        $fragment=~tr/CDM/IVX/;
    }
    elsif ($d==3) {
        $fragment=~tr/M/I/;
    }

    $d=10**$d;
    return $d*length($fragment) if $fragment=~m/^I{1,3}$/;
    return $d*4 if $fragment eq 'IV';
    return $d*(4+length($fragment)) if $fragment=~m/^VI{0,3}$/;
    return $d*9;
}

# преобразование римских чисел
sub parse_roman {
    if(shift=~m/^(M{0,3})(D?C{0,3}|C[DM])(L?X{0,3}|X[LC])(V?I{0,3}|I[VX])$/) {
        return parse_roman_helper($1, 3)
            +parse_roman_helper($2, 2)
            +parse_roman_helper($3, 1)
            +parse_roman_helper($4, 0);
    }
    return;
}

sub remove_tags {
    my $text = shift;
    $text =~ s/<.+?>//g;
    return $text;
}

1;